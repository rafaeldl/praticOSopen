// Order list pages read straight from Firestore (who sees values, ADR-001).
// The first page is started as early as the token allows (see main.ts) and
// picked up by the screen, so the query does not wait for the route and the
// screen code to download.
import { cacheState, firestoreClient } from './firebase'
import { mark } from './marks'

export interface OrderRow {
  id: string
  number?: number
  status?: string
  customer?: { name?: string }
  createdAt?: string
  [field: string]: unknown
}

/** Small on purpose: it fills a screen and is what the first paint waits for. */
export const FIRST_PAGE = 30
export const PAGE_SIZE = 100

export interface OrdersQuery {
  companyId: string
  /** null: every order. Otherwise only the ones this user created (firestore.rules). */
  createdBy: string | null
  /** null: every status. Indexed with createdAt (firestore.indexes.json). */
  statuses?: string[] | null
}

const pending = new Map<string, Promise<OrderRow[]>>()
const keyOf = (query: OrdersQuery, size: number, after?: string) =>
  `${query.companyId}|${query.createdBy ?? '*'}|${(query.statuses ?? []).join(',')}|${size}|${after ?? ''}`

export interface Page {
  rows: OrderRow[]
  /** The server did not answer and Firestore served its saved copy. */
  fromCache: boolean
}

type Snapshot = { docs: { id: string; data: () => unknown }[]; metadata: { fromCache: boolean } }
const toRows = (snapshot: Snapshot) => snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() as object) }) as OrderRow)

/** createdAt as stored: the app writes a Timestamp, the API an ISO string. */
function cursorValue(row: OrderRow): unknown {
  return row.createdAt ?? ''
}

async function buildQuery(query: OrdersQuery, size: number, after?: OrderRow) {
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const { collection, documentId, limit, orderBy, query: build, startAfter, where } = firestore
  const filters = [
    ...(query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : []),
    ...(query.statuses?.length ? [where('status', 'in', query.statuses)] : []),
  ]
  // Id as tie-break: two orders with the same createdAt are neither repeated nor skipped between pages.
  const cursor = after ? [startAfter(cursorValue(after), after.id)] : []
  const built = build(
    collection(db, 'companies', query.companyId, 'orders'),
    ...filters,
    orderBy('createdAt', 'desc'),
    orderBy(documentId(), 'desc'),
    ...cursor,
    limit(size),
  )
  return { built, firestore }
}

async function run(query: OrdersQuery, size: number, after?: OrderRow): Promise<Page> {
  mark('orders:query')
  const { built, firestore } = await buildQuery(query, size, after)
  const { getDocs, getDocsFromCache } = firestore
  // A full first page on disk is shown at once; the server copy follows through onFresh.
  if (!after && cacheState.trusted) {
    try {
      const cached = await getDocsFromCache(built)
      if (cached.docs.length === size) {
        void getDocs(built).then(
          // Offline, getDocs answers from the cache instead of failing: that is not a server copy.
          (fresh) => deliverFresh(fresh.metadata.fromCache ? { failed: true } : { rows: toRows(fresh) }),
          (error) => {
            console.warn('orders: server copy failed, showing the saved one', error)
            deliverFresh({ failed: true })
          },
        )
        return { rows: toRows(cached), fromCache: false }
      }
    } catch {
      // Nothing cached yet.
    }
  }
  const snapshot = await getDocs(built)
  return { rows: toRows(snapshot), fromCache: snapshot.metadata.fromCache }
}

/** The server copy of a first page shown from disk, or the news that it failed. */
export type FreshResult = { rows: OrderRow[]; failed?: undefined } | { failed: true; rows?: undefined }

let onFresh: ((result: FreshResult) => void) | undefined
let heldFresh: FreshResult | undefined

// The server copy can arrive before the screen exists: hold it until it subscribes.
function deliverFresh(result: FreshResult): void {
  if (onFresh) onFresh(result)
  else heldFresh = result
}

/** The screen that shows the first page receives the server copy here. */
export function onFreshFirstPage(listener: ((result: FreshResult) => void) | undefined): void {
  onFresh = listener
  if (listener && heldFresh) listener(heldFresh)
  heldFresh = undefined
}

/** Starts (or reuses) the first page. Safe to call before anything renders. */
export function firstOrdersPage(query: OrdersQuery): Promise<OrderRow[]> {
  const key = keyOf(query, FIRST_PAGE)
  let promise = pending.get(key)
  if (!promise) {
    promise = run(query, FIRST_PAGE).then((page) => {
      if (page.fromCache) deliverFresh({ failed: true })
      return page.rows
    })
    pending.set(key, promise)
    // Only the startup reuses it; later visits read fresh data.
    promise.finally(() => setTimeout(() => pending.delete(key), 5000)).catch(() => {})
  }
  return promise
}

export function nextOrdersPage(query: OrdersQuery, last: OrderRow, size: number): Promise<Page> {
  return run(query, size, last)
}

/**
 * Live copy of the first `size` rows: another person's change, a new order or
 * one that left the filter shows without reloading the list. Returns the stop.
 */
export async function watchFirstRows(
  query: OrdersQuery,
  size: number,
  onRows: (rows: OrderRow[]) => void,
  onError: (error: unknown) => void,
): Promise<() => void> {
  const { built, firestore } = await buildQuery(query, size)
  return firestore.onSnapshot(
    built,
    (snapshot) => {
      if (!snapshot.metadata.fromCache) onRows(toRows(snapshot as unknown as Snapshot))
    },
    onError,
  )
}

/** An order by its number (search). Equality on two fields needs no composite index. */
export async function orderByNumber(query: OrdersQuery, number: number): Promise<OrderRow[]> {
  const [db, { collection, getDocs, limit, query: build, where }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const filters = [where('number', '==', number), ...(query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : [])]
  return toRows((await getDocs(build(collection(db, 'companies', query.companyId, 'orders'), ...filters, limit(5)))) as Snapshot)
}
