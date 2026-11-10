// Quadro limpo: Concluída keeps the last week, idle quotes go aside.
import { describe, expect, test, vi } from 'vitest'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  firestoreLite: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const { normalizeOrder } = await import('../src/lib/orders/model')
const { boardRows, doneSinceIso, idleMonths, isRecentDone, isStaleQuote } = await import('../src/lib/orders/board')

const now = new Date('2026-11-10T12:00:00Z')
const order = (id: string, raw: Record<string, unknown>) => normalizeOrder(id, { status: 'approved', ...raw }, false)
const daysAgo = (days: number) => new Date(now.getTime() - days * 86_400_000).toISOString()

describe('Concluída: last 7 days', () => {
  test('concluded 6 days ago stays; 8 days ago goes', () => {
    expect(isRecentDone(order('a', { status: 'done', completedAt: daysAgo(6) }), now)).toBe(true)
    expect(isRecentDone(order('b', { status: 'done', completedAt: daysAgo(8) }), now)).toBe(false)
  })

  test('concluded before completedAt existed is old, even if edited today', () => {
    expect(isRecentDone(order('c', { status: 'done', updatedAt: daysAgo(0) }), now)).toBe(false)
  })

  test('the window starts 7 days back, in UTC like completedAt', () => {
    expect(doneSinceIso(now)).toBe('2026-11-03T12:00:00.000Z')
  })
})

describe('Orçamento: idle for 90 days goes aside', () => {
  test('a quote changed 89 days ago stays; 90 goes', () => {
    expect(isStaleQuote(order('a', { status: 'quote', updatedAt: daysAgo(89) }), now)).toBe(false)
    expect(isStaleQuote(order('b', { status: 'quote', updatedAt: daysAgo(90) }), now)).toBe(true)
  })

  test('without updatedAt, the creation counts', () => {
    expect(isStaleQuote(order('c', { status: 'quote', createdAt: daysAgo(200) }), now)).toBe(true)
  })

  test('only quotes: an old approved order is never stale', () => {
    expect(isStaleQuote(order('d', { status: 'approved', updatedAt: daysAgo(400) }), now)).toBe(false)
  })

  test('months idle, whole', () => {
    expect(idleMonths(order('e', { status: 'quote', updatedAt: daysAgo(95) }), now)).toBe(3)
  })
})

describe('boardRows', () => {
  test('splits cards, stale quotes (idle longest first) and drops old concluded orders', () => {
    const rows = [
      order('open', { status: 'progress', updatedAt: daysAgo(300) }),
      order('fresh-quote', { status: 'quote', updatedAt: daysAgo(3) }),
      order('stale-1', { status: 'quote', updatedAt: daysAgo(100) }),
      order('stale-2', { status: 'quote', updatedAt: daysAgo(400) }),
      order('done-new', { status: 'done', completedAt: daysAgo(1) }),
      order('done-old', { status: 'done', completedAt: daysAgo(30) }),
    ]
    const { cards, staleQuotes } = boardRows(rows, now)
    expect(cards.map((o) => o.id)).toEqual(['open', 'fresh-quote', 'done-new'])
    expect(staleQuotes.map((o) => o.id)).toEqual(['stale-2', 'stale-1'])
  })
})
