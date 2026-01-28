/**
 * Analytics Service
 * Business logic for dashboard and reporting
 */

import {
  getTenantCollection,
  Timestamp,
} from './firestore.service';
import {
  Order,
  AnalyticsSummary,
  AnalyticsPeriod,
  OrdersByStatus,
  RevenueMetrics,
  TopCustomer,
  TopService,
  PendingItems,
  PendingOrder,
} from '../models/types';
import {
  getPeriodDates,
  PeriodType,
  toISODateString,
  isToday,
  isOverdue,
  daysOverdue,
  timestampToDate,
} from '../utils/date.utils';

// ============================================================================
// Summary Analytics
// ============================================================================

/**
 * Get analytics summary for a period
 */
export async function getAnalyticsSummary(
  companyId: string,
  period: PeriodType,
  startDate?: string,
  endDate?: string
): Promise<AnalyticsSummary> {
  const dateRange = getPeriodDates(period, startDate, endDate);
  const collection = getTenantCollection(companyId, 'orders');

  // Get orders in the period
  const snapshot = await collection
    .where('createdAt', '>=', Timestamp.fromDate(dateRange.start))
    .where('createdAt', '<=', Timestamp.fromDate(dateRange.end))
    .get();

  const orders = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[];

  // Calculate metrics
  const ordersByStatus = calculateOrdersByStatus(orders);
  const revenue = calculateRevenue(orders);
  const topCustomers = calculateTopCustomers(orders);
  const topServices = calculateTopServices(orders);

  const periodResult: AnalyticsPeriod = {
    start: toISODateString(dateRange.start),
    end: toISODateString(dateRange.end),
  };

  return {
    period: periodResult,
    orders: {
      total: orders.length,
      byStatus: ordersByStatus,
    },
    revenue,
    topCustomers,
    topServices,
  };
}

/**
 * Calculate orders count by status
 */
function calculateOrdersByStatus(orders: Order[]): OrdersByStatus {
  const byStatus: OrdersByStatus = {
    quote: 0,
    approved: 0,
    progress: 0,
    done: 0,
    canceled: 0,
  };

  for (const order of orders) {
    if (order.status in byStatus) {
      byStatus[order.status as keyof OrdersByStatus]++;
    }
  }

  return byStatus;
}

/**
 * Calculate revenue metrics
 */
function calculateRevenue(orders: Order[]): RevenueMetrics {
  let total = 0;
  let paid = 0;
  let discount = 0;

  for (const order of orders) {
    // Only count orders that are not canceled
    if (order.status !== 'canceled') {
      total += order.total || 0;
      paid += order.paidAmount || 0;
      discount += order.discount || 0;
    }
  }

  return {
    total,
    paid,
    unpaid: total - discount - paid,
    discount,
  };
}

/**
 * Calculate top customers by revenue
 */
function calculateTopCustomers(orders: Order[], limit = 5): TopCustomer[] {
  const customerMap = new Map<
    string,
    { name: string; total: number; orderCount: number }
  >();

  for (const order of orders) {
    if (order.customer && order.status !== 'canceled') {
      const customerId = order.customer.id;
      const existing = customerMap.get(customerId) || {
        name: order.customer.name || 'Unknown',
        total: 0,
        orderCount: 0,
      };

      existing.total += order.total || 0;
      existing.orderCount += 1;
      customerMap.set(customerId, existing);
    }
  }

  return Array.from(customerMap.entries())
    .map(([id, data]) => ({ id, ...data }))
    .sort((a, b) => b.total - a.total)
    .slice(0, limit);
}

/**
 * Calculate top services by revenue
 */
function calculateTopServices(orders: Order[], limit = 5): TopService[] {
  const serviceMap = new Map<
    string,
    { name: string; total: number; count: number }
  >();

  for (const order of orders) {
    if (order.services && order.status !== 'canceled') {
      for (const orderService of order.services) {
        if (orderService.service) {
          const serviceId = orderService.service.id;
          const existing = serviceMap.get(serviceId) || {
            name: orderService.service.name || 'Unknown',
            total: 0,
            count: 0,
          };

          existing.total += orderService.value || 0;
          existing.count += 1;
          serviceMap.set(serviceId, existing);
        }
      }
    }
  }

  return Array.from(serviceMap.entries())
    .map(([id, data]) => ({ id, ...data }))
    .sort((a, b) => b.total - a.total)
    .slice(0, limit);
}

