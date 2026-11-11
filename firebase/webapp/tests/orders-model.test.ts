import { createHash } from 'node:crypto'
import { describe, expect, test } from 'vitest'
import { lineIds } from '../src/lib/orders/line-ids'
import {
  accessOf,
  createStatuses,
  deviceSummary,
  exactFirst,
  versionOf,
  filtersFor,
  initialsOf,
  lateness,
  linesByDevice,
  matchesFilter,
  matchesSearch,
  monthGroups,
  nextStep,
  normalizeOrder,
  remainingOnRow,
  rowsFor,
  summaryFromCounts,
  summaryOf,
  totals,
  type Order,
} from '../src/lib/orders/model'

const NOW = new Date(2026, 10, 3, 10, 0)
const day = (offset: number, hour = 12) => new Date(2026, 10, 3 + offset, hour, 0).toISOString()
const order = (id: string, raw: Record<string, unknown> = {}, money = true): Order =>
  normalizeOrder(id, { status: 'approved', createdAt: day(-1), createdBy: { id: 'u1' }, ...raw }, money)

describe('normalizeOrder', () => {
  test('lines, devices and money; no money for who does not see values', () => {
    const raw = {
      status: 'done',
      total: 300,
      paidAmount: 100,
      services: [{ service: { id: 's1', name: 'Troca' }, value: 200 }],
      products: [{ product: { id: 'p1', name: 'Filtro' }, value: 50, quantity: 2 }],
      device: { id: 'd1', name: 'Gol' },
    }
    const shown = normalizeOrder('o1', raw, true)
    expect(shown.lines.map((line) => [line.kind, line.name, line.value, line.total ?? null])).toEqual([
      ['service', 'Troca', 200, null],
      ['product', 'Filtro', 50, 100],
    ])
    expect(shown.devices).toEqual([{ id: 'd1', name: 'Gol' }])
    expect(totals(shown).remaining).toBe(200)
    expect(remainingOnRow(shown)).toBe(200)
    const hidden = normalizeOrder('o1', raw, false)
    expect(hidden.total).toBeUndefined()
    expect(hidden.lines.every((line) => line.value === undefined && line.total === undefined)).toBe(true)
    expect(remainingOnRow(hidden)).toBeNull()
  })

  test('a hold mark outside approved and progress is ignored', () => {
    expect(order('o', { status: 'done', onHold: { reason: 'part', since: day(-2) } }).onHold).toBeNull()
    expect(order('o', { status: 'progress', onHold: { reason: 'part', since: day(-2) } }).onHold?.reason).toBe('part')
  })
})

