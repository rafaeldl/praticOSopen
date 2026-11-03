/**
 * Financeiro of the web app (docs/WEB_API.md, "Financeiro"): the numbers of the
 * tab, the report and Receber, computed here so the browser never reads
 * thousands of orders. Same rules as the app (lib/utils/financial_summary.dart
 * and OrderStore.loadOrdersForDashboard), with the app's defects left out:
 * the last day of a period counts (defect 60), the report's "a receber" list
 * matches its value (defect 58) and a chosen customer keeps the ranking (D6).
 * Contract: docs/web-app/contract-cases/finance-summary.json.
 *
 * Money is added in cents. Days are the company's (utils/company-zone.ts).
 */
import { db } from './firestore.service';
import { daysRange, instantOf } from '../utils/company-zone';

/** What an order has that these numbers read. Everything optional: old orders lack fields. */
export interface FinanceOrder {
  id: string;
  number?: number | null;
  status?: string | null;
  customer?: { id?: string | null; name?: string | null } | null;
  devices?: Array<{ name?: string | null; serial?: string | null }> | null;
  device?: { name?: string | null; serial?: string | null } | null;
  services?: Array<{ service?: { name?: string | null } | null; description?: string | null; value?: number | null; quantity?: number | null }> | null;
  products?: Array<{ product?: { name?: string | null } | null; description?: string | null; value?: number | null; quantity?: number | null; total?: number | null }> | null;
  total?: number | null;
  paidAmount?: number | null;
  payment?: string | null;
  transactions?: Array<{ type?: string; amount?: number; paidAt?: unknown; createdAt?: unknown }> | null;
  createdAt?: unknown;
  updatedAt?: unknown;
}

export interface Period {
  from: string;
  to: string;
  zone: string;
}

/** One order as the screens show it. */
export interface FinanceRow {
  id: string;
  number: number | null;
  status: string | null;
  customer: { id: string | null; name: string | null } | null;
  device: string | null;
  total: number;
  paid: number;
  open: number;
  createdAt: string | null;
  /** What this row adds to its list: received in the period, sold total or what is open. */
  amount: number;
}

export interface Debtor {
  /** The customer id, or `_none` for the orders without one. */
  key: string;
  customer: { id: string | null; name: string | null } | null;
  amount: number;
  since: string | null;
  orders: FinanceRow[];
}

export interface FinanceSummary {
  from: string;
  to: string;
  received: { total: number; orders: FinanceRow[] };
  sold: { total: number; orders: FinanceRow[] };
  receivable: { total: number; owed: number; depositOwed: number; customers: number; debtors: Debtor[]; deposits: FinanceRow[] };
  progress: { total: number; orders: FinanceRow[] };
}

export interface ReportRow extends FinanceRow {
  payment: 'paid' | 'pending';
  updatedAt: string | null;
}

export interface FinanceReport {
  from: string;
  to: string;
  count: number;
  paidCount: number;
  revenue: number;
  paid: number;
  remaining: number;
  composition: { services: number; products: number };
  customers: Array<{ id: string | null; name: string | null; total: number; paid: number; remaining: number; count: number }>;
  services: Array<{ name: string | null; total: number; count: number; quantity: number }>;
  products: Array<{ name: string | null; total: number; count: number; quantity: number }>;
  orders: ReportRow[];
}

export const NO_CUSTOMER = '_none';

const cents = (value: unknown): number => Math.round((Number(value) || 0) * 100);
const money = (value: number): number => value / 100;
const text = (value: unknown): string | null => (typeof value === 'string' && value.trim() ? value : null);
const timeOf = (value: unknown, zone: string): number => instantOf(value, zone)?.getTime() ?? 0;
/** The stored date as it came, for the screen (it reads it in the same zone). */
const stored = (value: unknown, zone: string): string | null => {
  if (typeof value === 'string') return value;
  const date = instantOf(value, zone);
  return date ? date.toISOString() : null;
};

/** Counts as sold (Vendido, and every total of the report): anything but quotes and canceled orders. */
export const isSold = (order: FinanceOrder): boolean => order.status !== 'quote' && order.status !== 'canceled';

/** What was paid: legacy paid orders without paidAmount count their total. */
function paidCents(order: FinanceOrder): number {
  if (order.payment === 'paid') return cents(order.paidAmount ?? order.total ?? 0);
  return cents(order.paidAmount ?? 0);
}

function openCents(order: FinanceOrder): number {
  return cents(order.total) - cents(order.paidAmount);
}

/** Has money to receive: not a quote, not canceled, not paid, something open. */
export function isOpen(order: FinanceOrder): boolean {
  return isSold(order) && order.payment !== 'paid' && openCents(order) > 0;
}

