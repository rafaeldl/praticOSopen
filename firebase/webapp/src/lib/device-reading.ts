// The device's reading (odometer in km, hour meter in h…): the same rules as
// the app's lib/utils/device_reading.dart (docs/DEVICE_READING.md). The
// segment marks the device field that is the reading (`reading: true`), with
// its name and unit; the last value stays in that field of the device's
// customData, and each order keeps the value of the visit in
// `deviceReadings`, by device id. A segment without one shows nothing.
// Pure (the order model imports it): callers pass `segmentFieldList()`.
import { formatNumber } from './format'
import type { FormField } from './segment-fields'

const fieldName = (field: FormField) => field.key.split('.').pop() as string

/** Device fields that were readings before the `reading` flag. */
export const LEGACY_READING_KEYS = ['device.mileage', 'device.operatingHours']

export type ReadingField = FormField & { reading?: boolean; suffix?: string }

/** The segment's reading field, or null when it has none. */
export function readingFieldOf(fields: readonly FormField[]): ReadingField | null {
  const numbers = (fields as ReadingField[]).filter((field) => field.type === 'number' && field.key.split('.')[0] === 'device')
  return numbers.find((field) => field.reading === true) ?? LEGACY_READING_KEYS.map((key) => numbers.find((field) => field.key === key)).find(Boolean) ?? null
}

/** A whole number of zero or more, else null ("98.000" and "98,000" are 98000). */
export function parseReading(value: unknown): number | null {
  if (typeof value === 'number') return Number.isInteger(value) && value >= 0 ? value : null
  const digits = String(value ?? '').trim().replace(/[.,\s]/g, '')
  return /^\d+$/.test(digits) ? Number(digits) : null
}

/** "98.000 km", "1.250 h"; empty when there is no reading. */
export function formatReading(field: ReadingField, value: unknown, country?: string | null): string {
  const number = parseReading(value)
  if (number === null) return ''
  const suffix = field.suffix?.trim()
  const text = formatNumber(number, country)
  return suffix ? `${text} ${suffix}` : text
}

/** The device's last reading, from its customData (by name, else by the whole key). */
export function deviceReading(customData: Record<string, unknown> | null | undefined, field: ReadingField): number | null {
  return parseReading(customData?.[fieldName(field)] ?? customData?.[field.key])
}

/** A visit's reading becomes the device's when the device has none or it does not go back. */
export const readingAdvances = (current: number | null, next: number): boolean => current === null || next >= current

/** `deviceReadings` of the order with [deviceId] set to [value] (null removes it); null when empty. */
export function withReading(readings: Record<string, number> | null | undefined, deviceId: string, value: number | null): Record<string, number> | null {
  const out = { ...(readings ?? {}) }
  if (value === null) delete out[deviceId]
  else out[deviceId] = value
  return Object.keys(out).length ? out : null
}

/** Readings of an order document, numbers only. */
export function readingsOf(raw: unknown): Record<string, number> | undefined {
  if (!raw || typeof raw !== 'object') return undefined
  const out: Record<string, number> = {}
  for (const [id, value] of Object.entries(raw as Record<string, unknown>)) {
    const number = parseReading(value)
    if (number !== null) out[id] = number
  }
  return Object.keys(out).length ? out : undefined
}
