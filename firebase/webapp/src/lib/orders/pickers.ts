// What the order pickers add to the plain search: "Recentes" (customer.picker.recents),
// the plate that brings customer and device together (customer.picker.plate),
// "Mais usados" of the catalog (order.item-search.most-used) and the device
// sections (device.list.pick). Reads go through the API, which cuts by role:
// the consultant sees the customers of the orders they read, never an empty
// section because a query was refused (the app's defect).
import { loadCatalogList } from '@/lib/catalog/data'
import { loadDevice } from '@/lib/customers/data'
import { normalizePlate } from '@/lib/customers/model'
import { api, can } from '@/lib/session'
import type { Device } from './catalog'

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