const isRunning = (order: FinanceOrder) => order.status === 'approved' || order.status === 'progress';
const hasDeposit = (order: FinanceOrder) => cents(order.paidAmount) > 0;

/** Done with a balance, or running with a down payment: what Receber lists. */
export function isReceivable(order: FinanceOrder): boolean {
  return isOpen(order) && (order.status === 'done' || (isRunning(order) && hasDeposit(order)));
}

const customerOf = (order: FinanceOrder) =>
  order.customer && (order.customer.id || order.customer.name)
    ? { id: text(order.customer.id), name: text(order.customer.name) }
    : null;
const customerKey = (order: FinanceOrder) => text(order.customer?.id) ?? NO_CUSTOMER;

function rowOf(order: FinanceOrder, zone: string, amountCents: number): FinanceRow {
  const device = order.devices?.[0] ?? order.device ?? null;
  return {
    id: order.id,
    number: typeof order.number === 'number' ? order.number : null,
    status: order.status ?? null,
    customer: customerOf(order),
    device: text(device?.name) ?? text(device?.serial),
    total: money(cents(order.total)),
    paid: money(paidCents(order)),
    open: money(isSold(order) && order.payment !== 'paid' ? Math.max(0, openCents(order)) : 0),
    createdAt: stored(order.createdAt, zone),
    amount: money(amountCents),
  };
}

const oldestFirst = (zone: string) => (a: FinanceOrder, b: FinanceOrder) =>
  timeOf(a.createdAt, zone) - timeOf(b.createdAt, zone) || a.id.localeCompare(b.id);

function inPeriod(value: unknown, period: Period): boolean {
  const date = instantOf(value, period.zone);
  if (!date) return false;
  const { start, end } = daysRange(period.from, period.to, period.zone);
  return date >= start && date < end;
}

/**
 * Money received on [order] in the period, by the date of each payment (its
 * chosen `paidAt`, or when it was recorded). Money paid before transactions
 * existed counts on the day the order was created.
 */
export function receivedIn(order: FinanceOrder, period: Period): { cents: number; at: number } {
  const payments = (order.transactions ?? []).filter((t) => t?.type === 'payment');
  let tracked = 0;
  let dated = 0;
  let at = 0;
  for (const payment of payments) {
    tracked += cents(payment.amount);
    const when = payment.paidAt ?? payment.createdAt;
    if (inPeriod(when, period)) {
      dated += cents(payment.amount);
      at = Math.max(at, timeOf(when, period.zone));
    }
  }
  const untracked = paidCents(order) - tracked;
  if (untracked > 0 && inPeriod(order.createdAt, period)) {
    dated += untracked;
    at = Math.max(at, timeOf(order.createdAt, period.zone));
  }
  return { cents: dated, at };
}

/**
 * The Financeiro tab for the period: Recebido and Vendido change with it;
 * A receber and Em andamento are about today. `orders` is every order that
 * may matter (created in the period, paid since its start, and the open ones),
 * repeated ids allowed.
 */
export function summarizeOrders(orders: FinanceOrder[], period: Period): FinanceSummary {
  const { zone } = period;
  const unique = [...new Map(orders.map((order) => [order.id, order])).values()];

  const received = unique
    .filter((order) => order.status !== 'quote')
    .map((order) => ({ order, got: receivedIn(order, period) }))
    .filter(({ got }) => got.cents !== 0)
    .sort((a, b) => b.got.at - a.got.at || a.order.id.localeCompare(b.order.id));

  const sold = unique
    .filter((order) => isSold(order) && inPeriod(order.createdAt, period))
    .sort((a, b) => oldestFirst(zone)(b, a));

  const open = unique.filter(isOpen).sort(oldestFirst(zone));
  const groups = new Map<string, FinanceOrder[]>();
  for (const order of open.filter((o) => o.status === 'done')) {
    const key = customerKey(order);
    groups.set(key, [...(groups.get(key) ?? []), order]);
  }
  const debtors: Debtor[] = [...groups.entries()].map(([key, list]) => ({
    key,
    customer: customerOf(list[0]),
    amount: money(list.reduce((sum, order) => sum + openCents(order), 0)),
    since: stored(list[0].createdAt, zone),
    orders: list.map((order) => rowOf(order, zone, openCents(order))),
  }));
  // Groups keep the order of their oldest order, which `open` already has.
  const running = open.filter(isRunning);
  const deposits = running.filter(hasDeposit);
  const notPaid = running.filter((order) => !hasDeposit(order));
  const owed = open.filter((o) => o.status === 'done').reduce((sum, order) => sum + openCents(order), 0);
  const depositOwed = deposits.reduce((sum, order) => sum + openCents(order), 0);

  return {
    from: period.from,
    to: period.to,
    received: {
      total: money(received.reduce((sum, { got }) => sum + got.cents, 0)),
      orders: received.map(({ order, got }) => rowOf(order, zone, got.cents)),
    },
    sold: {
      total: money(sold.reduce((sum, order) => sum + cents(order.total), 0)),
      orders: sold.map((order) => rowOf(order, zone, cents(order.total))),
    },
    receivable: {
      total: money(owed + depositOwed),
      owed: money(owed),
      depositOwed: money(depositOwed),
      customers: new Set([...debtors.map((d) => d.key), ...deposits.map(customerKey)]).size,
      debtors,
      deposits: deposits.map((order) => rowOf(order, zone, openCents(order))),
    },
    progress: {
      total: money(notPaid.reduce((sum, order) => sum + openCents(order), 0)),
      orders: notPaid.map((order) => rowOf(order, zone, openCents(order))),
    },
  };
}

