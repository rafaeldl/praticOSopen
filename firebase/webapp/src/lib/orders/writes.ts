// Money, status and items always go through /v1/app/orders (ADR-001): one set
// of rules, the server's. `expectedUpdatedAt` refuses a write over a newer save
// (409 ORDER_CHANGED); payments and discounts carry a `clientTransactionId`, so
// a retry or a double click never books twice. Customer, device, comments and
// photos carry no money and go to Firestore, like the app (only changed fields).
import { firestoreClient, storageClient } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import { normalizeOrder, type HoldReason, type Order, type OrderStatus } from './model'

const base = (id: string) => `/v1/app/orders/${encodeURIComponent(id)}`

interface OrderResponse {
  order?: Record<string, unknown>
  itemId?: string
  transactionId?: string
}

/** The order of a write response, in the screen's shape. */
export function orderOf(response: OrderResponse, showsMoney: boolean): Order | null {
  const raw = response.order
  return raw ? normalizeOrder(String(raw.id), raw, showsMoney) : null
}

/** A new id for each payment or discount the person asks for; reused only on a retry. */
export function newTransactionId(): string {
  return crypto.randomUUID()
}

/**
 * #516 on the server: POST /items without catalogId (an item outside the catalog,
 * "+ Usar «texto» nesta OS") and `clientOrderId` on POST /orders (a retry after a
 * network failure returns the order already created). On since #516 is in master.
 */
export const API_516 = true

export interface NewOrderInput {
  /** One per Nova OS opened, reused on every retry (sent only with API_516). */
  clientOrderId?: string
  customerId: string
  deviceId?: string
  services: { serviceId: string; value?: number | null }[]
  products: { productId: string; quantity: number; value?: number | null }[]
  status?: OrderStatus
  dueDate?: string
  scheduledDate?: string
}

export function createOrder(input: NewOrderInput) {
  const { clientOrderId, ...rest } = input
  const body = API_516 && clientOrderId ? { ...rest, clientOrderId } : rest
  return api<{ id: string; number: number; status: OrderStatus }>('/v1/app/orders', { method: 'POST', body })
}

export function patchOrder(
  id: string,
  patch: { status?: OrderStatus; dueDate?: string | null; scheduledDate?: string | null; assignedTo?: string | null },
  expectedUpdatedAt?: string | null,
) {
  return api<OrderResponse>(base(id), {
    method: 'PATCH',
    body: { ...patch, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) },
  })
}

export function deleteOrder(id: string) {
  return api<{ id: string; deleted: boolean }>(base(id), { method: 'DELETE' })
}

export function addItem(
  id: string,
  // Without catalogId (API_516): an item outside the catalog, named by its description.
  item: { kind: 'service' | 'product'; catalogId?: string; description?: string; value?: number | null; quantity?: number; deviceId?: string | null },
  expectedUpdatedAt?: string | null,
) {
  return api<OrderResponse>(`${base(id)}/items`, {
    method: 'POST',
    body: { ...item, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) },
  })
}

export function updateItem(
  id: string,
  itemId: string,
  patch: { description?: string; value?: number | null; quantity?: number; total?: number | null; deviceId?: string | null },
  expectedUpdatedAt?: string | null,
) {
  return api<OrderResponse>(`${base(id)}/items/${encodeURIComponent(itemId)}`, {
    method: 'PATCH',
    body: { ...patch, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) },
  })
}

export function removeItem(id: string, itemId: string, expectedUpdatedAt?: string | null) {
  const query = expectedUpdatedAt ? `?expectedUpdatedAt=${encodeURIComponent(expectedUpdatedAt)}` : ''
  return api<OrderResponse>(`${base(id)}/items/${encodeURIComponent(itemId)}${query}`, { method: 'DELETE' })
}

/** expectedUpdatedAt: a payment over a newer version is refused (two screens receiving the same balance). */
export function receivePayment(
  id: string,
  body: { amount: number; paymentMethod?: string; paidAt?: string; clientTransactionId: string; receiptFile?: { url: string; storagePath: string; fileName: string; contentType: string } },
  expectedUpdatedAt?: string | null,
) {
  return api<OrderResponse>(`${base(id)}/payments`, { method: 'POST', body: { ...body, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) } })
}

