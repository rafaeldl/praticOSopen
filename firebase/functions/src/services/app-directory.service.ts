/**
 * Customers and devices for the web app (/v1/app/customers, /v1/app/devices).
 *
 * Reads that depend on orders follow firestore.rules, like GET /orders: who has
 * `viewAllOrders` counts every order; consultant and technician only the ones
 * they created (the technician also the ones assigned to them). The app runs
 * the same queries without that filter, the rules deny them and the screen
 * shows nothing or an error (fatia 03, defects 1, 2 and 9). Here the answer is
 * partial and says so (`partial`).
 *
 * Without `viewPrices` no money leaves: the order rows go through
 * projectOrderSummary and the totals are null.
 */
import { db, FieldValue, getTenantCollection } from './firestore.service';
import type { Order, UserAggr, CompanyAggr } from '../models/types';
import { projectOrderSummary } from './order-projection';
import { generatePhoneKeywords, generateSearchKeywords } from '../utils/search.utils';
import { timestampToDate } from '../utils/date.utils';
import { orderVersion, versionMatches } from './order-version';
import { OrderRuleError } from './order-errors';

type Json = Record<string, unknown>;

/** Upper bound of a company list read in one call. The biggest company has ~1.500 customers. */
export const DIRECTORY_LIMIT = 5000;
/** Orders read for one customer or device screen. */
const ORDERS_LIMIT = 500;

export interface OrderScope {
  /** Every order (viewAllOrders). */
  all: boolean;
  userId: string;
  /** The technician also reads the orders assigned to them (isOrderAssignee). */
  assigned: boolean;
}

type Query = FirebaseFirestore.Query;

/** Runs `build` once per slice the scope may read and merges by id. */
export async function scopedOrders(companyId: string, scope: OrderScope, build: (base: Query) => Query[]): Promise<Order[]> {
  const orders = getTenantCollection(companyId, 'orders') as unknown as Query;
  const bases: Query[] = scope.all
    ? [orders]
    : [
      orders.where('createdBy.id', '==', scope.userId),
      ...(scope.assigned ? [orders.where('assignedTo.id', '==', scope.userId)] : []),
    ];
  const snapshots = await Promise.all(bases.flatMap(build).map((query) => query.get()));
  const byId = new Map<string, Order>();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) byId.set(doc.id, { ...(doc.data() as Order), id: doc.id });
  }
  return [...byId.values()];
}

const time = (value: unknown): number => timestampToDate(value as string | undefined)?.getTime() ?? 0;
export const newestFirst = (a: Order, b: Order) => time(b.createdAt) - time(a.createdAt) || String(b.id).localeCompare(String(a.id));

// ============================================================================
// Customers
// ============================================================================

export interface DirectoryCustomer {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  taxId: string | null;
  address: string | null;
  /** Open orders (approved, progress) the person reads. */
  open: number;
  /** Of those, the ones past the promised date. */
  late: number;
}

const text = (value: unknown): string | null => (typeof value === 'string' && value.trim() ? value : null);

/** Every customer of the company with the order badges of the list. */
export async function customerDirectory(companyId: string, scope: OrderScope, now = new Date()): Promise<{ customers: DirectoryCustomer[]; truncated: boolean }> {
  const [snapshot, open] = await Promise.all([
    getTenantCollection(companyId, 'customers').limit(DIRECTORY_LIMIT + 1).get(),
    scopedOrders(companyId, scope, (base) => [base.where('status', 'in', ['approved', 'progress'])]),
  ]);
  const badges = new Map<string, { open: number; late: number }>();
  for (const order of open) {
    const id = order.customer?.id;
    if (!id) continue;
    const badge = badges.get(id) ?? { open: 0, late: 0 };
    badge.open++;
    const due = timestampToDate(order.dueDate as string | undefined);
    if (due && due.getTime() < now.getTime()) badge.late++;
    badges.set(id, badge);
  }
  const customers = snapshot.docs.slice(0, DIRECTORY_LIMIT).map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: String(data.name ?? ''),
      phone: text(data.phone),
      email: text(data.email),
      taxId: text(data.taxId),
      address: text(data.address),
      ...(badges.get(doc.id) ?? { open: 0, late: 0 }),
    };
  });
  return { customers, truncated: snapshot.docs.length > DIRECTORY_LIMIT };
}

