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
import { countOrder, customerOwed, OPEN_STATUSES, type CustomerCounts, type SummaryOrder } from './customer-summary';
import { dayIn, instantOf } from '../utils/company-zone';
import { orderVersion, versionMatches } from './order-version';
import { dateMillis } from './customer-activity.service';
import { OrderRuleError } from './order-errors';
import { deletePhotoFileIn, recordPhotoFolder, storagePathOfUrl, type PhotoInput } from './record-photo';

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

/** Orders per page when a list only adds them up. */
const PAGE = 1000;

/**
 * [scopedOrders] for lists that only add the orders up: each slice is read in
 * pages of PAGE with only `fields`, and each order (once, by id) goes to
 * `onOrder`. Nothing of the orders is kept but their ids.
 */
async function eachScopedOrder(
  companyId: string,
  scope: OrderScope,
  build: (base: Query) => Query,
  fields: string[],
  onOrder: (order: SummaryOrder) => void,
): Promise<void> {
  const orders = getTenantCollection(companyId, 'orders') as unknown as Query;
  const bases: Query[] = scope.all
    ? [orders]
    : [
      orders.where('createdBy.id', '==', scope.userId),
      ...(scope.assigned ? [orders.where('assignedTo.id', '==', scope.userId)] : []),
    ];
  const seen = new Set<string>();
  for (const base of bases) {
    const query = build(base).orderBy('__name__').select(...fields);
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    for (;;) {
      const page = await (last ? query.startAfter(last) : query).limit(PAGE).get();
      for (const doc of page.docs) {
        if (seen.has(doc.id)) continue;
        seen.add(doc.id);
        onOrder(doc.data() as SummaryOrder);
      }
      if (page.docs.length < PAGE) break;
      last = page.docs[page.docs.length - 1];
    }
  }
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
  /** Razão social for the nota ("Nota fiscal para" shows it). */
  legalName: string | null;
  address: string | null;
  /** "Em aberto" of the Início (quote, approved, progress) the person reads. */
  open: number;
  /** Of those, the ones past the promised day (by day). */
  late: number;
  /** "Falta receber" (A receber rule); null for who does not read the Financeiro. */
  owed: number | null;
  /** Last activity (UTC ISO): `lastActivityAt`, or the customer's own dates before the backfill. */
  lastActivity: string | null;
}

const text = (value: unknown): string | null => (typeof value === 'string' && value.trim() ? value : null);

/** `lastActivityAt` (customer-activity.service.ts); before the backfill, the most recent of `updatedAt` and `createdAt`. UTC ISO. */
export function lastActivityOf(data: Record<string, unknown>): string | null {
  const stamped = dateMillis(data.lastActivityAt);
  if (stamped != null) return new Date(stamped).toISOString();
  const times = [data.updatedAt, data.createdAt].map(dateMillis).filter((ms): ms is number => ms != null);
  return times.length ? new Date(Math.max(...times)).toISOString() : null;
}

/** Late of a customer from `openDueDates` (customer-aggregates.service.ts): promised days behind today, in the company's zone. */
export function lateOf(openDueDates: unknown, now: Date, zone: string): number {
  if (!Array.isArray(openDueDates)) return 0;
  const today = dayIn(now, zone);
  return openDueDates.filter((value) => {
    const due = instantOf(value, zone);
    return !!due && dayIn(due, zone) < today;
  }).length;
}

const count = (value: unknown): number => (typeof value === 'number' && Number.isFinite(value) ? value : 0);

/**
 * Every customer of the company with the order badges of the list
 * (customer-summary.ts). The numbers come from the customer itself
 * (`openOrders`, `openDueDates`, `owed`, kept by the server:
 * customer-aggregates.service.ts), so who sees every order reads no order.
 * Consultant and technician count only the orders they may read (OrderScope),
 * so for them the open and late still come from those orders. `withOwed`
 * (who reads the Financeiro, that is, every order) adds `owed`.
 */
