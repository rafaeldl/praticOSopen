// What the order pickers add to the plain search: "Recentes" (customer.picker.recents),
// the plate that brings customer and device together (customer.picker.plate),
// "Mais usados" of the catalog (order.item-search.most-used) and the device
// sections (device.list.pick). Reads go through the API, which cuts by role:
// the consultant sees the customers of the orders they read, never an empty
// section because a query was refused (the app's defect).
import { loadCatalogList } from '@/lib/catalog/data'
import { loadDevice } from '@/lib/customers/data'
import { isBrazilianPlate, normalizePlate } from '@/lib/customers/model'
import { firestoreLite } from '@/lib/firebase'
import { api, can, session } from '@/lib/session'
import { shallowRef } from 'vue'
import { forgetLists, type Device } from './catalog'

export interface Named {
  id: string
  name: string
}

/** 5 distinct customers of the last 50 orders this person reads, the newest first. */
export async function recentCustomers(max = 5): Promise<Named[]> {
  const body = await api<{ data?: { customer?: { id?: string; name?: string } | null }[] }>('/v1/app/orders?limit=50', { raw: true })
  return recentOf(body.data ?? [], max)
}

export function recentOf(rows: { customer?: { id?: string; name?: string } | null }[], max = 5): Named[] {
  const seen = new Map<string, Named>()
  for (const row of rows) {
    const customer = row.customer
    if (customer?.id && !seen.has(customer.id)) seen.set(customer.id, { id: customer.id, name: customer.name ?? '' })
    if (seen.size >= max) break
  }
  return [...seen.values()]
}

/** From 3 characters, without hyphen, space or case; at most 5, on top of the customers. */
export function plateHits<T extends Device>(devices: T[], query: string, max = 5): T[] {
  const plate = normalizePlate(query)
  if (plate.length < 3) return []
  return devices.filter((device) => normalizePlate(device.serial).includes(plate)).slice(0, max)
}

/** Owner of a device: the customer of its most recent order (the API reads it by role). Null when unknown. */
export async function ownerOf(deviceId: string): Promise<Named | null> {
  try {
    const owner = (await loadDevice(deviceId)).owner
    return owner?.id ? { id: owner.id, name: owner.name ?? '' } : null
  } catch {
    return null
  }
}

/**
 * Owner of each plate shown, read once per device and kept for the visit: the
 * picker reads `plateOwners` and redraws when an owner arrives (customer.picker.plate:
 * "placa · modelo" with the owner's name below).
 */
export const plateOwners = shallowRef(new Map<string, Named | null>())
const asked = new Set<string>()
export function plateOwnerName(deviceId: string): string | undefined {
  const known = plateOwners.value.get(deviceId)
  if (known !== undefined) return known?.name || undefined
  if (!asked.has(deviceId)) {
    asked.add(deviceId)
    void ownerOf(deviceId).then((owner) => (plateOwners.value = new Map(plateOwners.value).set(deviceId, owner)))
  }
  return undefined
}

/**
 * Most used of the catalog ("service:id" / "product:id"), from the last orders,
 * as the catalog screen shows them. A failure only hides the section.
 */
export async function mostUsedKeys(max = 6): Promise<string[]> {
  const kinds = (['service', 'product'] as const).filter((kind) => can(kind === 'service' ? 'viewServices' : 'viewProducts'))
  const lists = await Promise.all(kinds.map((kind) => loadCatalogList(kind).then((list) => list.mostUsed.map((id) => `${kind}:${id}`), () => [])))
  // One of each kind in turn, so services do not push products out.
  const keys: string[] = []
  for (let index = 0; keys.length < max && lists.some((list) => index < list.length); index++) {
    for (const list of lists) if (list[index] && keys.length < max) keys.push(list[index] as string)
  }
  return keys
}

/**
 * Devices this customer brought before (the devices of their last orders): the
 * section "do cliente" of device.list.pick. Who sees values reads Firestore;
 * who does not, the API projection. A failure only loses the suggestion.
 */
export async function devicesOfCustomer(customerId: string, showsMoney: boolean): Promise<Device[]> {
  try {
    let rows: { devices?: Device[]; device?: Device }[] = []
    if (showsMoney) {
      const [db, { collection, getDocs, limit, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
      const filters = [where('customer.id', '==', customerId), ...(can('viewAllOrders') ? [] : [where('createdBy.id', '==', session.uid)])]
      rows = (await getDocs(query(collection(db, 'companies', session.companyId as string, 'orders'), ...filters, limit(10)))).docs.map((doc) => doc.data())
    } else {
      const body = await api<{ data?: typeof rows }>(`/v1/app/orders?limit=10&customerId=${encodeURIComponent(customerId)}`, { raw: true })
      rows = body.data ?? []
    }
    const found = new Map<string, Device>()
    for (const row of rows) for (const item of row.devices?.length ? row.devices : row.device ? [row.device] : []) if (item?.id) found.set(item.id, item)
    return [...found.values()]
  } catch (error) {
    console.warn('pickers: devices of the customer not read', error)
    return []
  }
}

/** device.list.pick-create: a Brazilian plate becomes the serial in capitals, anything else the model. */
export async function createDeviceFrom(text: string): Promise<Device> {
  const typed = text.trim()
  const plate = isBrazilianPlate(typed)
  const created = await api<{ id: string; name: string | null; serial?: string | null }>('/v1/app/devices', { method: 'POST', body: plate ? { serial: typed.toUpperCase() } : { name: typed } })
  const serial = created.serial ?? (plate ? typed.toUpperCase() : null)
  forgetLists()
  return { id: created.id, name: created.name || serial || typed, ...(serial ? { serial } : {}) }
}

/** The company's devices in the app's order (TenantDeviceRepository orderBy name), not the storage's id order. */
export function byName<T extends { name?: string | null }>(list: readonly T[]): T[] {
  return [...list].sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '', 'pt', { sensitivity: 'base', numeric: true }))
}
