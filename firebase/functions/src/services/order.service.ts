/**
 * Order Service
 * Business logic for order (OS) operations.
 *
 * Every write that reads the order first runs in a Firestore transaction and
 * accepts `OrderWriteOptions`: a `guard` that checks the permission on the
 * fresh order (the route's check could be stale) and an optional
 * `expectedUpdatedAt` that refuses the write when someone saved in between.
 * Totals are always recomputed from the items (order-items.ts).
 */

import { v4 as uuidv4 } from 'uuid';
import {
  getTenantCollection,
  getDocument,
  updateDocument,
  getNextOrderNumber,
  runTransaction,
} from './firestore.service';
import {
  Order,
  OrderAggr,
  OrderStatus,
  OrderService as OrderServiceItem,
  OrderProduct as OrderProductItem,
  OrderPhoto,
  OrderDocument,
  PaymentTransaction,
  PaymentStatus,
  TransactionType,
  UserAggr,
  CompanyAggr,
  CustomerAggr,
  DeviceAggr,
} from '../models/types';
import * as catalogService from './catalog.service';
import { roundMoney } from '../utils/money';
import { timestampToDate } from '../utils/date.utils';
import { computeOrderTotal, findLine, ItemKind } from './order-items';
import { OrderRuleError } from './order-errors';
import { orderFilesPrefix, ReceiptFileInput, validatePaidAt, validateReceiptFile } from './payment-input';

export { roundMoney };
export { computeOrderTotal, productLineTotal, summarizeItems } from './order-items';

// ============================================================================
// Write options
// ============================================================================

export interface OrderWriteOptions {
  /** Runs on the fresh order inside the transaction; throws (OrderRuleError) to refuse. */
  guard?: (order: Order) => void;
  /** `updatedAt` the client last saw; another value means someone saved in between (409). */
  expectedUpdatedAt?: string;
}

type OrderRef = FirebaseFirestore.DocumentReference;

function orderDoc(companyId: string, orderId: string): OrderRef {
  return getTenantCollection(companyId, 'orders').doc(orderId) as unknown as OrderRef;
}

/** Same instant? Both sides go through the same parse, so ISO strings with or without zone compare alike. */
function sameInstant(stored: unknown, expected: string): boolean {
  const current = timestampToDate(stored as string | undefined)?.getTime();
  return current !== undefined && current === Date.parse(expected);
}

/** Reads the order in [tx], runs the guard and the `expectedUpdatedAt` check. Null when missing. */
export async function readOrderForWrite(
  tx: FirebaseFirestore.Transaction,
  ref: OrderRef,
  options: OrderWriteOptions = {},
): Promise<Order | null> {
  const snap = await tx.get(ref);
  if (!snap.exists) return null;
  const order = { ...(snap.data() as Order), id: snap.id };
  options.guard?.(order);
  if (options.expectedUpdatedAt !== undefined && !sameInstant(order.updatedAt, options.expectedUpdatedAt)) {
    throw new OrderRuleError('ORDER_CHANGED', 409, 'The order changed since it was loaded');
  }
  return order;
}

function audit(actor: UserAggr | undefined, now: string): Record<string, unknown> {
  return { updatedAt: now, ...(actor ? { updatedBy: actor } : {}) };
}

// ============================================================================
// Query Operations
// ============================================================================

export type OrderSort = 'createdAt' | 'updatedAt' | 'dueDate' | 'scheduledDate' | 'number';

export interface OrderQueryParams {
  status?: OrderStatus | OrderStatus[];
  customerId?: string;
  deviceId?: string;
  assignedTo?: string;
  /** Only the orders this user created (consultant and technician). */
  createdById?: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
  offset?: number;
  /** Id of the last order of the previous page. */
  cursor?: string;
  sort?: OrderSort;
  direction?: 'asc' | 'desc';
}

export interface OrderPage {
  data: Order[];
  /** Matching orders; only on the first page (no cursor), it costs a count query. */
  total?: number;
  hasMore: boolean;
  nextCursor?: string | null;
}

const DEFAULT_DIRECTION: Record<OrderSort, 'asc' | 'desc'> = {
  createdAt: 'desc', updatedAt: 'desc', number: 'desc', dueDate: 'asc', scheduledDate: 'asc',
};

/**
 * List orders, newest first by default, with cursor pagination. A query the
 * Firestore indexes do not cover answers UNSUPPORTED_QUERY (400) instead of 500.
 */
