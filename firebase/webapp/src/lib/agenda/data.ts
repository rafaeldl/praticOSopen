// The agenda reads and writes through the API (/v1/app/orders), for every role:
// the server applies who sees what (created by, assigned to) and drops money
// for who lacks viewPrices, the same projection as the list.
import { api, can } from '@/lib/session'
import { normalizeOrder, type Order } from '@/lib/orders/model'
import { patchOrder } from '@/lib/orders/writes'

export type AgendaField = 'scheduledDate' | 'dueDate'

export interface AgendaOrder {
  order: Order
  /** The date as stored (text without a zone from the app), placed by lib/agenda/model.ts. */
  stored: string | null
}

interface ApiList {
  data?: Record<string, unknown>[]
  pagination?: { hasMore?: boolean; nextCursor?: string | null }
}

const PAGE = 100
/** 30 pages of 100: a busy month of a big team. Past that the screen says the list is cut. */
const MAX_PAGES = 30

export interface AgendaQuery {
  field: AgendaField
  startDate: string
  endDate: string
  /** "De quem": orders assigned to this person (no assignee leaves them out, like the app). */
  assignedTo?: string | null
}

export async function loadAgenda(query: AgendaQuery): Promise<{ orders: AgendaOrder[]; cut: boolean }> {
  const showsMoney = can('viewPrices')
  const orders: AgendaOrder[] = []
  let cursor: string | null = null
  for (let page = 0; page < MAX_PAGES; page++) {
    const params = new URLSearchParams({ sort: query.field, direction: 'asc', startDate: query.startDate, endDate: query.endDate, limit: String(PAGE) })
    if (query.assignedTo) params.set('assignedTo', query.assignedTo)
    if (cursor) params.set('cursor', cursor)
    const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?${params}`, { raw: true })
    const envelope = Array.isArray(body) ? { data: body } : body
    for (const row of envelope.data ?? []) {
      const stored = row[query.field]
      orders.push({ order: normalizeOrder(String(row.id), row, showsMoney), stored: typeof stored === 'string' ? stored : null })
    }
    cursor = envelope.pagination?.hasMore ? (envelope.pagination.nextCursor ?? null) : null
    if (!cursor) return { orders, cut: false }
  }
  return { orders, cut: true }
}

/** Only the date: PATCH respects canEditOrderMainFields and the version read (409 ORDER_CHANGED). */
export function saveDate(order: Order, field: AgendaField, value: string | null) {
  return patchOrder(order.id, { [field]: value }, order.version)
}