export function giveDiscount(id: string, body: { amount: number; clientTransactionId: string }, expectedUpdatedAt?: string | null) {
  return api<OrderResponse>(`${base(id)}/discounts`, { method: 'POST', body: { ...body, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) } })
}

export function markOnHold(id: string, reason: HoldReason, note?: string) {
  return api<OrderResponse>(`${base(id)}/hold`, { method: 'POST', body: { reason, ...(note ? { note } : {}) } })
}

export function resumeOrder(id: string) {
  return api<OrderResponse>(`${base(id)}/hold`, { method: 'DELETE' })
}

// ---------------------------------------------------------------------------
// Firestore: no money in these fields
// ---------------------------------------------------------------------------

const author = () => ({ id: session.uid, name: session.name ?? session.email ?? '' })

async function orderDoc(orderId: string) {
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return { ref: firestore.doc(db, 'companies', session.companyId as string, 'orders', orderId), firestore }
}

/** Only the fields that change, so nothing another device saved is overwritten. */
export async function updateOrderFields(orderId: string, fields: Record<string, unknown>): Promise<void> {
  const { ref, firestore } = await orderDoc(orderId)
  await firestore.updateDoc(ref, { ...fields, updatedAt: new Date().toISOString(), updatedBy: author() })
}

export async function addComment(orderId: string, text: string, isInternal: boolean): Promise<void> {
  const [db, { addDoc, collection }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  await addDoc(collection(db, 'companies', session.companyId as string, 'orders', orderId, 'comments'), {
    text,
    authorType: 'internal',
    author: { name: session.name ?? '', email: session.email ?? '', userId: session.uid },
    source: 'web',
    isInternal,
    createdAt: new Date().toISOString(),
  })
}

/**
 * Takes one photo out (order.photo.delete): a transaction rereads the list and
 * drops only this one (photos added elsewhere stay), then the file leaves the
 * Storage. A file already gone is fine.
 */
export async function deletePhoto(orderId: string, photo: { id?: string; url?: string; storagePath?: string }): Promise<void> {
  const { ref: docRef, firestore } = await orderDoc(orderId)
  const db = await firestoreClient()
  await firestore.runTransaction(db, async (tx) => {
    const snap = await tx.get(docRef)
    const photos = ((snap.data()?.photos ?? []) as { id?: string; url?: string }[]).filter((item) => (photo.id ? item.id !== photo.id : item.url !== photo.url))
    tx.update(docRef, { photos, updatedAt: new Date().toISOString(), updatedBy: author() })
  })
  // Only a file in this order's photos folder leaves the Storage (an odd path in the document never does).
  if (!photo.storagePath || !photo.storagePath.startsWith(`tenants/${session.companyId}/orders/${orderId}/photos/`) || photo.storagePath.includes('..')) return
  const [storage, { ref, deleteObject }] = await Promise.all([storageClient(), import('firebase/storage')])
  await deleteObject(ref(storage, photo.storagePath)).catch((error: { code?: string }) => {
    if (error?.code !== 'storage/object-not-found') console.warn('photos: file not deleted', error)
  })
}

/** Photo in the order's folder, then appended to `photos` (arrayUnion keeps others' photos). */
export async function uploadPhoto(orderId: string, file: File): Promise<void> {
  const companyId = session.companyId as string
  const id = crypto.randomUUID()
  const extension = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '')
  const path = `tenants/${companyId}/orders/${orderId}/photos/${id}.${extension}`
  const [storage, { ref, uploadBytes, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  const target = ref(storage, path)
  await uploadBytes(target, file, { contentType: file.type })
  const url = await getDownloadURL(target)
  const { ref: docRef, firestore } = await orderDoc(orderId)
  await firestore.updateDoc(docRef, {
    photos: firestore.arrayUnion({ id, url, storagePath: path, createdAt: new Date().toISOString(), createdBy: author() }),
    updatedAt: new Date().toISOString(),
    updatedBy: author(),
  })
}
