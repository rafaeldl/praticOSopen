/**
 * The company's time zone, the same rule as the web app (firebase/webapp/src/lib/zone.ts).
 *
 * The company has no zone field: it comes from the country, and the zone the
 * browser asks for wins when it is one of that country's (a company in Manaus
 * opened on a computer in Manaus). Dates the app stores without a zone (Dart
 * toIso8601String) are wall time in this zone.
 */

/** Main zone of each country the app formats. */
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
};

/** Countries with more than one zone: the one asked for wins when it is one of them. */
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
};

/** Without a country the app follows the device; the server follows Brazil, where every company so far is. */
export const DEFAULT_ZONE = 'America/Sao_Paulo';

function isZone(zone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

/**
 * The company's zone. `requested` (the browser's) is used when it belongs to
 * the company's country, or when the company has no country and it is a real zone.
 */
export function companyZone(country: string | null | undefined, requested?: string | null): string {
  const code = country?.toUpperCase() ?? '';
  const main = COUNTRY_ZONE[code];
  if (!main) return requested && isZone(requested) ? requested : DEFAULT_ZONE;
  return requested && COUNTRY_ZONES[code]?.includes(requested) ? requested : main;
}

const formats = new Map<string, Intl.DateTimeFormat>();
function partsFormat(zone: string): Intl.DateTimeFormat {
  let format = formats.get(zone);
  if (!format) {
    format = new Intl.DateTimeFormat('en-US', {
      timeZone: zone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
    });
    formats.set(zone, format);
  }
  return format;
}

/** The day (YYYY-MM-DD) a clock in `zone` shows at this instant. */
export function dayIn(date: Date, zone: string): string {
  const parts = Object.fromEntries(partsFormat(zone).formatToParts(date).map((part) => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function offsetAt(date: Date, zone: string): number {
  const parts = Object.fromEntries(partsFormat(zone).formatToParts(date).map((part) => [part.type, part.value]));
  const asUtc = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day), Number(parts.hour) % 24, Number(parts.minute), Number(parts.second));
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** The instant a clock in `zone` shows this day and time. */
export function fromWall(day: string, hour: number, minute: number, zone: string, second = 0, ms = 0): Date {
  const [y, m, d] = day.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hour, minute, second, ms);
  let instant = guess - offsetAt(new Date(guess), zone);
  // Near a change of daylight saving time the first offset can be the other one.
  const second2 = guess - offsetAt(new Date(instant), zone);
  if (second2 !== instant) instant = second2;
  return new Date(instant);
}

const ZONELESS = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$/;
const DAY_ONLY = /^\d{4}-\d{2}-\d{2}$/;

/**
 * A stored date as an instant. Text without a zone (written by the app) is
 * wall time in the company's zone; a Timestamp or text with a zone is already
 * an instant. A bare day is midnight of that day in the zone.
 */
export function instantOf(value: unknown, zone: string): Date | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'string') {
    if (DAY_ONLY.test(value)) return fromWall(value, 0, 0, zone);
    const match = ZONELESS.exec(value);
    if (match) {
      const [, y, m, d, h, min, s, frac] = match;
      const ms = frac ? Number(frac.slice(0, 3).padEnd(3, '0')) : 0;
      return fromWall(`${y}-${m}-${d}`, Number(h), Number(min), zone, Number(s ?? 0), ms);
    }
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  const ts = value as { toDate?: () => Date; seconds?: number; _seconds?: number };
  if (typeof ts.toDate === 'function') return ts.toDate();
  if (typeof ts.seconds === 'number') return new Date(ts.seconds * 1000);
  if (typeof ts._seconds === 'number') return new Date(ts._seconds * 1000);
  return null;
}

/** The day after `day` (YYYY-MM-DD). */
export function nextDay(day: string): string {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);
}

/**
 * A period of whole days in `zone`, both ends included: [start, end) as instants,
 * `end` being midnight after the last day (the app left the last day out, defect 60).
 */
export function daysRange(from: string, to: string, zone: string): { start: Date; end: Date } {
  return { start: fromWall(from, 0, 0, zone), end: fromWall(nextDay(to), 0, 0, zone) };
}
