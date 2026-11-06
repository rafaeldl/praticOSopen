// Agenda rules, pure (no Vue, no Firebase), covered by tests/agenda-model.test.ts.
//
// Days are civil days of the COMPANY's zone, written yyyy-mm-dd, never the
// browser's: a visit at 09:00 in São Paulo is on the same day for everyone who
// opens the company, wherever the computer is. Visits stored by the app are
// local time without a zone (Dart toIso8601String); they are read as wall time
// in the company's zone. Visits stored by the API carry a zone (UTC).

import { companyZone, fromWall, parseStored, wallOf, type Wall } from '@/lib/zone'

export { companyZone, fromWall, parseStored, wallOf, type Wall }

const pad = (value: number, size = 2) => String(value).padStart(size, '0')

// ---------------------------------------------------------------------------
// Civil days (yyyy-mm-dd)
// ---------------------------------------------------------------------------

const utcOf = (day: string) => {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  return new Date(Date.UTC(y, m - 1, d))
}
const dayOfUtc = (date: Date) => `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`

export const isDay = (value: unknown): value is string => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(utcOf(value).getTime()) && dayOfUtc(utcOf(value)) === value

export function addDays(day: string, count: number): string {
  const date = utcOf(day)
  date.setUTCDate(date.getUTCDate() + count)
  return dayOfUtc(date)
}

/** 0 is Sunday. */
export const weekday = (day: string) => utcOf(day).getUTCDay()

/** Whole days from `a` to `b`. */
export const daysFrom = (a: string, b: string) => Math.round((utcOf(b).getTime() - utcOf(a).getTime()) / 86400000)

/** The same day `count` months away, or the month's last day (31 Oct + 1 = 30 Nov). */
export function addMonths(day: string, count: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  const first = new Date(Date.UTC(y, m - 1 + count, 1))
  const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate()
  return dayOfUtc(new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(d, last))))
}

export const today = (zone: string, now = new Date()) => wallOf(now, zone).day

/** Countries whose week starts on Sunday (CLDR), when Intl does not say. */
const SUNDAY_FIRST = new Set(['BR', 'US', 'CA', 'MX', 'PE', 'CO', 'PY', 'PT', 'MZ', 'BO'])

/** 0 Sunday, 1 Monday: what the country's calendar shows first (the app always starts on Sunday). */
export function firstDayOfWeek(country: string | null | undefined, locale: string): number {
  try {
    const info = new Intl.Locale(locale) as Intl.Locale & { getWeekInfo?: () => { firstDay: number }; weekInfo?: { firstDay: number } }
    const firstDay = info.getWeekInfo?.().firstDay ?? info.weekInfo?.firstDay
    if (firstDay) return firstDay % 7
  } catch {
    // Older browsers: the table below.
  }
  return SUNDAY_FIRST.has(country?.toUpperCase() ?? 'BR') ? 0 : 1
}

export function weekOf(day: string, firstDay: number): string[] {
  const start = addDays(day, -((weekday(day) - firstDay + 7) % 7))
  return Array.from({ length: 7 }, (_, index) => addDays(start, index))
}

/** Six weeks that hold the month of `day`, from the first day of its first week. */
export function monthGrid(day: string, firstDay: number): string[] {
  const first = `${day.slice(0, 8)}01`
  const start = weekOf(first, firstDay)[0] as string
  return Array.from({ length: 42 }, (_, index) => addDays(start, index))
}

export type AgendaView = 'day' | 'week'

/** Days on screen: one, or the week. */
export function visibleDays(view: AgendaView, day: string, firstDay: number): string[] {
  return view === 'day' ? [day] : weekOf(day, firstDay)
}

/** Previous or next day/week. Week keeps the weekday (app: ±7 days). */
export function step(view: AgendaView, day: string, direction: -1 | 1): string {
  return addDays(day, view === 'week' ? 7 * direction : direction)
}

/**
 * What to ask the server: the days on screen and the month grid on the side,
 * widened by 14 h each way. Text without a zone (app) is compared to the bounds
 * as text, so a visit near midnight could fall out of an exact range; each one
 * is placed on its day afterwards (`placeVisits`).
 */
export function queryRange(days: string[], zone: string): { startDate: string; endDate: string } {
  const sorted = [...days].sort()
  const start = fromWall(sorted[0] as string, 0, 0, zone).getTime() - 14 * 3600_000
  const end = fromWall(addDays(sorted[sorted.length - 1] as string, 1), 0, 0, zone).getTime() + 14 * 3600_000
  return { startDate: new Date(start).toISOString(), endDate: new Date(end).toISOString() }
}

// ---------------------------------------------------------------------------
// Visits on days
// ---------------------------------------------------------------------------

export interface Visit<T> {
  item: T
  at: Date
  day: string
  hour: number
  minute: number
  /** 00:00 is "Dia todo" (the app's rule), and so is everything without useScheduling. */
  allDay: boolean
}

/**
 * Each item on its day, in the company's zone. Within a day: with time first,
 * by time; "Dia todo" last (app: agenda_store ordersForSelectedDate).
 */