describe('lateness and groups', () => {
  test('late by day, never by minute', () => {
    expect(lateness(order('a', { dueDate: day(0, 8) }), NOW)).toBeNull()
    expect(lateness(order('a', { dueDate: day(-3) }), NOW)).toEqual({ unit: 'days', count: 3 })
    expect(lateness(order('a', { dueDate: day(-90) }), NOW)?.unit).toBe('months')
    expect(lateness(order('a', { dueDate: day(-400) }), NOW)?.unit).toBe('years')
    expect(lateness(order('a', { status: 'done', dueDate: day(-3) }), NOW)).toBeNull()
  })

  test('open: late first (oldest promise), then today, then the server order', () => {
    // The server sends only open orders (lib/orders/data.ts): the screen orders them, it never drops one.
    const rows = [order('new'), order('today', { dueDate: day(0, 18) }), order('late1', { dueDate: day(-1) }), order('late5', { dueDate: day(-5) })]
    expect(rowsFor('open', rows, NOW, 'u1').map((row) => row.id)).toEqual(['late5', 'late1', 'today', 'new'])
  })

  test('quotes oldest first; on hold longest first; mine: visits of today by hour', () => {
    const quotes = [order('q2', { status: 'quote', createdAt: day(-1) }), order('q1', { status: 'quote', createdAt: day(-9) })]
    const held = [
      order('h1', { status: 'progress', onHold: { reason: 'part', since: day(-1) } }),
      order('h2', { status: 'progress', onHold: { reason: 'other', since: day(-4) } }),
    ]
    const mine = [
      order('m2', { assignedTo: { id: 'tech' }, scheduledDate: day(0, 15) }),
      order('m1', { assignedTo: { id: 'tech' }, scheduledDate: day(0, 9) }),
      order('m3', { assignedTo: { id: 'tech' } }),
    ]
    expect(rowsFor('quotes', quotes, NOW, 'tech').map((r) => r.id)).toEqual(['q1', 'q2'])
    expect(rowsFor('onHold', held, NOW, 'tech').map((r) => r.id)).toEqual(['h2', 'h1'])
    expect(rowsFor('mine', mine, NOW, 'tech').map((r) => r.id)).toEqual(['m1', 'm2', 'm3'])
  })

  test('rowsFor never leaves out a row the server sent (the query is the filter)', () => {
    const rows = [order('a', { status: 'done' }), order('b', { dueDate: day(3) })]
    for (const filter of ['open', 'late', 'quotes', 'onHold', 'unpaid', 'mine', 'done', 'all'] as const) {
      expect(rowsFor(filter, rows, NOW, 'u1')).toHaveLength(2)
    }
  })

  test('matchesFilter: an order changed on screen leaves the filter', () => {
    const late = order('late', { dueDate: day(-2) })
    const today = order('today', { scheduledDate: day(0, 15) })
    const owed = order('owed', { status: 'done', total: 100, paidAmount: 40 })
    const paid = order('paid', { status: 'done', total: 100, paidAmount: 100 })
    expect(matchesFilter('late', late, NOW, null)).toBe(true)
    expect(matchesFilter('late', today, NOW, null)).toBe(false)
    expect(matchesFilter('unpaid', owed, NOW, null)).toBe(true)
    expect(matchesFilter('unpaid', paid, NOW, null)).toBe(false)
    expect(matchesFilter('quotes', order('q', { status: 'approved' }), NOW, null)).toBe(false)
    expect(matchesFilter('onHold', order('h', { status: 'progress', onHold: { reason: 'part', since: day(-1) } }), NOW, null)).toBe(true)
    expect(matchesFilter('mine', order('m', { assignedTo: { id: 'tech' } }), NOW, 'tech')).toBe(true)
    expect(matchesFilter('mine', order('m', { assignedTo: { id: 'other' } }), NOW, 'tech')).toBe(false)
  })

  test('summary from the server counts, before every page is loaded', () => {
    const some = [order('a')]
    expect(summaryFromCounts('open', { count: 40, late: 35 }, some, false, NOW)).toEqual({ kind: 'open', open: 40, late: 35 })
    expect(summaryFromCounts('unpaid', { count: 33, amount: 1650.004 }, some, false, NOW)).toEqual({ kind: 'unpaid', count: 33, amount: 1650 })
    expect(summaryFromCounts('quotes', { count: 0 }, [], true, NOW)).toBeNull()
    expect(summaryFromCounts('onHold', { count: 2 }, some, false, NOW)).toEqual({ kind: 'onHold', count: 2 })
    // No count (Paradas on the API): only with the whole list, as before.
    expect(summaryFromCounts('onHold', null, some, false, NOW)).toBeNull()
    const held = [order('h', { status: 'progress', onHold: { reason: 'part', since: day(-1) } })]
    expect(summaryFromCounts('onHold', null, held, true, NOW)).toEqual({ kind: 'onHold', count: 1 })
    expect(summaryFromCounts('mine', { count: 35 }, some, false, NOW)).toEqual({ kind: 'mine', count: 35, today: false })
  })

  test('Sem receber; número exato primeiro', () => {
    const rows = [order('owed', { status: 'done', total: 100, paidAmount: 40 })]
    expect(summaryOf('unpaid', rowsFor('unpaid', rows, NOW, null), true, NOW)).toEqual({ kind: 'unpaid', count: 1, amount: 60 })
    const numbered = [order('a', { number: 31 }), order('b', { number: 3 }), order('c', { number: 13 })]
    expect(exactFirst(numbered, '3').map((r) => r.id)).toEqual(['b', 'a', 'c'])
    // Same filters and order as the app's Início.
    expect(filtersFor('admin', true)).toEqual(['open', 'late', 'quotes', 'onHold', 'unpaid', 'done', 'all'])
    expect(filtersFor('supervisor', false)).toEqual(['open', 'late', 'quotes', 'onHold', 'done', 'all'])
  })

  test('all: by month of creation in arrival order', () => {
    const groups = monthGroups([order('a', { createdAt: day(0) }), order('b', { createdAt: day(-40) }), order('c', { createdAt: null })])
    expect(groups.map((group) => [group.key === 'none' ? null : group.month?.getMonth(), group.rows.map((r) => r.id)])).toEqual([
      [10, ['a']],
      [8, ['b']],
      [null, ['c']],
    ])
  })

  test('summary only with the whole list loaded', () => {
    const rows = [order('a', { dueDate: day(-1) }), order('b')]
    expect(summaryOf('open', rows, false, NOW)).toBeNull()
    expect(summaryOf('open', rows, true, NOW)).toEqual({ kind: 'open', open: 2, late: 1 })
    expect(summaryOf('done', rows, true, NOW)).toBeNull()
    expect(summaryOf('open', [], true, NOW)).toBeNull()
  })
})

