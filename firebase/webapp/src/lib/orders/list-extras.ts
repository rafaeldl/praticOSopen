// What the list does after it shows, loaded then (out of the first download):
// the ⌘K search over orders and customers, the Sem receber count and the lists
// Nova OS needs.
import { shallowRef } from 'vue'
import { t } from '@/i18n'
import { registerSearcher, type Command } from '@/lib/commands'
import { loadCatalog, loadCustomers, loadDevices, type Customer } from './catalog'
import { countOrders, type OrdersQuery } from '@/lib/orders-query'
import { roundMoney } from '@/lib/rules/order-rules'
import { apiCount, filterSources, type ListContext } from './data'
import { deviceSummary, exactFirst, matchesSearch, type FilterCounts, type ListFilter, type Order } from './model'
import { orderShort, statusText } from './text'

/**
 * What the server counts for a filter (home.summary.count), with the same
 * queries as the pages: a Firestore aggregation for who sees values, the API's
 * `total` for who does not. Null when the server cannot count it (Paradas on
 * the API, a technician's own orders) or for a filter without a sentence.
 */
export async function filterCounts(ctx: ListContext, filter: ListFilter, now: Date): Promise<FilterCounts | null> {
  if (!['open', 'quotes', 'onHold', 'unpaid', 'mine'].includes(filter)) return null
  try {
    const [source] = filterSources(ctx, filter, now)
    if (!source) return null
    if (ctx.showsMoney) {
      if (filter === 'unpaid') return await unpaidCounts(ctx, now)
      const [all, late] = await Promise.all([
        countOrders(source.firestore),
        filter === 'open' ? countOrders((filterSources(ctx, 'late', now)[0] as { firestore: OrdersQuery }).firestore) : null,
      ])
      return { count: all.count, ...(late ? { late: late.count } : {}) }
    }
    if (source.keep) return null
    const [all, late] = await Promise.all([apiCount(source.api), filter === 'open' ? apiCount(filterSources(ctx, 'late', now)[0]?.api ?? {}) : null])
    if (all === null) return null
    return { count: all, ...(late !== null ? { late } : {}) }
  } catch (error) {
    console.warn('orders: not counted', error)
    return null
  }
}

/** Sem receber: how many and how much is left (sum of totals less sum of what was paid). */
async function unpaidCounts(ctx: ListContext, now: Date): Promise<FilterCounts | null> {
  const source = filterSources(ctx, 'unpaid', now)[0]
  if (!source) return null
  const { count, sums } = await countOrders(source.firestore, ['total', 'paidAmount'])
  return { count, amount: roundMoney(Math.max(0, (sums.total ?? 0) - (sums.paidAmount ?? 0))) }
}


// Reactive, so the open palette shows customers as soon as they arrive.
const customers = shallowRef<Customer[]>([])

/** Nova OS opens with its lists ready; the palette finds customers from the same list. */
export function warmLists(): void {
  void Promise.all([loadCustomers(), loadDevices(), loadCatalog()])
    .then(([list]) => (customers.value = list))
    .catch(() => {})
}

/** How many done orders still owe and how much in all (the day opens with it: "R$ 2.151 para receber"). */
export async function unpaidTotals(ctx: ListContext): Promise<{ count: number; amount: number } | null> {
  if (!ctx.showsMoney) return null
  try {
    const counts = await unpaidCounts(ctx, new Date())
    return counts ? { count: counts.count, amount: counts.amount ?? 0 } : null
  } catch (error) {
    console.warn('orders: unpaid not counted', error)
    return null
  }
}

/** ⌘K finds an order by number (exact first), customer or device, and a customer (opens their orders). */
export function paletteSearch(rows: () => Order[], openOrder: (id: string) => void, showCustomer: (name: string) => void): () => void {
  return registerSearcher('orders', (query): Command[] => {
    const orders = exactFirst(rows().filter((order) => matchesSearch(order, query, statusText(order.status))), query)
      .slice(0, 6)
      .map((order) => ({
        id: `order:${order.id}`,
        label: 'order' as const,
        text: `${orderShort()} ${order.number ?? ''} · ${order.customer?.name ?? ''}`,
        sub: deviceSummary(order) || statusText(order.status),
        run: () => openOrder(order.id),
      }))
    if (!customers.value.length) void loadCustomers().then((list) => (customers.value = list)).catch(() => {})
    const people = customers.value
      .filter((customer) => matchesSearch({ customer, devices: [] } as unknown as Order, `${query}`, customer.phone ?? ''))
      .slice(0, 4)
      .map((customer) => ({ id: `customer:${customer.id}`, label: 'customer' as const, text: customer.name, sub: t('customer'), run: () => showCustomer(customer.name) }))
    return [...orders, ...people]
  })
}
