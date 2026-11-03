// "Manutenções chegando" on Início (home.maintenance.*), as
// lib/services/device_maintenance_service.dart and home.dart: devices whose
// next maintenance is late or within 7 days, minus the ones under an active
// contract. Read after the list paints, through the REST build of Firestore
// (devices are readable by every member, like in the app).
import { firestoreLite } from '../firebase'
import { toIsoDay } from '../format'
import { api, session } from '../session'

/** Days before the date that the maintenance starts to show (kMaintenanceLeadDays). */
export const LEAD_DAYS = 7
/** How many show before "Ver mais" (_maintenancesShown). */
export const SHOWN = 3

export interface Maintenance {
  id: string
  name: string
  serial: string | null
  day: string
  customer: { id?: string; name?: string } | null
  lastService: string | null
}

/** yyyy-mm-dd plus `days`, by the calendar. */
export function addDays(day: string, days: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10)
}

/** Last day that counts as "chegando" (maintenanceWindowEnd). */
export const windowEnd = (today: string) => addDays(today, LEAD_DAYS)

export const isLate = (day: string, today: string) => day < today

/** First word of the name (firstName). */
export function firstName(name: string | null | undefined): string {
  return (name ?? '').trim().split(/\s+/)[0] ?? ''
}

function toMaintenance(id: string, data: Record<string, unknown>): Maintenance | null {
  const day = data.nextMaintenanceDate
  if (typeof day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day)) return null
  const customer = data.nextMaintenanceCustomer
  return {
    id,
    name: typeof data.name === 'string' ? data.name : '',
    serial: typeof data.serial === 'string' ? data.serial : null,
    day,
    customer: customer && typeof customer === 'object' ? (customer as Maintenance['customer']) : null,
    lastService: typeof data.nextMaintenanceLastService === 'string' && data.nextMaintenanceLastService.trim() ? data.nextMaintenanceLastService.trim() : null,
  }
}

const lite = () => Promise.all([firestoreLite(), import('firebase/firestore/lite')])

/**
 * Under an active contract (activeContract): the contract keeps it. Whoever
 * cannot read contracts (technician, consultant) gets an error from the rules,
 * and the device stays, as in the app.
 */
async function underContract(companyId: string, deviceId: string): Promise<boolean> {
  try {
    const [db, { collection, getDocs, query, where }] = await lite()
    const snapshot = await getDocs(
      query(collection(db, 'companies', companyId, 'orders'), where('isContract', '==', true), where('deviceIds', 'array-contains', deviceId)),
    )
    return snapshot.docs.some((doc) => (doc.data().contract as { active?: unknown } | undefined)?.active === true)
  } catch {
    return false
  }
}

export async function loadMaintenances(now = new Date()): Promise<Maintenance[]> {
  const companyId = session.companyId
  if (!companyId) return []
  const [db, { collection, getDocs, orderBy, query, where }] = await lite()
  const snapshot = await getDocs(
    query(collection(db, 'companies', companyId, 'devices'), where('nextMaintenanceDate', '<=', windowEnd(toIsoDay(now))), orderBy('nextMaintenanceDate')),
  )
  const all = snapshot.docs.map((doc) => toMaintenance(doc.id, doc.data())).filter((item): item is Maintenance => !!item)
  const covered = await Promise.all(all.map((item) => underContract(companyId, item.id)))
  return all.filter((_, index) => !covered[index])
}

export type CustomerPhone = { kind: 'phone'; phone: string } | { kind: 'none' } | { kind: 'gone' }

/** The customer's phone read now (customerPhone); a deleted customer is told apart. */
export async function customerPhone(customerId: string): Promise<CustomerPhone> {
  const companyId = session.companyId
  if (!companyId) return { kind: 'none' }
  const [db, { doc, getDoc }] = await lite()
  const snapshot = await getDoc(doc(db, 'companies', companyId, 'customers', customerId))
  if (!snapshot.exists()) return { kind: 'gone' }
  const phone = snapshot.data().phone
  return typeof phone === 'string' && phone.trim() ? { kind: 'phone', phone } : { kind: 'none' }
}

export interface SeedItem {
  id: string
  name: string
  value: number | null
}

/**
 * Services of the last finished order of the device ("Abrir OS"), with their
 * value. Read through the API, filtered by role on the server; nothing readable
 * opens Nova OS without services (newOrderFor).
 */
export async function lastServices(deviceId: string): Promise<SeedItem[]> {
  try {
    const detail = await api<{ orders: { id: string; status: string; createdAt?: string }[] }>(`/v1/app/devices/${encodeURIComponent(deviceId)}`)
    const last = detail.orders.filter((order) => order.status === 'done').sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''))[0]
    if (!last) return []
    const order = await api<{ services?: { service?: { id?: string; name?: string }; description?: string; value?: number | null }[] }>(
      `/v1/app/orders/${encodeURIComponent(last.id)}`,
    )
    return (order.services ?? [])
      .filter((line) => typeof line.service?.id === 'string')
      .map((line) => ({ id: line.service!.id as string, name: line.service?.name ?? line.description ?? '', value: typeof line.value === 'number' ? line.value : null }))
  } catch (error) {
    console.warn('maintenance: last services not read', error)
    return []
  }
}
