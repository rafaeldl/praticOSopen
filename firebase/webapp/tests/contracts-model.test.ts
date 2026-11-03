import { describe, expect, it } from 'vitest'
import * as model from '@/lib/contracts/model'
import {
  afterEnd,
  byNext,
  clampEnd,
  isTemplate,
  newContract,
  nextPlanned,
  normalizeContract,
  plannedNext,
  repeatChoices,
  repeatOfKey,
  scheduleChanges,
  stateOf,
  stepFrom,
  stopChanges,
  titleClashes,
  wallOfStored,
  type Contract,
} from '@/lib/contracts/model'

const toWall = (date: Date) => date.toISOString().replace('Z', '')
const monthly = { frequency: 'monthly', interval: 1 }

function contract(fields: Partial<Contract> = {}): Contract {
  return {
    frequency: 'monthly',
    interval: 1,
    startDate: '2026-10-15T00:00:00.000',
    endDate: null,
    nextDueDate: '2026-11-15T00:00:00.000',
    lastGeneratedDate: null,
    generatedCount: 0,
    autoGenerate: true,
    active: true,
    reminderDaysBefore: 3,
    parentOrderId: null,
    parentOrderNumber: null,
    ...fields,
  }
}

describe('stepFrom (OrderContract.stepFrom)', () => {
  it('monthly rolls day 31 like Dart DateTime, at midnight', () => {
    expect(stepFrom('2026-01-31T10:30:00.000', monthly)).toBe('2026-03-03T00:00:00.000')
    expect(stepFrom('2026-01-30T00:00:00.000', monthly)).toBe('2026-03-02T00:00:00.000')
    expect(stepFrom('2026-12-15T00:00:00.000', { frequency: 'monthly', interval: 3 })).toBe('2027-03-15T00:00:00.000')
  })
  it('yearly from 29/02 is 01/03', () => {
    expect(stepFrom('2028-02-29T00:00:00.000', { frequency: 'yearly', interval: 1 })).toBe('2029-03-01T00:00:00.000')
  })
  it('daily and weekly keep the time', () => {
    expect(stepFrom('2026-11-03T14:00:00.000', { frequency: 'daily', interval: 1 })).toBe('2026-11-04T14:00:00.000')
    expect(stepFrom('2026-11-03T14:00:00.000', { frequency: 'weekly', interval: 2 })).toBe('2026-11-17T14:00:00.000')
  })
  it('unknown frequency: no next', () => {
    expect(stepFrom('2026-11-03T00:00:00.000', { frequency: 'hourly', interval: 1 })).toBeNull()
  })
})

describe('reading what the app and the server wrote', () => {
  it('keeps zoneless text as written and converts instants with the company clock', () => {
    expect(wallOfStored('2026-12-03T00:00:00.000', toWall)).toBe('2026-12-03T00:00:00.000')
    expect(wallOfStored('2026-12-03T00:00:00', toWall)).toBe('2026-12-03T00:00:00.000')
    expect(wallOfStored('2026-12-03T03:00:00.000Z', (d) => toWall(new Date(d.getTime() - 3 * 3600_000)))).toBe('2026-12-03T00:00:00.000')
    expect(wallOfStored({ seconds: 0 }, toWall)).toBe('1970-01-01T00:00:00.000')
    expect(wallOfStored('', toWall)).toBeNull()
  })
  it('normalizes the contract map; missing autoGenerate reads as on, missing active as off', () => {
    const c = normalizeContract({ frequency: 'weekly', interval: 2, nextDueDate: '2026-11-10T00:00:00.000' }, toWall)
    expect(c).toMatchObject({ frequency: 'weekly', interval: 2, autoGenerate: true, active: false, generatedCount: 0 })
    expect(normalizeContract(null, toWall)).toBeNull()
  })
  it('a generated order is not a contract of its own', () => {
    expect(isTemplate(true, contract())).toBe(true)
    expect(isTemplate(true, contract({ parentOrderId: 'x' }))).toBe(false)
    expect(isTemplate(undefined, contract())).toBe(false)
  })
})

describe('states and the next order', () => {
  it('on or ended: off is ended, as in the app; no paused state (A1 and M3 of the #527 review)', () => {
    expect(stateOf(contract())).toBe('active')
    expect(stateOf(contract({ active: false }))).toBe('ended')
    // A pausedAt written by an older web build changes nothing.
    expect(stateOf({ ...contract({ active: false }), pausedAt: '2026-11-01T09:00:00.000' } as Contract)).toBe('ended')
    expect(Object.keys(model.normalizeContract({ active: false, pausedAt: '2026-11-01T09:00:00.000' }, toWall) ?? {})).not.toContain('pausedAt')
  })
  it('next planned: date, late, manual, or none after the end (endDate included)', () => {
    expect(nextPlanned(contract(), '2026-11-03')).toEqual({ kind: 'date', date: '2026-11-15T00:00:00.000', late: false })
    expect(nextPlanned(contract(), '2026-11-20')).toMatchObject({ kind: 'date', late: true })
    expect(nextPlanned(contract({ autoGenerate: false }), '2026-11-03')).toMatchObject({ kind: 'manual' })
    expect(nextPlanned(contract({ endDate: '2026-11-15T00:00:00.000' }), '2026-11-03').kind).toBe('date')
    expect(nextPlanned(contract({ endDate: '2026-11-14T00:00:00.000' }), '2026-11-03')).toEqual({ kind: 'none' })
    expect(afterEnd(contract({ endDate: '2026-11-15T00:00:00.000' }), '2026-11-15T23:00:00.000')).toBe(false)
  })
})

