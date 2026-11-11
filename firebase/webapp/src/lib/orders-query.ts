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

export type FilterOp = '==' | '<' | '>' | '>='

export interface OrdersQuery {
  companyId: string
  /** null: every order. Otherwise only the ones this user created (firestore.rules). */
  createdBy: string | null
  /** null: every status. Indexed with createdAt (firestore.indexes.json). */
  statuses?: string[] | null
  /** More filters of the Início filter (dates, payment, hold, assignee). */
  where?: [field: string, op: FilterOp, value: string][]
  /** Sort field and direction; the id breaks ties the same way. createdAt desc by default. */
  order?: { field: string; dir: 'asc' | 'desc' }
}

const pending = new Map<string, Promise<OrderRow[]>>()
const keyOf = (query: OrdersQuery, size: number, after?: string) =>
  `${query.companyId}|${query.createdBy ?? '*'}|${(query.statuses ?? []).join(',')}|${JSON.stringify(query.where ?? [])}|${query.order?.field ?? ''} ${query.order?.dir ?? ''}|${size}|${after ?? ''}`

/** The company's day as the app stores dates: local wall text without a zone. */
export interface DayBounds {
  /** "2026-11-05T00:00:00.000": start of today. */
  today: string
  /** Start of tomorrow, same form. */
  tomorrow: string
}

const OPEN = ['quote', 'approved', 'progress']

/**
 * The Firestore query of an Início filter (in a list, as the loaders take
 * sources). Each query is the filter itself, so a
 * page never needs filtering on screen and a count of it is the filter's count.
 * Dates are stored as text (the app writes local time without a zone), so the
 * bounds are the company's day in that form. Each query has its composite
 * index in firestore.indexes.json, with and without `createdBy.id`.
 */
export function filterQueries(
  filter: string,
  base: { companyId: string; createdBy: string | null; uid: string | null },
  day: DayBounds | null,
): OrdersQuery[] | null {
  const q = (extra: Partial<OrdersQuery>): OrdersQuery => ({ companyId: base.companyId, createdBy: base.createdBy, ...extra })
  switch (filter) {
    case 'open':
      return [q({ statuses: OPEN })]
    case 'late':
      // The lower bound leaves out an empty text (no date).
      return day ? [q({ statuses: OPEN, where: [['dueDate', '>', ''], ['dueDate', '<', day.today]], order: { field: 'dueDate', dir: 'asc' } })] : null
    case 'quotes':
      // Waiting longest first.
      return [q({ statuses: ['quote'], order: { field: 'createdAt', dir: 'asc' } })]
    case 'onHold':
      // Stopped longest first. The app and the API always write `since` with the mark.
      return [q({ statuses: ['approved', 'progress'], where: [['onHold.since', '>', '']], order: { field: 'onHold.since', dir: 'asc' } })]
    case 'unpaid':
      return [q({ statuses: ['done'], where: [['payment', '==', 'unpaid']] })]
    case 'mine':
      // Given to this person, created by anyone (firestore.rules isOrderAssignee).
      return [{ companyId: base.companyId, createdBy: null, statuses: OPEN, where: [['assignedTo.id', '==', base.uid ?? '']] }]
    case 'done':
      return [q({ statuses: ['done'] })]
    case 'all':
      return [q({ statuses: null })]
    default:
      return null
  }
}

type Snapshot = { docs: { id: string; data: () => unknown }[] }
// The document id last: old orders store an `id` field of their own (often null), which
// must not replace it (the next page's cursor is this id).
const toRows = (snapshot: Snapshot) => snapshot.docs.map((doc) => ({ ...(doc.data() as object), id: doc.id }) as OrderRow)

/** A field of a row by its path ("onHold.since"). */
export function valueAt(row: Record<string, unknown>, path: string): unknown {
  return path.split('.').reduce<unknown>((value, key) => (value && typeof value === 'object' ? (value as Record<string, unknown>)[key] : undefined), row)
}

