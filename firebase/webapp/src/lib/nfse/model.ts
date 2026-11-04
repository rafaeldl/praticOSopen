// Notas fiscais (NFS-e through Asaas, docs/NFSE_ASAAS.md). Pure rules, the same
// as lib/models/nfse.dart: which notas the month shows, what needs attention,
// what counts as issued, search and what blocks issuing. No Vue, no Firebase.

export type NfseStatus =
  | 'creating'
  | 'scheduled'
  | 'synchronized'
  | 'authorized'
  | 'processingCancellation'
  | 'cancellationDenied'
  | 'canceled'
  | 'error'

const STATUSES: NfseStatus[] = ['creating', 'scheduled', 'synchronized', 'authorized', 'processingCancellation', 'cancellationDenied', 'canceled', 'error']

export interface NfseInvoice {
  id: string
  status: NfseStatus
  customerId: string | null
  customerName: string | null
  orderIds: string[]
  orders: { orderId: string; orderNumber: number | null; value: number }[]
  value: number
  serviceDescription: string | null
  /** Day the nota is issued, YYYY-MM-DD. */
  effectiveDate: string | null
  number: string | null
  pdfUrl: string | null
  xmlUrl: string | null
  statusDescription: string | null
  errorCode: string | null
  auto: boolean
  createdAt: number | null
  conflict: boolean
}

const str = (value: unknown): string | null => (typeof value === 'string' && value ? value : null)
const num = (value: unknown): number => (typeof value === 'number' && Number.isFinite(value) ? value : 0)

function millis(value: unknown): number | null {
  if (typeof value === 'string') {
    const time = Date.parse(value)
    return Number.isNaN(time) ? null : time
  }
  const ts = value as { toMillis?: () => number; seconds?: number } | null
  if (ts && typeof ts.toMillis === 'function') return ts.toMillis()
  if (ts && typeof ts.seconds === 'number') return ts.seconds * 1000
  return null
}

/** Only https links leave the screen as links (the server writes Asaas's). */
export function safeHttps(value: unknown): string | null {
  const text = str(value)
  if (!text) return null
  try {
    return new URL(text).protocol === 'https:' ? text : null
  } catch {
    return null
  }
}

export function invoiceOf(id: string, data: Record<string, unknown>): NfseInvoice {
  const customer = (data.customer ?? {}) as Record<string, unknown>
  const status = STATUSES.includes(data.status as NfseStatus) ? (data.status as NfseStatus) : 'creating'
  return {
    id,
    status,
    customerId: str(customer.id),
    customerName: str(customer.name),
    orderIds: Array.isArray(data.orderIds) ? data.orderIds.filter((o): o is string => typeof o === 'string') : [],
    orders: Array.isArray(data.orders)
      ? data.orders
          .filter((o): o is Record<string, unknown> => !!o && typeof o === 'object')
          .map((o) => ({
            orderId: str(o.orderId) ?? str(o.id) ?? '',
            orderNumber: typeof o.orderNumber === 'number' ? o.orderNumber : typeof o.number === 'number' ? o.number : null,
            value: num(o.value),
          }))
      : [],
    value: num(data.value),
    serviceDescription: str(data.serviceDescription),
    effectiveDate: str(data.effectiveDate),
    number: str(data.number),
    pdfUrl: safeHttps(data.pdfUrl),
    xmlUrl: safeHttps(data.xmlUrl),
    statusDescription: str(data.statusDescription),
    errorCode: str(data.errorCode),
    auto: data.auto === true,
    createdAt: millis(data.createdAt),
    conflict: data.conflict === true,
  }
}

/** A `creating` nota older than this never reached Asaas. */
export const STALE_CREATING_MS = 15 * 60 * 1000

/** Blocks a second nota for its orders. */
export function isActive(invoice: NfseInvoice, now = Date.now()): boolean {
  if (invoice.conflict || invoice.status === 'canceled' || invoice.status === 'error') return false
  if (invoice.status === 'creating' && invoice.createdAt !== null && now - invoice.createdAt > STALE_CREATING_MS) return false
  return true
}

/** Issued and still valid: counts in the month. */
export const isIssued = (invoice: NfseInvoice): boolean =>
  !invoice.conflict && (invoice.status === 'authorized' || invoice.status === 'cancellationDenied')