export async function customerDirectory(
  companyId: string,
  scope: OrderScope,
  options: { zone: string; withOwed: boolean; now?: Date },
): Promise<{ customers: DirectoryCustomer[]; truncated: boolean }> {
  const now = options.now ?? new Date();
  // Only the counts are kept: a big company has thousands of open orders.
  const counts = scope.all ? null : new Map<string, CustomerCounts>();
  const [snapshot] = await Promise.all([
    getTenantCollection(companyId, 'customers')
      .select('name', 'phone', 'email', 'taxId', 'legalName', 'address', 'lastActivityAt', 'updatedAt', 'createdAt', 'openOrders', 'openDueDates', 'owed')
      .limit(DIRECTORY_LIMIT + 1)
      .get(),
    counts
      ? eachScopedOrder(companyId, scope, (base) => base.where('status', 'in', [...OPEN_STATUSES]), ['status', 'customer.id', 'dueDate'], (order) =>
        countOrder(counts, order, now, options.zone))
      : null,
  ]);
  const customers = snapshot.docs.slice(0, DIRECTORY_LIMIT).map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: String(data.name ?? ''),
      phone: text(data.phone),
      email: text(data.email),
      taxId: text(data.taxId),
      legalName: text(data.legalName),
      address: text(data.address),
      ...(counts
        ? counts.get(doc.id) ?? { open: 0, late: 0 }
        : { open: count(data.openOrders), late: lateOf(data.openDueDates, now, options.zone) }),
      owed: options.withOwed ? count(data.owed) : null,
      lastActivity: lastActivityOf(data),
    };
  });
  return { customers, truncated: snapshot.docs.length > DIRECTORY_LIMIT };
}

/**
 * Devices of a list of orders, with how many orders each one is in (distinctVehicles).
 * The orders come newest first, so the device of the latest order comes first:
 * what is in the shop now is on top, not the first name in the alphabet.
 */
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
  return [...found.values()];
}

