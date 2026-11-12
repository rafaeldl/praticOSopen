// Modo TV (#627) on TV browsers: when the live link never brings server data
// (no error, no rows), the TV reads pages like the list does.
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
const ordersPage = vi.fn(async (query: { statuses?: string[] | null }) => [
  { id: `page-${query.statuses?.[0] ?? 'done'}`, status: query.statuses?.[0] ?? 'done', customer: { name: 'Cliente' } },
])

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
  ordersPage.mockClear()
})
afterEach(() => vi.useRealTimers())

describe('Modo TV sem ligação ao vivo', () => {
  test('nothing from the server in time: reads pages for every column and keeps reading', async () => {
    const { columns, onError, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    expect(listeners).toHaveLength(4)
    // Only the cache answered (empty), as on the TV of the shop.
    listeners.forEach((l) => l.onRows([], true))
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS)
    expect(ordersPage).toHaveBeenCalledTimes(4)
    expect(columns).toMatchObject({ quote: ['page-quote'], approved: ['page-approved'], progress: ['page-progress'], done: ['page-done'] })
    listeners.forEach((l) => expect(l.stop).toHaveBeenCalled())
    await vi.advanceTimersByTimeAsync(TV_POLL_MS)
    expect(ordersPage).toHaveBeenCalledTimes(8)
    // A late live event no longer overwrites the pages.
    listeners[0]?.onRows([], false)
    expect(columns.quote).toEqual(['page-quote'])
    expect(onError).not.toHaveBeenCalled()
    live.stop()
    await vi.advanceTimersByTimeAsync(TV_POLL_MS)
    expect(ordersPage).toHaveBeenCalledTimes(8)
  })

  test('server data in every column: stays live, no pages', async () => {
    const { columns, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    listeners.forEach((l, i) => l.onRows([{ id: `live-${i}`, status: 'approved' }], false))
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS + TV_POLL_MS)
    expect(ordersPage).not.toHaveBeenCalled()
    expect(columns.quote).toEqual(['live-0'])
    live.stop()
  })

  test('the live link fails: reads pages at once', async () => {
    const { columns, onError, live } = open()
    await vi.advanceTimersByTimeAsync(0)
    listeners[1]?.onError(new Error('unavailable'))
    await vi.advanceTimersByTimeAsync(0)
    expect(ordersPage).toHaveBeenCalledTimes(4)
    expect(columns.approved).toEqual(['page-approved'])
    expect(onError).not.toHaveBeenCalled()
    live.stop()
  })

  test('pages fail too: the screen shows the error', async () => {
    ordersPage.mockRejectedValueOnce(new Error('offline'))
    const { onError, live } = open()
    await vi.advanceTimersByTimeAsync(TV_LIVE_WAIT_MS)
    expect(onError).toHaveBeenCalledTimes(1)
    live.stop()
  })
})
