// Modo TV (#627): which orders each column shows and in what order.
import { describe, expect, test, vi } from 'vitest'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  firestoreLite: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const { normalizeOrder } = await import('../src/lib/orders/model')
const { dayStartIso, doneToday, sortForTv } = await import('../src/lib/orders/tv')

const order = (id: string, raw: Record<string, unknown>) => normalizeOrder(id, { status: 'approved', ...raw }, false)

describe('Concluídas hoje', () => {
  test('the day starts at midnight in the company zone, as UTC like completedAt', () => {
    // 10:00 in São Paulo (UTC-3) on 6 Nov.
    expect(dayStartIso(new Date('2026-11-06T13:00:00Z'), 'America/Sao_Paulo')).toBe('2026-11-06T03:00:00.000Z')
  })

  test('only done orders completed from the start of the day, newest first', () => {
    const start = '2026-11-06T03:00:00.000Z'
    const rows = [
      order('yesterday', { status: 'done', completedAt: '2026-11-06T02:59:00.000Z' }),
      order('early', { status: 'done', completedAt: '2026-11-06T11:00:00.000Z' }),
      order('late', { status: 'done', completedAt: '2026-11-06T18:00:00.000Z' }),
      order('reopened', { status: 'progress', completedAt: '2026-11-06T12:00:00.000Z' }),
      order('no-date', { status: 'done' }),
    ]
    expect(doneToday(rows, start).map((row) => row.id)).toEqual(['late', 'early'])
  })
})

describe('order of the cards', () => {
  test('late first (most late first), then stopped, then the rest as they came', () => {
    const now = new Date('2026-11-06T15:00:00Z')
    const rows = [
      order('new', {}),
      order('held', { onHold: { reason: 'part', since: '2026-11-04T10:00:00.000Z' } }),
      order('late-1', { dueDate: '2026-11-05T12:00:00.000Z' }),
      order('other', {}),
      order('late-5', { dueDate: '2026-11-01T12:00:00.000Z' }),
    ]
    expect(sortForTv(rows, now).map((row) => row.id)).toEqual(['late-5', 'late-1', 'held', 'new', 'other'])
  })

  test('no values kept: the TV reads orders without money', () => {
    expect(order('x', { total: 4321 }).showsMoney).toBe(false)
  })
})
