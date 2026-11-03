// Money and links always through the API (WEB_API.md): payments, receipts,
// charges and the customer link. Firestore only reads what the server writes
// and the rules let this person read (charges, settings/payments, unpaid orders).
import { firestoreClient } from '@/lib/firebase'
import { normalizeOrder, type Order } from '@/lib/orders/model'
import { remainingOnRow } from '@/lib/orders/model'
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

/** settings/payments (members read): charges only with the pilot on and the account connected. */
export async function paymentSettings(): Promise<PaymentSettings> {
  try {
    const [db, { doc, getDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
    const snap = await getDoc(doc(db, 'companies', session.companyId as string, 'settings', 'payments'))
    const data = (snap.data() ?? {}) as Record<string, unknown>
    return { ready: data.asaasEnabled === true && data.asaasConnected === true }
  } catch (error) {
    // The app hides the section on a read error (ASAAS_INTEGRATION).
    console.warn('receive: payment settings not read', error)
    return { ready: false }
  }
}

/** Charges of one order, live (owner, admin, manager and the consultant read them, #514). */
export async function watchOrderCharges(orderId: string, onCharges: (charges: Charge[]) => void): Promise<() => void> {
  const [db, { collection, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return onSnapshot(
    collection(db, 'companies', session.companyId as string, 'orders', orderId, 'charges'),
    (snap) => onCharges(snap.docs.map((d) => chargeOf(d.id, d.data()))),
    (error) => {
      console.warn('receive: charges not read', error)
      onCharges([])
    },
  )
}

/** Charges over several orders of a customer (one equality filter, no index). */
export async function customerCharges(customerId: string): Promise<Charge[]> {
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const snap = await getDocs(query(collection(db, 'companies', session.companyId as string, 'customerCharges'), where('customer.id', '==', customerId)))
  return snap.docs.map((d) => chargeOf(d.id, d.data()))
}

// ---------------------------------------------------------------------------
// Financeiro > Receber
// ---------------------------------------------------------------------------

/**
 * Done orders that still owe, read through `payment == 'unpaid'` (indexed with
 * createdAt, like "Sem receber"), newest 500. Only financial roles reach it, and
 * they read every order.
 */
export async function unpaidDoneOrders(): Promise<{ orders: Order[]; truncated: boolean }> {
  const [db, { collection, getDocs, limit, orderBy, query, where }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const max = 500
  const snap = await getDocs(
    query(collection(db, 'companies', session.companyId as string, 'orders'), where('payment', '==', 'unpaid'), orderBy('createdAt', 'desc'), limit(max)),
  )
  const orders = snap.docs
    .map((d) => normalizeOrder(d.id, d.data(), true))
    .filter((o) => o.status === 'done' && (remainingOnRow(o) ?? 0) > 0)
  return { orders, truncated: snap.docs.length === max }
}

/** Full orders for printing several at once: Firestore for who sees values, the API projection otherwise. */
export async function ordersForPrint(ids: readonly string[], showsMoney: boolean): Promise<Order[]> {
  if (!showsMoney) {
    const rows = await Promise.all(ids.map((id) => api<Record<string, unknown>>(order(id))))
    return rows.map((raw, i) => normalizeOrder(ids[i] as string, raw, false))
  }
  const [db, { doc, getDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const snaps = await Promise.all(ids.map((id) => getDoc(doc(db, 'companies', session.companyId as string, 'orders', id))))
  return snaps.filter((s) => s.exists()).map((s) => normalizeOrder(s.id, s.data() as Record<string, unknown>, true))
}
