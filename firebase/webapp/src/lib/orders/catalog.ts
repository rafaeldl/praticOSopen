// Reference lists for the order screens: customers, devices, catalog and team.
// Read once per company and kept in memory (no money in them except catalog
// prices, which only show for who has viewPrices).
import { firestoreClient } from '@/lib/firebase'
import { can, session } from '@/lib/session'
import { matchesWords } from '@/lib/text'

export interface Customer {
  id: string
  name: string
  phone?: string
  address?: string | null
}
export interface Device {
  id: string
  name: string
  serial?: string | null
}
export interface CatalogItem {
  id: string
  kind: 'service' | 'product'
  name: string
  value: number | null
}
export interface Member {
  id: string
  name: string
  role?: string
}

const cache = new Map<string, Promise<unknown>>()

async function readAll<T>(collectionName: string, map: (id: string, data: Record<string, unknown>) => T | null, max = 2000): Promise<T[]> {
  const companyId = session.companyId as string
  const key = `${companyId}|${collectionName}`
  let promise = cache.get(key) as Promise<T[]> | undefined
  if (!promise) {
    promise = (async () => {
      const [db, { collection, getDocs, limit, query }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
      const snapshot = await getDocs(query(collection(db, 'companies', companyId, collectionName), limit(max)))
      return snapshot.docs.map((doc) => map(doc.id, doc.data())).filter((item): item is T => item !== null)
    })()
    cache.set(key, promise)
    promise.catch(() => cache.delete(key))
  }
  return promise
}

const byName = <T extends { name: string }>(a: T, b: T) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })

export const loadCustomers = () =>
  readAll<Customer>('customers', (id, data) => ({
    id,
    name: String(data.name ?? ''),
    phone: data.phone as string | undefined,
    address: (data.address as string | null) ?? null,
  })).then((list) => [...list].sort(byName))

export const loadDevices = () =>
  readAll<Device>('devices', (id, data) => ({ id, name: String(data.name ?? ''), serial: (data.serial as string | null) ?? null })).then(
    (list) => [...list].sort(byName),
  )

/** Services and products the person may see (viewServices / viewProducts). Prices only with viewPrices. */
export async function loadCatalog(): Promise<CatalogItem[]> {
  const prices = can('viewPrices')
  const map = (kind: CatalogItem['kind']) => (id: string, data: Record<string, unknown>) =>
    ({ id, kind, name: String(data.name ?? ''), value: prices && typeof data.value === 'number' ? data.value : null }) as CatalogItem
  const [services, products] = await Promise.all([
    can('viewServices') ? readAll('services', map('service')) : Promise.resolve([]),
    can('viewProducts') ? readAll('products', map('product')) : Promise.resolve([]),
  ])
  return [...services, ...products].sort(byName)
}

export const loadTeam = () =>
  readAll<Member>('memberships', (id, data) => {
    const user = (data.user ?? {}) as { name?: string; email?: string }
    return { id: (data.userId as string) || id, name: user.name || user.email || id, role: data.role as string | undefined }
  }).then((list) => [...list].sort(byName))

/** Forget the lists (after a new customer or device was created here). */
export function forgetLists(): void {
  cache.clear()
}

export function search<T extends { name: string }>(items: T[], query: string, extra: (item: T) => string = () => '', max = 8): T[] {
  const text = query.trim()
  if (!text) return items.slice(0, max)
  return items.filter((item) => matchesWords(`${item.name} ${extra(item)}`, text)).slice(0, max)
}
