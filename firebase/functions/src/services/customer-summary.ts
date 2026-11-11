/**
 * What the Clientes list and the customer screen say about each customer, with
 * the words and the math of the Início and the Financeiro
 * (docs/web-app/contract-cases/customer-summary.json, the same cases the app runs):
 *
 * - open: "Em aberto" of the Início: quote, approved and progress.
 * - late: of those, the promised day is behind today, by day in the company's zone (overdue.json).
 * - owed: "Falta receber", the A receber of the Financeiro (isReceivable): done with a
 *   balance, or running with a down payment.
 */
import { dayIn, instantOf } from '../utils/company-zone';
import { isReceivable, openAmount, type FinanceOrder } from './app-finance.service';

/** The fields read here: an order of the API (Order) or of the Financeiro query (FinanceOrder). */
export interface SummaryOrder {
  status?: string | null;
  customer?: { id?: string | null } | null;
  dueDate?: unknown;
  total?: number | null;
  paidAmount?: number | null;
  payment?: string | null;
}
const asFinance = (order: SummaryOrder) => order as FinanceOrder;

export const OPEN_STATUSES = ['quote', 'approved', 'progress'] as const;

export const isOpenStatus = (status: unknown): boolean => (OPEN_STATUSES as readonly unknown[]).includes(status);

/** Late by day, in the company's zone: quotes count, done and canceled never. */
export function isLate(order: SummaryOrder, now: Date, zone: string): boolean {
  if (order.status === 'done' || order.status === 'canceled') return false;
  const due = instantOf(order.dueDate, zone);
  return !!due && dayIn(due, zone) < dayIn(now, zone);
}

/** What the customer owes now, the A receber rule. */
export function customerOwed(orders: SummaryOrder[]): number {
  return Math.round(orders.filter((o) => isReceivable(asFinance(o))).reduce((sum, o) => sum + openAmount(asFinance(o)), 0) * 100) / 100;
}

export interface CustomerCounts {
  open: number;
  late: number;
}

/** Open and late orders per customer id; customers with none are absent. */
export function countsByCustomer(orders: SummaryOrder[], now: Date, zone: string): Map<string, CustomerCounts> {
  const result = new Map<string, CustomerCounts>();
  for (const order of orders) countOrder(result, order, now, zone);
  return result;
}

/** Adds one order to [countsByCustomer]'s map: the lists read page by page and keep only the counts. */
export function countOrder(result: Map<string, CustomerCounts>, order: SummaryOrder, now: Date, zone: string): void {
  const id = order.customer?.id;
  if (!id || !isOpenStatus(order.status)) return;
  const counts = result.get(id) ?? { open: 0, late: 0 };
  counts.open++;
  if (isLate(order, now, zone)) counts.late++;
  result.set(id, counts);
}

/** [customerOwed] per customer id; customers that owe nothing are absent. */
export function owedByCustomer(orders: SummaryOrder[]): Map<string, number> {
  const tally = new OwedTally();
  for (const order of orders) tally.add(order);
  return tally.result();
}

/**
 * [owedByCustomer] one order at a time, without keeping the orders: the same
 * sum as [customerOwed] (receivable orders only, in the order they come, then
 * rounded to cents), so the list and the customer screen say the same.
 */
export class OwedTally {
  private sums = new Map<string, number>();
  add(order: SummaryOrder): void {
    const id = order.customer?.id;
    if (!id) return;
    const sum = this.sums.get(id) ?? 0;
    this.sums.set(id, isReceivable(asFinance(order)) ? sum + openAmount(asFinance(order)) : sum);
  }
  result(): Map<string, number> {
    const result = new Map<string, number>();
    for (const [id, sum] of this.sums) {
      const owed = Math.round(sum * 100) / 100;
      if (owed > 0) result.set(id, owed);
    }
    return result;
  }
}