export async function listOrders(companyId: string, params: OrderQueryParams): Promise<OrderPage> {
  const collection = getTenantCollection(companyId, 'orders');
  let query: FirebaseFirestore.Query = collection;
  const statuses = params.status === undefined ? [] : Array.isArray(params.status) ? params.status : [params.status];
  if (statuses.length === 1) query = query.where('status', '==', statuses[0]);
  if (statuses.length > 1) query = query.where('status', 'in', statuses);
  if (params.createdById) query = query.where('createdBy.id', '==', params.createdById);
  if (params.customerId) query = query.where('customer.id', '==', params.customerId);
  if (params.deviceId) query = query.where('device.id', '==', params.deviceId);
  if (params.assignedTo) query = query.where('assignedTo.id', '==', params.assignedTo);
  if (params.startDate) query = query.where('createdAt', '>=', new Date(params.startDate).toISOString());
  if (params.endDate) query = query.where('createdAt', '<=', new Date(params.endDate).toISOString());

  const sort = params.sort ?? 'createdAt';
  const direction = params.direction ?? DEFAULT_DIRECTION[sort];
  const limit = params.limit ?? 20;

  try {
    const total = params.cursor ? undefined : (await query.count().get()).data().count;
    let page = query.orderBy(sort, direction).orderBy('__name__', direction);
    if (params.cursor) {
      const last = await collection.doc(params.cursor).get();
      if (!last.exists) throw new OrderRuleError('INVALID_CURSOR', 400, 'Unknown cursor');
      page = page.startAfter(last);
    } else if (params.offset) {
      page = page.offset(params.offset);
    }
    const snapshot = await page.limit(limit + 1).get();
    const docs = snapshot.docs.slice(0, limit);
    const hasMore = snapshot.docs.length > limit;
    return {
      data: docs.map((doc) => ({ ...(doc.data() as Order), id: doc.id })),
      ...(total === undefined ? {} : { total }),
      hasMore,
      nextCursor: hasMore ? docs[docs.length - 1].id : null,
    };
  } catch (error) {
    // FAILED_PRECONDITION: no composite index for this filter + order.
    if ((error as { code?: unknown })?.code === 9) {
      throw new OrderRuleError('UNSUPPORTED_QUERY', 400, 'This combination of filters and order is not supported');
    }
    throw error;
  }
}

/**
 * Get a single order by ID
 */
export async function getOrder(
  companyId: string,
  orderId: string
): Promise<Order | null> {
  const collection = getTenantCollection(companyId, 'orders');
  return getDocument<Order>(collection, orderId);
}

/**
 * Get a single order by its number
 */
export async function getOrderByNumber(
  companyId: string,
  orderNumber: number
): Promise<Order | null> {
  const collection = getTenantCollection(companyId, 'orders');
  const snapshot = await collection
    .where('number', '==', orderNumber)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  return {
    ...doc.data(),
    id: doc.id,
  } as Order;
}

/**
 * Find the most recent order created by `createdById` for `customerId` within
 * the time window. Returns null if none.
 *
 * Used by `POST /bot/orders/full` to dedupe rapid-fire creations (e.g. when two
 * WhatsApp photos arrive in the same burst before the bot's "OS ativa" memory
 * write completes).
 *
 * Index reuse: Firestore query uses only `(customer.id ==, createdAt >=)`,
 * covered by the existing composite index `(customer.id ASC, createdAt DESC)`
 * in firestore.indexes.json. The `createdBy.id` match is post-filtered in
 * memory to avoid requiring a new 3-field composite index. The limit(5) margin
 * is plenty since a single customer rarely gets >1 OS per minute.
 */
export async function findRecentOrderByCustomer(
  companyId: string,
  customerId: string,
  createdById: string,
  sinceMs: number = 60_000
): Promise<Order | null> {
  const collection = getTenantCollection(companyId, 'orders');
  const sinceIso = new Date(Date.now() - sinceMs).toISOString();
  const snapshot = await collection
    .where('customer.id', '==', customerId)
    .where('createdAt', '>=', sinceIso)
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();

  if (snapshot.empty) return null;

  for (const doc of snapshot.docs) {
    const data = doc.data() as Order & { createdBy?: { id?: string } };
    if (data.createdBy?.id === createdById) {
      return { ...data, id: doc.id } as Order;
    }
  }
  return null;
}

/**
 * Get orders by status
 */
export async function getOrdersByStatus(
  companyId: string,
  status: OrderStatus,
  limit = 50
): Promise<Order[]> {
  const collection = getTenantCollection(companyId, 'orders');
  const snapshot = await collection
    .where('status', '==', status)
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Order[];
}

/**
 * Get orders due today
 * Note: Queries use ISO string comparison (works correctly with ISO format)
 */
export async function getOrdersDueToday(
  companyId: string
): Promise<Order[]> {
  const collection = getTenantCollection(companyId, 'orders');
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const snapshot = await collection
    .where('dueDate', '>=', today.toISOString())
    .where('dueDate', '<', tomorrow.toISOString())
    .where('status', 'in', ['approved', 'progress'])
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Order[];
}

/**
 * Get unpaid orders
 */
export async function getUnpaidOrders(
  companyId: string,
  limit = 50
): Promise<Order[]> {
  const collection = getTenantCollection(companyId, 'orders');
  const snapshot = await collection
    .where('paid', '==', false)
    .where('status', '==', 'done')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Order[];
}

/**
 * Get overdue orders: due before today and still open. A quote counts too
 * (the app's Início shows a past-due quote as late, contract overdue.json).
 * Note: Queries use ISO string comparison (works correctly with ISO format)
 */
export async function getOverdueOrders(
  companyId: string
): Promise<Order[]> {
  const collection = getTenantCollection(companyId, 'orders');
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const snapshot = await collection
    .where('dueDate', '<', today.toISOString())
    .where('status', 'in', ['quote', 'approved', 'progress'])
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Order[];
}

// ============================================================================
// Items
// ============================================================================

export interface CatalogItemRef {
  id: string;
  name: string;
  value?: number | null;
  photo?: string | null;
}

export interface NewItemInput {
  kind: ItemKind;
  /** Null: an item without catalog (`service`/`product` null, as the app saves it). */
  catalog: CatalogItemRef | null;
  /** Own price (editPrices). Absent: the catalog price; null: no price. */
  value?: number | null;
  quantity?: number;
  /** Product line total when it differs from value × quantity (editPrices). */
  total?: number | null;
  description?: string;
  deviceId?: string | null;
}

