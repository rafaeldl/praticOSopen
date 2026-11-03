// The company's time zone, for every date on screen and every date the web
// writes (revisão do #521, M1, M2 e B2). Pure: no Vue, no Firebase.
//
// The company has no zone field: it comes from the country, and the browser's
// own zone wins when it is one of that country's. Visits and deliveries the app
// stores are local time without a zone (Dart toIso8601String): they are wall
// time in this zone, and the web writes them the same way.

/** Main zone of each country the app formats (lib/format.ts COUNTRIES). */
const COUNTRY_ZONE: Record<string, string> = {
  BR: 'America/Sao_Paulo',
  US: 'America/New_York',
  PT: 'Europe/Lisbon',
  ES: 'Europe/Madrid',
  MX: 'America/Mexico_City',
  AR: 'America/Argentina/Buenos_Aires',
  CL: 'America/Santiago',
  CO: 'America/Bogota',
  PE: 'America/Lima',
  UY: 'America/Montevideo',
  PY: 'America/Asuncion',
  BO: 'America/La_Paz',
  GB: 'Europe/London',
  CA: 'America/Toronto',
  AO: 'Africa/Luanda',
  MZ: 'Africa/Maputo',
}

/** Countries with more than one zone: the browser's wins when it is one of them. */
const COUNTRY_ZONES: Record<string, string[]> = {
  BR: [
    'America/Sao_Paulo', 'America/Bahia', 'America/Fortaleza', 'America/Recife', 'America/Maceio', 'America/Belem',
    'America/Araguaina', 'America/Santarem', 'America/Manaus', 'America/Cuiaba', 'America/Campo_Grande',
    'America/Porto_Velho', 'America/Boa_Vista', 'America/Rio_Branco', 'America/Eirunepe', 'America/Noronha',
  ],
  US: [
    'America/New_York', 'America/Chicago', 'America/Denver', 'America/Phoenix', 'America/Los_Angeles', 'America/Anchorage',
    'America/Detroit', 'America/Boise', 'America/Indiana/Indianapolis', 'Pacific/Honolulu',
  ],
  CA: ['America/Toronto', 'America/Vancouver', 'America/Edmonton', 'America/Winnipeg', 'America/Halifax', 'America/St_Johns', 'America/Regina'],
  MX: ['America/Mexico_City', 'America/Cancun', 'America/Monterrey', 'America/Tijuana', 'America/Chihuahua', 'America/Hermosillo', 'America/Mazatlan', 'America/Merida'],
  ES: ['Europe/Madrid', 'Atlantic/Canary'],
  PT: ['Europe/Lisbon', 'Atlantic/Azores', 'Atlantic/Madeira'],
  AR: ['America/Argentina/Buenos_Aires', 'America/Argentina/Cordoba', 'America/Argentina/Mendoza'],
  CL: ['America/Santiago', 'America/Punta_Arenas'],
}

/** The country has a zone of its own here (else the company follows the browser). */
export const hasCountryZone = (country: string): boolean => !!COUNTRY_ZONE[country.toUpperCase()]

/** The company's zone. A company without a country follows the browser. */
export function companyZone(country: string | null | undefined, browserZone = Intl.DateTimeFormat().resolvedOptions().timeZone): string {
  const code = country?.toUpperCase() ?? ''
  const main = COUNTRY_ZONE[code]
  if (!main) return browserZone || 'UTC'
  return COUNTRY_ZONES[code]?.includes(browserZone) ? browserZone : main
}

// ---------------------------------------------------------------------------
// Wall time in a zone
// ---------------------------------------------------------------------------

export interface Wall {
  day: string
  hour: number
  minute: number
}

const partsFormats = new Map<string, Intl.DateTimeFormat>()
function partsFormat(zone: string): Intl.DateTimeFormat {
  let format = partsFormats.get(zone)
  if (!format) {
    format = new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
    partsFormats.set(zone, format)
  }
  return format
}

/** What a clock on the wall of `zone` shows at this instant. */
export function wallOf(date: Date, zone: string): Wall & { second: number } {
  const parts = Object.fromEntries(partsFormat(zone).formatToParts(date).map((part) => [part.type, part.value]))
  return {
    day: `${parts.year}-${parts.month}-${parts.day}`,
    hour: Number(parts.hour) % 24,
    minute: Number(parts.minute),
    second: Number(parts.second),
  }
}

/** Offset of `zone` at this instant, in milliseconds (São Paulo: -3 h). */
function offsetAt(date: Date, zone: string): number {
  const wall = wallOf(date, zone)
  const [y, m, d] = wall.day.split('-').map(Number) as [number, number, number]
  const asUtc = Date.UTC(y, m - 1, d, wall.hour, wall.minute, wall.second)
  return asUtc - Math.floor(date.getTime() / 1000) * 1000
}

/** The instant a clock in `zone` shows this day and time. */
export function fromWall(day: string, hour: number, minute: number, zone: string): Date {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  const guess = Date.UTC(y, m - 1, d, hour, minute)
  let instant = guess - offsetAt(new Date(guess), zone)
  // Near a change of daylight saving time the first offset can be the other one.
  const second = guess - offsetAt(new Date(instant), zone)
  if (second !== instant) instant = second
  return new Date(instant)
}

const ZONELESS = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/

/**
 * A stored visit or delivery as an instant. Text without a zone (written by the
 * app) is wall time in the company's zone; a Timestamp, a Date or text with a
 * zone is already an instant.
 */
export function parseStored(value: unknown, zone: string): Date | null {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'string') {
    const match = ZONELESS.exec(value)
    if (match) {
      const [, y, m, d, h, min] = match
      return fromWall(`${y}-${m}-${d}`, Number(h), Number(min), zone)
    }
    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : date
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value
  const ts = value as { toDate?: () => Date; seconds?: number }
  if (typeof ts.toDate === 'function') return ts.toDate()
  if (typeof ts.seconds === 'number') return new Date(ts.seconds * 1000)
  return null
}

const pad = (value: number, size = 2) => String(value).padStart(size, '0')

// Read once: resolvedOptions() builds a formatter, too slow for every date on a list.
const BROWSER_ZONE = Intl.DateTimeFormat().resolvedOptions().timeZone
export const browserZone = () => BROWSER_ZONE

/** '' while the company's zone is the browser's: local getters, no Intl per call. */
let zone = ''

/** Set from the company (App.vue). null goes back to the browser's zone. */
export function setZone(next: string | null | undefined): void {
  zone = next && next !== browserZone() ? next : ''
}

export const currentZone = () => zone || browserZone()

/** Year, month (1-12), day, hour and minute on the company's clock. */
export function wallParts(date: Date): { y: number; m: number; d: number; h: number; min: number } {
  if (!zone) return { y: date.getFullYear(), m: date.getMonth() + 1, d: date.getDate(), h: date.getHours(), min: date.getMinutes() }
  const wall = wallOf(date, zone)
  const [y, m, d] = wall.day.split('-').map(Number) as [number, number, number]
  return { y, m, d, h: wall.hour, min: wall.minute }
}

/** The instant as the app stores a visit: company's local time, no zone. */
export function wallText(date: Date): string {
  const p = wallParts(date)
  return `${p.y}-${pad(p.m)}-${pad(p.d)}T${pad(p.h)}:${pad(p.min)}:00.000`
}

/** Zoneless text (the app's) as an instant in the company's zone; anything else as is. */
export function instantOf(value: string): Date {
  return parseStored(value, currentZone()) ?? new Date(NaN)
}
