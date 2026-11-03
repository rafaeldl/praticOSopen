// Catalog through the API (/v1/app/services, /v1/app/products). Without
// viewPrices the server leaves the price out, so it never reaches the network
// or any cache of this browser. No Firestore here: these screens add nothing
// to the first download. The photo goes to Storage (same folder as the app)
// only after the item exists, so cancelling never leaves an item behind (C9).
import { ApiError } from '@/lib/api'
import { storageClient } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import type { CatalogItem, CatalogKind } from './model'

const BASE: Record<CatalogKind, string> = { service: '/v1/app/services', product: '/v1/app/products' }
const COLLECTION: Record<CatalogKind, string> = { service: 'services', product: 'products' }

export interface CatalogList {
  items: CatalogItem[]
  /** The server sent prices (viewPrices). */
  prices: boolean
  mostUsed: string[]
  truncated: boolean
}

const cache = new Map<string, Promise<CatalogList>>()

/** After any write: the next read asks the server again. */
export function forgetCatalog(): void {
  cache.clear()
}

export function loadCatalogList(kind: CatalogKind, fresh = false): Promise<CatalogList> {
  const key = `${session.companyId}|${kind}`
  if (fresh) cache.delete(key)
  let promise = cache.get(key)
  if (!promise) {
    promise = api<{ data: CatalogItem[]; meta?: { prices?: boolean; mostUsed?: string[]; truncated?: boolean } }>(BASE[kind], { raw: true }).then((body) => ({
      items: body.data ?? [],
      prices: !!body.meta?.prices,
      mostUsed: body.meta?.mostUsed ?? [],
      truncated: !!body.meta?.truncated,
    }))
    cache.set(key, promise)
    promise.catch(() => cache.delete(key))
  }
  return promise
}

/** Someone saved the item (or one of the prices) since it was read. */
export const changedSince = (error: unknown) => error instanceof ApiError && error.status === 409 && error.code === 'CATALOG_ITEM_CHANGED'

export interface CatalogInput {
  name?: string
  value?: number | null
  customData?: Record<string, unknown> | null
  photo?: { url: string; storagePath: string } | null
  version?: string
}

export async function saveItem(kind: CatalogKind, id: string | null, input: CatalogInput): Promise<{ id: string; version: string | null }> {
  const result = id
    ? await api<{ id: string; version: string | null }>(`${BASE[kind]}/${encodeURIComponent(id)}`, { method: 'PATCH', body: input })
    : await api<{ id: string; version: string | null }>(BASE[kind], { method: 'POST', body: input })
  forgetCatalog()
  return result
}

export async function deleteItem(kind: CatalogKind, id: string): Promise<void> {
  await api(`${BASE[kind]}/${encodeURIComponent(id)}`, { method: 'DELETE' })
  forgetCatalog()
}

/** The photo in the item's folder (tenants/{company}/{services|products}/{id}/photo.jpg, as the app). */
export async function uploadItemPhoto(kind: CatalogKind, id: string, file: Blob): Promise<{ url: string; storagePath: string }> {
  const storagePath = `tenants/${session.companyId}/${COLLECTION[kind]}/${id}/photo.jpg`
  const [storage, { ref, uploadBytes, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  const target = ref(storage, storagePath)
  await uploadBytes(target, file, { contentType: file.type || 'image/jpeg' })
  return { url: await getDownloadURL(target), storagePath }
}

export async function importItems(kind: CatalogKind, importId: string, items: { name: string; value?: number | null }[]): Promise<{ created: number; existing: number }> {
  const result = await api<{ created: number; existing: number }>(`${BASE[kind]}/import`, { method: 'POST', body: { importId, items } })
  forgetCatalog()
  return result
}

/** Many prices at once; each says the price the person saw. Repeating is safe. */
export async function applyPrices(kind: CatalogKind, changes: { id: string; from: number | null; to: number }[]): Promise<{ updated: number; unchanged: number }> {
  let updated = 0
  let unchanged = 0
  try {
    for (let start = 0; start < changes.length; start += 500) {
      const result = await api<{ updated: number; unchanged: number }>(`${BASE[kind]}/prices`, { method: 'POST', body: { changes: changes.slice(start, start + 500) } })
      updated += result.updated
      unchanged += result.unchanged
    }
  } finally {
    forgetCatalog()
  }
  return { updated, unchanged }
}