// ============================================================================
// Pending Items
// ============================================================================

/**
 * Get all pending items (approvals, due today, unpaid, overdue)
 */
export async function getPendingItems(companyId: string): Promise<PendingItems> {
  const collection = getTenantCollection(companyId, 'orders');

  // Get all non-canceled orders
  const snapshot = await collection
    .where('status', 'in', ['quote', 'approved', 'progress', 'done'])
    .get();

  const orders = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[];

  const toApprove: PendingOrder[] = [];
  const dueToday: PendingOrder[] = [];
  const unpaid: PendingOrder[] = [];
  const overdue: PendingOrder[] = [];

  for (const order of orders) {
    const createdAt = timestampToDate(order.createdAt);
    const dueDate = timestampToDate(order.dueDate);

    const pendingOrder: PendingOrder = {
      id: order.id,
      number: order.number,
      customer: order.customer,
      device: order.device,
      total: order.total,
      createdAt: createdAt?.toISOString() || '',
    };

    // To approve (status = quote)
    if (order.status === 'quote') {
      toApprove.push(pendingOrder);
    }

    // Due today
    if (dueDate && isToday(dueDate) && ['approved', 'progress'].includes(order.status)) {
      dueToday.push({
        ...pendingOrder,
        dueDate: toISODateString(dueDate),
      });
    }

    // Unpaid (status = done, not fully paid)
    if (order.status === 'done' && !order.paid) {
      const remaining = (order.total || 0) - (order.discount || 0) - (order.paidAmount || 0);
      if (remaining > 0) {
        unpaid.push({
          ...pendingOrder,
          remainingBalance: remaining,
        });
      }
    }

    // Overdue (dueDate < today, not done/canceled)
    if (dueDate && isOverdue(dueDate) && ['approved', 'progress'].includes(order.status)) {
      overdue.push({
        ...pendingOrder,
        dueDate: toISODateString(dueDate),
        daysOverdue: daysOverdue(dueDate),
      });
    }
  }

  // Sort by most relevant first
  toApprove.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  unpaid.sort((a, b) => (b.remainingBalance || 0) - (a.remainingBalance || 0));
  overdue.sort((a, b) => (b.daysOverdue || 0) - (a.daysOverdue || 0));

  return {
    toApprove,
    dueToday,
    unpaid,
    overdue,
  };
}

// ============================================================================
// Today Summary (for Bot)
// ============================================================================

export interface TodaySummaryData {
  totalOrders: number;
  toApprove: number;
  dueToday: number;
  unpaidAmount: number;
  revenue: number;
  ordersCreatedToday: number;
}

/**
 * Get today's summary data (optimized for bot)
 */
export async function getTodaySummary(companyId: string): Promise<TodaySummaryData> {
  const collection = getTenantCollection(companyId, 'orders');

  // Get today's date range
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  // Get orders created today
  const todaySnapshot = await collection
    .where('createdAt', '>=', Timestamp.fromDate(today))
    .where('createdAt', '<', Timestamp.fromDate(tomorrow))
    .get();

  const ordersCreatedToday = todaySnapshot.size;

  // Calculate revenue from orders created today
  let revenue = 0;
  todaySnapshot.docs.forEach((doc) => {
    const order = doc.data() as Order;
    if (order.status !== 'canceled') {
      revenue += order.total || 0;
    }
  });

  // Get pending items
  const pending = await getPendingItems(companyId);

  // Calculate total unpaid amount
  let unpaidAmount = 0;
  pending.unpaid.forEach((order) => {
    unpaidAmount += order.remainingBalance || 0;
  });

  // Get total active orders
  const activeSnapshot = await collection
    .where('status', 'in', ['quote', 'approved', 'progress'])
    .get();

  return {
    totalOrders: activeSnapshot.size,
    toApprove: pending.toApprove.length,
    dueToday: pending.dueToday.length,
    unpaidAmount,
    revenue,
    ordersCreatedToday,
  };
}
