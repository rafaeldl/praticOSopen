// Início filters as server queries (home.filter.*): each filter is its own
// Firestore query (or API call), paged with a cursor on its sort field and
// counted by the server, so an order outside the first page still shows.
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'

type Call = [string, ...unknown[]]
const calls: Call[] = []
let pages: Record<string, unknown>[][] = []
let aggregate: Record<string, number> = {}
const apiCalls: string[] = []
let apiPages: Record<string, { data: Record<string, unknown>[]; pagination: Record<string, unknown> }> = {}

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(async () => ({})), firestoreLite: vi.fn(async () => ({})) }))
vi.mock('firebase/firestore/lite', () => {
  const record = (name: string) => (...args: unknown[]) => {
    calls.push([name, ...args])
    return { name, args }
  }
  return {
    collection: record('collection'),
    documentId: () => '__name__',
    where: record('where'),
    orderBy: record('orderBy'),
    startAfter: record('startAfter'),
    limit: record('limit'),
    query: record('query'),
    count: () => ({ kind: 'count' }),
    sum: (field: string) => ({ kind: 'sum', field }),
    getDocs: vi.fn(async () => {
      const docs = pages.shift() ?? []
      return { docs: docs.map((raw) => ({ id: String(raw.docId ?? raw.id), data: () => raw })) }
    }),
    getAggregate: vi.fn(async (_q: unknown, spec: Record<string, unknown>) => {
      calls.push(['getAggregate', spec])
      return { data: () => aggregate }
    }),
  }
})
vi.mock('../src/lib/session', () => ({
  session: { companyId: 'c1', uid: 'u1', role: 'admin' },
  can: () => true,
  api: vi.fn(async (path: string) => {
    apiCalls.push(path)
    const params = new URLSearchParams(path.split('?')[1])
    const key = `${params.get('sort') ?? 'createdAt'}|${params.get('cursor') ?? ''}`
    return apiPages[key] ?? { data: [], pagination: { hasMore: false, nextCursor: null, total: 0 } }
  }),
}))

import { compareBy, applyFreshFirstPage, mergeById } from '../src/lib/order-list'
import { createFilterLoader, dayBounds, filterSources, type ListContext } from '../src/lib/orders/data'
import { filterCounts } from '../src/lib/orders/list-extras'
import { countOrders, filterQueries, FIRST_PAGE } from '../src/lib/orders-query'
import { setZone } from '../src/lib/zone'

const admin: ListContext = { companyId: 'c1', uid: 'u1', seesAll: true, showsMoney: true }
const consultant: ListContext = { companyId: 'c1', uid: 'cons', seesAll: false, showsMoney: true }
const supervisor: ListContext = { companyId: 'c1', uid: 'sup', seesAll: true, showsMoney: false }
const technician: ListContext = { companyId: 'c1', uid: 'tech', seesAll: false, showsMoney: false }
// 5 Nov 2026, 22:30 in São Paulo (01:30 UTC of the 6th): the company's day, not UTC's.
const NOW = new Date('2026-11-06T01:30:00.000Z')
const DAY = { today: '2026-11-05T00:00:00.000', tomorrow: '2026-11-06T00:00:00.000' }

beforeEach(() => setZone('America/Sao_Paulo'))
afterEach(() => {
  calls.length = 0
  apiCalls.length = 0
  pages = []
  apiPages = {}
  aggregate = {}
  setZone(null)
})

const wheres = () => calls.filter((call) => call[0] === 'where').map((call) => call.slice(1))
const orders = () => calls.filter((call) => call[0] === 'orderBy').map((call) => call.slice(1))