/** "gastou" (customer_utils totalSpent): total of the done orders. */
export function totalSpent(orders: Pick<Order, 'status' | 'total'>[]): number {
  return round(orders.filter((o) => o.status === 'done').reduce((sum, o) => sum + (o.total ?? 0), 0));
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
  // Receber takes any open order (Debtor.openOrders), not only what counts as owed.
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
      ...invoiceDataOf(data),
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

/** Structured address of the nota (customers/{id}.fiscalAddress, lib/models/fiscal_address.dart). */
export interface FiscalAddress {
  postalCode?: string | null;
  street?: string | null;
  number?: string | null;
  complement?: string | null;
  district?: string | null;
  cityCode?: string | null;
  cityName?: string | null;
  state?: string | null;
}

const FISCAL_ADDRESS_KEYS = ['postalCode', 'street', 'number', 'complement', 'district', 'cityCode', 'cityName', 'state'] as const;

/** "Dados para nota" of a customer as the screens read them (docs/NFSE_DIRECT.md, etapa #568). */
export function invoiceDataOf(data: Json): Json {
  const address = data.fiscalAddress && typeof data.fiscalAddress === 'object' ? (data.fiscalAddress as Json) : null;
  const recipient = data.invoiceRecipient && typeof data.invoiceRecipient === 'object' ? (data.invoiceRecipient as Json) : null;
  return {
    legalName: text(data.legalName),
    fiscalAddress: address ? Object.fromEntries(FISCAL_ADDRESS_KEYS.map((key) => [key, text(address[key])])) : null,
    invoiceEmail: text(data.invoiceEmail),
    invoiceRecipient: recipient && text(recipient.id) ? { id: String(recipient.id), name: String(recipient.name ?? '') } : null,
    autoIssueInvoice: typeof data.autoIssueInvoice === 'boolean' ? data.autoIssueInvoice : null,
  };
}

export interface CustomerInput {
  name?: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  taxId?: string | null;
  customData?: Record<string, unknown> | null;
  legalName?: string | null;
  fiscalAddress?: FiscalAddress | null;
  invoiceEmail?: string | null;
  /** "Nota fiscal para": another customer's id; the server copies its summary. */
  invoiceRecipientId?: string | null;
  autoIssueInvoice?: boolean | null;
}

/** The customer that gets the notas, as the app embeds it (CustomerAggr). */
async function recipientAggr(companyId: string, recipientId: string, selfId: string | null): Promise<Json> {
  if (recipientId === selfId) throw new OrderRuleError('INVOICE_RECIPIENT_INVALID', 400, 'A customer cannot be its own invoice recipient');
  const snapshot = await getTenantCollection(companyId, 'customers').doc(recipientId).get();
  if (!snapshot.exists) throw new OrderRuleError('INVOICE_RECIPIENT_INVALID', 400, 'Invoice recipient not found');
  const data = snapshot.data() ?? {};
  return { id: snapshot.id, name: text(data.name), phone: text(data.phone), email: text(data.email), taxId: text(data.taxId) };
}

/** Writes "Nota fiscal para" from the id the web sends (null takes it off). */
async function withRecipient(companyId: string, selfId: string | null, input: CustomerInput, fields: Json): Promise<Json> {
  if (input.invoiceRecipientId === undefined) return fields;
  return { ...fields, invoiceRecipient: input.invoiceRecipientId === null ? null : await recipientAggr(companyId, input.invoiceRecipientId, selfId) };
}

/** Fields of a write. `customData` is replaced whole: the web sends every field, without the legacy keys. */
function customerFields(input: CustomerInput, current: Json = {}): Json {
  const out: Json = {};
  for (const key of ['phone', 'email', 'address', 'taxId', 'legalName', 'invoiceEmail'] as const) {
    if (input[key] !== undefined) out[key] = input[key] === '' ? null : input[key];
  }
  if (input.autoIssueInvoice !== undefined) out.autoIssueInvoice = input.autoIssueInvoice;
  if (input.fiscalAddress !== undefined) {
    const address = input.fiscalAddress
      ? Object.fromEntries(FISCAL_ADDRESS_KEYS.map((key) => [key, input.fiscalAddress?.[key] || null]).filter(([, value]) => value !== null))
      : {};
    out.fiscalAddress = Object.keys(address).length ? address : null;
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
  const fields = await withRecipient(companyId, ref.id, input, customerFields(input));
  const data = { phone: null, email: null, address: null, taxId: null, ...fields, company, createdBy, createdAt: now, updatedBy: createdBy, updatedAt: now };
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
    const fields = await withRecipient(companyId, customerId, input, customerFields(input, snapshot.data() ?? {}));
    tx.update(ref, { ...fields, updatedBy, updatedAt });
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
  /** Only replaced, never removed (as the app). The route checks it is a file of this device. */
  photo?: PhotoInput;
}

/** Folder the Storage rules give to one device (the app writes photo.jpg there). */
export const devicePhotoFolder = (companyId: string, deviceId: string) => recordPhotoFolder(companyId, 'devices', deviceId);

function deviceFields(input: DeviceInput, current: Json = {}): Json {
  const out: Json = {};
  for (const key of ['name', 'manufacturer', 'category', 'description', 'status'] as const) {
    if (input[key] !== undefined) out[key] = input[key] === '' ? null : input[key];
  }
  // Serial: trimmed and uppercase (device.form.serial-rules).
  if (input.serial !== undefined) out.serial = input.serial ? input.serial.trim().toUpperCase() || null : null;
  if (input.customData !== undefined) out.customData = input.customData && Object.keys(input.customData).length ? input.customData : null;
  if (input.photo) out.photo = input.photo.url;
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
  const fields = deviceFields({ ...input, photo: undefined }); // the photo needs the id (its folder): set afterwards
  await ref.create({ name: null, serial: null, manufacturer: null, category: null, description: null, ...fields, company, createdBy, createdAt: now, updatedBy: createdBy, updatedAt: now });
  return { id: ref.id, name: (fields.name as string | null) ?? null, serial: (fields.serial as string | null) ?? null };
}

/** Never touches the next maintenance fields: only setNextMaintenance writes them. */
export async function updateDevice(companyId: string, deviceId: string, input: DeviceInput, updatedBy: UserAggr, version?: string): Promise<'ok' | 'not_found' | 'empty'> {
  const ref = getTenantCollection(companyId, 'devices').doc(deviceId);
  let replaced: unknown = null;
  const result = await db.runTransaction(async (tx) => {
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
    replaced = input.photo && current.photo !== input.photo.url ? current.photo : null;
    tx.update(ref, { ...fields, updatedBy, updatedAt: new Date().toISOString() });
    return 'ok' as const;
  });
  // The old file goes only when it is another file of this device's folder (photo.jpg overwritten stays).
  if (result === 'ok' && replaced && input.photo) {
    if (storagePathOfUrl(String(replaced)) !== input.photo.storagePath) await deletePhotoFileIn(devicePhotoFolder(companyId, deviceId), replaced, 'device');
  }
  return result;
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
/**
 * Customer and main service of the order that set the date (the app's
 * DeviceMaintenanceService.save): the order's customer, and its first service
 * on this device (a line without device counts for every device).
 */
function fromOrder(order: Record<string, unknown>, deviceId: string): { customer: { id: string; name: string } | null; lastService: string | null } {
  const raw = order.customer as { id?: string; name?: string } | undefined;
  const services = (Array.isArray(order.services) ? order.services : []) as { deviceId?: string | null; description?: string; service?: { name?: string } }[];
  const line = services.find((item) => !item.deviceId || item.deviceId === deviceId);
  const name = (line?.service?.name ?? line?.description ?? '').trim();
  return { customer: raw?.id ? { id: raw.id, name: raw.name ?? '' } : null, lastService: name || null };
}

export async function setNextMaintenance(
  companyId: string,
  deviceId: string,
  date: string | null,
  updatedBy?: UserAggr,
  orderId?: string,
): Promise<boolean | 'ORDER_MISMATCH'> {
  const ref = getTenantCollection(companyId, 'devices').doc(deviceId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return false;
  const audit = { updatedAt: new Date().toISOString(), ...(updatedBy ? { updatedBy } : {}) };
  let source: ReturnType<typeof fromOrder> | null = null;
  if (orderId && date !== null) {
    const order = (await getTenantCollection(companyId, 'orders').doc(orderId).get()).data();
    const ids = new Set<string>([
      ...((order?.deviceIds as string[] | undefined) ?? []),
      ...(((order?.devices as { id?: string }[] | undefined) ?? []).map((item) => item.id ?? '')),
      (order?.device as { id?: string } | undefined)?.id ?? '',
    ]);
    if (!order || !ids.has(deviceId)) return 'ORDER_MISMATCH';
    source = fromOrder(order, deviceId);
  }
  if (date === null) {
    await ref.update({
      ...audit,
      nextMaintenanceDate: FieldValue.delete(),
      nextMaintenanceCustomer: FieldValue.delete(),
      nextMaintenanceLastService: FieldValue.delete(),
      nextMaintenanceNoticeFor: FieldValue.delete(),
    });
    return true;
  }
  const found = source ? null : await deviceHistory(companyId, deviceId);
  const history: { customer: { id: string; name: string } | null; lastService: string | null } = source ?? { customer: found?.owner ?? null, lastService: found?.lastService ?? null };
  await ref.update({
    ...audit,
    nextMaintenanceDate: date,
    ...(history.customer ? { nextMaintenanceCustomer: history.customer } : {}),
    nextMaintenanceLastService: history.lastService ?? FieldValue.delete(),
    nextMaintenanceNoticeFor: FieldValue.delete(),
  });
  return true;
}

/** Today in Brazil, `YYYY-MM-DD` (the day the daily notice also uses). */
export function todayInBrazil(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}