describe('schedule', () => {
  it('counts periods from the start, the start being the order that holds it, from today on', () => {
    expect(plannedNext({ frequency: 'monthly', interval: 1, startDate: '2026-11-03T00:00:00.000', lastGeneratedDate: null }, '2026-11-03')).toBe('2026-12-03T00:00:00.000')
    // Start long ago: missed periods are not made up; today counts.
    expect(plannedNext({ frequency: 'monthly', interval: 1, startDate: '2026-01-03T00:00:00.000', lastGeneratedDate: null }, '2026-11-03')).toBe('2026-11-03T00:00:00.000')
    // Never the day already generated.
    expect(plannedNext({ frequency: 'daily', interval: 1, startDate: '2026-11-01T00:00:00.000', lastGeneratedDate: '2026-11-03T02:00:00.000' }, '2026-11-03')).toBe('2026-11-04T00:00:00.000')
  })
  it('new contract: the app defaults with the person choices, written in the app shape', () => {
    const c = newContract({ repeat: monthly, startDay: '2026-11-03', endDay: null, autoGenerate: true }, '2026-11-03')
    expect(c).toEqual({
      frequency: 'monthly', interval: 1, startDate: '2026-11-03T00:00:00.000', endDate: null, nextDueDate: '2026-12-03T00:00:00.000',
      lastGeneratedDate: null, generatedCount: 0, autoGenerate: true, active: true, reminderDaysBefore: 3, parentOrderId: null, parentOrderNumber: null,
    })
  })
  it('save writes only what changed, and the next order when the schedule moved', () => {
    const c = contract()
    expect(scheduleChanges(c, { repeat: monthly, startDay: '2026-10-15', endDay: null, autoGenerate: true }, '2026-11-03')).toEqual({})
    expect(scheduleChanges(c, { repeat: monthly, startDay: '2026-10-15', endDay: '2027-10-15', autoGenerate: false }, '2026-11-03')).toEqual({
      endDate: '2027-10-15T00:00:00.000',
      autoGenerate: false,
    })
    expect(scheduleChanges(c, { repeat: { frequency: 'weekly', interval: 1 }, startDay: '2026-10-15', endDay: null, autoGenerate: true }, '2026-11-03')).toEqual({
      frequency: 'weekly',
      nextDueDate: '2026-11-05T00:00:00.000',
    })
  })
  it('the end is never before the start', () => {
    expect(clampEnd('2026-11-10', '2026-11-01')).toBe('2026-11-10')
    expect(clampEnd('2026-11-10', null)).toBeNull()
  })
})

describe('stop', () => {
  it('no pause nor resume until the app reads the template in its transaction (A1 of the #527 review)', () => {
    expect('pauseChanges' in model).toBe(false)
    expect('resumeChanges' in model).toBe(false)
  })
  it('stop keeps the contract, off, ending today unless it ended before', () => {
    expect(stopChanges(contract(), '2026-11-03')).toEqual({ active: false, endDate: '2026-11-03T00:00:00.000' })
    expect(stopChanges(contract({ endDate: '2026-10-01T00:00:00.000' }), '2026-11-03')).toEqual({ active: false })
  })
})

describe('list helpers', () => {
  it('the 8 choices, plus the current one when it is another', () => {
    expect(repeatChoices(monthly)).toHaveLength(8)
    expect(repeatChoices({ frequency: 'monthly', interval: 4 })).toHaveLength(9)
    expect(repeatOfKey('weekly:2')).toEqual({ frequency: 'weekly', interval: 2 })
  })
  it('next order first, without a date last', () => {
    const rows = [
      { contract: contract({ nextDueDate: null }), customer: 'A' },
      { contract: contract({ nextDueDate: '2026-12-01T00:00:00.000' }), customer: 'B' },
      { contract: contract({ nextDueDate: '2026-11-20T00:00:00.000' }), customer: 'C' },
    ]
    expect(rows.sort(byNext).map((r) => r.customer)).toEqual(['C', 'B', 'A'])
  })
  it('title clashes when the segment calls each order Contrato', () => {
    expect(titleClashes('Contratos', 'Contratos')).toBe(true)
    expect(titleClashes('OS', 'Contratos')).toBe(false)
  })
})