describe('filterQueries: one server query per filter', () => {
  const base = { companyId: 'c1', createdBy: null, uid: 'u1' }

  test('the company day, as the app stores dates (wall text, no zone)', () => {
    expect(dayBounds(NOW)).toEqual(DAY)
  })

  test('each filter asks the server for exactly its orders, in screen order', () => {
    expect(filterQueries('open', base, DAY)).toEqual([{ companyId: 'c1', createdBy: null, statuses: ['quote', 'approved', 'progress'] }])
    const [late] = filterQueries('late', base, DAY) ?? []
    expect(late?.where).toEqual([['dueDate', '>', ''], ['dueDate', '<', DAY.today]])
    expect(late?.order).toEqual({ field: 'dueDate', dir: 'asc' })
    // Para hoje left the list (the Agenda answers it), as in the app.
    expect(filterQueries('today', base, DAY)).toBeNull()
    expect(filterQueries('quotes', base, DAY)?.[0]).toMatchObject({ statuses: ['quote'], order: { field: 'createdAt', dir: 'asc' } })
    expect(filterQueries('onHold', base, DAY)?.[0]).toMatchObject({
      statuses: ['approved', 'progress'],
      where: [['onHold.since', '>', '']],
      order: { field: 'onHold.since', dir: 'asc' },
    })
    expect(filterQueries('unpaid', base, DAY)?.[0]).toMatchObject({ statuses: ['done'], where: [['payment', '==', 'unpaid']] })
    expect(filterQueries('done', base, DAY)?.[0]).toMatchObject({ statuses: ['done'] })
    expect(filterQueries('all', base, DAY)?.[0]?.statuses).toBeNull()
    // Dates need the company's day: without it (main.ts preload) there is no query.
    expect(filterQueries('late', base, null)).toBeNull()
    expect(filterQueries('nope', base, DAY)).toBeNull()
  })

  test('who sees only their own orders keeps createdBy in every query; Minhas is by assignee', () => {
    const own = { companyId: 'c1', createdBy: 'cons', uid: 'cons' }
    for (const filter of ['open', 'late', 'quotes', 'onHold', 'unpaid', 'done', 'all']) {
      for (const query of filterQueries(filter, own, DAY) ?? []) expect(query.createdBy).toBe('cons')
    }
    expect(filterQueries('mine', own, DAY)?.[0]).toMatchObject({ createdBy: null, where: [['assignedTo.id', '==', 'cons']] })
  })
})

describe('Firestore pages (who sees values)', () => {
  test('Atrasadas: the query filters and orders by the promise; the next page starts after the last date and id', async () => {
    pages = [Array.from({ length: FIRST_PAGE }, (_, i) => ({ id: `o${i}`, status: 'approved', dueDate: `2026-10-${String(i + 1).padStart(2, '0')}T12:00:00.000` })), [{ id: 'o99', status: 'approved', dueDate: '2026-11-01T12:00:00.000' }]]
    const loader = createFilterLoader(consultant, 'late', NOW)
    const first = await loader.first()
    expect(first.rows).toHaveLength(FIRST_PAGE)
    expect(first.hasMore).toBe(true)
    expect(wheres()).toEqual([
      ['createdBy.id', '==', 'cons'],
      ['status', 'in', ['quote', 'approved', 'progress']],
      ['dueDate', '>', ''],
      ['dueDate', '<', DAY.today],
    ])
    expect(orders()).toEqual([
      ['dueDate', 'asc'],
      ['__name__', 'asc'],
    ])
    calls.length = 0
    const next = await loader.more()
    expect(next.rows.map((row) => row.id)).toEqual(['o99'])
    expect(calls.find((call) => call[0] === 'startAfter')?.slice(1)).toEqual([`2026-10-${FIRST_PAGE}T12:00:00.000`, `o${FIRST_PAGE - 1}`])
  })

  test('Paradas: the cursor reads the nested field', async () => {
    pages = [Array.from({ length: FIRST_PAGE }, (_, i) => ({ id: `h${i}`, status: 'progress', onHold: { reason: 'part', since: `2026-10-${String(i + 1).padStart(2, '0')}` } })), []]
    const loader = createFilterLoader(admin, 'onHold', NOW)
    await loader.first()
    expect(wheres()).toContainEqual(['onHold.since', '>', ''])
    await loader.more()
    expect(calls.find((call) => call[0] === 'startAfter')?.slice(1)).toEqual([`2026-10-${FIRST_PAGE}`, `h${FIRST_PAGE - 1}`])
  })

  test('counts come from the server with the same filters: Em aberto with its late ones, Sem receber with what is left', async () => {
    aggregate = { count: 42 }
    expect(await filterCounts(admin, 'open', NOW)).toEqual({ count: 42, late: 42 })
    expect(calls.filter((call) => call[0] === 'getAggregate')).toHaveLength(2)
    // A plain count carries the page's sort, so the page's index serves it (production asks for one).
    expect(orders()).toEqual([
      ['createdAt', 'desc'],
      ['__name__', 'desc'],
      ['dueDate', 'asc'],
      ['__name__', 'asc'],
    ])
    calls.length = 0
    aggregate = { count: 33, s0: 9900, s1: 3300.5 }
    expect(await filterCounts(consultant, 'unpaid', NOW)).toEqual({ count: 33, amount: 6599.5 })
    expect(wheres()).toEqual([
      ['createdBy.id', '==', 'cons'],
      ['status', '==', 'done'],
      ['payment', '==', 'unpaid'],
    ])
    expect(calls.find((call) => call[0] === 'getAggregate')?.[1]).toMatchObject({ s0: { field: 'total' }, s1: { field: 'paidAmount' } })
    // A sum cannot carry a sort (no index has fields after __name__): it has its own
    // index with the summed fields (firestore.indexes.json). No limit either.
    expect(calls.some((call) => call[0] === 'orderBy' || call[0] === 'limit')).toBe(false)
    expect(await filterCounts(admin, 'done', NOW)).toBeNull()
  })

  test('the next page starts after the document id, even when the order stores an id field of its own', async () => {
    // Old orders carry `id: null` (or another id) inside the document: the cursor must still be the doc id.
    const rest = Array.from({ length: FIRST_PAGE - 1 }, (_, i) => ({ id: `r${i}`, status: 'approved', createdAt: '2026-01-03' }))
    pages = [[...rest, { docId: 'doc-1', id: null, status: 'approved', createdAt: '2026-01-02' }], []]
    const loader = createFilterLoader(admin, 'open', NOW)
    const first = await loader.first()
    expect(first.rows.map((row) => row.id)).toContain('doc-1')
    await loader.more()
    const after = calls.find((call) => call[0] === 'startAfter')
    expect(after?.slice(1)).toEqual(['2026-01-02', 'doc-1'])
  })

  test('countOrders with no sums', async () => {
    aggregate = { count: 7 }
    expect(await countOrders({ companyId: 'c1', createdBy: null, statuses: ['quote'] })).toEqual({ count: 7, sums: {} })
  })
})

