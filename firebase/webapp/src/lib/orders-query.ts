// Order list pages read straight from Firestore (who sees values, ADR-001).
// The first page is started as early as the token allows (see main.ts) and
// picked up by the screen, so the query does not wait for the route and the
// screen code to download.
import { firestoreClient, firestoreLite } from './firebase'
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

type Snapshot = { docs: { id: string; data: () => unknown }[] }
const toRows = (snapshot: Snapshot) => snapshot.docs.map((doc) => ({ id: doc.id, ...(doc.data() as object) }) as OrderRow)

/** createdAt as stored: the app writes a Timestamp, the API an ISO string. */
function cursorValue(row: OrderRow): unknown {
  return row.createdAt ?? ''
}

type Module = typeof import('firebase/firestore') | typeof import('firebase/firestore/lite')

/** Same query on either build: the REST one for pages, the full one for live rows. */
function buildQuery<M extends Module>(firestore: M, db: unknown, query: OrdersQuery, size: number, after?: OrderRow) {
  const { collection, documentId, limit, orderBy, query: build, startAfter, where } = firestore as typeof import('firebase/firestore/lite')
  const filters = [
    ...(query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : []),
    ...(query.statuses?.length ? [where('status', 'in', query.statuses)] : []),
  ]
  // Id as tie-break: two orders with the same createdAt are neither repeated nor skipped between pages.
  const cursor = after ? [startAfter(cursorValue(after), after.id)] : []
  return build(
    collection(db as import('firebase/firestore/lite').Firestore, 'companies', query.companyId, 'orders'),
    ...filters,
    orderBy('createdAt', 'desc'),
    orderBy(documentId(), 'desc'),
    ...cursor,
    limit(size),
  )
}

/**
 * A page from the server, through the REST build (lib/firebase.ts): the list
 * paints without waiting for the full client, which only comes for live rows.
 */
async function run(query: OrdersQuery, size: number, after?: OrderRow): Promise<OrderRow[]> {
  mark('orders:query')
  const [db, firestore] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  return toRows(await firestore.getDocs(buildQuery(firestore, db, query, size, after)))
}

/** Starts (or reuses) the first page. Safe to call before anything renders. */
export function firstOrdersPage(query: OrdersQuery): Promise<OrderRow[]> {
  const key = keyOf(query, FIRST_PAGE)
  let promise = pending.get(key)
  if (!promise) {
    promise = run(query, FIRST_PAGE)
    pending.set(key, promise)
    // Only the startup reuses it; later visits read fresh data. A failure is
    // forgotten at once, so "Tentar de novo" asks the server again.
    promise.then(
      () => setTimeout(() => pending.delete(key), 5000),
      () => pending.delete(key),
    )
  }
  return promise
}

export function nextOrdersPage(query: OrdersQuery, last: OrderRow, size: number): Promise<OrderRow[]> {
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
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return firestore.onSnapshot(
    buildQuery(firestore, db, query, size) as unknown as import('firebase/firestore').Query,
    (snapshot) => {
      if (!snapshot.metadata.fromCache) onRows(toRows(snapshot as unknown as Snapshot))
    },
    onError,
  )
}

/** An order by its number (search). Equality on two fields needs no composite index. */
export async function orderByNumber(query: OrdersQuery, number: number): Promise<OrderRow[]> {
  const [db, { collection, getDocs, limit, query: build, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const filters = [where('number', '==', number), ...(query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : [])]
  return toRows((await getDocs(build(collection(db, 'companies', query.companyId, 'orders'), ...filters, limit(5)))) as Snapshot)
}