/** The sort field as stored (createdAt: the app writes a Timestamp, the API an ISO string). */
function cursorValue(query: OrdersQuery, row: OrderRow): unknown {
  return valueAt(row, query.order?.field ?? 'createdAt') ?? ''
}

type Module = typeof import('firebase/firestore') | typeof import('firebase/firestore/lite')

/** Same query on either build: the REST one for pages, the full one for live rows. No size: the whole filter (a count). */
function buildQuery<M extends Module>(firestore: M, db: unknown, query: OrdersQuery, size?: number, after?: OrderRow) {
  const { collection, documentId, limit, orderBy, query: build, startAfter } = firestore as typeof import('firebase/firestore/lite')
  const order = query.order ?? { field: 'createdAt', dir: 'desc' }
  // Id as tie-break: two orders with the same date are neither repeated nor skipped between pages.
  const cursor = after ? [startAfter(cursorValue(query, after), after.id)] : []
  return build(
    collection(db as import('firebase/firestore/lite').Firestore, 'companies', query.companyId, 'orders'),
    ...filtersOf(firestore, query),
    orderBy(order.field, order.dir),
    orderBy(documentId(), order.dir),
    ...cursor,
    ...(size ? [limit(size)] : []),
  )
}

/** The filters alone: a page and its count ask the same. */
function filtersOf<M extends Module>(firestore: M, query: OrdersQuery) {
  const { where } = firestore as typeof import('firebase/firestore/lite')
  const statuses = query.statuses ?? []
  return [
    ...(query.createdBy ? [where('createdBy.id', '==', query.createdBy)] : []),
    ...(statuses.length === 1 ? [where('status', '==', statuses[0])] : statuses.length ? [where('status', 'in', statuses)] : []),
    ...(query.where ?? []).map(([field, op, value]) => where(field, op, value)),
  ]
}

/**
 * How many orders the query has, and the sum of number fields, counted by the
 * server (Firestore aggregation). A plain count is the page's query without the
 * limit, sort included, so the page's composite index serves it. A sum cannot
 * carry the sort (Firestore has no index with fields after __name__): it has an
 * index of its own with the summed fields (Sem receber: payment, status,
 * paidAmount, total in firestore.indexes.json), which the emulator never asks for.
 */
export async function countOrders(query: OrdersQuery, sums: string[] = []): Promise<{ count: number; sums: Record<string, number> }> {
  const [db, firestore] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const { count, getAggregate, sum } = firestore
  const spec: Record<string, ReturnType<typeof count> | ReturnType<typeof sum>> = { count: count() }
  sums.forEach((field, index) => (spec[`s${index}`] = sum(field)))
  const counted = sums.length
    ? firestore.query(firestore.collection(db, 'companies', query.companyId, 'orders'), ...filtersOf(firestore, query))
    : buildQuery(firestore, db, query)
  const snapshot = await getAggregate(counted, spec)
  const data = snapshot.data() as Record<string, number | null | undefined>
  return { count: Number(data.count ?? 0), sums: Object.fromEntries(sums.map((field, index) => [field, Number(data[`s${index}`] ?? 0)])) }
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

/** One page of `size` rows after `last` (or the first one), never reused: for screens other than the list. */
export function ordersPage(query: OrdersQuery, size: number, last?: OrderRow): Promise<OrderRow[]> {
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
  /**
   * Also the rows the SDK already has (fromCache). Needed when this is the only
   * read: a query the cache can answer gets no second event when the server
   * agrees, so skipping the cached one would leave the screen empty (Modo TV).
   */
  acceptCache = false,
): Promise<() => void> {
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return firestore.onSnapshot(
    buildQuery(firestore, db, query, size) as unknown as import('firebase/firestore').Query,
    (snapshot) => {
      if (acceptCache || !snapshot.metadata.fromCache) onRows(toRows(snapshot as unknown as Snapshot))
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
