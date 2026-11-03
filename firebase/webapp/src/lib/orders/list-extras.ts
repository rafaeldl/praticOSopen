// What the list does after it shows, loaded then (out of the first download):
// the ⌘K search over orders and customers, the Sem receber count and the lists
// Nova OS needs.
import { shallowRef } from 'vue'
import { t } from '@/i18n'
import { registerSearcher, type Command } from '@/lib/commands'
import { loadCatalog, loadCustomers, loadDevices, type Customer } from './catalog'
import { firestoreLite } from '@/lib/firebase'
import { roundMoney } from '@/lib/rules/order-rules'
import type { ListContext } from './data'
import { deviceSummary, exactFirst, matchesSearch, normalizeOrder, remainingOnRow, type Order } from './model'
import { orderShort, statusText } from './text'

/**
 * "Sem receber": done orders with a balance. Read through `payment == 'unpaid'`
 * (indexed with createdAt), newest 200, then counted here. Null when unknown.
 */
async function unpaidOrders(ctx: ListContext): Promise<Order[] | null> {
  if (!ctx.showsMoney) return null
  try {
    const [db, { collection, getDocs, limit, orderBy, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
    const filters = [where('payment', '==', 'unpaid'), ...(ctx.seesAll ? [] : [where('createdBy.id', '==', ctx.uid)])]
    const snapshot = await getDocs(query(collection(db, 'companies', ctx.companyId, 'orders'), ...filters, orderBy('createdAt', 'desc'), limit(200)))
    return snapshot.docs.map((doc) => normalizeOrder(doc.id, doc.data(), true)).filter((order) => remainingOnRow(order) !== null)
  } catch (error) {
    console.warn('orders: unpaid not read', error)
    return null
  }
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
export function unpaidTotals(ctx: ListContext): Promise<{ count: number; amount: number } | null> {
  return unpaidOrders(ctx).then((list) =>
    list ? { count: list.length, amount: roundMoney(list.reduce((sum, order) => sum + (remainingOnRow(order) ?? 0), 0)) } : null,
  )
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