/** Devices of a list of orders, with how many orders each one is in (distinctVehicles). */
function devicesOf(orders: Order[]): { id: string; name: string; serial: string | null; count: number }[] {
  const found = new Map<string, { id: string; name: string; serial: string | null; count: number }>();
  for (const order of orders) {
    const list = order.devices?.length ? order.devices : order.device ? [order.device] : [];
    const seen = new Set<string>();
    for (const device of list) {
      if (!device?.id || seen.has(device.id)) continue;
      seen.add(device.id);
      const current = found.get(device.id) ?? { id: device.id, name: String(device.name ?? ''), serial: device.serial ?? null, count: 0 };
      current.count++;
      found.set(device.id, current);
    }
  }
  return [...found.values()].sort((a, b) => a.name.localeCompare(b.name));
}

/** "gastou" (customer_utils totalSpent): total of the done orders. */
export function totalSpent(orders: Pick<Order, 'status' | 'total'>[]): number {
  return round(orders.filter((o) => o.status === 'done').reduce((sum, o) => sum + (o.total ?? 0), 0));
}

/** "falta receber" (customerOwed): what is left on orders that are not quotes, canceled or paid, of any month. */
export function customerOwed(orders: Pick<Order, 'status' | 'total' | 'paidAmount' | 'payment'>[]): number {
  return round(
    orders
      .filter((o) => o.status !== 'quote' && o.status !== 'canceled' && o.payment !== 'paid')
      .reduce((sum, o) => sum + Math.max((o.total ?? 0) - (o.paidAmount ?? 0), 0), 0),
  );
}

const round = (value: number) => Math.round(value * 100) / 100;

export interface CustomerScreen {
  customer: Json;
  /** Opaque version (order-version.ts), sent back on PATCH. */
  version: string | null;
  orders: Json[];
  /** More than ORDERS_LIMIT: the list, "gastou" and "falta receber" are of the newest ones. */
  ordersTruncated: boolean;
  /** Everything tied to the customer, whoever reads it: told before deleting, without detail. */
  links: { orders: number; receipts: number; charges: number };
  devices: ReturnType<typeof devicesOf>;
  spent: number | null;
  owed: number | null;
  /** Orders the person may receive on, oldest first (customer.detail.receive). */
  receivable: string[];
  partial: boolean;
}

export async function customerScreen(
  companyId: string,
  customerId: string,
  scope: OrderScope,
  options: { showPrices: boolean; canReceive: (order: Order) => boolean },
): Promise<CustomerScreen | null> {
  // Newest first (indexes customer.id + createdAt, also with createdBy / assignedTo), one more to know it was cut.
  const count = (name: string) =>
    (getTenantCollection(companyId, name) as unknown as Query).where('customer.id', '==', customerId).count().get().then((result) => result.data().count);
  const [snapshot, scoped, ordersTotal, receipts, charges] = await Promise.all([
    getTenantCollection(companyId, 'customers').doc(customerId).get(),
    scopedOrders(companyId, scope, (base) => [base.where('customer.id', '==', customerId).orderBy('createdAt', 'desc').limit(ORDERS_LIMIT + 1)]),
    count('orders'),
    count('receipts'),
    count('customerCharges'),
  ]);
  if (!snapshot.exists) return null;
  scoped.sort(newestFirst);
  const ordersTruncated = scoped.length > ORDERS_LIMIT;
  const orders = scoped.slice(0, ORDERS_LIMIT);
  const data = snapshot.data() ?? {};
  const owedOrders = orders.filter((o) => o.status !== 'quote' && o.status !== 'canceled' && o.payment !== 'paid' && (o.total ?? 0) - (o.paidAmount ?? 0) > 0);
  return {
    customer: {
      id: snapshot.id,
      name: String(data.name ?? ''),
      phone: text(data.phone),
      email: text(data.email),
      taxId: text(data.taxId),
      address: text(data.address),
      latitude: typeof data.latitude === 'number' ? data.latitude : null,
      longitude: typeof data.longitude === 'number' ? data.longitude : null,
      customData: data.customData && typeof data.customData === 'object' ? data.customData : null,
    },
    version: orderVersion(data.updatedAt),
    orders: orders.map((o) => projectOrderSummary(o, options.showPrices)),
    ordersTruncated,
    links: { orders: ordersTotal, receipts, charges },
    devices: devicesOf(orders),
    spent: options.showPrices ? totalSpent(orders) : null,
    owed: options.showPrices ? customerOwed(orders) : null,
    receivable: options.showPrices ? owedOrders.filter(options.canReceive).reverse().map((o) => o.id as string) : [],
    partial: !scope.all,
  };
}