export const canCancel = (invoice: NfseInvoice): boolean =>
  invoice.status === 'scheduled' || invoice.status === 'authorized' || invoice.status === 'cancellationDenied'

/** "Corrigir e emitir": a refused nota of ours, with its orders. */
export const canFix = (invoice: NfseInvoice): boolean => invoice.status === 'error' && !invoice.conflict && invoice.orderIds.length > 0

export const orderNumbers = (invoice: NfseInvoice): string =>
  invoice.orders.map((o) => o.orderNumber).filter((n): n is number => n !== null).join(', ')

const monthOf = (day: string) => day.slice(0, 7)

function previousMonth(today: string): string {
  const [y, m] = today.split('-').map(Number) as [number, number]
  return new Date(Date.UTC(y, m - 2, 1)).toISOString().slice(0, 7)
}

/** First day read for `month`: that month, or the month before today when earlier. */
export function querySince(month: string, today: string): string {
  const previous = previousMonth(today)
  return `${month < previous ? month : previous}-01`
}

/** Last day read for `month`: its last day (the app had no upper limit, D12). */
export function queryUntil(month: string): string {
  const [y, m] = month.split('-').map(Number) as [number, number]
  return new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10)
}

export interface MonthList {
  attention: NfseInvoice[]
  rows: NfseInvoice[]
  issuedCount: number
  issuedTotal: number
}

/**
 * The notas of `month` (YYYY-MM) as the list shows them. A refused nota whose
 * orders all have an active nota again is hidden; a stale `creating` too.
 * Problems from the month before today on stay on top whatever month is open.
 */
export function monthList(invoices: NfseInvoice[], month: string, today: string, now = Date.now()): MonthList {
  const attentionSince = previousMonth(today)
  const covered = new Set(invoices.filter((i) => isActive(i, now)).flatMap((i) => i.orderIds))
  const reissued = (i: NfseInvoice) => i.orderIds.length > 0 && i.orderIds.every((id) => covered.has(id))
  const problem = (i: NfseInvoice) => i.conflict || i.status === 'cancellationDenied' || (i.status === 'error' && !reissued(i))
  const newestFirst = [...invoices].sort(
    (a, b) => (b.effectiveDate ?? '').localeCompare(a.effectiveDate ?? '') || (b.createdAt ?? 0) - (a.createdAt ?? 0),
  )
  const attention: NfseInvoice[] = []
  const rows: NfseInvoice[] = []
  let issuedCount = 0
  let cents = 0
  for (const invoice of newestFirst) {
    const day = invoice.effectiveDate
    if (!day) continue
    const inMonth = monthOf(day) === month
    if (inMonth && isIssued(invoice)) {
      issuedCount++
      cents += Math.round(invoice.value * 100)
    }
    if (problem(invoice)) {
      if (monthOf(day) >= attentionSince) attention.push(invoice)
      continue
    }
    if (!inMonth || invoice.status === 'error') continue
    if (invoice.status === 'creating' && !isActive(invoice, now)) continue
    rows.push(invoice)
  }
  return { attention, rows, issuedCount, issuedTotal: cents / 100 }
}

const plain = (text: string) =>
  text
    .toLocaleLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')

/** Customer, nota number or an order number; accents and case do not matter. */
export function matches(invoice: NfseInvoice, query: string): boolean {
  const term = plain(query.trim())
  if (!term) return true
  return (
    plain(invoice.customerName ?? '').includes(term) ||
    (invoice.number ?? '').includes(term) ||
    invoice.orders.some((o) => String(o.orderNumber ?? '').includes(term))
  )
}

/** The search shows only with more than this many notas (the app's rule). */
export const SEARCH_FROM = 10

// ---------------------------------------------------------------------------
// Issuing
// ---------------------------------------------------------------------------

export type CustomerField = 'email' | 'postalCode' | 'address' | 'addressNumber' | 'province'
export interface Contact {
  email?: string | null
  postalCode?: string | null
  address?: string | null
  addressNumber?: string | null
  complement?: string | null
  province?: string | null
}

export interface Preview {
  value: number
  orders: { orderId: string; orderNumber: number | null; value: number; servicesTotal: number; productsTotal: number; discount: number }[]
  hasProducts: boolean
  serviceDescription: string
  effectiveDate: string
  customer: { id: string; name: string | null; hasTaxId: boolean; contact: Contact; missingData: CustomerField[] }
  invoicedOrders: Record<string, string>
  municipalServiceName: string
}

