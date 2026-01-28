/**
 * Order Service
 * Business logic for order (OS) operations
 */

import { v4 as uuidv4 } from 'uuid';
import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  updateDocument,
  getNextOrderNumber,
  Timestamp,
  QueryFilter,
} from './firestore.service';
import {
  Order,
  OrderAggr,
  OrderStatus,
  OrderService as OrderServiceItem,
  OrderProduct as OrderProductItem,
  PaymentTransaction,
  TransactionType,
  UserAggr,
  CompanyAggr,
  CustomerAggr,
  DeviceAggr,
} from '../models/types';
import * as catalogService from './catalog.service';

// ============================================================================
// Query Operations
// ============================================================================

export interface OrderQueryParams {
  status?: OrderStatus;
  customerId?: string;
  deviceId?: string;
  assignedTo?: string;
  startDate?: string;
  endDate?: string;
  limit?: number;
  offset?: number;
}

/**
 * List orders with filtering and pagination
 */
export async function listOrders(
  companyId: string,
  params: OrderQueryParams
): Promise<{ data: Order[]; total: number; hasMore: boolean }> {
  const collection = getTenantCollection(companyId, 'orders');
  const filters: QueryFilter[] = [];

  if (params.status) {
    filters.push({ field: 'status', operator: '==', value: params.status });
  }

  if (params.customerId) {
    filters.push({ field: 'customer.id', operator: '==', value: params.customerId });
  }

  if (params.deviceId) {
    filters.push({ field: 'device.id', operator: '==', value: params.deviceId });
  }

  if (params.assignedTo) {
    filters.push({ field: 'assignedTo.id', operator: '==', value: params.assignedTo });
  }

  if (params.startDate) {
    filters.push({
      field: 'createdAt',
      operator: '>=',
      value: Timestamp.fromDate(new Date(params.startDate)),
    });
  }

  if (params.endDate) {
    filters.push({
      field: 'createdAt',
      operator: '<=',
      value: Timestamp.fromDate(new Date(params.endDate)),
    });
  }

  return paginatedQuery<Order>(collection, {
    limit: params.limit,
    offset: params.offset,
    orderBy: 'createdAt',
    orderDirection: 'desc',
    filters,
  });
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
    id: doc.id,
    ...doc.data(),
  })) as Order[];
}

/**
 * Get orders due today
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
    .where('dueDate', '>=', Timestamp.fromDate(today))
    .where('dueDate', '<', Timestamp.fromDate(tomorrow))
    .where('status', 'in', ['approved', 'progress'])
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
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
    id: doc.id,
    ...doc.data(),
  })) as Order[];
}

/**
 * Get overdue orders
 */
export async function getOverdueOrders(
  companyId: string
): Promise<Order[]> {
  const collection = getTenantCollection(companyId, 'orders');
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const snapshot = await collection
    .where('dueDate', '<', Timestamp.fromDate(today))
    .where('status', 'in', ['approved', 'progress'])
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[];
}

// ============================================================================
// Write Operations
// ============================================================================

export interface CreateOrderInput {
  customerId: string;
  customer: CustomerAggr;
  deviceId?: string;
  device?: DeviceAggr;
  services?: Array<{
    serviceId: string;
    value?: number;
    description?: string;
  }>;
  products?: Array<{
    productId: string;
    quantity: number;
    value?: number;
    description?: string;
  }>;
  dueDate?: string;
  status?: OrderStatus;
}

/**
 * Create a new order
 */
export async function createOrder(
  companyId: string,
  input: CreateOrderInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; number: number; status: OrderStatus }> {
  const collection = getTenantCollection(companyId, 'orders');

  // Get next order number
  const orderNumber = await getNextOrderNumber(companyId);

  // Process services
  let orderServices: OrderServiceItem[] = [];
  let servicesTotal = 0;

  if (input.services && input.services.length > 0) {
    for (const s of input.services) {
      const service = await catalogService.getService(companyId, s.serviceId);
      if (service) {
        const value = s.value ?? service.value ?? 0;
        orderServices.push({
          service: {
            id: service.id,
            name: service.name,
            value: service.value,
            photo: service.photo,
          },
          description: s.description || service.name,
          value,
        });
        servicesTotal += value;
      }
    }
  }

  // Process products
  let orderProducts: OrderProductItem[] = [];
  let productsTotal = 0;

  if (input.products && input.products.length > 0) {
    for (const p of input.products) {
      const product = await catalogService.getProduct(companyId, p.productId);
      if (product) {
        const value = p.value ?? product.value ?? 0;
        const quantity = p.quantity || 1;
        orderProducts.push({
          product: {
            id: product.id,
            name: product.name,
            value: product.value,
            photo: product.photo,
          },
          description: p.description || product.name,
          value,
          quantity,
        });
        productsTotal += value * quantity;
      }
    }
  }

  const total = servicesTotal + productsTotal;
  const status = input.status || 'quote';

  const orderData = {
    number: orderNumber,
    customer: input.customer,
    device: input.device || null,
    services: orderServices,
    products: orderProducts,
    photos: [],
    total,
    discount: 0,
    dueDate: input.dueDate ? Timestamp.fromDate(new Date(input.dueDate)) : null,
    status,
    done: status === 'done',
    paid: false,
    payment: 'unpaid',
    paidAmount: 0,
    transactions: [],
    assignedTo: null,
    company,
    createdBy,
    createdAt: Timestamp.now(),
  };

  const id = await createDocument(collection, orderData);

  return { id, number: orderNumber, status };
}

