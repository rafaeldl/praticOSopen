// Work stages (docs/WORK_STAGES.md): reading the company's list, which column an
// order goes to, its place in it and the services printed for each stage.
import { describe, expect, test, vi } from 'vitest'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  firestoreLite: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const { normalizeOrder } = await import('../src/lib/orders/model')
const { linesForStage, rankAt, sortInStage, stageIdOf, stagesOf, suggestedStage } = await import('../src/lib/orders/stages')

const STAGES = stagesOf([
  { id: 'paint', name: 'Pintura', keywords: ['pint', 'lataria'] },
  { id: 'polish', name: 'Polimento', keywords: ['polim', 'higien'] },
])
const service = (name: string, description?: string) => ({ service: { id: name, name }, description: description ?? name, value: 10 })
const order = (id: string, raw: Record<string, unknown> = {}) =>
  normalizeOrder(id, { status: 'progress', services: [], products: [], ...raw }, true)

describe('stagesOf', () => {
  test('keeps stages with id and name, trims names and drops odd words', () => {
    expect(stagesOf([{ id: 'a', name: ' Pintura ', keywords: ['pint', 3, ' '] }, { id: '', name: 'X' }, { id: 'b' }, null, 'c'])).toEqual([
      { id: 'a', name: 'Pintura', keywords: ['pint'] },
    ])
    expect(stagesOf(undefined)).toEqual([])
    expect(stagesOf({})).toEqual([])
  })
})

describe('stage of an order', () => {
  test('only in progress; without a stage, or with a removed one, it is the first column', () => {
    expect(stageIdOf(order('a', { stage: { id: 'polish', rank: 1, since: '2026-11-06T10:00:00Z' } }), STAGES)).toBe('polish')
    expect(stageIdOf(order('b'), STAGES)).toBe('paint')
    expect(stageIdOf(order('c', { stage: { id: 'gone', rank: 1 } }), STAGES)).toBe('paint')
    expect(stageIdOf(order('d', { status: 'approved' }), STAGES)).toBeNull()
    expect(stageIdOf(order('e'), [])).toBeNull()
  })

  test('a stage left outside progress is ignored when read', () => {
    expect(order('a', { status: 'done', stage: { id: 'paint', rank: 1 } }).stage).toBeNull()
    expect(order('b', { stage: { id: 'paint', rank: 2, since: '2026-11-06T10:00:00Z' } }).stage).toEqual({ id: 'paint', rank: 2, since: '2026-11-06T10:00:00.000Z' })
  })
})

describe('order inside a stage', () => {
  const ranked = (id: string, rank: number, stage = 'paint') => order(id, { stage: { id: stage, rank } })
  // Put in progress outside the board: no place, only the creation date.
  const loose = (id: string, createdAt: string) => order(id, { createdAt })

  test('by rank; orders with no place count by creation, then the ones without a date', () => {
    const rows = [order('nodate'), ranked('b', Date.parse('2026-11-06T12:00:00Z')), loose('u1', '2026-11-06T10:00:00Z'), ranked('other', 1, 'polish'), ranked('a', 10)]
    expect(sortInStage(rows, 'paint').map((row) => row.id)).toEqual(['a', 'u1', 'b', 'nodate', 'other'])
  })

  test('rank between the neighbours, before the first, after the last', () => {
    const column = [ranked('a', 10), ranked('b', 20)]
    expect(rankAt(column, 1, 'paint')).toBe(15)
    expect(rankAt(column, 0, 'paint')).toBe(10 - 1024)
    expect(rankAt(column, 2, 'paint')).toBe(20 + 1024)
    expect(rankAt([], 0, 'paint')).toBeUndefined()
    expect(rankAt([order('nodate')], 1, 'paint')).toBeUndefined()
  })

  test('a card goes below or between orders that have no place yet', () => {
    const u1 = loose('u1', '2026-11-06T10:00:00Z')
    const u2 = loose('u2', '2026-11-06T11:00:00Z')
    const t1 = Date.parse('2026-11-06T10:00:00Z')
    const t2 = Date.parse('2026-11-06T11:00:00Z')
    expect(rankAt([u1, u2], 1, 'paint')).toBe((t1 + t2) / 2)
    expect(rankAt([u1, u2], 2, 'paint')).toBe(t2 + 1024)
    expect(rankAt([u1, u2], 0, 'paint')).toBe(t1 - 1024)
    // Alt + ↓ on the first card of [A, U1, U2] lands between U1 and U2, and stays there.
    const a = ranked('a', 5)
    const moved = { ...a, stage: { id: 'paint', rank: rankAt([u1, u2], 1, 'paint')!, since: '' } }
    expect(sortInStage([moved, u1, u2], 'paint').map((row) => row.id)).toEqual(['u1', 'a', 'u2'])
  })
})