export interface CustomerInput {
  name?: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  taxId?: string | null;
  customData?: Record<string, unknown> | null;
}

/** Fields of a write. `customData` is replaced whole: the web sends every field, without the legacy keys. */
function customerFields(input: CustomerInput, current: Json = {}): Json {
  const out: Json = {};
  for (const key of ['phone', 'email', 'address', 'taxId'] as const) {
    if (input[key] !== undefined) out[key] = input[key] === '' ? null : input[key];
  }
  if (input.customData !== undefined) out.customData = input.customData && Object.keys(input.customData).length ? input.customData : null;
  if (input.name !== undefined) {
    out.name = input.name;
    out.nameLower = input.name.toLowerCase();
  }
  if (input.name !== undefined || input.phone !== undefined) {
    const name = (input.name ?? current.name ?? '') as string;
    const phone = (input.phone !== undefined ? input.phone : current.phone) as string | undefined;
    out.keywords = [...generateSearchKeywords(name), ...generatePhoneKeywords(phone ?? undefined)];
  }
  return out;
}

export async function createCustomer(companyId: string, input: CustomerInput & { name: string }, createdBy: UserAggr, company: CompanyAggr, id?: string): Promise<{ id: string; created: boolean }> {
  const collection = getTenantCollection(companyId, 'customers');
  const ref = id ? collection.doc(id) : collection.doc();
  const now = new Date().toISOString();
  const data = { phone: null, email: null, address: null, taxId: null, ...customerFields(input), company, createdBy, createdAt: now, updatedBy: createdBy, updatedAt: now };
  try {
    await ref.create(data);
    return { id: ref.id, created: true };
  } catch (error) {
    // Same id again (an import repeated after a network failure): already there.
    if (id && (error as { code?: number }).code === 6) return { id: ref.id, created: false };
    throw error;
  }
}

/**
 * `version`: what the person saw (GET). Another save since then (web or app)
 * refuses with 409 CUSTOMER_CHANGED and writes nothing. Returns the new version.
 */
export async function updateCustomer(companyId: string, customerId: string, input: CustomerInput, updatedBy: UserAggr, version?: string): Promise<string | null | false> {
  const ref = getTenantCollection(companyId, 'customers').doc(customerId);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return false;
    if (version !== undefined && !versionMatches(snapshot.data()?.updatedAt, version)) {
      throw new OrderRuleError('CUSTOMER_CHANGED', 409, 'The customer changed since it was read');
    }
    const updatedAt = new Date().toISOString();
    tx.update(ref, { ...customerFields(input, snapshot.data() ?? {}), updatedBy, updatedAt });
    return updatedAt;
  });
}

/**
 * Deletes the customer. Orders keep their embedded copy, as in the app. Devices
 * whose next maintenance pointed to this customer keep the name and lose the id,
 * so "Chamar cliente" does not look up a customer that no longer exists.
 */