export type Blocker = { kind: 'invoiced'; numbers: string } | { kind: 'zero' } | { kind: 'taxId' } | { kind: 'contact' }

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

/** CPF or CNPJ (also alphanumeric) in the shape the server normalizes: digits and capital letters. */
export const normalizeTaxId = (value: string): string => value.toUpperCase().replace(/[^0-9A-Z]/g, '')

export interface IssueForm {
  taxId: string
  contact: Contact
  /** Fields the sheet asks for: the missing ones, or all of them after a refusal about the customer. */
  asking: CustomerField[]
}

/**
 * What keeps "Emitir" grey, the first reason first (nfse_issue_sheet.dart):
 * an order already has a nota, nothing to bill, no CPF/CNPJ, missing contact.
 * `validTaxId` comes from lib/tax-id.ts (the same contract as the app).
 */
export function blockerOf(preview: Preview, form: IssueForm, validTaxId: (value: string) => boolean): Blocker | null {
  const invoiced = preview.orders.filter((o) => preview.invoicedOrders[o.orderId])
  if (invoiced.length) return { kind: 'invoiced', numbers: invoiced.map((o) => o.orderNumber ?? '').join(', ') }
  if (preview.value <= 0) return { kind: 'zero' }
  if (!preview.customer.hasTaxId && !validTaxId(normalizeTaxId(form.taxId))) return { kind: 'taxId' }
  const c = form.contact
  for (const field of form.asking) {
    if (field === 'email' && !EMAIL.test((c.email ?? '').trim())) return { kind: 'contact' }
    if (field === 'postalCode' && (c.postalCode ?? '').replace(/\D/g, '').length !== 8) return { kind: 'contact' }
    if ((field === 'address' || field === 'addressNumber' || field === 'province') && !(c[field] ?? '').trim()) return { kind: 'contact' }
  }
  return null
}

/** Asking for any part of the address asks for all of it (the city needs the whole). */
export function askedFields(missing: CustomerField[]): CustomerField[] {
  const address: CustomerField[] = ['postalCode', 'address', 'addressNumber', 'province']
  const asksAddress = missing.some((field) => address.includes(field))
  return [...(missing.includes('email') ? (['email'] as CustomerField[]) : []), ...(asksAddress ? address : [])]
}

export const ALL_FIELDS: CustomerField[] = ['email', 'postalCode', 'address', 'addressNumber', 'province']

/** Errors that the configuration fixes: the owner can open it in the app. */
export const SETUP_ERRORS = new Set(['NFSE_SETUP_REJECTED', 'NFSE_NOT_READY', 'NFSE_SETUP_NEEDED', 'NFSE_RECONNECT_NEEDED'])

// ---------------------------------------------------------------------------
// The nota of an order and of a customer (order.nfse.*, nfse.orders.pick)
// ---------------------------------------------------------------------------

/** The nota that stands for an order: the newest active one, else the newest (never a stale "creating"). The app's currentInvoiceOf. */
export function currentInvoiceOf(invoices: NfseInvoice[], now = Date.now()): NfseInvoice | null {
  if (!invoices.length) return null
  const sorted = [...invoices].sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0))
  const active = sorted.find((invoice) => isActive(invoice, now))
  if (active) return active
  const latest = sorted[0] as NfseInvoice
  return latest.status === 'creating' ? null : latest
}

export interface NfseOrderLike {
  status: string
  discount?: number
  lines: { kind: 'service' | 'product'; value?: number | null; quantity?: number; total?: number | null }[]
}

/** The services' part of the order after its share of the discount (the app's nfseValueOfOrder): products never go in a nota. */
export function nfseValueOf(order: NfseOrderLike): number {
  const services = order.lines.filter((l) => l.kind === 'service').reduce((sum, l) => sum + (l.value ?? 0), 0)
  const products = order.lines.filter((l) => l.kind === 'product' && l.value !== null && l.value !== undefined).reduce((sum, l) => sum + (l.total ?? (l.value as number) * (l.quantity ?? 1)), 0)
  const gross = services + products
  const discount = Math.min(Math.max(order.discount ?? 0, 0), Math.max(gross, 0))
  const share = gross > 0 ? services / gross : 0
  const value = services - discount * share
  return value <= 0 ? 0 : Math.round(value * 100) / 100
}

