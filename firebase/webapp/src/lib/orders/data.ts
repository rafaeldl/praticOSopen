// Where orders are read from (ADR-001): Firestore for who sees values, the API
// projection (no money in any field) for who does not. Writes are in writes.ts.
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import {
  FIRST_PAGE,
  PAGE_SIZE,
  filterQueries,
  firstOrdersPage,
  nextOrdersPage,
  orderByNumber,
  watchFirstRows,
  type DayBounds,
  type OrderRow,
  type OrdersQuery,
} from '@/lib/orders-query'
import { api, can, session } from '@/lib/session'
import { wallParts } from '@/lib/zone'
import { lineIds } from './line-ids'
import { OPEN_STATUSES, isHeld, normalizeOrder, type ListFilter, type Order, type OrderStatus } from './model'

export interface ListContext {
  companyId: string
  uid: string
  /** viewAllOrders: otherwise only the orders this person created (rules and API). */
  seesAll: boolean
  /** viewPrices with values on: Firestore. Otherwise the API projection. */
  showsMoney: boolean
}

export function listContext(): ListContext {
  return {
    companyId: session.companyId as string,
    uid: session.uid as string,
    seesAll: can('viewAllOrders'),
    showsMoney: can('viewPrices'),
  }
}

export interface ListPage {
  rows: Order[]
  hasMore: boolean
}

interface ApiList {
  data?: Record<string, unknown>[]
  pagination?: { hasMore?: boolean; nextCursor?: string | null; total?: number }
}

/** One server query of a list: Firestore (who sees values) and the same thing asked to the API. */
interface Source {
  firestore: OrdersQuery
  api: Record<string, string>
  /**
   * Only for the API when it has no filter for it (Paradas): rows kept from the
   * pages read, which go on until a page is full or the list ends.
   */
  keep?: (order: Order) => boolean
}

interface PageReader {
  first(): Promise<ListPage>
  more(): Promise<ListPage>
}

/**
 * Pages of one source. Firestore pages by the sort field and id; the API by
 * its cursor. Both keep the same order.
 */
function sourceReader(ctx: ListContext, source: Source): PageReader {
  const query = source.firestore
  let lastRaw: OrderRow | null = null
  let cursor: string | null = null
  let apiDone = false
  const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, ctx.showsMoney)

  async function apiPage(size: number): Promise<ListPage> {
    const params = new URLSearchParams({ ...source.api, limit: String(size) })
    if (cursor) params.set('cursor', cursor)
    // The list carries pagination next to data: read the raw envelope.
    const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?${params}`, { raw: true })
    const envelope = Array.isArray(body) ? { data: body } : body
    cursor = envelope.pagination?.nextCursor ?? null
    apiDone = !envelope.pagination?.hasMore || !cursor
    return { rows: (envelope.data ?? []).map(toOrder), hasMore: !apiDone }
  }

  /** The API without the filter: read on until `size` rows are kept or the list ends. */
  async function apiKept(size: number, keep: (order: Order) => boolean): Promise<ListPage> {
    const rows: Order[] = []
    do {
      const page = await apiPage(PAGE_SIZE)
      rows.push(...page.rows.filter(keep))
    } while (!apiDone && rows.length < size)
    return { rows, hasMore: !apiDone }
  }

  return {
    async first(): Promise<ListPage> {
      lastRaw = null
      cursor = null
      apiDone = false
      if (!ctx.showsMoney) return source.keep ? apiKept(FIRST_PAGE, source.keep) : apiPage(FIRST_PAGE)
      const raw = await firstOrdersPage(query)
      lastRaw = raw[raw.length - 1] ?? null
      return { rows: raw.map(toOrder), hasMore: raw.length === FIRST_PAGE }
    },
    async more(): Promise<ListPage> {
      if (!ctx.showsMoney) {
        if (apiDone) return { rows: [], hasMore: false }
        return source.keep ? apiKept(PAGE_SIZE, source.keep) : apiPage(PAGE_SIZE)
      }
      if (!lastRaw) return { rows: [], hasMore: false }
      const raw = await nextOrdersPage(query, lastRaw, PAGE_SIZE)
      lastRaw = raw[raw.length - 1] ?? lastRaw
      return { rows: raw.map(toOrder), hasMore: raw.length === PAGE_SIZE }
    },
  }
}

/** Two sources read side by side (Para hoje: delivery today, visit today), the same order once. */
function mergedReader(readers: PageReader[]): PageReader {
  let open = readers.map(() => true)
  const join = (pages: (ListPage | null)[]) => {
    open = pages.map((page, index) => (page ? page.hasMore : open[index] as boolean))
    const seen = new Set<string>()
    const rows = pages.flatMap((page) => page?.rows ?? []).filter((row) => (seen.has(row.id) ? false : (seen.add(row.id), true)))
    return { rows, hasMore: open.some(Boolean) }
  }
  return {
    async first() {
      return join(await Promise.all(readers.map((reader) => reader.first())))
    },
    async more() {
      return join(await Promise.all(readers.map((reader, index) => (open[index] ? reader.more() : null))))
    },
  }
}

function makeLoader(ctx: ListContext, sources: Source[]) {
  const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, ctx.showsMoney)
  const readers = sources.map((source) => sourceReader(ctx, source))
  const reader = readers.length === 1 ? (readers[0] as PageReader) : mergedReader(readers)
  const base: OrdersQuery = { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid }
  return {
    query: (sources[0] as Source).firestore,
    first: () => reader.first(),
    more: () => reader.more(),
    /** Live first rows (Firestore, one source only). The API list is refreshed after each write instead. */
    watch(size: number, onRows: (rows: Order[]) => void, onError: (error: unknown) => void) {
      if (!ctx.showsMoney || sources.length !== 1) return Promise.resolve(() => {})
      return watchFirstRows((sources[0] as Source).firestore, size, (rows) => onRows(rows.map(toOrder)), onError)
    },
    async byNumber(number: number): Promise<Order[]> {
      // Who does not see values asks the API (projected, only what the person may see).
      if (!ctx.showsMoney) {
        const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?number=${number}`, { raw: true })
        return ((Array.isArray(body) ? body : body.data) ?? []).map(toOrder)
      }
      return (await orderByNumber(base, number)).map(toOrder)
    },
  }
}