export async function deleteCustomer(companyId: string, customerId: string): Promise<boolean> {
  const ref = getTenantCollection(companyId, 'customers').doc(customerId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return false;
  const devices = await getTenantCollection(companyId, 'devices').where('nextMaintenanceCustomer.id', '==', customerId).get();
  const batch = db.batch();
  for (const doc of devices.docs) {
    const name = (doc.data().nextMaintenanceCustomer as { name?: string } | undefined)?.name;
    batch.update(doc.ref, { nextMaintenanceCustomer: name ? { name } : FieldValue.delete() });
  }
  batch.delete(ref);
  await batch.commit();
  return true;
}

// ============================================================================
// Devices
// ============================================================================

export const DEVICE_STATUSES = ['active', 'maintenance', 'inactive', 'decommissioned'] as const;

export async function deviceDirectory(companyId: string): Promise<{ devices: Json[]; truncated: boolean }> {
  const snapshot = await getTenantCollection(companyId, 'devices').limit(DIRECTORY_LIMIT + 1).get();
  const devices = snapshot.docs.slice(0, DIRECTORY_LIMIT).map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: text(data.name),
      serial: text(data.serial),
      manufacturer: text(data.manufacturer),
      category: text(data.category),
      status: text(data.status),
      photo: text(data.photo),
      nextMaintenanceDate: text(data.nextMaintenanceDate),
    };
  });
  return { devices, truncated: snapshot.docs.length > DIRECTORY_LIMIT };
}

/** Orders that have the device: `deviceIds` and the legacy single `device`. */
async function ordersOfDevice(companyId: string, deviceId: string, scope: OrderScope): Promise<Order[]> {
  const orders = await scopedOrders(companyId, scope, (base) => [
    base.where('deviceIds', 'array-contains', deviceId).limit(ORDERS_LIMIT),
    base.where('device.id', '==', deviceId).limit(ORDERS_LIMIT),
  ]);
  return orders.sort(newestFirst);
}

/** First service of the order on this device (a line without device counts for all). */
function mainService(order: Order, deviceId: string): string | null {
  for (const line of order.services ?? []) {
    if (line.deviceId && line.deviceId !== deviceId) continue;
    const name = line.service?.name || line.description;
    if (name) return name;
  }
  return null;
}

/** Owner (customer of the newest order) and main service of the newest done order. */
async function deviceHistory(companyId: string, deviceId: string): Promise<{ owner: { id: string; name: string } | null; lastService: string | null }> {
  const orders = await ordersOfDevice(companyId, deviceId, { all: true, userId: '', assigned: false });
  const newest = orders.find((o) => o.customer?.id);
  const done = orders.find((o) => o.status === 'done');
  return {
    owner: newest?.customer?.id ? { id: newest.customer.id, name: String(newest.customer.name ?? '') } : null,
    lastService: done ? mainService(done, deviceId) : null,
  };
}

export async function deviceScreen(companyId: string, deviceId: string, scope: OrderScope, showPrices: boolean): Promise<Json | null> {
  const [snapshot, orders, history] = await Promise.all([
    getTenantCollection(companyId, 'devices').doc(deviceId).get(),
    ordersOfDevice(companyId, deviceId, scope),
    // The owner is customer data, which every member reads: from all orders, not only the person's.
    deviceHistory(companyId, deviceId),
  ]);
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  return {
    version: orderVersion(data.updatedAt),
    device: {
      id: snapshot.id,
      name: text(data.name),
      serial: text(data.serial),
      manufacturer: text(data.manufacturer),
      category: text(data.category),
      description: text(data.description),
      status: text(data.status),
      photo: text(data.photo),
      customData: data.customData && typeof data.customData === 'object' ? data.customData : null,
      nextMaintenanceDate: text(data.nextMaintenanceDate),
      nextMaintenanceCustomer: data.nextMaintenanceCustomer ?? null,
      nextMaintenanceLastService: text(data.nextMaintenanceLastService),
    },
    orders: orders.map((o) => projectOrderSummary(o, showPrices)),
    owner: history.owner,
    lastService: history.lastService,
    partial: !scope.all,
  };
}

export interface DeviceInput {
  name?: string | null;
  serial?: string | null;
  manufacturer?: string | null;
  category?: string | null;
  description?: string | null;
  status?: string | null;
  customData?: Record<string, unknown> | null;
}

