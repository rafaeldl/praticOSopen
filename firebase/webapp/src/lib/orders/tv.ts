// Modo TV (#627): the board on a screen in the shop, all day. Read-only, no
// values, live. Each column is its own query (the newest TV_LIMIT of that
// status), so old orders piling up in one status never push the others out.
// Concluído is only what was done today (completedAt, written by the server).
import { watchFirstRows, type OrdersQuery } from '@/lib/orders-query'
import { currentZone, fromWall, wallParts } from '@/lib/zone'
import { createListLoader, type ListContext } from './data'
import { isHeld, lateness, normalizeOrder, type Order, type OrderStatus } from './model'

export const TV_COLUMNS: OrderStatus[] = ['quote', 'approved', 'progress', 'done']
/** Cards per column: more than a TV shows, few enough to stay cheap. */
export const TV_LIMIT = 50
/** Who reads the API (no Firestore) asks again this often. */
export const TV_API_REFRESH_MS = 2 * 60_000

export type TvColumns = Record<OrderStatus, Order[]>

/** "2026-11-06": the company's day of this instant. */
export function companyDay(now: Date): string {
  const p = wallParts(now)
  return `${p.y}-${String(p.m).padStart(2, '0')}-${String(p.d).padStart(2, '0')}`
}

/** The instant the company's day starts, as the server writes completedAt (UTC ISO). */
export function dayStartIso(now: Date, zone = currentZone()): string {
  return fromWall(companyDay(now), 0, 0, zone).toISOString()
}

/** Done today: completedAt from the start of the company's day on. */
export function doneToday(orders: Order[], dayStart: string): Order[] {
  return orders
    .filter((order) => order.status === 'done' && !!order.completedAt && order.completedAt >= dayStart)
    .sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''))
}

/**
 * What needs eyes first: late ones (most late first), then stopped ones, then
 * the rest as they came (newest first). Stable.
 */
export function sortForTv(orders: Order[], now: Date): Order[] {
  const rank = (order: Order) => {
    const late = lateness(order, now)
    if (late) return 0
    return isHeld(order) ? 1 : 2
  }
  const lateDays = (order: Order) => {
    const due = order.dueDate ? Date.parse(order.dueDate) : NaN
    return Number.isNaN(due) ? 0 : now.getTime() - due
  }
  return orders
    .map((order, index) => ({ order, index }))
    .sort((a, b) => rank(a.order) - rank(b.order) || (rank(a.order) === 0 ? lateDays(b.order) - lateDays(a.order) : 0) || a.index - b.index)
    .map(({ order }) => order)
}

export const emptyColumns = (): TvColumns => ({ quote: [], approved: [], progress: [], done: [], canceled: [] })

/**
 * Live columns. Firestore readers get one listener per column; API readers
 * (no values) ask again every TV_API_REFRESH_MS and when `refresh()` is called.
 * Orders are kept without values (normalizeOrder with showsMoney false): the
 * TV never shows money.
 */
export function watchTv(
  ctx: ListContext,
  dayStart: string,
  onColumn: (status: OrderStatus, orders: Order[]) => void,
  onError: (error: unknown) => void,
): { stop: () => void; refresh: () => Promise<void> } {
  const stops: (() => void)[] = []
  let stopped = false
  const open = TV_COLUMNS.filter((status) => status !== 'done')

  if (ctx.showsMoney) {
    const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, false)
    const listen = (query: OrdersQuery, status: OrderStatus) =>
      watchFirstRows(query, TV_LIMIT, (rows) => onColumn(status, rows.map(toOrder)), onError, true).then((stop) => (stopped ? stop() : stops.push(stop)))
    const base = { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid }
    for (const status of open) void listen({ ...base, statuses: [status] }, status).catch(onError)
    // Single-field range: no composite index. The TV route asks for viewAllOrders, so no createdBy here.
    void listen({ ...base, createdBy: null, where: [['completedAt', '>=', dayStart]], order: { field: 'completedAt', dir: 'desc' } }, 'done').catch(onError)
    return {
      stop: () => {
        stopped = true
        stops.splice(0).forEach((stop) => stop())
      },
      refresh: () => Promise.resolve(),
    }
  }

  const refresh = async () => {
    try {
      await Promise.all(
        TV_COLUMNS.map(async (status) => {
          const rows = (await createListLoader(ctx, [status]).first()).rows
          if (!stopped) onColumn(status, status === 'done' ? doneToday(rows, dayStart) : rows)
        }),
      )
    } catch (error) {
      onError(error)
    }
  }
  void refresh()
  const timer = setInterval(() => void refresh(), TV_API_REFRESH_MS)
  return {
    stop: () => {
      stopped = true
      clearInterval(timer)
    },
    refresh,
  }
}
