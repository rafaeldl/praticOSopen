import { currentZone, fromWall, instantOf, wallParts } from './zone'

// Money, dates and numbers follow the company's COUNTRY, not the interface
// language: one order shows the same value to everyone (business-rules-map, D9).
interface CountryFormat {
  currency: string
  locale: string
}

const COUNTRIES: Record<string, CountryFormat> = {
  BR: { currency: 'BRL', locale: 'pt-BR' },
  US: { currency: 'USD', locale: 'en-US' },
  PT: { currency: 'EUR', locale: 'pt-PT' },
  ES: { currency: 'EUR', locale: 'es-ES' },
  MX: { currency: 'MXN', locale: 'es-MX' },
  AR: { currency: 'ARS', locale: 'es-AR' },
  CL: { currency: 'CLP', locale: 'es-CL' },
  CO: { currency: 'COP', locale: 'es-CO' },
  PE: { currency: 'PEN', locale: 'es-PE' },
  UY: { currency: 'UYU', locale: 'es-UY' },
  PY: { currency: 'PYG', locale: 'es-PY' },
  BO: { currency: 'BOB', locale: 'es-BO' },
  GB: { currency: 'GBP', locale: 'en-GB' },
  CA: { currency: 'CAD', locale: 'en-CA' },
  AO: { currency: 'AOA', locale: 'pt-AO' },
  MZ: { currency: 'MZN', locale: 'pt-MZ' },
}

const DEFAULT_FORMAT: CountryFormat = { currency: 'BRL', locale: 'pt-BR' }

export function countryFormat(country?: string | null): CountryFormat {
  return (country && COUNTRIES[country.toUpperCase()]) || DEFAULT_FORMAT
}

// Building an Intl formatter is slow and lists call these per cell.
const formatters = new Map<string, Intl.NumberFormat | Intl.DateTimeFormat>()

function numberFormat(locale: string, options: Intl.NumberFormatOptions): Intl.NumberFormat {
  const key = `n|${locale}|${JSON.stringify(options)}`
  let formatter = formatters.get(key) as Intl.NumberFormat | undefined
  if (!formatter) {
    formatter = new Intl.NumberFormat(locale, options)
    formatters.set(key, formatter)
  }
  return formatter
}

/** Dates in the company's zone (lib/zone.ts), whatever the computer's. */
function dateFormat(locale: string, base: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const timeZone = currentZone()
  const key = `d|${locale}|${timeZone}|${JSON.stringify(base)}`
  let formatter = formatters.get(key) as Intl.DateTimeFormat | undefined
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, { ...base, timeZone })
    formatters.set(key, formatter)
  }
  return formatter
}

type DateInput = Date | string | number | null | undefined

function toDate(value: DateInput): Date | null {
  if (value === null || value === undefined || value === '') return null
  const date = value instanceof Date ? value : typeof value === 'string' ? instantOf(value) : new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

export function formatMoney(value: number | null | undefined, country?: string | null): string {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  const { currency, locale } = countryFormat(country)
  return numberFormat(locale, { style: 'currency', currency }).format(value)
}

export function formatNumber(value: number | null | undefined, country?: string | null): string {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  return numberFormat(countryFormat(country).locale, { maximumFractionDigits: 2 }).format(value)
}

/** `15.5` is 15,5%, like FormatService.formatPercent. */
export function formatPercent(value: number | null | undefined, country?: string | null): string {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  return numberFormat(countryFormat(country).locale, { style: 'percent', maximumFractionDigits: 2 }).format(value / 100)
}

export function formatDate(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, { day: '2-digit', month: '2-digit', year: 'numeric' }).format(date)
}

export function formatDateLong(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, { day: 'numeric', month: 'long', year: 'numeric' }).format(date)
}

export function formatDateTime(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

/** "15/10" (or "10/15" in the US): the short date of list rows. */
export function formatDayMonth(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, { day: '2-digit', month: '2-digit' }).format(date)
}

