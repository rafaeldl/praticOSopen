// Words and dates of the Financeiro: the company's country gives the format
// (lib/format.ts), like the agenda. A civil day (yyyy-mm-dd) is formatted at
// noon UTC, read in UTC: no zone can move it.
import { t } from '@/i18n'
import { countryFormat, toIsoDay } from '@/lib/format'
import { session } from '@/lib/session'
import type { Days, PeriodKind } from './period'

const locale = () => countryFormat(session.company?.country).locale
const formats = new Map<string, Intl.DateTimeFormat>()
function format(options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const key = `${locale()}|${JSON.stringify(options)}`
  let found = formats.get(key)
  if (!found) {
    found = new Intl.DateTimeFormat(locale(), { timeZone: 'UTC', ...options })
    formats.set(key, found)
  }
  return found
}
const noonOf = (day: string) => new Date(`${day}T12:00:00Z`)

/** Today on the company's calendar. */
export const today = (): string => toIsoDay(new Date())

/** "março" */
export const monthName = (month: string) => format({ month: 'long' }).format(noonOf(`${month}-01`))
/** "março de 2026" */
export const monthYear = (month: string) => format({ month: 'long', year: 'numeric' }).format(noonOf(`${month}-01`))
/** "10/03/2026" */
export const dayText = (day: string) => format({ day: '2-digit', month: '2-digit', year: 'numeric' }).format(noonOf(day))
/** "10/03" */
export const dayShort = (day: string) => format({ day: '2-digit', month: '2-digit' }).format(noonOf(day))

/** What the period selector says: "Hoje", "01/11 a 07/11", "Mês atual", "março de 2026", "2026"… */
export function periodLabel(kind: PeriodKind | 'custom', offset: number, days: Days): string {
  if (kind === 'custom') return t('web.report.range', { from: dayText(days.from), to: dayText(days.to) })
  if (kind === 'day') return offset === 0 ? t('today') : dayText(days.from)
  if (kind === 'week') return t('web.report.range', { from: dayShort(days.from), to: dayShort(days.to) })
  if (kind === 'month') return offset === 0 ? t('currentMonth') : monthYear(days.from.slice(0, 7))
  return offset === 0 ? t('currentYear') : days.from.slice(0, 4)
}

/** The period inside a sentence: "em março de 2026", "de 01/11 a 07/11". */
export function periodPhrase(days: Days): string {
  if (days.from === days.to) return t('web.report.onDay', { day: dayText(days.from) })
  return t('web.report.inRange', { from: dayText(days.from), to: dayText(days.to) })
}