export function placeVisits<T>(items: T[], stored: (item: T) => unknown, zone: string, timed = true): Map<string, Visit<T>[]> {
  const byDay = new Map<string, Visit<T>[]>()
  for (const item of items) {
    const at = parseStored(stored(item), zone)
    if (!at) continue
    const wall = wallOf(at, zone)
    const visit = { item, at, day: wall.day, hour: wall.hour, minute: wall.minute, allDay: !timed || (wall.hour === 0 && wall.minute === 0) }
    const list = byDay.get(wall.day) ?? []
    list.push(visit)
    byDay.set(wall.day, list)
  }
  for (const list of byDay.values()) {
    list.sort((a, b) => (a.allDay === b.allDay ? a.at.getTime() - b.at.getTime() : a.allDay ? 1 : -1))
  }
  return byDay
}

/** First and last hour of the grid: 7 to 19, widened to show every timed visit. */
export function hourSpan(visits: Visit<unknown>[], from = 7, to = 19): { start: number; end: number } {
  let start = from
  let end = to
  for (const visit of visits) {
    if (visit.allDay) continue
    start = Math.min(start, visit.hour)
    end = Math.max(end, visit.hour + 1)
  }
  return { start, end: Math.min(24, end) }
}

export const SLOT_MINUTES = 30

/** A point of the grid (minutes from midnight) snapped to the half hour, inside the day. */
export function snapMinutes(minutes: number): number {
  const snapped = Math.round(minutes / SLOT_MINUTES) * SLOT_MINUTES
  return Math.max(0, Math.min(24 * 60 - SLOT_MINUTES, snapped))
}

/** The half hour a click on the grid falls in: 14:20 is 14:00 (the slot under the pointer). */
export function slotAt(minutes: number): number {
  const slot = Math.floor(minutes / SLOT_MINUTES) * SLOT_MINUTES
  return Math.max(0, Math.min(24 * 60 - SLOT_MINUTES, slot))
}

export interface Target {
  day: string
  /** null: "Dia todo" (00:00). */
  minutes: number | null
}

/** Where a keyboard move lands: Shift+↑/↓ half an hour, Shift+←/→ a day (time kept). */
export function nudge(from: Target, key: 'ArrowUp' | 'ArrowDown' | 'ArrowLeft' | 'ArrowRight'): Target {
  if (key === 'ArrowLeft' || key === 'ArrowRight') return { ...from, day: addDays(from.day, key === 'ArrowLeft' ? -1 : 1) }
  // "Dia todo" moves into the grid at 08:00 going down; nothing above it.
  if (from.minutes === null) return key === 'ArrowDown' ? { ...from, minutes: 8 * 60 } : from
  const next = from.minutes + (key === 'ArrowUp' ? -SLOT_MINUTES : SLOT_MINUTES)
  if (next < 0) return from
  return { ...from, minutes: Math.min(24 * 60 - SLOT_MINUTES, next) }
}

/** The instant of a target. */
export function targetInstant(target: Target, zone: string): Date {
  const minutes = target.minutes ?? 0
  return fromWall(target.day, Math.floor(minutes / 60), minutes % 60, zone)
}

/**
 * What to save for a target, as the app writes it: the company's local time
 * without a zone ("Dia todo" is midnight). The app reads it with DateTime.parse
 * and its hour, day and month filter stay right (revisão do #521, M1).
 */
export function storedText(target: Target): string {
  const minutes = target.minutes ?? 0
  return `${target.day}T${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}:00.000`
}

/** A target as the value of a datetime-local field of Nova OS ("Dia todo" is midnight). */
export function localInput(target: Target): string {
  return storedText(target).slice(0, 16)
}

export function sameTarget(a: Target, b: Target): boolean {
  return a.day === b.day && a.minutes === b.minutes
}

/**
 * Moving a visit the customer already counts on: it had a date, it has a
 * customer and it is not over. The screen asks before saving (a new date for
 * an order without one is not a change for the customer).
 */
export function affectsCustomer(order: { status: string; customer?: { id?: string; name?: string } | null }, hadDate: boolean): boolean {
  return hadDate && !!(order.customer?.id || order.customer?.name) && order.status !== 'done' && order.status !== 'canceled'
}

/**
 * Side by side in a day column: orders have no duration, so each one takes an
 * hour; those that overlap share the width (lane of lanes).
 */
export function layoutColumn<T>(visits: Visit<T>[]): Map<Visit<T>, { lane: number; lanes: number }> {
  const timed = visits.filter((visit) => !visit.allDay).sort((a, b) => a.at.getTime() - b.at.getTime())
  const result = new Map<Visit<T>, { lane: number; lanes: number }>()
  let cluster: Visit<T>[] = []
  let laneEnds: number[] = []
  let clusterEnd = -Infinity
  const close = () => {
    for (const visit of cluster) result.set(visit, { lane: result.get(visit)?.lane ?? 0, lanes: laneEnds.length })
    cluster = []
    laneEnds = []
    clusterEnd = -Infinity
  }
  for (const visit of timed) {
    const start = visit.hour * 60 + visit.minute
    if (start >= clusterEnd) close()
    let lane = laneEnds.findIndex((end) => end <= start)
    if (lane < 0) lane = laneEnds.push(0) - 1
    laneEnds[lane] = start + 60
    clusterEnd = Math.max(clusterEnd, start + 60)
    cluster.push(visit)
    result.set(visit, { lane, lanes: 0 })
  }
  close()
  return result
}