/** "17:00" (24 h where the country uses it). */
export function formatTime(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, { hour: '2-digit', minute: '2-digit' }).format(date)
}

/** "outubro de 2026": month headings of "Todas". */
export function formatMonthYear(value: DateInput, country?: string | null): string {
  const date = toDate(value)
  if (!date) return ''
  return dateFormat(countryFormat(country).locale, { month: 'long', year: 'numeric' }).format(date)
}

/** Currency symbol for a field prefix ("R$", "€"). */
export function currencySymbol(country?: string | null): string {
  const { currency, locale } = countryFormat(country)
  const parts = numberFormat(locale, { style: 'currency', currency }).formatToParts(0)
  return parts.find((part) => part.type === 'currency')?.value ?? currency
}

/** Decimal places of the country's currency: 2 for BRL, 0 for CLP. */
export function moneyDigits(country?: string | null): number {
  const { currency, locale } = countryFormat(country)
  return numberFormat(locale, { style: 'currency', currency }).resolvedOptions().maximumFractionDigits ?? 2
}

/** Plain number for an input: "1.234,50", without the symbol. */
export function formatMoneyInput(value: number | null | undefined, country?: string | null): string {
  if (value === null || value === undefined || Number.isNaN(value)) return ''
  const digits = moneyDigits(country)
  return numberFormat(countryFormat(country).locale, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value)
}

function separators(locale: string): { group: string; decimal: string } {
  const parts = numberFormat(locale, {}).formatToParts(1234567.5)
  return {
    group: parts.find((part) => part.type === 'group')?.value ?? ',',
    decimal: parts.find((part) => part.type === 'decimal')?.value ?? '.',
  }
}

/**
 * Reads what a person typed. Digits are never treated as cents: "150" is 150,
 * so a price can never end up 100 times smaller. "12.50" on a pt-BR keyboard
 * still reads as 12,50: a lone separator is thousands only before three digits.
 * Returns null when the text is not a number.
 */
export function parseMoney(text: string, country?: string | null): number | null {
  const cleaned = text.replace(/[\s  ]/g, '').replace(/[^\d.,'’-]/g, '')
  if (!/\d/.test(cleaned)) return null
  const negative = cleaned.startsWith('-')
  const body = cleaned.replace(/-/g, '').replace(/['’]/g, '')
  const { decimal } = separators(countryFormat(country).locale)

  const marks = body.match(/[.,]/g) ?? []
  let integer = body
  let fraction = ''
  if (marks.length > 0) {
    const last = Math.max(body.lastIndexOf('.'), body.lastIndexOf(','))
    const after = body.slice(last + 1)
    const mixed = new Set(marks).size > 1
    // Three digits after a lone mark: thousands, unless it is this country's decimal mark.
    const isDecimal = mixed || (marks.length === 1 && (after.length !== 3 || body[last] === decimal))
    if (isDecimal) {
      integer = body.slice(0, last)
      fraction = after
    }
  }
  integer = integer.replace(/[.,]/g, '')
  if (!/^\d*$/.test(integer) || !/^\d*$/.test(fraction)) return null
  const value = Number(`${integer || '0'}.${fraction || '0'}`)
  if (!Number.isFinite(value)) return null
  const scale = 10 ** moneyDigits(country)
  const rounded = Math.round(value * scale) / scale
  return negative ? -rounded : rounded
}

/** The company's calendar day as yyyy-mm-dd. toISOString would move it across midnight. */
export function toIsoDay(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0')
  const p = wallParts(date)
  return `${p.y}-${pad(p.m)}-${pad(p.d)}`
}

/** yyyy-mm-dd as a local date. `new Date('2026-11-02')` would be UTC, the day before in Brazil. */
export function fromIsoDay(day: string | null | undefined): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day ?? '')
  if (!match) return null
  // Noon of that day in the company's zone: shown in that zone, it is always that day.
  const date = fromWall(`${match[1]}-${match[2]}-${match[3]}`, 12, 0, currentZone())
  return Number.isNaN(date.getTime()) ? null : date
}