export interface ItemPatch {
  description?: string;
  value?: number | null;
  quantity?: number;
  total?: number | null;
  deviceId?: string | null;
}

export interface ItemWriteOptions extends OrderWriteOptions {
  /** The bot sends device ids it took from the order itself: no check. */
  skipDeviceCheck?: boolean;
}

export interface ItemWriteResult {
  order: Order;
  itemId: string;
  newTotal: number;
}

const isPriced = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

function deviceIdsOf(order: Pick<Order, 'device' | 'devices'>): string[] {
  const ids = (order.devices ?? []).map((d) => d.id);
  if (order.device?.id && !ids.includes(order.device.id)) ids.push(order.device.id);
  return ids;
}

function checkDevice(order: Order, deviceId: string | null | undefined, options: ItemWriteOptions): void {
  if (!deviceId || options.skipDeviceCheck) return;
  if (!deviceIdsOf(order).includes(deviceId)) {
    throw new OrderRuleError('INVALID_DEVICE', 400, 'The device is not on this order');
  }
}

/** A new line: catalog price unless an own value is given; null stays "sem valor". */
export function buildLine(input: NewItemInput): OrderServiceItem | OrderProductItem {
  const { catalog } = input;
  const value = input.value !== undefined ? input.value : isPriced(catalog?.value) ? catalog?.value : null;
  const aggr = catalog
    ? { id: catalog.id, name: catalog.name, value: isPriced(catalog.value) ? catalog.value : null, photo: catalog.photo ?? null }
    : null;
  const base = {
    id: uuidv4(),
    description: input.description?.trim() || catalog?.name || '',
    value: isPriced(value) ? roundMoney(value) : null,
    ...(input.deviceId ? { deviceId: input.deviceId } : {}),
  };
  if (input.kind === 'service') return { ...base, service: aggr } as OrderServiceItem;
  const quantity = input.quantity || 1;
  const line = { ...base, product: aggr, quantity } as OrderProductItem;
  if (isPriced(line.value)) line.total = isPriced(input.total) ? roundMoney(input.total) : roundMoney(line.value * quantity);
  return line;
}

/**
 * `paid`/`payment` after the total changed without money coming in: stamps
 * `paymentSyncedAt`, so the order trigger does not issue a nota for an order
 * that became "paid" because items were removed. Legacy orders without
 * `paidAmount` are left alone (same as syncPaymentStatusWithTotal).
 */
export function paymentSyncUpdate(
  order: Pick<Order, 'status' | 'paid' | 'payment' | 'paidAmount'>,
  total: number,
  now: string,
): Record<string, unknown> {
  if (order.paidAmount === undefined || order.paidAmount === null) return {};
  const { paid, payment } = paymentStatusFields(order.status, total, Number(order.paidAmount) || 0);
  if ((order.paid === true) === paid && (order.payment ?? null) === payment) return {};
  return { paid, payment, paymentSyncedAt: now };
}

function itemsUpdate(
  order: Order,
  services: OrderServiceItem[],
  products: OrderProductItem[],
  actor: UserAggr | undefined,
): Record<string, unknown> & { total: number } {
  const now = new Date().toISOString();
  const total = computeOrderTotal({ services, products, discount: order.discount });
  return { services, products, total, ...audit(actor, now), ...paymentSyncUpdate(order, total, now) };
}

async function mutateItems(
  companyId: string,
  orderId: string,
  actor: UserAggr | undefined,
  options: ItemWriteOptions,
  change: (order: Order, services: OrderServiceItem[], products: OrderProductItem[]) => string,
): Promise<ItemWriteResult | null> {
  const ref = orderDoc(companyId, orderId);
  return runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;
    const services = [...(order.services ?? [])];
    const products = [...(order.products ?? [])];
    const itemId = change(order, services, products);
    const update = itemsUpdate(order, services, products, actor);
    tx.update(ref, update);
    return { order: { ...order, ...update } as Order, itemId, newTotal: update.total };
  });
}

/** Adds a service or product line (transaction; total from the server). Null when the order is missing. */
export async function addOrderItem(
  companyId: string,
  orderId: string,
  input: NewItemInput,
  actor: UserAggr | undefined,
  options: ItemWriteOptions = {},
): Promise<ItemWriteResult | null> {
  return mutateItems(companyId, orderId, actor, options, (order, services, products) => {
    checkDevice(order, input.deviceId, options);
    const line = buildLine(input);
    if (input.kind === 'service') services.push(line as OrderServiceItem);
    else products.push(line as OrderProductItem);
    return line.id as string;
  });
}

/** Changes one line. A line without a stored id gets one (returned as `itemId`). */
export async function updateOrderItem(
  companyId: string,
  orderId: string,
  itemId: string,
  patch: ItemPatch,
  actor: UserAggr | undefined,
  options: ItemWriteOptions = {},
): Promise<ItemWriteResult | null> {
  return mutateItems(companyId, orderId, actor, options, (order, services, products) => {
    const found = findLine(order, itemId);
    if (!found) throw new OrderRuleError('ITEM_NOT_FOUND', 404, 'Item not found');
    if (found.kind === 'service' && (patch.quantity !== undefined || patch.total !== undefined)) {
      throw new OrderRuleError('VALIDATION_ERROR', 400, 'A service has no quantity or line total');
    }
    const line = { ...found.line, id: found.line.id || uuidv4() } as OrderServiceItem & OrderProductItem;
    if (patch.description !== undefined) line.description = patch.description;
    if (patch.deviceId !== undefined) {
      checkDevice(order, patch.deviceId, options);
      line.deviceId = patch.deviceId;
    }
    if (patch.value !== undefined) line.value = isPriced(patch.value) ? roundMoney(patch.value) : null;
    if (found.kind === 'product') {
      if (patch.quantity !== undefined) line.quantity = patch.quantity;
      if (patch.total !== undefined || patch.value !== undefined || patch.quantity !== undefined) {
        const own = patch.total !== undefined ? patch.total : undefined;
        delete line.total;
        if (isPriced(line.value)) line.total = isPriced(own) ? roundMoney(own) : roundMoney(line.value * (line.quantity || 1));
      }
      products[found.index] = line;
    } else {
      services[found.index] = line;
    }
    return line.id as string;
  });
}

