// Agenda words and dates: the company's country gives the format and the zone
// (lib/agenda/model.ts companyZone), never the browser.
import { t } from '@/i18n'
import { countryFormat } from '@/lib/format'
import { session } from '@/lib/session'
import { companyZone, type Target } from './model'

export const zone = () => companyZone(session.company?.country)
export const agendaLocale = () => countryFormat(session.company?.country).locale

const formats = new Map<string, Intl.DateTimeFormat>()
function format(options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const key = `${agendaLocale()}|${JSON.stringify(options)}`
  let found = formats.get(key)
  if (!found) {
    found = new Intl.DateTimeFormat(agendaLocale(), options)
    formats.set(key, found)
  }
  return found
}

/** A civil day (yyyy-mm-dd) is formatted at noon UTC, read in UTC: no zone can move it. */
const noonOf = (day: string) => new Date(`${day}T12:00:00Z`)

export const dayShort = (day: string) => format({ timeZone: 'UTC', weekday: 'short', day: 'numeric', month: 'short' }).format(noonOf(day))
export const dayLong = (day: string) => format({ timeZone: 'UTC', weekday: 'long', day: 'numeric', month: 'long' }).format(noonOf(day))
export const dayNumber = (day: string) => format({ timeZone: 'UTC', day: 'numeric' }).format(noonOf(day))
export const weekdayShort = (day: string) => format({ timeZone: 'UTC', weekday: 'short' }).format(noonOf(day))
export const weekdayLong = (day: string) => format({ timeZone: 'UTC', weekday: 'long' }).format(noonOf(day))
export const monthTitle = (day: string) => format({ timeZone: 'UTC', month: 'long', year: 'numeric' }).format(noonOf(day))
export const dayMonth = (day: string) => format({ timeZone: 'UTC', day: 'numeric', month: 'short' }).format(noonOf(day))

/** "09:30" in the company's zone (24 h where the country uses it). */
export const timeOf = (date: Date) => format({ timeZone: zone(), hour: '2-digit', minute: '2-digit' }).format(date)

/** Hour label of the grid, in the country's format ("14:00", "2 PM"). */
export const hourLabel = (hour: number) => format({ timeZone: 'UTC', hour: 'numeric', minute: '2-digit' }).format(new Date(Date.UTC(2031, 0, 1, hour)))

export function minutesLabel(minutes: number): string {
  return format({ timeZone: 'UTC', hour: '2-digit', minute: '2-digit' }).format(new Date(Date.UTC(2031, 0, 1, Math.floor(minutes / 60), minutes % 60)))
}

/** "qua., 12 de mar., 10:00", or the day and "Dia todo". */
export function targetText(target: Target): string {
  const time = target.minutes === null || target.minutes === 0 ? t('allDay') : minutesLabel(target.minutes)
  return t('web.agenda.dayAt', { day: dayShort(target.day), time })
}
