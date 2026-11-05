// Money and links always through the API (WEB_API.md): payments, receipts,
// charges and the customer link. Firestore only reads what the server writes
// (one-off reads through the REST build, live ones through the full client)
// and the rules let this person read (charges, settings/payments, unpaid orders).
import type { MessageKey } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { firestoreClient, firestoreLite, storageClient } from '@/lib/firebase'
import { normalizeOrder, type Order } from '@/lib/orders/model'
import { api, session } from '@/lib/session'
import { chargeOf, type Charge, type OpenOrder, type SharePermission, type ShareToken } from './model'

const order = (id: string) => `/v1/app/orders/${encodeURIComponent(id)}`
const customer = (id: string) => `/v1/app/customers/${encodeURIComponent(id)}`

interface OrderResponse {
  order?: Record<string, unknown>
}

// ---------------------------------------------------------------------------
// Link to the customer
// ---------------------------------------------------------------------------

export const listShareTokens = (orderId: string) => api<ShareToken[]>(`${order(orderId)}/share`)

export function createShareToken(orderId: string, permissions: SharePermission[], expiresInDays: number) {
  return api<ShareToken>(`${order(orderId)}/share`, { method: 'POST', body: { permissions, expiresInDays } })
}

export const revokeShareToken = (orderId: string, token: string) =>
  api<unknown>(`${order(orderId)}/share/${encodeURIComponent(token)}`, { method: 'DELETE' })

// ---------------------------------------------------------------------------
// Payments of one order
// ---------------------------------------------------------------------------

export function receivePayment(
  orderId: string,
  body: { amount: number; paymentMethod?: string; paidAt?: string; clientTransactionId: string },
  expectedUpdatedAt?: string | null,
) {
  return api<OrderResponse>(`${order(orderId)}/payments`, { method: 'POST', body: { ...body, ...(expectedUpdatedAt ? { expectedUpdatedAt } : {}) } })
}

/** A discount and a payment leave through their own route (WEB_API, Rotas). */
export function removeTransaction(orderId: string, transactionId: string, type: 'payment' | 'discount') {
  const kind = type === 'discount' ? 'discounts' : 'payments'
  return api<OrderResponse>(`${order(orderId)}/${kind}/${encodeURIComponent(transactionId)}`, { method: 'DELETE' })
}

// ---------------------------------------------------------------------------
// Proof of a payment (pay.order.attach-proof)
// ---------------------------------------------------------------------------

export interface ProofFile {
  url: string
  storagePath: string
  fileName: string
  contentType: string
}

/**
 * Uploads to the payment's folder (the app's path), with a new name each time:
 * the server deletes the old file after a replace, so the new one never shares
 * its path. The order's API call comes after, with this file.
 */