/** Removes one line by id. */
export async function removeOrderItem(
  companyId: string,
  orderId: string,
  itemId: string,
  actor: UserAggr | undefined,
  options: ItemWriteOptions = {},
): Promise<ItemWriteResult | null> {
  return mutateItems(companyId, orderId, actor, options, (order, services, products) => {
    const found = findLine(order, itemId);
    if (!found) throw new OrderRuleError('ITEM_NOT_FOUND', 404, 'Item not found');
    (found.kind === 'service' ? services : products).splice(found.index, 1);
    return found.itemId;
  });
}

export interface AddItemOptions extends ItemWriteOptions {
  total?: number | null;
  deviceId?: string | null;
}

/** Add a service from the catalog (POST /:id/services, MCP). */
export async function addOrderService(
  companyId: string,
  orderId: string,
  serviceId: string,
  value?: number | null,
  description?: string,
  updatedBy?: UserAggr,
  options: AddItemOptions = {}
): Promise<{ success: boolean; newTotal: number; order?: Order; itemId?: string }> {
  const service = await catalogService.getService(companyId, serviceId);
  if (!service) return { success: false, newTotal: 0 };
  const result = await addOrderItem(
    companyId,
    orderId,
    { kind: 'service', catalog: service, value, description, deviceId: options.deviceId },
    updatedBy,
    options,
  );
  return result ? { success: true, ...result } : { success: false, newTotal: 0 };
}

/** Add a product from the catalog (POST /:id/products, MCP). */
export async function addOrderProduct(
  companyId: string,
  orderId: string,
  productId: string,
  quantity: number,
  value?: number | null,
  description?: string,
  updatedBy?: UserAggr,
  options: AddItemOptions = {}
): Promise<{ success: boolean; newTotal: number; order?: Order; itemId?: string }> {
  const product = await catalogService.getProduct(companyId, productId);
  if (!product) return { success: false, newTotal: 0 };
  const result = await addOrderItem(
    companyId,
    orderId,
    { kind: 'product', catalog: product, value, quantity, total: options.total, description, deviceId: options.deviceId },
    updatedBy,
    options,
  );
  return result ? { success: true, ...result } : { success: false, newTotal: 0 };
}

// ============================================================================
// Create and update
// ============================================================================

export interface CreateOrderInput {
  /**
   * Id the client generated for the order (idempotency). It becomes the
   * document id: repeating it returns the order already created by the same
   * user; created by someone else → 409 ORDER_ID_CONFLICT.
   */
  clientOrderId?: string;
  customerId: string;
  customer: CustomerAggr;
  deviceId?: string;
  device?: DeviceAggr;
  deviceIds?: string[];
  devices?: DeviceAggr[];
  services?: Array<{
    serviceId: string;
    value?: number | null;
    description?: string;
  }>;
  products?: Array<{
    productId: string;
    quantity: number;
    value?: number | null;
    total?: number | null;
    description?: string;
  }>;
  dueDate?: string;
  scheduledDate?: string;
  status?: OrderStatus;
}

function sanitizeDevice(device: DeviceAggr): DeviceAggr {
  return {
    id: device.id,
    name: device.name,
    serial: device.serial ?? null,
    photo: device.photo ?? null,
    category: device.category ?? null,
  };
}

/**
 * Create a new order. Items missing from the catalog are skipped; an item
 * without a price stays "sem valor" (null). Aggregates carry the same fields
 * as the app (customer taxId, device category, `deviceIds`).
 */
