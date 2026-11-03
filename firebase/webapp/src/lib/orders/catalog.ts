// Reference lists for the order screens: customers, devices, catalog and team.
// Read once per company and kept in memory (no money in them except catalog
// prices, which only show for who has viewPrices).
import { authClient, firestoreClient } from '@/lib/firebase'
import { can, session } from '@/lib/session'
import { matchesWords } from '@/lib/text'

export interface Customer {
  id: string
  name: string
  phone?: string
  email?: string
  taxId?: string
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
    email: data.email as string | undefined,
    taxId: data.taxId as string | undefined,
    address: (data.address as string | null) ?? null,
  })).then((list) => [...list].sort(byName))

export const loadDevices = () =>
  readAll<Device>('devices', (id, data) => ({ id, name: String(data.name ?? ''), serial: (data.serial as string | null) ?? null })).then(
    (list) => [...list].sort(byName),
  )

/**
 * Names of a collection by the Firestore REST API with a field mask: only `name`
 * travels, and nothing goes to this browser's persistent cache. For who does
 * not see values, so no price reaches the network or the disk.
 */
async function readNamesRest(collectionName: string): Promise<{ id: string; name: string }[]> {
  const env = import.meta.env
  const companyId = session.companyId as string
  const key = `${companyId}|rest|${collectionName}`
  let promise = cache.get(key) as Promise<{ id: string; name: string }[]> | undefined
  if (!promise) {
    promise = (async () => {
      const auth = await authClient()
      const token = await auth.currentUser?.getIdToken()
      const host = import.meta.env.VITE_USE_EMULATORS === '1' ? `http://127.0.0.1:${env.VITE_EMULATOR_FIRESTORE_PORT ?? 8080}` : 'https://firestore.googleapis.com'
      const base = `${host}/v1/projects/${env.VITE_FIREBASE_PROJECT_ID}/databases/(default)/documents/companies/${companyId}/${collectionName}`
      const items: { id: string; name: string }[] = []
      let pageToken = ''
      do {
        const response = await fetch(`${base}?pageSize=300&mask.fieldPaths=name${pageToken ? `&pageToken=${pageToken}` : ''}`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        if (!response.ok) throw new Error(`catalog ${response.status}`)
        const body = (await response.json()) as { documents?: { name: string; fields?: { name?: { stringValue?: string } } }[]; nextPageToken?: string }
        for (const doc of body.documents ?? []) items.push({ id: doc.name.split('/').pop() as string, name: doc.fields?.name?.stringValue ?? '' })
        pageToken = body.nextPageToken ?? ''
      } while (pageToken && items.length < 2000)
      return items
    })()
    cache.set(key, promise)
    promise.catch(() => cache.delete(key))
  }
  return promise
}

/** Services and products the person may see (viewServices / viewProducts). Prices only with viewPrices. */
export async function loadCatalog(): Promise<CatalogItem[]> {
  const prices = can('viewPrices')
  const read = (name: 'services' | 'products', kind: CatalogItem['kind']): Promise<CatalogItem[]> =>
    prices
      ? readAll(name, (id, data) => ({ id, kind, name: String(data.name ?? ''), value: typeof data.value === 'number' ? data.value : null }))
      : readNamesRest(name).then((list) => list.map((item) => ({ ...item, kind, value: null })))
  const [services, products] = await Promise.all([
    can('viewServices') ? read('services', 'service') : Promise.resolve([]),
    can('viewProducts') ? read('products', 'product') : Promise.resolve([]),
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
