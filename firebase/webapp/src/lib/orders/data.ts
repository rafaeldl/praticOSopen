// Where orders are read from (ADR-001): Firestore for who sees values, the API
// projection (no money in any field) for who does not. Writes are in writes.ts.
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import { FIRST_PAGE, PAGE_SIZE, firstOrdersPage, nextOrdersPage, orderByNumber, watchFirstRows, type OrderRow, type OrdersQuery } from '@/lib/orders-query'
import { api, can, session } from '@/lib/session'
import { lineIds } from './line-ids'
import { normalizeOrder, type Order, type OrderStatus } from './model'

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
  pagination?: { hasMore?: boolean; nextCursor?: string | null }
}

/**
 * Pages of one filter. Firestore pages by createdAt and id; the API by its
 * cursor. Both keep the same order: newest first.
 */
export function createListLoader(ctx: ListContext, statuses: OrderStatus[] | null, assignedTo?: string) {
  const query: OrdersQuery = { companyId: ctx.companyId, createdBy: ctx.seesAll ? null : ctx.uid, statuses }
  let lastRaw: OrderRow | null = null
  let cursor: string | null = null
  const toOrder = (row: Record<string, unknown>) => normalizeOrder(String(row.id), row, ctx.showsMoney)

  async function apiPage(size: number): Promise<ListPage> {
    const params = new URLSearchParams({ limit: String(size) })
    if (statuses?.length) params.set('status', statuses.join(','))
    if (cursor) params.set('cursor', cursor)
    if (assignedTo) params.set('assignedTo', assignedTo)
    // The list carries pagination next to data: read the raw envelope.
    const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?${params}`, { raw: true })
    const envelope = Array.isArray(body) ? { data: body } : body
    cursor = envelope.pagination?.nextCursor ?? null
    return { rows: (envelope.data ?? []).map(toOrder), hasMore: !!envelope.pagination?.hasMore && !!cursor }
  }

  return {
    query,
    async first(): Promise<ListPage> {
      lastRaw = null
      cursor = null
      if (!ctx.showsMoney) return apiPage(FIRST_PAGE)
      const raw = await firstOrdersPage(query)
      lastRaw = raw[raw.length - 1] ?? null
      return { rows: raw.map(toOrder), hasMore: raw.length === FIRST_PAGE }
    },
    async more(): Promise<ListPage> {
      if (!ctx.showsMoney) return apiPage(PAGE_SIZE)
      if (!lastRaw) return { rows: [], hasMore: false }
      const raw = await nextOrdersPage(query, lastRaw, PAGE_SIZE)
      lastRaw = raw[raw.length - 1] ?? lastRaw
      return { rows: raw.map(toOrder), hasMore: raw.length === PAGE_SIZE }
    },
    /** Live first rows (Firestore only). The API list is refreshed after each write instead. */
    watch(size: number, onRows: (rows: Order[]) => void, onError: (error: unknown) => void) {
      if (!ctx.showsMoney) return Promise.resolve(() => {})
      return watchFirstRows(query, size, (rows) => onRows(rows.map(toOrder)), onError)
    },
    async byNumber(number: number): Promise<Order[]> {
      // Who does not see values asks the API (projected, only what the person may see).
      if (!ctx.showsMoney) {
        const body = await api<ApiList | Record<string, unknown>[]>(`/v1/app/orders?number=${number}`, { raw: true })
        return ((Array.isArray(body) ? body : body.data) ?? []).map(toOrder)
      }
      return (await orderByNumber(query, number)).map(toOrder)
    },
  }
}

export type ListLoader = ReturnType<typeof createListLoader>

/**
 * Minhas by `assignedTo` (the technician sees what was given to them, created by
 * anyone). On since the rules and indexes of #514 are in: the API list is
 * asked for `assignedTo=<uid>` instead of the orders the technician created.
 */
export const ASSIGNED_READS = true

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
