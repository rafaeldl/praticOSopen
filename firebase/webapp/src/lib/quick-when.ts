// Day and time typed in a few letters ("amanhã 14h", "+3", "seg 8:30", "9/5 14h"),
// for the visit and the promised date. Pure: wall time on the company's clock in,
// "yyyy-mm-ddThh:mm" out (the value of a datetime-local), or null when not understood.

export interface WallNow {
  y: number
  m: number
  d: number
  h: number
  min: number
}

const fold = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

const RELATIVE: Record<string, number> = { hoje: 0, today: 0, hoy: 0, amanha: 1, tomorrow: 1, manana: 1 }
/** Sunday = 0. Portuguese, English and Spanish short names (they never clash). */
const WEEKDAYS: Record<string, number> = {
  dom: 0, seg: 1, ter: 2, qua: 3, qui: 4, sex: 5, sab: 6,
  sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6,
  lun: 1, mar: 2, mie: 3, jue: 4, vie: 5,
}

const pad = (n: number) => String(n).padStart(2, '0')
const dayOf = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d))
const isoDay = (date: Date) => `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`
const addDays = (date: Date, days: number) => new Date(date.getTime() + days * 86_400_000)

function parseDay(token: string, today: Date, locale: string): Date | null | undefined {
  if (token in RELATIVE) return addDays(today, RELATIVE[token] as number)
  const plus = /^\+(\d{1,3})$/.exec(token)
  if (plus) return addDays(today, Number(plus[1]))
  const weekday = WEEKDAYS[token.replace(/\.$/, '')]
  if (weekday !== undefined) {
    // The next one after today: "ter" on a Tuesday is next week's.
    const ahead = (weekday - today.getUTCDay() + 7) % 7 || 7
    return addDays(today, ahead)
  }
  const date = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2}|\d{4}))?$/.exec(token)
  if (!date) return undefined
  const [a, b] = [Number(date[1]), Number(date[2])]
  const [d, m] = locale === 'en' ? [b, a] : [a, b]
  let y = date[3] ? Number(date[3].length === 2 ? `20${date[3]}` : date[3]) : today.getUTCFullYear()
  const valid = (year: number) => {
    const at = dayOf(year, m, d)
    return at.getUTCMonth() === m - 1 && at.getUTCDate() === d ? at : null
  }
  let at = m >= 1 && m <= 12 ? valid(y) : null
  if (!at) return null
  // Without a year, a day already gone is next year's.
  if (!date[3] && at < today) at = valid(++y)
  return at
}

function parseTime(token: string): [number, number] | null | undefined {
  const match = /^(\d{1,2})(?:(?::|h)(\d{2})?)?(am|pm)?$/.exec(token)
  if (!match) return undefined
  let h = Number(match[1])
  const min = match[2] ? Number(match[2]) : 0
  if (match[3]) {
    if (h < 1 || h > 12) return null
    h = (h % 12) + (match[3] === 'pm' ? 12 : 0)
  }
  return h <= 23 && min <= 59 ? [h, min] : null
}

/**
 * `current` is the value already there ("yyyy-mm-ddThh:mm" or ""): a typed day
 * keeps its time, a typed time keeps its day. Without either, today and 9:00.
 */
export function parseQuickWhen(text: string, now: WallNow, current: string, locale = 'pt'): string | null {
  const tokens = fold(text).trim().split(/\s+/).filter(Boolean)
  if (!tokens.length) return null
  const today = dayOf(now.y, now.m, now.d)
  let day: Date | null = null
  let time: [number, number] | null = null
  for (const token of tokens) {
    const asDay: Date | null | undefined = day ? undefined : parseDay(token, today, locale)
    if (asDay === null) return null
    if (asDay) {
      day = asDay
      continue
    }
    const asTime: [number, number] | null | undefined = time ? undefined : parseTime(token)
    if (!asTime) return null
    time = asTime
  }
  const known = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(current)
  const base = day ?? (known ? dayOf(Number(known[1]), Number(known[2]), Number(known[3])) : today)
  const [h, min] = time ?? (known ? [Number(known[4]), Number(known[5])] : [9, 0])
  return `${isoDay(base)}T${pad(h)}:${pad(min)}`
}

/** ↑/↓ move a day; with Shift, half an hour (the agenda's step). */
export function shiftWhen(value: string, unit: 'day' | 'time', step: number): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(value)
  if (!match) return value
  const [y, m, d, h, min] = match.slice(1).map(Number) as [number, number, number, number, number]
  const at = new Date(Date.UTC(y, m - 1, d, h, min) + step * (unit === 'day' ? 86_400_000 : 1_800_000))
  return `${isoDay(at)}T${pad(at.getUTCHours())}:${pad(at.getUTCMinutes())}`
}
