// Catalog through the API (/v1/app/services, /v1/app/products). Without
// viewPrices the server leaves the price out, so it never reaches the network
// or any cache of this browser. No Firestore here: these screens add nothing
// to the first download. The photo goes to Storage (same folder as the app)
// only after the item exists, so cancelling never leaves an item behind (C9).
import { ApiError } from '@/lib/api'
import { storageClient } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import { MAX_PRICE_BATCH, priceBatchBody, type CatalogItem, type CatalogKind, type PriceBatch } from './model'

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

/** One item read now (value and version as the server has them). Null: gone. */
export async function loadItem(kind: CatalogKind, id: string): Promise<CatalogItem | null> {
  try {
    return await api<CatalogItem>(`${BASE[kind]}/${encodeURIComponent(id)}`)
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return null
    throw error
  }
}

/** Someone saved the item (or one of the prices) since it was read. */
export const changedSince = (error: unknown) => error instanceof ApiError && error.status === 409 && error.code === 'CATALOG_ITEM_CHANGED'

export interface CatalogInput {
  name?: string
  value?: number | null
  customData?: Record<string, unknown> | null
  photo?: { url: string; storagePath: string } | null
  /** With `photo: null`: the photo the person saw. */
  photoSeen?: string | null
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

/**
 * One batch, one request, one transaction (up to 500 items): all or nothing.
 * Each change says the price the person saw and the batch carries its key, so
 * sending the same batch again never applies it twice.
 */
export async function applyPrices(batch: PriceBatch): Promise<{ updated: number; unchanged: number }> {
  if (batch.changes.length > MAX_PRICE_BATCH) throw new Error('batch too big')
  try {
    return await api<{ updated: number; unchanged: number }>(`${BASE[batch.kind]}/prices`, { method: 'POST', body: priceBatchBody(batch) })
  } finally {
    forgetCatalog()
  }
}