/** Not a quote, not canceled, with services of some value (orderCanHaveNfse). */
export const canHaveNfse = (order: NfseOrderLike): boolean => order.status !== 'quote' && order.status !== 'canceled' && nfseValueOf(order) > 0

/**
 * The blue step of a finished, paid order (order.nfse.next-step): issue, or
 * "Corrigir e emitir" after a refused nota. Nothing with an active nota, after
 * one canceled on purpose, or before the setup is done.
 */
export function nfseNextStep(order: NfseOrderLike, current: NfseInvoice | null, ready: boolean, remaining: number, now = Date.now()): 'issue' | 'fix' | null {
  if (!ready || order.status !== 'done' || remaining > 0 || !canHaveNfse(order)) return null
  if (!current) return 'issue'
  if (isActive(current, now)) return null
  return current.status === 'error' ? 'fix' : null
}

/** Orders that may go in a nota now: can have one and no active nota (nfse.orders.pick). */
export function eligibleOrderIds(orders: { id: string; order: NfseOrderLike }[], invoices: NfseInvoice[], now = Date.now()): string[] {
  const taken = new Set(invoices.filter((invoice) => isActive(invoice, now)).flatMap((invoice) => invoice.orderIds))
  return orders.filter(({ id, order }) => canHaveNfse(order) && !taken.has(id)).map(({ id }) => id)
}

// ---------------------------------------------------------------------------
// Setup (nfse.setup.*): GET /v1/app/nfse/setup and what it says is missing
// ---------------------------------------------------------------------------

export type SetupMissing = 'fiscalInfo' | 'cityAccess' | 'service'
export type AutoIssue = 'manual' | 'paid' | 'completed'
export interface FiscalInfo {
  email?: string | null
  municipalInscription?: string | null
  simplesNacional?: boolean | null
  cnae?: string | null
  specialTaxRegime?: string | null
  serviceListItem?: string | null
}
export interface CityOptions {
  authenticationType?: string | null
  supportsCancellation?: boolean | null
  usesSpecialTaxRegimes?: boolean | null
  usesServiceListItem?: boolean | null
  specialTaxRegimesList?: { label: string; value: string }[] | null
}
export interface Taxes {
  retainIss: boolean
  iss: number
  pis: number
  cofins: number
  csll: number
  inss: number
  ir: number
}
export interface ServiceSettings {
  municipalServiceId?: string | null
  municipalServiceCode?: string | null
  municipalServiceName: string
  taxes: Taxes
  descriptionTemplate: string
  autoIssue?: AutoIssue
}
export interface NfseSetup {
  ready: boolean
  missing: SetupMissing[]
  fiscalInfo: FiscalInfo | null
  municipalOptions: CityOptions | null
  service: ServiceSettings | null
}
export interface MunicipalService {
  id: string
  description: string
  issTax?: number | null
}

/** The server's default text of a nota (DEFAULT_DESCRIPTION_TEMPLATE): an empty field goes back to it. */
export const DEFAULT_TEMPLATE = '{servicos}'

/** What the blue button opens: fiscal info, then the Asaas panel (city access), then the service. */
export function nextSetupStep(missing: SetupMissing[]): SetupMissing | null {
  for (const step of ['fiscalInfo', 'cityAccess', 'service'] as const) if (missing.includes(step)) return step
  return null
}

/** Which sentence explains the city access (the app's _cityAccessText). */
export function cityAccessKind(setup: Pick<NfseSetup, 'fiscalInfo' | 'municipalOptions'>): 'first' | 'certificate' | 'token' | 'password' | 'none' {
  if (!setup.fiscalInfo) return 'first'
  switch (setup.municipalOptions?.authenticationType) {
    case 'CERTIFICATE':
      return 'certificate'
    case 'TOKEN':
      return 'token'
    case 'USER_AND_PASSWORD':
      return 'password'
    default:
      return 'none'
  }
}

/** A percent typed with comma or point ("2,5", "2.5 %"); invalid or empty is 0, kept between 0 and 100. */
export function parsePercent(text: string): number {
  const value = Number.parseFloat(text.trim().replace('%', '').replace(',', '.'))
  if (!Number.isFinite(value)) return 0
  return Math.min(100, Math.max(0, value))
}

export const isEmail = (text: string): boolean => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(text.trim())