/** Product line value: its `total`, else value × quantity (the server's order total rule). */
const productCents = (line: NonNullable<FinanceOrder['products']>[number]) =>
  line.total !== undefined && line.total !== null ? cents(line.total) : cents(line.value) * (Number(line.quantity) || 1);

export interface ReportFilters {
  /** A customer id, or 'none' for the orders without one. */
  customer?: string | null;
  payment?: 'paid' | 'unpaid' | null;
}

/**
 * The report of the period: orders created in it, without quotes and canceled
 * ones. A chosen customer narrows every number but the customer ranking; the
 * payment filter narrows only the list of orders ("a receber" is anything not
 * paid, partial and missing included).
 */
export function reportOf(orders: FinanceOrder[], period: Period & ReportFilters): FinanceReport {
  const { zone } = period;
  const unique = [...new Map(orders.map((order) => [order.id, order])).values()];
  const all = unique.filter((order) => isSold(order) && inPeriod(order.createdAt, period));
  const chosen =
    period.customer === 'none'
      ? all.filter((order) => customerKey(order) === NO_CUSTOMER)
      : period.customer
        ? all.filter((order) => text(order.customer?.id) === period.customer)
        : all;

  const remainingOf = (order: FinanceOrder) => (order.payment === 'paid' ? 0 : Math.max(0, openCents(order)));

  const byCustomer = new Map<string, { id: string | null; name: string | null; total: number; paid: number; remaining: number; count: number }>();
  for (const order of all) {
    const key = customerKey(order);
    const entry = byCustomer.get(key) ?? { id: key === NO_CUSTOMER ? null : key, name: text(order.customer?.name), total: 0, paid: 0, remaining: 0, count: 0 };
    entry.total += cents(order.total);
    entry.paid += paidCents(order);
    entry.remaining += remainingOf(order);
    entry.count += 1;
    entry.name ??= text(order.customer?.name);
    byCustomer.set(key, entry);
  }

  const services = new Map<string, { name: string | null; total: number; count: number; quantity: number }>();
  const products = new Map<string, { name: string | null; total: number; count: number; quantity: number }>();
  let servicesCents = 0;
  let productsCents = 0;
  for (const order of chosen) {
    for (const line of order.services ?? []) {
      const name = text(line?.service?.name) ?? text(line?.description);
      const value = cents(line?.value);
      servicesCents += value;
      const entry = services.get(name ?? '') ?? { name, total: 0, count: 0, quantity: 0 };
      entry.total += value;
      entry.count += 1;
      entry.quantity += Number(line?.quantity) || 1;
      services.set(name ?? '', entry);
    }
    for (const line of order.products ?? []) {
      const name = text(line?.product?.name) ?? text(line?.description);
      const value = productCents(line);
      productsCents += value;
      const entry = products.get(name ?? '') ?? { name, total: 0, count: 0, quantity: 0 };
      entry.total += value;
      entry.count += 1;
      entry.quantity += Number(line?.quantity) || 1;
      products.set(name ?? '', entry);
    }
  }

  const listed = chosen
    .filter((order) => (period.payment === 'paid' ? order.payment === 'paid' : period.payment === 'unpaid' ? order.payment !== 'paid' : true))
    .sort(
      (a, b) =>
        timeOf(b.updatedAt, zone) - timeOf(a.updatedAt, zone) ||
        timeOf(b.createdAt, zone) - timeOf(a.createdAt, zone) ||
        a.id.localeCompare(b.id),
    );

  const ranked = <T extends { total: number }>(list: Iterable<T>) => [...list].filter((x) => x.total > 0).sort((a, b) => b.total - a.total);
  const asMoney = <T extends { total: number }>(entry: T) => ({ ...entry, total: money(entry.total) });

  return {
    from: period.from,
    to: period.to,
    count: chosen.length,
    paidCount: chosen.filter((order) => order.payment === 'paid').length,
    revenue: money(chosen.reduce((sum, order) => sum + cents(order.total), 0)),
    paid: money(chosen.reduce((sum, order) => sum + paidCents(order), 0)),
    remaining: money(chosen.reduce((sum, order) => sum + remainingOf(order), 0)),
    composition: { services: money(servicesCents), products: money(productsCents) },
    customers: ranked(byCustomer.values()).map((entry) => ({
      id: entry.id,
      name: entry.name,
      total: money(entry.total),
      paid: money(entry.paid),
      remaining: money(entry.remaining),
      count: entry.count,
    })),
    services: ranked(services.values()).map(asMoney),
    products: ranked(products.values()).map(asMoney),
    orders: listed.map((order) => ({
      ...rowOf(order, zone, cents(order.total)),
      payment: order.payment === 'paid' ? 'paid' : 'pending',
      updatedAt: stored(order.updatedAt, zone),
    })),
  };
}

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