/**
 * Pages of some statuses, newest first (the board, and Minhas by `assignedTo`).
 */
export function createListLoader(ctx: ListContext, statuses: OrderStatus[] | null, assignedTo?: string) {
  const api: Record<string, string> = {}
  if (statuses?.length) api.status = statuses.join(',')
  if (assignedTo) api.assignedTo = assignedTo
  return makeLoader(ctx, [{ firestore: { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid, statuses }, api }])
}

export type ListLoader = ReturnType<typeof createListLoader>

const OPEN_PARAM = OPEN_STATUSES.join(',')

/**
 * The company's day as the app stores dates (wall text, no zone): the bounds
 * of Atrasadas and Para hoje.
 */
export function dayBounds(now: Date): DayBounds {
  const p = wallParts(now)
  const text = (date: Date) => date.toISOString().slice(0, 10)
  const today = new Date(Date.UTC(p.y, p.m - 1, p.d))
  return { today: `${text(today)}T00:00:00.000`, tomorrow: `${text(new Date(today.getTime() + 86400000))}T00:00:00.000` }
}

/**
 * The API's range is inclusive and turned into UTC text before it is compared
 * with the stored text. The last instant before a wall day, written as UTC,
 * compares with stored text the way the Firestore bound does.
 */
const lastBefore = (wallDay: string) => `${new Date(Date.parse(`${wallDay.slice(0, 10)}T00:00:00.000Z`) - 1).toISOString()}`

/**
 * The server queries of an Início filter (home.filter.*): Firestore for who sees
 * values (lib/orders-query.ts filterQueries), the API for who does not. Pages
 * come already filtered; the screen only orders them.
 */
export function filterSources(ctx: ListContext, filter: ListFilter, now: Date): Source[] {
  const day = dayBounds(now)
  const queries = filterQueries(filter, { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid, uid: ctx.uid }, day) ?? []
  const apis: Record<string, string>[] = (() => {
    switch (filter) {
      case 'open':
        return [{ status: OPEN_PARAM }]
      case 'late':
        return [{ status: OPEN_PARAM, sort: 'dueDate', direction: 'asc', startDate: '1970-01-01T00:00:00.000Z', endDate: lastBefore(day.today) }]
      case 'today':
        return (['dueDate', 'scheduledDate'] as const).map((sort) => ({ status: OPEN_PARAM, sort, direction: 'asc', startDate: lastBefore(day.today), endDate: lastBefore(day.tomorrow) }))
      case 'quotes':
        return [{ status: 'quote', sort: 'createdAt', direction: 'asc' }]
      case 'onHold':
        return [{ status: 'approved,progress' }]
      case 'unpaid':
      case 'done':
        return [{ status: 'done' }]
      case 'mine':
        return [{ status: OPEN_PARAM, assignedTo: ctx.uid }]
      default:
        return [{}]
    }
  })()
  return queries.map((firestore, index) => ({
    firestore,
    api: apis[index] ?? {},
    // The API has no hold filter: Paradas reads the open pages and keeps the stopped ones.
    ...(filter === 'onHold' ? { keep: isHeld } : {}),
  }))
}

/** The pages of an Início filter, straight from the server (home.filter.*). */
export function createFilterLoader(ctx: ListContext, filter: ListFilter, now: Date) {
  return makeLoader(ctx, filterSources(ctx, filter, now))
}

/** How many orders the API has for these parameters (`total` of the first page); null when it does not say. */
export async function apiCount(params: Record<string, string>): Promise<number | null> {
  const body = await api<ApiList | unknown[]>(`/v1/app/orders?${new URLSearchParams({ ...params, limit: '1' })}`, { raw: true })
  const total = Array.isArray(body) ? undefined : body.pagination?.total
  return typeof total === 'number' ? total : null
}