describe('API pages (who does not see values)', () => {
  test('Atrasadas asks the API by date, with bounds that compare like the stored text', () => {
    const [late] = filterSources(supervisor, 'late', NOW)
    expect(late?.api).toMatchObject({ sort: 'dueDate', direction: 'asc', endDate: '2026-11-04T23:59:59.999Z', startDate: '1970-01-01T00:00:00.000Z' })
    // A delivery at midnight today (the app's "all day"), stored as wall text, is not late.
    expect('2026-11-05T00:00:00.000' > (late?.api.endDate ?? '')).toBe(true)
    expect(filterSources(supervisor, 'quotes', NOW)[0]?.api).toEqual({ status: 'quote', sort: 'createdAt', direction: 'asc' })
    expect(filterSources(technician, 'mine', NOW)[0]?.api).toEqual({ status: 'quote,approved,progress', assignedTo: 'tech' })
  })

  test('Paradas on the API: pages are read until stopped orders fill a page or the list ends', async () => {
    const open = (id: string, held = false) => ({ id, status: 'progress', ...(held ? { onHold: { reason: 'part', since: '2026-10-01' } } : {}) })
    apiPages = {
      'createdAt|': { data: [open('a'), open('b', true)], pagination: { hasMore: true, nextCursor: 'b' } },
      'createdAt|b': { data: [open('c'), open('d', true)], pagination: { hasMore: false, nextCursor: null } },
    }
    const page = await createFilterLoader(technician, 'onHold', NOW).first()
    expect(page.rows.map((row) => row.id)).toEqual(['b', 'd'])
    expect(page.hasMore).toBe(false)
    expect(apiCalls).toHaveLength(2)
    // No count from the API for it: the sentence waits for the whole list.
    expect(await filterCounts(technician, 'onHold', NOW)).toBeNull()
  })

  test('counts on the API are its total for the same parameters', async () => {
    apiPages = { 'createdAt|': { data: [], pagination: { hasMore: false, total: 35 } } }
    expect(await filterCounts(technician, 'mine', NOW)).toEqual({ count: 35 })
    expect(apiCalls[0]).toContain('assignedTo=tech')
    expect(apiCalls[0]).toContain('limit=1')
  })
})

describe('joining pages in the order of the query', () => {
  test('a list sorted by promise keeps later pages when the live first page comes', () => {
    const byDue = compareBy<{ id: string; dueDate?: string }>('dueDate', 'asc')
    const rows = [
      { id: 'a', dueDate: '2026-10-01' },
      { id: 'b', dueDate: '2026-10-02' },
      { id: 'c', dueDate: '2026-10-03' },
    ]
    expect(mergeById([rows[2]!], [rows[0]!, rows[1]!], byDue).map((r) => r.id)).toEqual(['a', 'b', 'c'])
    // First page of 2 (a, b) arrives again: c (page 2) stays; a removed order would go.
    expect(applyFreshFirstPage(rows, [rows[1]!, { id: 'z', dueDate: '2026-09-30' }], 2, byDue).map((r) => r.id)).toEqual(['z', 'b', 'c'])
    expect(compareBy<{ id: string; onHold?: { since: string } }>('onHold.since', 'asc')({ id: 'x', onHold: { since: '1' } }, { id: 'y', onHold: { since: '2' } })).toBeLessThan(0)
  })
})