export async function createOrder(
  companyId: string,
  input: CreateOrderInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; number: number; status: OrderStatus; existing?: boolean }> {
  const collection = getTenantCollection(companyId, 'orders');
  const sameOrder = async (): Promise<{ id: string; number: number; status: OrderStatus; existing: true } | null> => {
    if (!input.clientOrderId) return null;
    const snap = await collection.doc(input.clientOrderId).get();
    if (!snap.exists) return null;
    const existing = snap.data() as Order;
    if (existing.createdBy?.id !== createdBy.id) {
      throw new OrderRuleError('ORDER_ID_CONFLICT', 409, 'Another order already has this id');
    }
    return { id: snap.id, number: existing.number, status: existing.status, existing: true };
  };
  const before = await sameOrder();
  if (before) return before;
  const orderNumber = await getNextOrderNumber(companyId);

  const orderServices: OrderServiceItem[] = [];
  for (const s of input.services ?? []) {
    const service = await catalogService.getService(companyId, s.serviceId);
    if (service) {
      orderServices.push(buildLine({ kind: 'service', catalog: service, value: s.value, description: s.description }) as OrderServiceItem);
    }
  }

  const orderProducts: OrderProductItem[] = [];
  for (const p of input.products ?? []) {
    const product = await catalogService.getProduct(companyId, p.productId);
    if (product) {
      orderProducts.push(buildLine({
        kind: 'product', catalog: product, value: p.value, quantity: p.quantity, total: p.total, description: p.description,
      }) as OrderProductItem);
    }
  }

  const total = computeOrderTotal({ services: orderServices, products: orderProducts, discount: 0 });
  const status = input.status || 'quote';

  // Firestore rejects undefined: absent fields become null
  const sanitizedCustomer = {
    id: input.customer.id,
    name: input.customer.name,
    phone: input.customer.phone ?? null,
    email: input.customer.email ?? null,
    taxId: input.customer.taxId ?? null,
  };

  const sanitizedDevice = input.device ? sanitizeDevice(input.device) : null;
  const devicesArray: DeviceAggr[] = input.devices && input.devices.length > 0
    ? input.devices.map(sanitizeDevice)
    : sanitizedDevice ? [sanitizedDevice] : [];

  const now = new Date().toISOString();
  const orderData = {
    number: orderNumber,
    customer: sanitizedCustomer,
    device: sanitizedDevice ?? devicesArray[0] ?? null,
    devices: devicesArray,
    deviceIds: devicesArray.map((d) => d.id),
    services: orderServices,
    products: orderProducts,
    photos: [],
    total,
    discount: 0,
    dueDate: input.dueDate ? new Date(input.dueDate).toISOString() : null,
    scheduledDate: input.scheduledDate ? new Date(input.scheduledDate).toISOString() : null,
    status,
    paid: false,
    payment: status === 'quote' || status === 'canceled' ? null : 'unpaid',
    paidAmount: 0,
    transactions: [],
    assignedTo: null,
    company,
    createdBy,
    createdAt: now,
    updatedAt: now,
    updatedBy: createdBy,
  };

  if (input.clientOrderId) {
    try {
      await collection.doc(input.clientOrderId).create(orderData);
    } catch (error) {
      // Created meanwhile by a repeated request (the number is left unused).
      if ((error as { code?: unknown }).code !== 6) throw error;
      const raced = await sameOrder();
      if (raced) return raced;
      throw error;
    }
    return { id: input.clientOrderId, number: orderNumber, status };
  }
  const ref = await collection.add(orderData);
  return { id: ref.id, number: orderNumber, status };
}

export interface UpdateOrderInput {
  status?: OrderStatus;
  dueDate?: string | null;
  scheduledDate?: string | null;
  assignedTo?: UserAggr | null;
}

/**
 * Update status, dates and assignee in a transaction. `done` is not written
 * (the app never writes it; `status` is the source). The payment status
 * follows the new status like the app's applyOrderStatus: quote/canceled have
 * none; an active status recomputes it, except on legacy orders paid before
 * `paidAmount` existed. Returns the updated order, or null when missing.
 */
export async function updateOrder(
  companyId: string,
  orderId: string,
  input: UpdateOrderInput,
  updatedBy: UserAggr,
  options: OrderWriteOptions = {}
): Promise<Order | null> {
  const ref = orderDoc(companyId, orderId);
  return runTransaction(async (tx) => {
    const existing = await readOrderForWrite(tx, ref, options);
    if (!existing) return null;

    const updateData: Record<string, unknown> = audit(updatedBy, new Date().toISOString());

    if (input.status !== undefined) {
      updateData.status = input.status;
      const legacyPaid = existing.paidAmount === undefined || existing.paidAmount === null;
      if (input.status === 'quote' || input.status === 'canceled' || !legacyPaid || existing.payment == null) {
        Object.assign(updateData, paymentStatusFields(input.status, existing.total ?? 0, existing.paidAmount ?? 0));
      }
    }
    if (input.dueDate !== undefined) {
      updateData.dueDate = input.dueDate ? new Date(input.dueDate).toISOString() : null;
    }
    if (input.scheduledDate !== undefined) {
      updateData.scheduledDate = input.scheduledDate ? new Date(input.scheduledDate).toISOString() : null;
    }
    if (input.assignedTo !== undefined) {
      updateData.assignedTo = input.assignedTo;
    }

    tx.update(ref, updateData);
    return { ...existing, ...updateData } as Order;
  });
}

// ============================================================================
// Payments
// ============================================================================

/**
 * Payment status of an order (same rule as the app's OrderPaymentMath:
 * paymentStatusFor + applyOrderStatus/orderStatusPaymentUpdate). Quotes and
 * canceled orders have no payment status (`payment: null, paid: false`), even
 * when money was received; their paidAmount/transactions are still kept.
 * Otherwise compares rounded values on both sides, so float drift (from
 * FieldValue.increment on paidAmount or total) is ignored.
 */
export function paymentStatusFields(
  orderStatus: string | null | undefined,
  total: number,
  paidAmount: number
): { paid: boolean; payment: PaymentStatus | null } {
  if (orderStatus === 'quote' || orderStatus === 'canceled') {
    return { paid: false, payment: null };
  }
  const paid = total > 0 && roundMoney(paidAmount) >= roundMoney(total);
  return { paid, payment: paid ? 'paid' : 'unpaid' };
}

/**
 * Apply a payment or discount transaction to an order (pure).
 * Same rules as the app (lib/utils/order_payment_math.dart):
 * - discount increases `discount` AND lowers `total` (total is net of discount);
 * - remaining balance = total - paidAmount;
 * - `payment` is stored only as 'paid' | 'unpaid'.
 */