/** "Primeira vez": has this company ever created an order? Unknown counts as yes. */
export async function companyHasOrders(ctx: ListContext): Promise<boolean> {
  try {
    if (!ctx.showsMoney) {
      const body = await api<ApiList | unknown[]>('/v1/app/orders?limit=1', { raw: true })
      return (Array.isArray(body) ? body : (body.data ?? [])).length > 0
    }
    const [db, { collection, getDocs, limit, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
    const filters = ctx.seesAll ? [] : [where('createdBy.id', '==', ctx.uid)]
    const snapshot = await getDocs(query(collection(db, 'companies', ctx.companyId, 'orders'), ...filters, limit(1)))
    return !snapshot.empty
  } catch {
    return true
  }
}

export type DetailState =
  | { kind: 'loading' }
  | { kind: 'ready'; order: Order }
  | { kind: 'notFound' }
  | { kind: 'failed' }

/** Order from Firestore with the item ids the API expects. */
export async function orderFromDoc(id: string, raw: Record<string, unknown>): Promise<Order> {
  const order = normalizeOrder(id, raw, true)
  const ids = await lineIds(raw.services as Record<string, unknown>[], raw.products as Record<string, unknown>[])
  order.lines.forEach((line, index) => (line.id = ids[index] ?? line.id))
  return order
}

const isMissing = (error: unknown) => {
  const code = (error as { code?: string; status?: number })?.code
  return code === 'permission-denied' || code === 'NOT_FOUND' || code === 'FORBIDDEN' || code === 'INSUFFICIENT_PERMISSIONS'
}

/** How long the live channel may stay silent before the order is read once instead (B6). */
export const LIVE_TIMEOUT_MS = 6000

/**
 * One order, kept current. Firestore listens (who sees values); the API is read
 * again on `refresh()` and when the window gets focus. A deleted order, or one
 * this person cannot open, is "not found" (never an empty editable order).
 *
 * The live channel can stall (a busy network or emulator): after LIVE_TIMEOUT_MS
 * without its first answer, the order is read once through the REST build and
 * the channel keeps trying behind it. If that read fails too, the screen shows
 * the error with "Tentar de novo", never "Carregando…" forever.
 */
export function watchOrder(ctx: ListContext, id: string, onState: (state: DetailState) => void) {
  let stop: (() => void) | undefined
  let alive = true
  let answered = false
  let timer: ReturnType<typeof setTimeout> | undefined

  async function readApi() {
    try {
      const data = await api<Record<string, unknown>>(`/v1/app/orders/${encodeURIComponent(id)}`)
      if (alive) onState({ kind: 'ready', order: normalizeOrder(id, data, false) })
    } catch (error) {
      if (alive) onState({ kind: isMissing(error) ? 'notFound' : 'failed' })
    }
  }

  /** One read without the channel (REST build). */
  async function readOnce() {
    try {
      const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
      const snapshot = await getDoc(doc(db, 'companies', ctx.companyId, 'orders', id))
      if (!alive || answered) return
      if (!snapshot.exists()) onState({ kind: 'notFound' })
      else {
        const order = await orderFromDoc(id, snapshot.data() as Record<string, unknown>)
        if (alive && !answered) onState({ kind: 'ready', order })
      }
    } catch (error) {
      if (alive && !answered) onState({ kind: isMissing(error) ? 'notFound' : 'failed' })
    }
  }

  async function listen() {
    stop?.()
    answered = false
    clearTimeout(timer)
    timer = setTimeout(() => void readOnce(), LIVE_TIMEOUT_MS)
    const [db, { doc, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
    if (!alive) return
    stop = onSnapshot(
      doc(db, 'companies', ctx.companyId, 'orders', id),
      (snapshot) => {
        // A miss in this browser's cache is not "deleted": wait for the server (or the read after the timeout).
        if (!snapshot.exists() && snapshot.metadata.fromCache) return
        answered = true
        clearTimeout(timer)
        if (!snapshot.exists()) {
          onState({ kind: 'notFound' })
          return
        }
        void orderFromDoc(id, snapshot.data() as Record<string, unknown>).then((order) => alive && onState({ kind: 'ready', order }))
      },
      (error) => {
        answered = true
        clearTimeout(timer)
        onState({ kind: isMissing(error) ? 'notFound' : 'failed' })
      },
    )
  }

  async function start() {
    onState({ kind: 'loading' })
    if (!ctx.showsMoney) {
      await readApi()
      return
    }
    await listen()
  }

  const onFocus = () => {
    if (!ctx.showsMoney) void readApi()
  }
  window.addEventListener('focus', onFocus)
  void start()
  return {
    refresh: () => (ctx.showsMoney ? Promise.resolve() : readApi()),
    /** "Tentar de novo" after a failure: the API again, or listen again and read once meanwhile. */
    retry: async () => {
      if (!ctx.showsMoney) return readApi()
      onState({ kind: 'loading' })
      await listen()
      await readOnce()
    },
    stop() {
      alive = false
      clearTimeout(timer)
      stop?.()
      window.removeEventListener('focus', onFocus)
    },
  }
}

export { PAGE_SIZE, FIRST_PAGE }
