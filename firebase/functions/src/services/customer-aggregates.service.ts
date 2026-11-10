/**
 * What the Clientes list says about each customer, kept on the customer by the
 * server (docs/CUSTOMER_LAST_ACTIVITY.md), so the list reads only the customers:
 * - `openOrders`: how many orders are open (quote, approved, progress: OPEN_STATUSES);
 * - `owed`: "Falta receber", the A receber rule (customerOwed, the customer screen's sum);
 * - `openDueDates`: the promised days (UTC ISO, oldest first) of the open orders
 *   that have one. Late changes with time and not with a write, so the screens
 *   count the ones before today; the first one is the next due date.
 *
 * Every order trigger (created, changed, deleted, moved to another customer)
 * recounts the whole customer from their orders, so a lost or repeated event is
 * fixed by the next one, and writes only when a number changed. Writing these
 * fields fires the customer trigger, which ignores them (customerChanged).
 *
 * Without a transaction: reading every order of a customer in one would lock
 * them while the app edits them. Two changes of the same customer at the same
 * instant can leave the older count, until the next change or the backfill.
 */
import { db } from './firestore.service';
import { companyZone, instantOf } from '../utils/company-zone';
import { customerOwed, isOpenStatus, type SummaryOrder } from './customer-summary';
import { AGGREGATE_FIELDS, orderCustomerId } from './customer-activity.service';

export { AGGREGATE_FIELDS };

export interface CustomerAggregates {
  openOrders: number;
  owed: number;
  openDueDates: string[];
}

type Data = Record<string, unknown> | undefined;

/** Order fields that change the numbers above. */
const ORDER_FIELDS = ['status', 'dueDate', 'total', 'paidAmount', 'payment'] as const;

/** The numbers of one customer from all their orders. */
export function aggregatesOf(orders: SummaryOrder[], zone: string): CustomerAggregates {
  const open = orders.filter((order) => isOpenStatus(order.status));
  const openDueDates = open
    .map((order) => instantOf(order.dueDate, zone))
    .filter((date): date is Date => !!date)
    .sort((a, b) => a.getTime() - b.getTime())
    .map((date) => date.toISOString());
  return { openOrders: open.length, owed: customerOwed(orders), openDueDates };
}

const same = (a: unknown, b: unknown) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

/** Whether an order write can change its customers' numbers (created, deleted, moved or a counted field changed). */
export function orderAffectsCustomer(before: Data, after: Data): boolean {
  if (!before || !after) return true;
  if (orderCustomerId(before) !== orderCustomerId(after)) return true;
  return ORDER_FIELDS.some((field) => !same(before[field], after[field]));
}

/** Customers whose numbers an order write touches: the old one and the new one. */
export function customersOfOrderWrite(before: Data, after: Data): string[] {
  if (!orderAffectsCustomer(before, after)) return [];
  return [...new Set([orderCustomerId(before), orderCustomerId(after)].filter((id): id is string => !!id))];
}

async function zoneOf(companyId: string): Promise<string> {
  const company = await db.collection('companies').doc(companyId).get();
  return companyZone(company.data()?.country as string | undefined);
}

/** Recounts one customer from their orders; writes only when something changed. */
export async function recountCustomer(companyId: string, customerId: string, zone?: string): Promise<CustomerAggregates | null> {
  const company = db.collection('companies').doc(companyId);
  const ref = company.collection('customers').doc(customerId);
  const [snapshot, orders, companyZoneId] = await Promise.all([
    ref.get(),
    company.collection('orders').where('customer.id', '==', customerId).select('status', 'dueDate', 'total', 'paidAmount', 'payment').get(),
    zone ? Promise.resolve(zone) : zoneOf(companyId),
  ]);
  if (!snapshot.exists) return null;
  const next = aggregatesOf(orders.docs.map((doc) => doc.data() as SummaryOrder), companyZoneId);
  const current = snapshot.data() ?? {};
  if (AGGREGATE_FIELDS.every((field) => same(current[field], next[field]))) return next;
  await ref.update({ ...next });
  return next;
}

/** Order trigger: recounts the customers whose numbers the write can change. */
export async function recountCustomersOfOrder(companyId: string, before: Data, after: Data): Promise<void> {
  const ids = customersOfOrderWrite(before, after);
  if (!ids.length) return;
  const zone = await zoneOf(companyId);
  await Promise.all(ids.map((id) => recountCustomer(companyId, id, zone)));
}