export interface UpdateOrderInput {
  status?: OrderStatus;
  dueDate?: string;
  assignedTo?: UserAggr;
}

/**
 * Update an existing order
 */
export async function updateOrder(
  companyId: string,
  orderId: string,
  input: UpdateOrderInput,
  updatedBy: UserAggr
): Promise<boolean> {
  const collection = getTenantCollection(companyId, 'orders');

  // Check if order exists
  const existing = await getDocument<Order>(collection, orderId);
  if (!existing) return false;

  const updateData: Record<string, unknown> = {
    updatedBy,
    updatedAt: Timestamp.now(),
  };

  if (input.status !== undefined) {
    updateData.status = input.status;
    updateData.done = input.status === 'done';
  }

  if (input.dueDate !== undefined) {
    updateData.dueDate = Timestamp.fromDate(new Date(input.dueDate));
  }

  if (input.assignedTo !== undefined) {
    updateData.assignedTo = input.assignedTo;
  }

  await updateDocument(collection, orderId, updateData);
  return true;
}

/**
 * Add a service to an order
 */
export async function addOrderService(
  companyId: string,
  orderId: string,
  serviceId: string,
  value?: number,
  description?: string,
  updatedBy?: UserAggr
): Promise<{ success: boolean; newTotal: number }> {
  const collection = getTenantCollection(companyId, 'orders');
  const order = await getDocument<Order>(collection, orderId);

  if (!order) {
    return { success: false, newTotal: 0 };
  }

  const service = await catalogService.getService(companyId, serviceId);
  if (!service) {
    return { success: false, newTotal: order.total };
  }

  const serviceValue = value ?? service.value ?? 0;
  const newService: OrderServiceItem = {
    service: {
      id: service.id,
      name: service.name,
      value: service.value,
      photo: service.photo,
    },
    description: description || service.name,
    value: serviceValue,
  };

  const services = [...(order.services || []), newService];
  const newTotal = order.total + serviceValue;

  await updateDocument(collection, orderId, {
    services,
    total: newTotal,
    updatedBy,
    updatedAt: Timestamp.now(),
  });

  return { success: true, newTotal };
}

/**
 * Add a product to an order
 */
export async function addOrderProduct(
  companyId: string,
  orderId: string,
  productId: string,
  quantity: number,
  value?: number,
  description?: string,
  updatedBy?: UserAggr
): Promise<{ success: boolean; newTotal: number }> {
  const collection = getTenantCollection(companyId, 'orders');
  const order = await getDocument<Order>(collection, orderId);

  if (!order) {
    return { success: false, newTotal: 0 };
  }

  const product = await catalogService.getProduct(companyId, productId);
  if (!product) {
    return { success: false, newTotal: order.total };
  }

  const productValue = value ?? product.value ?? 0;
  const newProduct: OrderProductItem = {
    product: {
      id: product.id,
      name: product.name,
      value: product.value,
      photo: product.photo,
    },
    description: description || product.name,
    value: productValue,
    quantity,
  };

  const products = [...(order.products || []), newProduct];
  const newTotal = order.total + (productValue * quantity);

  await updateDocument(collection, orderId, {
    products,
    total: newTotal,
    updatedBy,
    updatedAt: Timestamp.now(),
  });

  return { success: true, newTotal };
}

/**
 * Add a payment or discount to an order
 */
export async function addPayment(
  companyId: string,
  orderId: string,
  amount: number,
  type: TransactionType,
  description: string | undefined,
  createdBy: UserAggr
): Promise<{
  transactionId: string;
  paidAmount: number;
  remainingBalance: number;
  isFullyPaid: boolean;
} | null> {
  const collection = getTenantCollection(companyId, 'orders');
  const order = await getDocument<Order>(collection, orderId);

  if (!order) return null;

  const transaction: PaymentTransaction = {
    id: uuidv4(),
    type,
    amount,
    description,
    createdAt: Timestamp.now(),
    createdBy,
  };

  const transactions = [...(order.transactions || []), transaction];

  let newPaidAmount = order.paidAmount;
  let newDiscount = order.discount;

  if (type === 'payment') {
    newPaidAmount += amount;
  } else if (type === 'discount') {
    newDiscount += amount;
  }

  const remainingBalance = order.total - newDiscount - newPaidAmount;
  const isFullyPaid = remainingBalance <= 0;

  await updateDocument(collection, orderId, {
    transactions,
    paidAmount: newPaidAmount,
    discount: newDiscount,
    paid: isFullyPaid,
    payment: isFullyPaid ? 'paid' : newPaidAmount > 0 ? 'partial' : 'unpaid',
    updatedBy: createdBy,
    updatedAt: Timestamp.now(),
  });

  return {
    transactionId: transaction.id,
    paidAmount: newPaidAmount,
    remainingBalance: Math.max(0, remainingBalance),
    isFullyPaid,
  };
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
  };
}

/**
 * Calculate remaining balance
 */
export function calculateRemainingBalance(order: Order): number {
  return Math.max(0, order.total - order.discount - order.paidAmount);
}