function deviceFields(input: DeviceInput, current: Json = {}): Json {
  const out: Json = {};
  for (const key of ['name', 'manufacturer', 'category', 'description', 'status'] as const) {
    if (input[key] !== undefined) out[key] = input[key] === '' ? null : input[key];
  }
  // Serial: trimmed and uppercase (device.form.serial-rules).
  if (input.serial !== undefined) out.serial = input.serial ? input.serial.trim().toUpperCase() || null : null;
  if (input.customData !== undefined) out.customData = input.customData && Object.keys(input.customData).length ? input.customData : null;
  if (input.name !== undefined) out.nameLower = typeof out.name === 'string' ? out.name.toLowerCase() : null;
  if (input.name !== undefined || input.serial !== undefined || input.manufacturer !== undefined) {
    const pick = (key: string) => (key in out ? out[key] : current[key]) as string | undefined;
    out.keywords = [...generateSearchKeywords(pick('name') ?? undefined), ...generateSearchKeywords(pick('serial') ?? undefined), ...generateSearchKeywords(pick('manufacturer') ?? undefined)];
  }
  return out;
}

export async function createDevice(companyId: string, input: DeviceInput, createdBy: UserAggr, company: CompanyAggr): Promise<{ id: string; name: string | null; serial: string | null }> {
  const ref = getTenantCollection(companyId, 'devices').doc();
  const now = new Date().toISOString();
  const fields = deviceFields(input);
  await ref.create({ name: null, serial: null, manufacturer: null, category: null, description: null, ...fields, company, createdBy, createdAt: now, updatedBy: createdBy, updatedAt: now });
  return { id: ref.id, name: (fields.name as string | null) ?? null, serial: (fields.serial as string | null) ?? null };
}

/** Never touches the next maintenance fields: only setNextMaintenance writes them. */
export async function updateDevice(companyId: string, deviceId: string, input: DeviceInput, updatedBy: UserAggr, version?: string): Promise<'ok' | 'not_found' | 'empty'> {
  const ref = getTenantCollection(companyId, 'devices').doc(deviceId);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return 'not_found' as const;
    const current = snapshot.data() ?? {};
    if (version !== undefined && !versionMatches(current.updatedAt, version)) {
      throw new OrderRuleError('DEVICE_CHANGED', 409, 'The device changed since it was read');
    }
    const fields = deviceFields(input, current);
    const name = 'name' in fields ? fields.name : current.name;
    const serial = 'serial' in fields ? fields.serial : current.serial;
    if (!name && !serial) return 'empty' as const;
    tx.update(ref, { ...fields, updatedBy, updatedAt: new Date().toISOString() });
    return 'ok' as const;
  });
}

export async function deleteDevice(companyId: string, deviceId: string): Promise<boolean> {
  const ref = getTenantCollection(companyId, 'devices').doc(deviceId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return false;
  await ref.delete();
  return true;
}

/**
 * Next maintenance of one device (TenantDeviceRepository.setNextMaintenance):
 * the day, who it is for (owner now, or the one already saved) and the main
 * service of the last done order. Changing or removing the day also clears
 * `nextMaintenanceNoticeFor`, so the daily notice counts the new day.
 */
export async function setNextMaintenance(companyId: string, deviceId: string, date: string | null): Promise<boolean> {
  const ref = getTenantCollection(companyId, 'devices').doc(deviceId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return false;
  if (date === null) {
    await ref.update({
      nextMaintenanceDate: FieldValue.delete(),
      nextMaintenanceCustomer: FieldValue.delete(),
      nextMaintenanceLastService: FieldValue.delete(),
      nextMaintenanceNoticeFor: FieldValue.delete(),
    });
    return true;
  }
  const history = await deviceHistory(companyId, deviceId);
  await ref.update({
    nextMaintenanceDate: date,
    ...(history.owner ? { nextMaintenanceCustomer: history.owner } : {}),
    nextMaintenanceLastService: history.lastService ?? FieldValue.delete(),
    nextMaintenanceNoticeFor: FieldValue.delete(),
  });
  return true;
}

/** Today in Brazil, `YYYY-MM-DD` (the day the daily notice also uses). */
export function todayInBrazil(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}
