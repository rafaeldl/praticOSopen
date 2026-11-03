// Pure rules of the customer and device screens (fatia 03). Each comes from the
// app (lib/utils/customer_utils.dart, device_suggestions.dart, the screens) and
// says where it does not copy a defect.
import { phoneMatchKey } from '@/lib/phone'

export interface CustomerRow {
  id: string
  name: string
  phone: string | null
  email: string | null
  taxId: string | null
  address: string | null
  /** Open orders (approved, progress) the person reads. */
  open: number
  late: number
}

export type DeviceStatus = 'active' | 'maintenance' | 'inactive' | 'decommissioned'
export const DEVICE_STATUSES: DeviceStatus[] = ['active', 'maintenance', 'inactive', 'decommissioned']

export interface DeviceRow {
  id: string
  name: string | null
  serial: string | null
  manufacturer: string | null
  category: string | null
  status: DeviceStatus | null
  photo: string | null
  nextMaintenanceDate: string | null
}

/** Lowercase, without accents (the app's search does not ignore accents: defect 16, not copied). */
export function fold(text: string): string {
  return text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
}

/** Plate or serial to compare: letters and digits, uppercase (normalizePlate). */
export const normalizePlate = (text: string | null | undefined) => (text ?? '').replace(/[^A-Za-z0-9]/g, '').toUpperCase()

/** Looks like a phone: digits, spaces and ()+- only, with at least 4 digits. */
export const looksLikePhone = (text: string) => /^[\d\s()+-]+$/.test(text) && text.replace(/\D/g, '').length >= 4

/** Name by words (each typed word starts a word of the name) or phone by digits. */
export function customerMatches(customer: Pick<CustomerRow, 'name' | 'phone' | 'email'>, query: string): boolean {
  const text = query.trim()
  if (!text) return true
  if (looksLikePhone(text)) return (customer.phone ?? '').replace(/\D/g, '').includes(text.replace(/\D/g, ''))
  const words = fold(`${customer.name} ${customer.email ?? ''}`).split(/[^\p{L}\p{N}@.]+/u).filter(Boolean)
  return fold(text)
    .split(/\s+/)
    .filter(Boolean)
    .every((part) => words.some((word) => word.startsWith(part)))
}

/** Plate search from 3 characters, without hyphen, space or case; at most 5 (customer.list.search). */
export function plateMatches(devices: DeviceRow[], query: string, max = 5): DeviceRow[] {
  const plate = normalizePlate(query)
  if (plate.length < 3) return []
  return devices.filter((device) => normalizePlate(device.serial).includes(plate)).slice(0, max)
}

/** Device search: model, serial (without hyphen or space) and brand, ignoring accents (device.list.search). */
export function deviceMatches(device: DeviceRow, query: string): boolean {
  const text = query.trim()
  if (!text) return true
  const plate = normalizePlate(text)
  if (plate.length >= 3 && normalizePlate(device.serial).includes(plate)) return true
  const words = fold(`${device.name ?? ''} ${device.manufacturer ?? ''} ${device.serial ?? ''}`).split(/[^\p{L}\p{N}]+/u).filter(Boolean)
  return fold(text)
    .split(/\s+/)
    .filter(Boolean)
    .every((part) => words.some((word) => word.startsWith(part)))
}

/** Initial for the groups: without accent, "#" for a name that does not start with a letter. */
export function initialOf(name: string): string {
  const first = fold(name.trim()).charAt(0).toUpperCase()
  return /[A-Z]/.test(first) ? first : '#'
}

export function byName<T extends { name: string | null }>(a: T, b: T): number {
  return (a.name ?? '').localeCompare(b.name ?? '', undefined, { sensitivity: 'base' })
}

/** Groups by initial, letters A-Z first and "#" last. */
export function groupByInitial<T extends { name: string }>(rows: T[]): { initial: string; rows: T[] }[] {
  const groups = new Map<string, T[]>()
  for (const row of [...rows].sort(byName)) {
    const initial = initialOf(row.name)
    groups.set(initial, [...(groups.get(initial) ?? []), row])
  }
  return [...groups.entries()]
    .sort(([a], [b]) => (a === '#' ? 1 : b === '#' ? -1 : a.localeCompare(b)))
    .map(([initial, list]) => ({ initial, rows: list }))
}

