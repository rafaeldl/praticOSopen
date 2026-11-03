// First page of the order list. Started as early as the token allows (see
// main.ts) and picked up by the screen, so the query does not wait for the
// route and the screen code to download.
import { firestoreClient } from './firebase'
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

async function run(query: OrdersQuery, size: number, after?: OrderRow): Promise<OrderRow[]> {
  mark('orders:query')
  const [db, { collection, getDocs, getDocsFromCache, limit, orderBy, query: build, startAfter, where }] = await Promise.all([
    firestoreClient(),
    import('firebase/firestore'),
  ])
  const filters = query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : []
  const cursor = after ? [startAfter(after.createdAt ?? '')] : []
  const built = build(collection(db, 'companies', query.companyId, 'orders'), ...filters, orderBy('createdAt', 'desc'), ...cursor, limit(size))
  const rows = (snapshot: { docs: { id: string; data: () => unknown }[] }) =>
    snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() as object) }) as OrderRow)
  // A full first page on disk is shown at once; the server copy follows through onFresh.
  if (!after) {
    try {
      const cached = await getDocsFromCache(built)
      if (cached.docs.length === size) {
        void getDocs(built).then((fresh) => deliverFresh(rows(fresh)), () => {})
        return rows(cached)
      }
    } catch {
      // Nothing cached yet.
    }
  }
  return rows(await getDocs(built))
}

let onFresh: ((rows: OrderRow[]) => void) | undefined
let heldFresh: OrderRow[] | undefined

// The server copy can arrive before the screen exists: hold it until it subscribes.
function deliverFresh(rows: OrderRow[]): void {
  if (onFresh) onFresh(rows)
  else heldFresh = rows
}

/** The screen that shows the first page receives the server copy here. */
export function onFreshFirstPage(listener: ((rows: OrderRow[]) => void) | undefined): void {
  onFresh = listener
  if (listener && heldFresh) listener(heldFresh)
  heldFresh = undefined
}

/** Starts (or reuses) the first page. Safe to call before anything renders. */
export function firstOrdersPage(query: OrdersQuery): Promise<OrderRow[]> {
  const key = keyOf(query, FIRST_PAGE)
  let promise = pending.get(key)
  if (!promise) {
    promise = run(query, FIRST_PAGE)
    pending.set(key, promise)
    // Only the startup reuses it; later visits read fresh data.
    promise.finally(() => setTimeout(() => pending.delete(key), 5000)).catch(() => {})
  }
  return promise
}

export function nextOrdersPage(query: OrdersQuery, last: OrderRow, size: number): Promise<OrderRow[]> {
  return run(query, size, last)
}