export function applyPaymentTransaction(
  order: Pick<Order, 'total' | 'discount' | 'paidAmount' | 'transactions'> & Partial<Pick<Order, 'status'>>,
  transaction: PaymentTransaction
): {
  transactions: PaymentTransaction[];
  total: number;
  discount: number;
  paidAmount: number;
  paid: boolean;
  payment: PaymentStatus | null;
  remainingBalance: number;
} {
  let total = order.total || 0;
  let discount = order.discount || 0;
  let paidAmount = order.paidAmount || 0;

  if (transaction.type === 'payment') {
    paidAmount = roundMoney(paidAmount + transaction.amount);
  } else {
    discount = roundMoney(discount + transaction.amount);
    total = Math.max(0, roundMoney(total - transaction.amount));
  }

  const { paid, payment } = paymentStatusFields(order.status, total, paidAmount);

  return {
    transactions: [...(order.transactions || []), transaction],
    total,
    discount,
    paidAmount,
    paid,
    payment,
    remainingBalance: calculateRemainingBalance({ total, paidAmount }),
  };
}

/** Thrown by addPayment when the request is invalid for the order's state. */
export class PaymentValidationError extends OrderRuleError {
  constructor(message: string) {
    super('VALIDATION_ERROR', 400, message);
    this.name = 'PaymentValidationError';
  }
}

export interface AddPaymentOptions extends OrderWriteOptions {
  /** When the money came in (ISO). */
  paidAt?: string;
  /** pix | cash | card | other */
  paymentMethod?: string;
  /** Proof already uploaded under tenants/{companyId}/orders/{orderId}/. */
  receiptFile?: ReceiptFileInput;
  /**
   * Id the client generated for this transaction (idempotency). When the
   * order already has a transaction with it, nothing is written and the
   * current state is returned; with another type or amount → 409.
   */
  clientTransactionId?: string;
}

/** OrderDocument of a payment proof, linked to [transactionId]. */
export function receiptDocument(
  file: ReceiptFileInput,
  transactionId: string,
  actor: UserAggr,
  now: string,
  id: string = uuidv4(),
): OrderDocument {
  return {
    id,
    url: file.url,
    storagePath: file.storagePath,
    fileName: file.fileName ?? null,
    contentType: file.contentType,
    type: 'receipt',
    createdAt: now,
    createdBy: { id: actor.id, name: actor.name },
    linkedTransactionId: transactionId,
  };
}

/** Money in cents, so 0.1 + 0.2 compares equal to 0.3. */
function cents(value: number): number {
  return Math.round(roundMoney(value) * 100);
}

/**
 * A payment never goes above what is left to receive (compared in cents).
 * Refuses with 409 PAYMENT_EXCEEDS_BALANCE and the current balance. Only the
 * app routes: Asaas payments that arrive are always recorded.
 */
export function assertPaymentWithinBalance(order: Pick<Order, 'total' | 'paidAmount'>, amount: number): void {
  const remainingBalance = calculateRemainingBalance(order);
  if (cents(amount) > cents(remainingBalance)) {
    throw new OrderRuleError('PAYMENT_EXCEEDS_BALANCE', 409, 'Payment exceeds the remaining balance', { remainingBalance });
  }
}

/**
 * Add a payment or discount to an order (inside a Firestore transaction,
 * so it never races with the Asaas webhook). A discount cannot pass the
 * remaining balance.
 */
export async function addPayment(
  companyId: string,
  orderId: string,
  amount: number,
  type: TransactionType,
  description: string | undefined,
  createdBy: UserAggr,
  options: AddPaymentOptions = {}
): Promise<{
  transactionId: string;
  paidAmount: number;
  remainingBalance: number;
  isFullyPaid: boolean;
  order: Order;
} | null> {
  const ref = orderDoc(companyId, orderId);
  const paidAt = options.paidAt ? validatePaidAt(options.paidAt) : undefined;
  validateReceiptFile(orderFilesPrefix(companyId, orderId), options.receiptFile);

  return runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;

    const clientId = options.clientTransactionId;
    const previous = clientId ? (order.transactions ?? []).find((t) => t.id === clientId) : undefined;
    if (previous) {
      if (previous.type !== type || roundMoney(previous.amount) !== roundMoney(amount)) {
        throw new OrderRuleError('TRANSACTION_ID_CONFLICT', 409, 'Another transaction already has this id');
      }
      const paidAmount = roundMoney(Number(order.paidAmount) || 0);
      return {
        transactionId: previous.id,
        paidAmount,
        remainingBalance: calculateRemainingBalance(order),
        isFullyPaid: order.paid === true,
        order,
      };
    }
    if (type === 'payment' && options.paidAt) validatePaidAt(options.paidAt, order.createdAt);
    if (type === 'payment') assertPaymentWithinBalance(order, amount);

    if (type === 'discount') {
      const remaining = calculateRemainingBalance(order);
      if (roundMoney(amount - remaining) > 0.005) {
        throw new PaymentValidationError('Discount cannot exceed the remaining balance');
      }
    }

    const now = new Date().toISOString();
    const transaction: PaymentTransaction = {
      id: clientId ?? uuidv4(),
      type,
      amount: roundMoney(amount),
      createdAt: now,
      createdBy,
      ...(description !== undefined ? { description } : {}),
      ...(type === 'payment' && paidAt ? { paidAt } : {}),
      ...(type === 'payment' && options.paymentMethod ? { paymentMethod: options.paymentMethod } : {}),
    };
    const update: Record<string, unknown> = {};
    if (type === 'payment' && options.receiptFile) {
      const document = receiptDocument(options.receiptFile, transaction.id, createdBy, now);
      transaction.receiptDocumentId = document.id;
      update.documents = [...(order.documents ?? []), document];
    }

    const result = applyPaymentTransaction(order, transaction);
    Object.assign(update, {
      transactions: result.transactions,
      total: result.total,
      discount: result.discount,
      paidAmount: result.paidAmount,
      paid: result.paid,
      payment: result.payment,
      updatedBy: createdBy,
      updatedAt: now,
    });
    tx.update(ref, update);

    return {
      transactionId: transaction.id,
      paidAmount: result.paidAmount,
      remainingBalance: result.remainingBalance,
      isFullyPaid: result.paid,
      order: { ...order, ...update } as Order,
    };
  });
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Convert Order to OrderAggr
 */