/** Orders read for one answer. Above it the answer says `truncated`. */
export const MAX_ORDERS = 20000;
const PAGE = 1000;
/** Text dates are compared as text: the app's have no zone, so the range is widened and each order placed by the zone. */
const SLACK_MS = 14 * 3600 * 1000;

type Query = FirebaseFirestore.Query;

async function readAll(query: Query, budget: { left: number }): Promise<{ orders: FinanceOrder[]; truncated: boolean }> {
  const orders: FinanceOrder[] = [];
  let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  for (;;) {
    const size = Math.min(PAGE, budget.left);
    if (size <= 0) return { orders, truncated: true };
    const page = await (last ? query.startAfter(last) : query).limit(size).get();
    for (const doc of page.docs) orders.push({ ...(doc.data() as Omit<FinanceOrder, 'id'>), id: doc.id });
    budget.left -= page.docs.length;
    if (page.docs.length < size) return { orders, truncated: false };
    last = page.docs[page.docs.length - 1];
  }
}

const ordersOf = (companyId: string) => db.collection('companies').doc(companyId).collection('orders');

/** Orders created in the period (widened; reportOf and summarizeOrders place each by the zone). */
function createdIn(companyId: string, period: Period): Query {
  const { start, end } = daysRange(period.from, period.to, period.zone);
  return ordersOf(companyId)
    .where('createdAt', '>=', new Date(start.getTime() - SLACK_MS).toISOString())
    .where('createdAt', '<', new Date(end.getTime() + SLACK_MS).toISOString())
    .orderBy('createdAt');
}

/**
 * Every order with money open, any month: `payment` unpaid or partial, and
 * running or done orders without the field (approved outside the app). Equality
 * filters only, as the app reads them (getUnpaidOrders).
 */
async function openOrders(companyId: string, budget: { left: number }) {
  const [unpaid, missing] = await Promise.all([
    readAll(ordersOf(companyId).where('payment', 'in', ['unpaid', 'partial']).orderBy('__name__'), budget),
    readAll(ordersOf(companyId).where('payment', '==', null).where('status', 'in', ['approved', 'progress', 'done']).orderBy('__name__'), budget),
  ]);
  return { orders: [...unpaid.orders, ...missing.orders], truncated: unpaid.truncated || missing.truncated };
}

export async function financeSummary(companyId: string, period: Period): Promise<FinanceSummary & { truncated: boolean }> {
  const budget = { left: MAX_ORDERS };
  const { start } = daysRange(period.from, period.to, period.zone);
  const [created, paid, open] = await Promise.all([
    readAll(createdIn(companyId, period), budget),
    // lastPaymentAt (UTC ISO, kept by the server) finds the orders paid since the start, whenever created.
    readAll(ordersOf(companyId).where('lastPaymentAt', '>=', start.toISOString()).orderBy('lastPaymentAt'), budget),
    openOrders(companyId, budget),
  ]);
  return {
    ...summarizeOrders([...created.orders, ...paid.orders, ...open.orders], period),
    truncated: created.truncated || paid.truncated || open.truncated,
  };
}

export async function financeReport(companyId: string, period: Period & ReportFilters): Promise<FinanceReport & { truncated: boolean }> {
  const created = await readAll(createdIn(companyId, period), { left: MAX_ORDERS });
  return { ...reportOf(created.orders, period), truncated: created.truncated };
}

/** Financeiro > Receber: every order that still owes, oldest first. */
export async function receivableOrders(companyId: string, zone: string): Promise<{ orders: FinanceRow[]; truncated: boolean }> {
  const open = await openOrders(companyId, { left: MAX_ORDERS });
  const unique = [...new Map(open.orders.map((order) => [order.id, order])).values()];
  return {
    orders: unique
      .filter(isReceivable)
      .sort(oldestFirst(zone))
      .map((order) => rowOf(order, zone, openCents(order))),
    truncated: open.truncated,
  };
}