describe('services of a stage', () => {
  const both = order('a', { services: [service('Pintura de capô'), service('Polimento + higienização'), service('Avaliação')] })

  test('only the services of the stage, by words without accents', () => {
    expect(linesForStage(both, STAGES[0]!).map((line) => line.name)).toEqual(['Pintura de capô'])
    expect(linesForStage(both, STAGES[1]!).map((line) => line.name)).toEqual(['Polimento + higienização'])
    expect(linesForStage(order('b', { services: [service('LATARIA')] }), STAGES[0]!).map((line) => line.name)).toEqual(['LATARIA'])
  })

  test('every service when none matches or the stage has no words', () => {
    expect(linesForStage(order('c', { services: [service('Avaliação')] }), STAGES[1]!).map((line) => line.name)).toEqual(['Avaliação'])
    expect(linesForStage(both, { id: 'x', name: 'Geral' })).toHaveLength(3)
  })

  test('the next stage is the first one of the company that a service points to', () => {
    expect(suggestedStage(both, STAGES)?.id).toBe('paint')
    expect(suggestedStage(order('d', { services: [service('Polimento')] }), STAGES)?.id).toBe('polish')
    expect(suggestedStage(order('e', { services: [service('Avaliação')] }), STAGES)).toBeNull()
  })
})

describe('editing stages (company.stages.edit)', async () => {
  const { draftsOf, stageIdFor, stagesFromDrafts } = await import('../src/lib/orders/stages')

  test('new ids come from the name, without accents, and never repeat', () => {
    expect(stageIdFor('Pintura', new Set())).toBe('pintura')
    expect(stageIdFor('Higienização / Polimento', new Set())).toBe('higienizacao-polimento')
    expect(stageIdFor('Pintura', new Set(['pintura', 'pintura-2']))).toBe('pintura-3')
    expect(stageIdFor('!!!', new Set())).toBe('stage')
  })

  test('kept stages keep their id, so orders stay where they are', () => {
    const drafts = draftsOf([{ id: 'paint', name: 'Pintura', keywords: ['pint'] }])
    drafts[0]!.name = ' Pintura geral '
    drafts.push({ name: 'Polimento', keywords: ' Polim, HIGIEN,, polim ' })
    expect(stagesFromDrafts(drafts)).toEqual({
      stages: [
        { id: 'paint', name: 'Pintura geral', keywords: ['pint'] },
        { id: 'polimento', name: 'Polimento', keywords: ['polim', 'higien'] },
      ],
    })
  })

  test('a blank or repeated name is a problem, not dropped', () => {
    expect(stagesFromDrafts([{ name: 'Pintura', keywords: '' }, { name: '  ', keywords: '' }])).toEqual({ problem: { kind: 'empty', index: 1 } })
    expect(stagesFromDrafts([{ name: 'Pintura', keywords: '' }, { name: 'pintura ', keywords: '' }])).toEqual({ problem: { kind: 'repeated', index: 1 } })
  })

  test('no stages turns them off', () => {
    expect(stagesFromDrafts([])).toEqual({ stages: [] })
  })
})
