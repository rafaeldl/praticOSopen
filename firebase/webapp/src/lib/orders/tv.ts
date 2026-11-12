// Modo TV (#627): the board on a screen in the shop, all day. Read-only, no
// values, live. Each column is its own query (the newest TV_LIMIT of that
// status), so old orders piling up in one status never push the others out.
// Concluído is only what was done today (completedAt, written by the server).
import { ordersPage, watchFirstRows, type OrdersQuery } from '@/lib/orders-query'
import { currentZone, fromWall, wallParts } from '@/lib/zone'
import { createListLoader, type ListContext } from './data'
import { isHeld, lateness, normalizeOrder, type Order, type OrderStatus } from './model'

export const TV_COLUMNS: OrderStatus[] = ['quote', 'approved', 'progress', 'done']
/** Cards per column: more than a TV shows, few enough to stay cheap. */
export const TV_LIMIT = 50
/** Who reads the API (no Firestore) asks again this often. */
export const TV_API_REFRESH_MS = 2 * 60_000
/**
 * The live link has this long to bring server data to every column. Some TV
 * browsers never hold it open (no error, no data): then the TV reads pages,
 * like the list does, every TV_POLL_MS. Longer than the SDK's own 10 s offline wait.
 */
export const TV_LIVE_WAIT_MS = 15_000
export const TV_POLL_MS = 60_000

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
  if (ctx.showsMoney) return watchFirestore(ctx, dayStart, onColumn, onError)

  let stopped = false

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

/** One Firestore query per column: the newest TV_LIMIT of each open status, and the done of today. */
export function tvQueries(ctx: ListContext, dayStart: string): [OrderStatus, OrdersQuery][] {
  const base = { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid }
  return [
    ...TV_COLUMNS.filter((status) => status !== 'done').map((status): [OrderStatus, OrdersQuery] => [status, { ...base, statuses: [status] }]),
    // Single-field range: no composite index. The TV route asks for viewAllOrders, so no createdBy here.
    ['done', { ...base, createdBy: null, where: [['completedAt', '>=', dayStart]], order: { field: 'completedAt', dir: 'desc' } }],
  ]
}

/**
 * Who reads Firestore: live listeners, and pages every TV_POLL_MS when the live
 * link brings no server data within TV_LIVE_WAIT_MS or fails (TV browsers).
 */
function watchFirestore(
  ctx: ListContext,
  dayStart: string,
  onColumn: (status: OrderStatus, orders: Order[]) => void,
  onError: (error: unknown) => void,
): { stop: () => void; refresh: () => Promise<void> } {
  const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, false)
  const queries = tvQueries(ctx, dayStart)
  const stops: (() => void)[] = []
  const synced = new Set<OrderStatus>()
  let stopped = false
  let polling = false
  let timer: ReturnType<typeof setInterval> | undefined
  let wait: ReturnType<typeof setTimeout> | undefined

  const stopLive = () => stops.splice(0).forEach((stop) => stop())

  const poll = async () => {
    try {
      const pages = await Promise.all(queries.map(async ([status, query]) => [status, await ordersPage(query, TV_LIMIT)] as const))
      if (!stopped) pages.forEach(([status, rows]) => onColumn(status, rows.map(toOrder)))
    } catch (error) {
      if (!stopped) onError(error)
    }
  }

  const fallBack = (reason: unknown) => {
    if (stopped || polling) return
    polling = true
    console.warn('tv: live link without server data, reading pages instead', reason)
    clearTimeout(wait)
    stopLive()
    void poll()
    timer = setInterval(() => void poll(), TV_POLL_MS)
  }

  for (const [status, query] of queries) {
    void watchFirstRows(
      query,
      TV_LIMIT,
      (rows, fromCache) => {
        if (polling) return
        if (!fromCache) synced.add(status)
        onColumn(status, rows.map(toOrder))
      },
      fallBack,
      true,
    ).then(
      (stop) => (stopped || polling ? stop() : stops.push(stop)),
      fallBack,
    )
  }
  wait = setTimeout(() => {
    if (synced.size < queries.length) fallBack('timeout')
  }, TV_LIVE_WAIT_MS)

  return {
    stop: () => {
      stopped = true
      clearTimeout(wait)
      clearInterval(timer)
      stopLive()
    },
    refresh: () => (polling ? poll() : Promise.resolve()),
  }
}