export function toOrderAggr(order: Order): OrderAggr {
  return {
    id: order.id,
    number: order.number,
    customer: order.customer,
    device: order.device,
    devices: order.devices,
    deviceCount: order.devices?.length || (order.device ? 1 : 0),
  };
}

/**
 * Calculate remaining balance. `total` is already net of discount,
 * so the discount must NOT be subtracted again.
 */
export function calculateRemainingBalance(order: Pick<Order, 'total' | 'paidAmount'>): number {
  return Math.max(0, roundMoney((order.total || 0) - (order.paidAmount || 0)));
}

// ============================================================================
// Bot Management Operations
// ============================================================================
// Same item rules as the routes above (transaction, total from the items),
// found by order number and, for removal, by position (the bot lists items
// in order and refers to them by index).

/**
 * Add a service to an order by order number
 * Used for bot integration with getOrCreate pattern
 */
export async function addServiceToOrderByNumber(
  companyId: string,
  orderNumber: number,
  service: CatalogItemRef,
  value: number | null,
  description?: string,
  updatedBy?: UserAggr,
  deviceId?: string
): Promise<{ success: boolean; newTotal: number; order?: Order }> {
  const order = await getOrderByNumber(companyId, orderNumber);
  if (!order) return { success: false, newTotal: 0 };
  const result = await addOrderItem(
    companyId,
    order.id,
    { kind: 'service', catalog: service, value, description, deviceId: deviceId || null },
    updatedBy,
    { skipDeviceCheck: true },
  );
  return result ? { success: true, newTotal: result.newTotal, order: result.order } : { success: false, newTotal: 0 };
}

/**
 * Add a product to an order by order number
 * Used for bot integration with getOrCreate pattern
 */
export async function addProductToOrderByNumber(
  companyId: string,
  orderNumber: number,
  product: CatalogItemRef,
  quantity: number,
  value: number | null,
  description?: string,
  updatedBy?: UserAggr,
  deviceId?: string
): Promise<{ success: boolean; newTotal: number; order?: Order }> {
  const order = await getOrderByNumber(companyId, orderNumber);
  if (!order) return { success: false, newTotal: 0 };
  const result = await addOrderItem(
    companyId,
    order.id,
    { kind: 'product', catalog: product, value, quantity, description, deviceId: deviceId || null },
    updatedBy,
    { skipDeviceCheck: true },
  );
  return result ? { success: true, newTotal: result.newTotal, order: result.order } : { success: false, newTotal: 0 };
}

async function removeLineByIndex<T extends OrderServiceItem | OrderProductItem>(
  companyId: string,
  orderNumber: number,
  kind: ItemKind,
  index: number,
  updatedBy?: UserAggr,
): Promise<{ success: boolean; removed?: T; newTotal: number }> {
  const order = await getOrderByNumber(companyId, orderNumber);
  if (!order) return { success: false, newTotal: 0 };
  let removed: T | undefined;
  const result = await mutateItems(companyId, order.id, updatedBy, {}, (_fresh, services, products) => {
    const lines = (kind === 'service' ? services : products) as T[];
    if (index < 0 || index >= lines.length) throw new OrderRuleError('ITEM_NOT_FOUND', 404, 'Item not found');
    [removed] = lines.splice(index, 1);
    return removed?.id ?? '';
  }).catch((error) => {
    if (error instanceof OrderRuleError && error.code === 'ITEM_NOT_FOUND') return 'missing' as const;
    throw error;
  });
  if (!result || result === 'missing') return { success: false, newTotal: order.total };
  return { success: true, removed, newTotal: result.newTotal };
}

/**
 * Remove a service from an order by index
 */
export async function removeServiceFromOrder(
  companyId: string,
  orderNumber: number,
  serviceIndex: number,
  updatedBy?: UserAggr
): Promise<{ success: boolean; removedService?: OrderServiceItem; newTotal: number }> {
  const { success, removed, newTotal } = await removeLineByIndex<OrderServiceItem>(companyId, orderNumber, 'service', serviceIndex, updatedBy);
  return { success, removedService: removed, newTotal };
}

/**
 * Remove a product from an order by index
 */
export async function removeProductFromOrder(
  companyId: string,
  orderNumber: number,
  productIndex: number,
  updatedBy?: UserAggr
): Promise<{ success: boolean; removedProduct?: OrderProductItem; newTotal: number }> {
  const { success, removed, newTotal } = await removeLineByIndex<OrderProductItem>(companyId, orderNumber, 'product', productIndex, updatedBy);
  return { success, removedProduct: removed, newTotal };
}

