// Notas fiscais: the list is read from Firestore (the server writes it; the
// rules let owner, admin and manager read it), the rest goes through the API
// routes the app already uses (/v1/app/nfse/*). Nothing here issues a nota by itself.
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import { normalizeOrder, type Order } from '@/lib/orders/model'
import { ordersPage, type OrderRow } from '@/lib/orders-query'
import { recordNfseAvailability } from './availability'
import { invoiceOf, queryUntil, querySince, type Contact, type FiscalInfo, type MunicipalService, type NfseInvoice, type NfseSetup, type Preview, type ServiceSettings } from './model'

export interface NfseSettings {
  /** nfseEnabled, Asaas on and connected: the notas exist for this company. */
  available: boolean
  /** The configuration is done: a nota can be issued. */
  ready: boolean
  /** The Asaas account is the sandbox (its panel is another address). */
  sandbox?: boolean
  /**
   * settings/payments.nfseDirectEnabled: the nota goes by our own engine
   * (docs/NFSE_DIRECT.md) and the Asaas nota stays hidden (spec decision 1).
   * `ready` then means the company has a CNPJ to issue by.
   */
  direct?: boolean
}

/** settings/payments (members read it). A failed read is an error, never "off" (D23 shows nothing forever). */
export async function nfseSettings(): Promise<NfseSettings> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const companyId = session.companyId as string
  const snap = await getDoc(doc(db, 'companies', companyId, 'settings', 'payments'))
  const data = (snap.data() ?? {}) as Record<string, unknown>
  if (data.nfseDirectEnabled === true) {
    recordNfseAvailability(companyId, true)
    return { available: true, ready: await hasEmitter(), direct: true }
  }
  const available = data.nfseEnabled === true && data.asaasEnabled === true && data.asaasConnected === true
  recordNfseAvailability(companyId, available)
  return { available, ready: available && data.nfseReady === true, sandbox: data.asaasEnvironment === 'sandbox' }
}