describe('access and next step', () => {
  const quote = order('q', { status: 'quote', createdBy: { id: 'tech' } })
  test('technician on own quote: approve; on another person order: nothing', () => {
    expect(nextStep(quote, accessOf(quote, 'technician', 'tech', true))).toEqual({ kind: 'status', to: 'approved' })
    expect(accessOf(quote, 'technician', 'other', true).canEdit).toBe(false)
  })
  test('done with balance: receive only for who receives', () => {
    const done = order('d', { status: 'done', total: 300, paidAmount: 100 })
    expect(nextStep(done, accessOf(done, 'admin', 'x', true))).toEqual({ kind: 'receive', amount: 200 })
    expect(nextStep(done, accessOf(done, 'supervisor', 'x', true))).toBeNull()
    expect(nextStep(done, accessOf(done, 'consultant', 'x', true))).toBeNull()
    expect(nextStep(done, accessOf(done, 'consultant', 'u1', true))).toEqual({ kind: 'receive', amount: 200 })
  })
  test('held order: the blue button resumes; consultant never changes the hold', () => {
    const held = order('h', { status: 'progress', onHold: { reason: 'part', since: day(-1) } })
    expect(nextStep(held, accessOf(held, 'admin', 'x', true))).toEqual({ kind: 'resume' })
    expect(accessOf(held, 'consultant', 'u1', true).canChangeHold).toBe(false)
  })
  test('initial status never offers canceled; technician does not create', () => {
    expect(createStatuses('consultant')).toEqual(['quote', 'approved'])
    expect(createStatuses('owner')).not.toContain('canceled')
    expect(createStatuses('technician')).toEqual([])
    expect(filtersFor('technician')).toEqual(['mine', 'onHold', 'all'])
  })
})

describe('row text', () => {
  test('device summary, search, by device and initials', () => {
    const o = order('o', { number: 186, customer: { name: 'José Álvares' }, devices: [{ id: 'd1', name: 'Gol', serial: 'ABC1D23' }, { id: 'd2', name: 'Uno' }] })
    expect(deviceSummary(o)).toBe('Gol +1')
    expect(matchesSearch(o, 'jose abc1', 'Aprovada')).toBe(true)
    expect(matchesSearch(o, '186', 'Aprovada')).toBe(true)
    expect(matchesSearch(o, 'maria', 'Aprovada')).toBe(false)
    const lines = order('o', {
      devices: [{ id: 'd1', name: 'Gol' }, { id: 'd2', name: 'Uno' }],
      services: [{ service: { name: 'A' }, deviceId: 'd2' }, { service: { name: 'B' } }],
    })
    expect(linesByDevice(lines).map((group) => [group.device?.id ?? null, group.lines.map((l) => l.name)])).toEqual([
      ['d2', ['A']],
      [null, ['B']],
    ])
    expect(initialsOf('Oficina do Zé e Filhos')).toBe('OF')
    expect(initialsOf('')).toBe('')
  })
})

describe('line ids', () => {
  test('same recipe as the server (order-items.ts locateLines)', async () => {
    const services = [{ service: { id: 's1' }, value: 50 }, { service: { id: 's1' }, value: 50 }]
    const products = [{ id: 'stored', product: { id: 'p1' } }]
    const hash = (parts: unknown[]) => createHash('sha256').update(JSON.stringify(parts)).digest('hex').slice(0, 20)
    const signature = hash(['service', 's1', null, 50, null, null, null])
    expect(await lineIds(services, products)).toEqual([`legacy_${signature}_0`, `legacy_${signature}_1`, 'stored'])
  })
})

describe('versionOf (revisao-pr515-3 A1)', () => {
  test('the stored updatedAt as is: local text without a zone is never read as an instant', () => {
    expect(versionOf({ updatedAt: '2026-10-01T09:00:00.123456' })).toBe('2026-10-01T09:00:00.123456')
    expect(versionOf({ updatedAt: '2026-10-01T10:00:00.000Z' })).toBe('2026-10-01T10:00:00.000Z')
  })
  test('a Timestamp is its millis; nothing is null; the API version wins', () => {
    expect(versionOf({ updatedAt: { seconds: 1790000000, nanoseconds: 123000000 } })).toBe('1790000000123')
    expect(versionOf({ updatedAt: { toMillis: () => 5 } })).toBe('5')
    expect(versionOf({})).toBeNull()
    expect(versionOf({ updatedAt: '2026-10-01T10:00:00.000Z', version: '2026-10-01T07:00:00.000' })).toBe('2026-10-01T07:00:00.000')
  })
})