/** Badge of a row: late wins over open (customer.list.badges). */
export function badgeOf(row: Pick<CustomerRow, 'open' | 'late'>): { kind: 'late' | 'open'; count: number } | null {
  if (row.late > 0) return { kind: 'late', count: row.late }
  if (row.open > 0) return { kind: 'open', count: row.open }
  return null
}

/** "Cadastrar «texto»": only digits, spaces and ()+- become the phone; the rest the name. */
export function draftFromSearch(text: string): { name: string; phone: string } {
  const value = text.trim()
  return /^[\d\s()+-]+$/.test(value) && /\d/.test(value) ? { name: '', phone: value } : { name: value, phone: '' }
}

/** Offer "Cadastrar «texto»" unless a customer already has that very name (ignoring accents and case). */
export function canOfferCreate(customers: Pick<CustomerRow, 'name'>[], text: string): boolean {
  const value = fold(text.trim())
  return !!value && !customers.some((customer) => fold(customer.name.trim()) === value)
}

/** First customer with the same phone in any format (findCustomerByPhone), or null. */
export function findByPhone<T extends Pick<CustomerRow, 'phone'>>(customers: T[], phone: string, country?: string | null, except?: string): T | null {
  const key = phoneMatchKey(phone, country)
  if (!key) return null
  return customers.find((customer) => (customer as unknown as { id?: string }).id !== except && !!customer.phone?.trim() && phoneMatchKey(customer.phone, country) === key) ?? null
}

/** Brazilian plate with or without hyphen (AAA-9A99, AAA9999): becomes the serial in "Cadastrar". */
export const isBrazilianPlate = (text: string) => /^[A-Za-z]{3}-?\d[A-Za-z0-9]\d{2}$/.test(text.trim())

/** Serial: optional, required without a model; checked against the segment pattern (device.form.serial-rules). */
export function serialError(serial: string, model: string, pattern?: string): 'required' | 'pattern' | null {
  const value = serial.trim()
  if (!value) return model.trim() ? null : 'required'
  if (pattern) {
    try {
      if (!new RegExp(pattern).test(value.toUpperCase())) return 'pattern'
    } catch {
      return null
    }
  }
  return null
}

/**
 * Model suggestions from the company's own devices: distinct model, brand and
 * category, by how many devices have it, found by model or brand, at most 5.
 */
export function modelSuggestions(devices: Pick<DeviceRow, 'name' | 'manufacturer' | 'category'>[], query: string, max = 5) {
  const text = fold(query.trim())
  if (!text) return []
  const counts = new Map<string, { name: string; manufacturer: string | null; category: string | null; count: number }>()
  for (const device of devices) {
    if (!device.name) continue
    if (!fold(device.name).includes(text) && !fold(device.manufacturer ?? '').includes(text)) continue
    const key = `${fold(device.name)}|${fold(device.manufacturer ?? '')}|${fold(device.category ?? '')}`
    const current = counts.get(key) ?? { name: device.name, manufacturer: device.manufacturer, category: device.category, count: 0 }
    current.count++
    counts.set(key, current)
  }
  return [...counts.values()].sort((a, b) => b.count - a.count || a.name.localeCompare(b.name)).slice(0, max)
}

/** Default day of the next maintenance: 6 months ahead, last day of the month when shorter (addMonths). */
export function addMonths(date: Date, months: number): Date {
  const target = new Date(date.getFullYear(), date.getMonth() + months, 1)
  const last = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate()
  return new Date(target.getFullYear(), target.getMonth(), Math.min(date.getDate(), last))
}

/** Maps link for an address or coordinates (customer.form.map), or null. */
export function mapsUrl(address: string | null | undefined, latitude?: number | null, longitude?: number | null): string | null {
  if (typeof latitude === 'number' && typeof longitude === 'number') return `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`
  const text = (address ?? '').trim()
  return text ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(text)}` : null
}

/** First name for "Nova OS para Ana". */
export const firstName = (name: string) => name.trim().split(/\s+/)[0] ?? name