/** The company has at least one CNPJ (fiscalEmitters: owner, admin and manager read it). */
export async function hasEmitter(): Promise<boolean> {
  const [db, { collection, getDocs, limit, query }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(query(collection(db, 'companies', session.companyId as string, 'fiscalEmitters'), limit(1)))
  return !snap.empty
}

/**
 * The notas `month` (YYYY-MM) needs: from that month, or the month before
 * today when earlier (attention), until the month's last day. One range on
 * effectiveDate: the automatic single-field index, no composite.
 */
export async function monthInvoices(month: string, today: string): Promise<NfseInvoice[]> {
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const ref = collection(db, 'companies', session.companyId as string, 'invoices')
  const snap = await getDocs(
    query(ref, where('effectiveDate', '>=', querySince(month, today)), where('effectiveDate', '<=', queryUntil(month))),
  )
  return snap.docs.map((d) => invoiceOf(d.id, d.data()))
}

/** One nota, live (the webhook changes its status while it is open). */
export async function watchInvoice(id: string, onInvoice: (invoice: NfseInvoice | null) => void, onError: () => void): Promise<() => void> {
  const [db, { doc, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return onSnapshot(
    doc(db, 'companies', session.companyId as string, 'invoices', id),
    (snap) => onInvoice(snap.exists() ? invoiceOf(snap.id, snap.data() as Record<string, unknown>) : null),
    () => onError(),
  )
}

export const previewInvoice = (orderIds: string[], customerId?: string | null) =>
  api<Preview>('/v1/app/nfse/invoices/preview', { method: 'POST', body: { orderIds, ...(customerId ? { customerId } : {}) } })

export interface IssueInput {
  orderIds: string[]
  customerId?: string | null
  serviceDescription?: string
  /** Today goes as nothing: the server issues at once (the app does the same). */
  effectiveDate?: string | null
  customerTaxId?: string
  customerData?: Contact
}

export function issueInvoice(input: IssueInput) {
  const { customerId, effectiveDate, ...rest } = input
  return api<Record<string, unknown>>('/v1/app/nfse/invoices', {
    method: 'POST',
    body: { ...rest, ...(customerId ? { customerId } : {}), ...(effectiveDate ? { effectiveDate } : {}) },
  })
}

export const cancelInvoice = (id: string, onlyOnAsaas = false) =>
  api<Record<string, unknown>>(`/v1/app/nfse/invoices/${encodeURIComponent(id)}/cancel`, { method: 'POST', body: onlyOnAsaas ? { onlyOnAsaas: true } : {} })

/**
 * The notas of an order (orderIds array-contains) or of a customer, live: the
 * webhook changes them while the screen is open. Single-field filters only
 * (automatic indexes, as the app's nfse_invoice_repository).
 */
export async function watchInvoicesOf(
  scope: { orderId: string } | { customerId: string },
  onInvoices: (invoices: NfseInvoice[]) => void,
  onError: () => void,
): Promise<() => void> {
  const [db, { collection, onSnapshot, query, where }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const ref = collection(db, 'companies', session.companyId as string, 'invoices')
  const filter = 'orderId' in scope ? where('orderIds', 'array-contains', scope.orderId) : where('customer.id', '==', scope.customerId)
  return onSnapshot(
    query(ref, filter),
    (snap) => onInvoices(snap.docs.map((d) => invoiceOf(d.id, d.data() as Record<string, unknown>))),
    () => onError(),
  )
}

/** The notas of one customer, once (the list "Notas de X"). */
export async function customerInvoices(customerId: string): Promise<NfseInvoice[]> {
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(query(collection(db, 'companies', session.companyId as string, 'invoices'), where('customer.id', '==', customerId)))
  return snap.docs.map((d) => invoiceOf(d.id, d.data()))
}

// Setup (owner and admin only; the server says 403 to anyone else).
export const nfseSetup = () => api<NfseSetup>('/v1/app/nfse/setup')
export const saveFiscalInfo = (body: Required<Pick<FiscalInfo, 'email'>> & { simplesNacional: boolean; municipalInscription?: string; cnae?: string; specialTaxRegime?: string; serviceListItem?: string }) =>
  api<NfseSetup>('/v1/app/nfse/setup/fiscal-info', { method: 'POST', body })
export const municipalServices = (q: string) => api<MunicipalService[]>(`/v1/app/nfse/setup/municipal-services?q=${encodeURIComponent(q.slice(0, 100))}`)
export const saveService = (body: ServiceSettings) => api<NfseSetup>('/v1/app/nfse/setup/service', { method: 'PUT', body })

/** Orders read per page for "várias OS": a customer can have thousands, the nota takes the recent ones. */
export const NFSE_ORDERS_PAGE = 50

export interface NfseOrdersPage {
  orders: { id: string; number?: number; createdAt?: string | null; order: Order }[]
  /** Cursor for the next page (the last raw row read). */
  last: OrderRow | null
  /** The page came full: there may be older orders. */
  hasMore: boolean
}

/**
 * The customer's orders with their lines, for "várias OS" (nfse.orders.pick),
 * newest first, one page at a time (pass the previous page's `last` for the
 * next): eligibility is the services' value, as the app (B7). Read by who
 * issues (chargeOrder: owner, admin, manager), who see values.
 */
export async function customerOrdersForNfse(customerId: string, after?: OrderRow | null, size = NFSE_ORDERS_PAGE): Promise<NfseOrdersPage> {
  const rows = await ordersPage({ companyId: session.companyId as string, createdBy: null, where: [['customer.id', '==', customerId]] }, size, after ?? undefined)
  const orders = rows.map((row) => {
    const order = normalizeOrder(row.id, row, true)
    return { id: row.id, number: order.number, createdAt: order.createdAt, order }
  })
  return { orders, last: rows.at(-1) ?? null, hasMore: rows.length === size }
}

/** CNPJs set up for the nota (fiscalEmitters: owner, admin and manager read it), for the Plan screen (#725). */
export async function countEmitters(): Promise<number> {
  const [db, { collection, getCount }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getCount(collection(db, 'companies', session.companyId as string, 'fiscalEmitters'))
  return snap.data().count
}
