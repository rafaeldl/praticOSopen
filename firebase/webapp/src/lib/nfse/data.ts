// Notas fiscais: the list is read from Firestore (the server writes it; the
// rules let owner, admin and manager read it), the rest goes through the API
// routes the app already uses (/v1/app/nfse/*). Nothing here issues a nota by itself.
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import { invoiceOf, queryUntil, querySince, type Contact, type NfseInvoice, type Preview } from './model'

export interface NfseSettings {
  /** nfseEnabled, Asaas on and connected: the notas exist for this company. */
  available: boolean
  /** The configuration is done: a nota can be issued. */
  ready: boolean
}

/** settings/payments (members read it). A failed read is an error, never "off" (D23 shows nothing forever). */
export async function nfseSettings(): Promise<NfseSettings> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDoc(doc(db, 'companies', session.companyId as string, 'settings', 'payments'))
  const data = (snap.data() ?? {}) as Record<string, unknown>
  const available = data.nfseEnabled === true && data.asaasEnabled === true && data.asaasConnected === true
  return { available, ready: available && data.nfseReady === true }
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