/**
 * Update order device
 */
export async function updateOrderDevice(
  companyId: string,
  orderNumber: number,
  device: DeviceAggr,
  updatedBy?: UserAggr
): Promise<{ success: boolean; order?: Order }> {
  const order = await getOrderByNumber(companyId, orderNumber);

  if (!order) {
    return { success: false };
  }

  const collection = getTenantCollection(companyId, 'orders');
  await updateDocument(collection, order.id, {
    device,
    devices: [device],
    deviceIds: [device.id],
    updatedBy,
    updatedAt: new Date().toISOString(),
  });

  return { success: true, order: { ...order, device, devices: [device] } };
}

/**
 * Update order customer
 */
export async function updateOrderCustomer(
  companyId: string,
  orderNumber: number,
  customer: CustomerAggr,
  updatedBy?: UserAggr
): Promise<{ success: boolean; order?: Order }> {
  const order = await getOrderByNumber(companyId, orderNumber);

  if (!order) {
    return { success: false };
  }

  const collection = getTenantCollection(companyId, 'orders');
  await updateDocument(collection, order.id, {
    customer,
    updatedBy,
    updatedAt: new Date().toISOString(),
  });

  return { success: true, order: { ...order, customer } };
}

/**
 * Add a device to an order (multi-device support)
 */
export async function addDeviceToOrder(
  companyId: string,
  orderNumber: number,
  device: DeviceAggr,
  updatedBy?: UserAggr
): Promise<{ success: boolean; devices: DeviceAggr[]; order?: Order }> {
  const order = await getOrderByNumber(companyId, orderNumber);
  if (!order) return { success: false, devices: [] };

  const devices = [...(order.devices || [])];
  // Avoid duplicates
  if (devices.some(d => d.id === device.id)) {
    return { success: true, devices, order };
  }

  const sanitizedDevice = {
    id: device.id, name: device.name,
    serial: device.serial ?? null, photo: device.photo ?? null,
  };
  devices.push(sanitizedDevice);

  const collection = getTenantCollection(companyId, 'orders');
  await updateDocument(collection, order.id, {
    devices,
    deviceIds: devices.map((d) => d.id),
    device: devices[0], // backward compat
    updatedBy,
    updatedAt: new Date().toISOString(),
  });

  return { success: true, devices, order: { ...order, devices, device: devices[0] } };
}

/**
 * Remove a device from an order (multi-device support)
 * Also cleans up orphaned deviceId references in services/products
 */
export async function removeDeviceFromOrder(
  companyId: string,
  orderNumber: number,
  deviceId: string,
  updatedBy?: UserAggr
): Promise<{ success: boolean; devices: DeviceAggr[] }> {
  const order = await getOrderByNumber(companyId, orderNumber);
  if (!order) return { success: false, devices: [] };

  const devices = (order.devices || []).filter(d => d.id !== deviceId);

  // Orphan cleanup: clear deviceId from services/products that referenced removed device
  const services = (order.services || []).map(s => ({
    ...s,
    deviceId: s.deviceId === deviceId ? null : (s.deviceId || null),
  }));
  const products = (order.products || []).map(p => ({
    ...p,
    deviceId: p.deviceId === deviceId ? null : (p.deviceId || null),
  }));

  const collection = getTenantCollection(companyId, 'orders');
  await updateDocument(collection, order.id, {
    devices,
    deviceIds: devices.map((d) => d.id),
    device: devices.length > 0 ? devices[0] : null,
    services,
    products,
    updatedBy,
    updatedAt: new Date().toISOString(),
  });

  return { success: true, devices };
}

// ============================================================================
// Photo Management
// ============================================================================

/**
 * Add photo to an order
 */
export async function addPhotoToOrder(
  companyId: string,
  orderId: string,
  photo: OrderPhoto
): Promise<void> {
  const collection = getTenantCollection(companyId, 'orders');
  const orderDoc = await getDocument<Order>(collection, orderId);

  if (!orderDoc) {
    throw new Error('Order not found');
  }

  const currentPhotos = orderDoc.photos || [];
  const updatedPhotos = [...currentPhotos, photo];

  await updateDocument(collection, orderId, {
    photos: updatedPhotos,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Remove photo from an order
 */
export async function removePhotoFromOrder(
  companyId: string,
  orderId: string,
  photoId: string
): Promise<void> {
  const collection = getTenantCollection(companyId, 'orders');
  const orderDoc = await getDocument<Order>(collection, orderId);

  if (!orderDoc) {
    throw new Error('Order not found');
  }

  const currentPhotos = orderDoc.photos || [];
  const updatedPhotos = currentPhotos.filter((p) => p.id !== photoId);

  await updateDocument(collection, orderId, {
    photos: updatedPhotos,
    updatedAt: new Date().toISOString(),
  });
}

// ============================================================================
// Share Link Management
// ============================================================================

export interface OrderShareLink {
  token: string;
  expiresAt: string;
  permissions: string[];
}

/**
 * Update the share link on an order
 */
export async function updateOrderShareLink(
  companyId: string,
  orderId: string,
  shareLink: OrderShareLink | null
): Promise<void> {
  const collection = getTenantCollection(companyId, 'orders');
  await updateDocument(collection, orderId, {
    shareLink,
    updatedAt: new Date().toISOString(),
  });
}
