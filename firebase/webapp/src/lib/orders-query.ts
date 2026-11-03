// First page of the order list. Started as early as the token allows (see
// main.ts) and picked up by the screen, so the query does not wait for the
// route and the screen code to download.
import { cacheState, firestoreClient } from './firebase'
import { mark } from './marks'

export interface OrderRow {
  id: string
  number?: number
  status?: string
  customer?: { name?: string }
  createdAt?: string
}

/** Small on purpose: it fills a screen and is what the first paint waits for. */
export const FIRST_PAGE = 30
export const PAGE_SIZE = 100

export interface OrdersQuery {
  companyId: string
  /** null: every order. Otherwise only the ones this user created (firestore.rules). */
  createdBy: string | null
}

const pending = new Map<string, Promise<OrderRow[]>>()
const keyOf = (query: OrdersQuery, size: number, after?: string) =>
  `${query.companyId}|${query.createdBy ?? '*'}|${size}|${after ?? ''}`

interface Page {
  rows: OrderRow[]
  /** The server did not answer and Firestore served its saved copy. */
  fromCache: boolean
}

async function run(query: OrdersQuery, size: number, after?: OrderRow): Promise<Page> {
  mark('orders:query')
  const [db, { collection, documentId, getDocs, getDocsFromCache, limit, orderBy, query: build, startAfter, where }] =
    await Promise.all([firestoreClient(), import('firebase/firestore')])
  const filters = query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : []
  // Id as tie-break: two orders with the same createdAt are neither repeated nor skipped between pages.
  const cursor = after ? [startAfter(after.createdAt ?? '', after.id)] : []
  const built = build(
    collection(db, 'companies', query.companyId, 'orders'),
    ...filters,
    orderBy('createdAt', 'desc'),
    orderBy(documentId(), 'desc'),
    ...cursor,
    limit(size),
  )
  type Snapshot = { docs: { id: string; data: () => unknown }[]; metadata: { fromCache: boolean } }
  const rows = (snapshot: Snapshot) => snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() as object) }) as OrderRow)
  // A full first page on disk is shown at once; the server copy follows through onFresh.
  if (!after && cacheState.trusted) {
    try {
      const cached = await getDocsFromCache(built)
      if (cached.docs.length === size) {
        void getDocs(built).then(
          // Offline, getDocs answers from the cache instead of failing: that is not a server copy.
          (fresh) => deliverFresh(fresh.metadata.fromCache ? { failed: true } : { rows: rows(fresh) }),
          (error) => {
            console.warn('orders: server copy failed, showing the saved one', error)
            deliverFresh({ failed: true })
          },
        )
        return { rows: rows(cached), fromCache: false }
      }
    } catch {
      // Nothing cached yet.
    }
  }
  const snapshot = await getDocs(built)
  return { rows: rows(snapshot), fromCache: snapshot.metadata.fromCache }
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
