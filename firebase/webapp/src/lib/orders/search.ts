// The search of Início (Lista and Quadro) asked to the server: the number, the
// customers whose name matches and the vehicles (or devices) whose name or plate
// matches, each one an indexed query of the orders. An order far from the loaded
// pages is still found. Who sees only their own orders keeps that filter (rules).
import { firestoreLite } from '@/lib/firebase'
import { orderByNumber } from '@/lib/orders-query'
import { api } from '@/lib/session'
import { matchesWords } from '@/lib/text'
import { loadCustomers, loadDevices } from './catalog'
import type { ListContext } from './data'
import { normalizeOrder, type Order } from './model'

/** Customers and devices asked per search: `in` and `array-contains-any` take up to 30. */
export const MAX_MATCHES = 10
/** Orders per query: the newest of each customer or device. */
export const PER_QUERY = 50

interface ApiList {
  data?: Record<string, unknown>[]
}

/** Customers and devices the typed words match (start of a word, no accents, no case). */
export function matchIds(text: string, customers: { id: string; name: string }[], devices: { id: string; name: string; serial?: string | null }[]) {
  const query = text.trim()
  if (!query) return { customers: [] as string[], devices: [] as string[] }
  return {
    customers: customers.filter((customer) => matchesWords(customer.name, query)).slice(0, MAX_MATCHES).map((customer) => customer.id),
    devices: devices
      .filter((device) => matchesWords(`${device.name} ${device.serial ?? ''}`, query))
      .slice(0, MAX_MATCHES)
      .map((device) => device.id),
  }
}

const unique = (orders: Order[]) => {
  const byId = new Map(orders.map((order) => [order.id, order]))
  return [...byId.values()]
}

/**
 * Orders matching the search, from the server. Firestore for who sees values:
 * number (`number ==`), customer (`customer.id in`, newest first, with
 * createdBy.id for who sees only their own) and device (`deviceIds
 * array-contains-any`, only for who sees every order: the single-field index
 * covers it). The API for who does not see values: number and customer
 * (`customerId`), the API applies created-by and assigned-to.
 */
export async function searchOrders(ctx: ListContext, text: string): Promise<Order[]> {
  const query = text.trim()
  if (!query) return []
  const number = Number(query)
  const isNumber = Number.isInteger(number) && number > 0
  const [customers, devices] = await Promise.all([loadCustomers().catch(() => []), loadDevices().catch(() => [])])
  const ids = matchIds(query, customers, devices)
  const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, ctx.showsMoney)
  const createdBy = ctx.seesAll ? null : ctx.uid

  if (!ctx.showsMoney) {
    const read = async (params: Record<string, string>) => {
      const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?${new URLSearchParams(params)}`, { raw: true })
      return ((Array.isArray(body) ? body : body.data) ?? []).map(toOrder)
    }
    const pages = await Promise.all([
      ...(isNumber ? [read({ number: String(number) })] : []),
      ...ids.customers.slice(0, 5).map((customerId) => read({ customerId, limit: String(PER_QUERY) })),
    ])
    return unique(pages.flat())
  }

  const [db, { collection, getDocs, limit, orderBy, query: build, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const orders = collection(db, 'companies', ctx.companyId, 'orders')
  const owner = createdBy ? [where('createdBy.id', '==', createdBy)] : []
  const rows = (snapshot: { docs: { id: string; data: () => Record<string, unknown> }[] }) => snapshot.docs.map((doc) => toOrder({ ...doc.data(), id: doc.id }))
  const pages = await Promise.all([
    isNumber ? orderByNumber({ companyId: ctx.companyId, createdBy }, number).then((found) => found.map((row) => toOrder(row))) : Promise.resolve([]),
    ids.customers.length
      ? getDocs(build(orders, ...owner, where('customer.id', 'in', ids.customers), orderBy('createdAt', 'desc'), limit(PER_QUERY))).then(rows)
      : Promise.resolve([]),
    ids.devices.length && !createdBy ? getDocs(build(orders, where('deviceIds', 'array-contains-any', ids.devices), limit(PER_QUERY))).then(rows) : Promise.resolve([]),
  ])
  return unique(pages.flat())
}