export async function uploadProof(orderId: string, transactionId: string, file: File): Promise<ProofFile> {
  const extension = file.type === 'application/pdf' ? 'pdf' : (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg'
  const storagePath = `tenants/${session.companyId}/orders/${orderId}/payments/${transactionId}/receipt_${Date.now()}.${extension}`
  const [storage, { ref, uploadBytes, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  const target = ref(storage, storagePath)
  await uploadBytes(target, file, { contentType: file.type })
  return { url: await getDownloadURL(target), storagePath, fileName: file.name.slice(0, 256), contentType: file.type }
}

/** The file just uploaded, when the API refused it: never left behind (a failure here is only logged). */
export async function dropUpload(storagePath: string): Promise<void> {
  try {
    const [storage, { ref, deleteObject }] = await Promise.all([storageClient(), import('firebase/storage')])
    await deleteObject(ref(storage, storagePath))
  } catch (error) {
    console.warn('proof: upload not removed', error)
  }
}

/** Attaches or replaces the proof of a payment; the server deletes the old file. */
export function setProof(orderId: string, transactionId: string, receiptFile: ProofFile) {
  return api<OrderResponse>(`${order(orderId)}/payments/${encodeURIComponent(transactionId)}/receipt`, { method: 'PUT', body: { receiptFile } })
}

export function removeProof(orderId: string, transactionId: string) {
  return api<OrderResponse>(`${order(orderId)}/payments/${encodeURIComponent(transactionId)}/receipt`, { method: 'DELETE' })
}

/** Manual payments and discounts leave; the Asaas ones stay. */
export const resetPayments = (orderId: string) => api<OrderResponse>(`${order(orderId)}/payments/reset`, { method: 'POST', body: {} })

// ---------------------------------------------------------------------------
// One customer, several orders
// ---------------------------------------------------------------------------

export const openOrders = (customerId: string) => api<OpenOrder[]>(`${customer(customerId)}/open-orders`)

export function registerReceipt(
  customerId: string,
  body: { receiptId: string; paidAt: string; allocations: { orderId: string; amount: number }[]; paymentMethod?: string },
) {
  return api<{ receiptId: string; amount: number }>(`${customer(customerId)}/receipts`, { method: 'POST', body })
}

export interface Receipt {
  id: string
  amount: number
  paidAt?: string
  paymentMethod?: string
  allocations: { orderId: string; orderNumber?: number | null; amount: number }[]
  status: 'active' | 'canceled'
  createdAt?: string
  createdBy?: { id?: string; name?: string }
  customer?: { id: string; name?: string | null }
  receiptFile?: { url?: string }
}

export const listReceipts = (customerId: string) => api<Receipt[]>(`${customer(customerId)}/receipts`)

export const cancelReceipt = (customerId: string, receiptId: string) =>
  api<Receipt>(`${customer(customerId)}/receipts/${encodeURIComponent(receiptId)}/cancel`, { method: 'POST', body: {} })

// ---------------------------------------------------------------------------
// Charges (Asaas)
// ---------------------------------------------------------------------------

export interface ChargeInput {
  value: number
  mode: 'single' | 'cardInstallments'
  installmentCount?: number
  dueDate?: string
  customerTaxId?: string
}

export const createOrderCharge = (orderId: string, body: ChargeInput) =>
  api<Record<string, unknown>>(`${order(orderId)}/charges`, { method: 'POST', body })

export const cancelOrderCharge = (orderId: string, chargeId: string) =>
  api<unknown>(`${order(orderId)}/charges/${encodeURIComponent(chargeId)}`, { method: 'DELETE' })

export const createCustomerCharge = (customerId: string, body: { orderIds: string[]; value: number; dueDate?: string; customerTaxId?: string }) =>
  api<Record<string, unknown>>(`${customer(customerId)}/charges`, { method: 'POST', body })

export const cancelCustomerCharge = (customerId: string, chargeId: string) =>
  api<unknown>(`${customer(customerId)}/charges/${encodeURIComponent(chargeId)}`, { method: 'DELETE' })

/** What to say when a charge is refused (the order screen and the batch say the same). */
export function chargeErrorKey(error: unknown): MessageKey {
  if (!(error instanceof ApiError)) return 'web.error.generic' as const
  if (error.code === 'TAX_ID_REQUIRED' || error.code === 'INVALID_TAX_ID') return 'web.charge.taxIdInvalid' as const
  if (error.code === 'ASAAS_NOT_CONNECTED' || error.code === 'ASAAS_NOT_ENABLED') return 'web.charge.notConnected' as const
  if (error.code === 'CUSTOMER_REQUIRED') return 'web.charge.noCustomer' as const
  if (error.code === 'INSTALLMENTS_IN_PROGRESS' || error.code === 'CHARGE_SUPERSEDED' || error.code === 'PREVIOUS_LINK_CANCELED') return 'web.charge.tryAgainLink' as const
  if (error.code === 'INVALID_VALUE' || error.code === 'VALUE_EXCEEDS_BALANCE') return 'web.error.paymentExceeds' as const
  return errorMessageKey(error)
}

export interface PaymentSettings {
  /** Pilot on for the company and an account connected. */
  ready: boolean
  /** Notas fiscais on for the company (nfseEnabled with Asaas connected, docs/NFSE_ASAAS.md). */
  nfse: boolean
  /** The nota setup is done (nfseReady): it can be issued. */
  nfseReady: boolean
  /**
   * The nota goes by our own engine (settings/payments.nfseDirectEnabled,
   * docs/NFSE_DIRECT.md): `nfse` is on without Asaas and `nfseReady` means the
   * company has a CNPJ to issue by. Absent when off.
   */
  nfseDirect?: boolean
}

/** Tries before giving up on a Firestore read of this screen, and the wait between them. */
export interface ReadRetry {
  retries?: number
  wait?: number
}
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

/**
 * settings/payments (members read): charges only with the pilot on and the
 * account connected. A read that fails once is tried again: reading it as "off"
 * hides an open link (CI of #520).
 */
export async function paymentSettings({ retries = 2, wait = 800 }: ReadRetry = {}): Promise<PaymentSettings> {
  for (let attempt = 0; ; attempt++) {
    try {
      // REST build: the full client's getDoc waits on the live channel, which can stall (CI of #521, R4).
      const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
      const snap = await getDoc(doc(db, 'companies', session.companyId as string, 'settings', 'payments'))
      const data = (snap.data() ?? {}) as Record<string, unknown>
      const ready = data.asaasEnabled === true && data.asaasConnected === true
      if (data.nfseDirectEnabled === true) {
        const { collection, getDocs, limit, query } = await import('firebase/firestore/lite')
        const emitters = await getDocs(query(collection(db, 'companies', session.companyId as string, 'fiscalEmitters'), limit(1))).catch(() => null)
        return { ready, nfse: true, nfseReady: !!emitters && !emitters.empty, nfseDirect: true }
      }
      return { ready, nfse: ready && data.nfseEnabled === true, nfseReady: ready && data.nfseEnabled === true && data.nfseReady === true }
    } catch (error) {
      if (attempt < retries) {
        await sleep(wait)
        continue
      }
      // The app hides the section on a read error (ASAAS_INTEGRATION).
      console.warn('receive: payment settings not read', error)
      return { ready: false, nfse: false, nfseReady: false }
    }
  }
}

/** How long the live channel may stay silent before the charges are read once instead (as watchOrder, B6). */
export const CHARGES_LIVE_TIMEOUT_MS = 4000

export interface ChargesWatch extends ReadRetry {
  /**
   * Neither the channel nor the REST read answered: the screen does not know
   * whether there is an open link, so it shows the error and never offers
   * Receber in blue (M1 of #518). Never an empty list instead.
   */
  onFailed?: () => void
}

/**
 * Charges of one order, live (owner, admin, manager and the consultant read
 * them, #514). A listener that fails is opened again a few times; only then
 * the screen hears `onFailed` (an open link that does not show lets someone
 * receive in blue over it: CI of #520, R4).
 *
 * The server's answer is what counts. A copy from this browser's cache shows
 * at once when it has charges, but only an answer from the server stops the
 * REST read; an empty cached copy is not "no charge". If the server says
 * nothing in CHARGES_LIVE_TIMEOUT_MS (a stalled channel was the R4 failure in
 * CI), the charges are read once through the REST build, and the channel keeps trying.
 */
export async function watchOrderCharges(
  orderId: string,
  onCharges: (charges: Charge[]) => void,
  { retries = 3, wait = 800, onFailed = () => undefined }: ChargesWatch = {},
): Promise<() => void> {
  const [db, { collection, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const path = ['companies', session.companyId as string, 'orders', orderId, 'charges'] as const
  const ref = collection(db, ...path)
  let stopped = false
  /** The server answered, through the channel or the REST read. */
  let known = false
  let fromServer = false
  let stop: () => void = () => undefined
  let timer: ReturnType<typeof setTimeout> | undefined
  const fallback = setTimeout(async () => {
    if (stopped || fromServer) return
    try {
      const [lite, { collection: liteCollection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
      const snap = await getDocs(liteCollection(lite, ...path))
      if (stopped || fromServer) return
      known = true
      onCharges(snap.docs.map((d) => chargeOf(d.id, d.data())))
    } catch (error) {
      console.warn('receive: charges not read', error)
      if (!stopped && !known) onFailed()
    }
  }, CHARGES_LIVE_TIMEOUT_MS)
  const listen = (attempt: number) => {
    stop = onSnapshot(
      ref,
      (snap) => {
        const cached = !!snap.metadata?.fromCache
        if (cached && !snap.docs.length) return
        if (!cached) {
          fromServer = true
          known = true
          clearTimeout(fallback)
        }
        onCharges(snap.docs.map((d) => chargeOf(d.id, d.data())))
      },
      (error) => {
        if (stopped) return
        if (attempt < retries) {
          timer = setTimeout(() => !stopped && listen(attempt + 1), wait)
          return
        }
        console.warn('receive: charges not read', error)
        clearTimeout(fallback)
        if (!known) onFailed()
      },
    )
  }
  listen(0)
  return () => {
    stopped = true
    clearTimeout(timer)
    clearTimeout(fallback)
    stop()
  }
}

/** Charges over several orders of a customer (one equality filter, no index). */
export async function customerCharges(customerId: string): Promise<Charge[]> {
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(query(collection(db, 'companies', session.companyId as string, 'customerCharges'), where('customer.id', '==', customerId)))
  return snap.docs.map((d) => chargeOf(d.id, d.data()))
}

/** Full orders for printing several at once: Firestore for who sees values, the API projection otherwise. */
export async function ordersForPrint(ids: readonly string[], showsMoney: boolean): Promise<Order[]> {
  if (!showsMoney) {
    const rows = await Promise.all(ids.map((id) => api<Record<string, unknown>>(order(id))))
    return rows.map((raw, i) => normalizeOrder(ids[i] as string, raw, false))
  }
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snaps = await Promise.all(ids.map((id) => getDoc(doc(db, 'companies', session.companyId as string, 'orders', id))))
  return snaps.filter((s) => s.exists()).map((s) => normalizeOrder(s.id, s.data() as Record<string, unknown>, true))
}
