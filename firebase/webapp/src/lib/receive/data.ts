// Money and links always through the API (WEB_API.md): payments, receipts,
// charges and the customer link. Firestore only reads what the server writes
// (one-off reads through the REST build, live ones through the full client)
// and the rules let this person read (charges, settings/payments, unpaid orders).
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import { normalizeOrder, type Order } from '@/lib/orders/model'
import { api, session } from '@/lib/session'
import { chargeOf, receivableOf, type Charge, type OpenOrder, type SharePermission, type ShareToken } from './model'

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

export interface PaymentSettings {
  /** Pilot on for the company and an account connected. */
  ready: boolean
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
      return { ready: data.asaasEnabled === true && data.asaasConnected === true }
    } catch (error) {
      if (attempt < retries) {
        await sleep(wait)
        continue
      }
      // The app hides the section on a read error (ASAAS_INTEGRATION).
      console.warn('receive: payment settings not read', error)
      return { ready: false }
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

// ---------------------------------------------------------------------------
// Financeiro > Receber
// ---------------------------------------------------------------------------

/**
 * Every order that still owes (receivableOf: done with a balance, open with a
 * down payment), read through `payment == 'unpaid'` (indexed with createdAt,
 * like "Sem receber") in pages of 500 until the end, so no old debt is cut.
 * Stops at 20.000 orders read and says so (the oldest would be the ones missing). The screen orders them oldest first.
 * Only financial roles reach it, and they read every order.
 */
export async function receivableOrders(): Promise<{ orders: Order[]; truncated: boolean }> {
  const [db, { collection, getDocs, limit, orderBy, query, startAfter, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const PAGE = 500
  const MAX = 20000
  const base = [where('payment', '==', 'unpaid'), orderBy('createdAt', 'desc')] as const
  const orders: Order[] = []
  let last: unknown = null
  let read = 0
  for (;;) {
    const snap = await getDocs(
      query(collection(db, 'companies', session.companyId as string, 'orders'), ...base, ...(last ? [startAfter(last)] : []), limit(PAGE)),
    )
    read += snap.docs.length
    for (const d of snap.docs) {
      const order = normalizeOrder(d.id, d.data(), true)
      if (receivableOf(order) !== null) orders.push(order)
    }
    if (snap.docs.length < PAGE) return { orders, truncated: false }
    if (read >= MAX) return { orders, truncated: true }
    last = snap.docs[snap.docs.length - 1]
  }
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
