// Periods of the Financeiro and the report. Pure: days are 'YYYY-MM-DD' of the
// company's calendar (lib/zone.ts), both ends included. One rule for the label,
// the request and the export (the app had three, defect D2).
// Contract: docs/web-app/contract-cases/finance-period.json.

export type PeriodKind = 'day' | 'week' | 'month' | 'year'

export interface Days {
  from: string
  to: string
}

const DAY = /^(\d{4})-(\d{2})-(\d{2})$/

function parts(day: string): [number, number, number] {
  const match = DAY.exec(day)
  if (!match) throw new Error(`not a day: ${day}`)
  return [Number(match[1]), Number(match[2]), Number(match[3])]
}

const iso = (date: Date) => date.toISOString().slice(0, 10)
const utc = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d))

/** Whether `day` is a real calendar day. */
export function isDay(day: unknown): day is string {
  if (typeof day !== 'string' || !DAY.test(day)) return false
  const [y, m, d] = parts(day)
  return iso(utc(y, m, d)) === day
}

export function addDays(day: string, count: number): string {
  const [y, m, d] = parts(day)
  return iso(utc(y, m, d + count))
}

/** Day of the week, 0 = Sunday. */
export function weekday(day: string): number {
  const [y, m, d] = parts(day)
  return utc(y, m, d).getUTCDay()
}

/**
 * The period of `kind`, `offset` periods away from the one with `today`
 * (negative: the past). The week goes from Sunday to Saturday, as in the app
 * (lib/utils/report_week.dart).
 */
export function periodOf(kind: PeriodKind, offset: number, today: string): Days {
  const [y, m] = parts(today)
  if (kind === 'day') {
    const day = addDays(today, offset)
    return { from: day, to: day }
  }
  if (kind === 'week') {
    const from = addDays(today, -weekday(today) + 7 * offset)
    return { from, to: addDays(from, 6) }
  }
  if (kind === 'month') {
    return { from: iso(utc(y, m + offset, 1)), to: iso(utc(y, m + offset + 1, 0)) }
  }
  return { from: `${y + offset}-01-01`, to: `${y + offset}-12-31` }
}

/** 'YYYY-MM' of a day. */
export const monthOf = (day: string): string => day.slice(0, 7)

/** The month `offset` months away from 'YYYY-MM'. */
export function shiftMonth(month: string, offset: number): string {
  const [y, m] = month.split('-').map(Number) as [number, number]
  return iso(utc(y, m + offset, 1)).slice(0, 7)
}

/** Whole days between two days (to − from). */
export function daysBetween(from: string, to: string): number {
  const [a, b, c] = parts(from)
  const [x, yy, z] = parts(to)
  return Math.round((utc(x, yy, z).getTime() - utc(a, b, c).getTime()) / 86_400_000)
}

