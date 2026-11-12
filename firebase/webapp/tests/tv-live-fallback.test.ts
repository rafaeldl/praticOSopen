// Modo TV (#627) on TV browsers: when the live link never brings server data
// (no error, no rows; seen on Safari), the TV still shows the orders:
// a page first, like the list, and pages again when nothing comes live.
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  firestoreLite: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

type OnRows = (rows: Record<string, unknown>[], fromCache: boolean) => void
const listeners: { onRows: OnRows; onError: (error: unknown) => void; stop: ReturnType<typeof vi.fn> }[] = []
const page = async (query: { statuses?: string[] | null }) => [
  { id: `page-${query.statuses?.[0] ?? 'done'}`, status: query.statuses?.[0] ?? 'done', customer: { name: 'Cliente' } },
]
const ordersPage = vi.fn(page)

vi.mock('../src/lib/orders-query', async (original) => ({
  ...(await original<typeof import('../src/lib/orders-query')>()),
  ordersPage: (query: { statuses?: string[] | null }) => ordersPage(query),
  watchFirstRows: async (_query: unknown, _size: number, onRows: OnRows, onError: (error: unknown) => void) => {
    const stop = vi.fn()
    listeners.push({ onRows, onError, stop })
    return stop
  },
}))

const { TV_LIVE_WAIT_MS, TV_POLL_MS, watchTv } = await import('../src/lib/orders/tv')

const ctx = { companyId: 'c1', uid: 'u1', seesAll: true, showsMoney: true }

function open() {
  const columns: Record<string, string[]> = {}
  const onError = vi.fn()
  const live = watchTv(ctx, '2026-11-12T03:00:00.000Z', (status, orders) => (columns[status] = orders.map((o) => o.id)), onError)
  return { columns, onError, live }
}

beforeEach(() => {
  vi.useFakeTimers()
  listeners.length = 0
  ordersPage.mockReset()
  ordersPage.mockImplementation(page)
})
afterEach(() => vi.useRealTimers())

describe('Modo TV sem ligação ao vivo', () => {
  test('first paint from a page, without waiting for the live link (Safari)', async () => {
    const { columns, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    expect(listeners).toHaveLength(4)
    expect(columns).toMatchObject({ quote: ['page-quote'], approved: ['page-approved'], progress: ['page-progress'], done: ['page-done'] })
    // An empty cache answer does not wipe what the server gave.
    listeners.forEach((l) => l.onRows([], true))
    expect(columns.approved).toEqual(['page-approved'])
    live.stop()
  })

  test('nothing live from the server in time: reads pages for every column and keeps reading', async () => {
    const { columns, onError, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    expect(ordersPage).toHaveBeenCalledTimes(4)
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS)
    expect(ordersPage).toHaveBeenCalledTimes(8)
    listeners.forEach((l) => expect(l.stop).toHaveBeenCalled())
    await vi.advanceTimersByTimeAsync(TV_POLL_MS)
    expect(ordersPage).toHaveBeenCalledTimes(12)
    // A late live event no longer overwrites the pages.
    listeners[0]?.onRows([], false)
    expect(columns.quote).toEqual(['page-quote'])
    expect(onError).not.toHaveBeenCalled()
    live.stop()
    await vi.advanceTimersByTimeAsync(TV_POLL_MS)
    expect(ordersPage).toHaveBeenCalledTimes(12)
  })

  test('server data live in every column: replaces the page and stays live', async () => {
    const { columns, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    listeners.forEach((l, i) => l.onRows([{ id: `live-${i}`, status: 'approved' }], false))
    expect(columns.quote).toEqual(['live-0'])
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS + TV_POLL_MS)
    expect(ordersPage).toHaveBeenCalledTimes(4)
    expect(columns.quote).toEqual(['live-0'])
    live.stop()
  })

  test('the live link fails: reads pages at once', async () => {
    const { columns, onError, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    listeners[1]?.onError(new Error('unavailable'))
    await vi.advanceTimersByTimeAsync(0)
    expect(ordersPage).toHaveBeenCalledTimes(8)
    expect(columns.approved).toEqual(['page-approved'])
    expect(onError).not.toHaveBeenCalled()
    live.stop()
  })

  test('pages fail and nothing comes live: the screen shows the error', async () => {
    ordersPage.mockRejectedValue(new Error('offline'))
    const { onError, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    expect(onError).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS)
    expect(onError).toHaveBeenCalledTimes(1)
    live.stop()
  })
})
