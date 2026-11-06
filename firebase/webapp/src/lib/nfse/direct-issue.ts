// Issuing, canceling and opening a nota of the NFS-e direct (docs/NFSE_DIRECT.md,
// "Motor de emissão"; spec §4.6, §4.7): the nfseApi routes under
// /v1/app/nfse/direct, the files in Storage, and the pure rules of the issue
// sheet (what keeps "Emitir" grey, what each refusal opens, the sentences).
import { t, type MessageKey } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { firestoreLite, storageClient } from '@/lib/firebase'
import { nfseApi, session } from '@/lib/session'
import { formatDate } from '@/lib/format'
import { isValidTaxId, normalizeTaxId } from '@/lib/tax-id'
import { emailDeliveryOf, refusalMessage, refusalOf, type DirectRefusal, type EmailDelivery } from './model'

export type EmitterProblem = 'certificate' | 'certificateExpired' | 'notEnabledInCity' | 'city' | 'service' | 'series' | 'regime'

export interface EmitterSummary {
  id: string
  legalName: string
  taxId: string
  regime: 'mei' | 'simples' | string | null
  /** Why it cannot issue now, or null. */
  problem: EmitterProblem | string | null
  isDefault: boolean
  serviceName: string | null
}

export interface FiscalAddress {
  postalCode?: string | null
  street?: string | null
  number?: string | null
  complement?: string | null
  district?: string | null
  /** IBGE code of the city (7 digits). */
  cityCode?: string | null
  cityName?: string | null
  /** UF, two letters. */
  state?: string | null
}

export type RecipientField = 'taxId' | 'address' | 'email'

export interface DirectPreview {
  value: number
  orders: { orderId: string; orderNumber: number | null; value: number; servicesTotal: number; productsTotal: number; discount: number }[]
  hasProducts: boolean
  description: string
  complementaryInfo: string
  emitter: EmitterSummary
  emitters: EmitterSummary[]
  customer: { id: string; name: string | null }
  recipient: {
    customerId: string
    name: string | null
    legalName: string | null
    taxId: string | null
    address: FiscalAddress | null
    email: string | null
    viaInvoiceRecipient: boolean
  }
  missing: RecipientField[]
  meiWarning: 'none' | 'near' | 'over'
  invoicedOrders: Record<string, string>
  /** settings/nfse.emailToCustomer: the nota goes to the customer's e-mail on its own (issue #611). */
  emailToCustomer?: boolean
}

export interface DirectRecipientInput {
  customerId?: string | null
  taxId?: string | null
  legalName?: string | null
  address?: FiscalAddress | null
  email?: string | null
}

export interface DirectIssueInput {
  orderIds: string[]
  emitterId?: string | null
  description?: string | null
  recipient?: DirectRecipientInput | null
}

const BASE = '/v1/app/nfse/direct'
const path = (id: string, action: string) => `${BASE}/invoices/${encodeURIComponent(id)}/${action}`

export const previewDirect = (input: { orderIds: string[]; emitterId?: string | null; recipientCustomerId?: string | null }) =>
  nfseApi<DirectPreview>(`${BASE}/invoices/preview`, {
    method: 'POST',
    body: {
      orderIds: input.orderIds,
      ...(input.emitterId ? { emitterId: input.emitterId } : {}),
      ...(input.recipientCustomerId ? { recipientCustomerId: input.recipientCustomerId } : {}),
    },
  })

/** Resolves with the nota: `authorized` (201) or `creating` (202: the government has not answered yet). */
export const issueDirect = (input: DirectIssueInput) =>
  nfseApi<{ id: string; status: string; number?: string | null }>(`${BASE}/invoices`, { method: 'POST', body: input })

export type CancelReason = 'issueError' | 'serviceNotProvided'
export const CANCEL_REASONS: readonly CancelReason[] = ['issueError', 'serviceNotProvided']

export const cancelDirect = (id: string, reason: CancelReason) =>
  nfseApi<{ status: string }>(path(id, 'cancel'), { method: 'POST', body: { reason } })

export const reconcileDirect = (id: string) => nfseApi<{ status: string }>(path(id, 'reconcile'), { method: 'POST', body: {} })

/** "Enviar de novo": e-mails the nota (or the cancellation notice) to the customer now. */
export const resendDirectEmail = async (id: string) =>
  emailDeliveryOf((await nfseApi<{ emailDelivery: unknown }>(path(id, 'email'), { method: 'POST', body: {} })).emailDelivery)

/** Under the sheet: whether the nota goes by e-mail. Null when the sheet asks for the e-mail (the field says it). */
export function emailLine(preview: DirectPreview, asking: readonly RecipientField[]): string | null {
  if (preview.emailToCustomer === false) return t('nfseDirectIssueEmailOff')
  if (asking.includes('email') || !preview.recipient.email) return null
  return t('nfseDirectIssueEmailGoesTo', { email: preview.recipient.email })
}

/** "Enviada para fulano@… em 05/11/2026", or why it did not go (same words as the app). */
export function emailDeliveryText(delivery: EmailDelivery | null, country?: string | null): string {
  if (!delivery) return t('nfseEmailNotSentYet')
  const to = delivery.to ?? ''
  const date = delivery.at === null ? '' : formatDate(delivery.at, country)
  if (delivery.status === 'sent') return t(delivery.canceled ? 'nfseEmailCancelSentTo' : 'nfseEmailSentTo', { email: to, date })
  if (delivery.status === 'failed') return t('nfseEmailFailedTo', { email: to, date })
  return t(delivery.reason === 'turnedOff' ? 'nfseEmailSkippedTurnedOff' : 'nfseEmailSkippedNoEmail')
}

/** Makes the PDF (DANFSe) when needed and returns its Storage path. */
export const directPdfPath = async (id: string) => (await nfseApi<{ pdfPath: string }>(path(id, 'pdf'), { method: 'POST', body: {} })).pdfPath

/** A download link for a file of the nota in Storage (members read tenants/{cid}/invoices/). */
export async function storageUrl(storagePath: string): Promise<string> {
  const [storage, { ref, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  return getDownloadURL(ref(storage, storagePath))
}

/** The company's CNPJs, for when the server cannot mark one (several, no default). */
export async function emitterSummaries(): Promise<EmitterSummary[]> {
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'fiscalEmitters'))
  return snap.docs
    .map((d) => {
      const data = d.data() as Record<string, unknown>
      return {
        id: d.id,
        legalName: typeof data.legalName === 'string' ? data.legalName : '',
        taxId: typeof data.taxId === 'string' ? data.taxId : '',
        regime: typeof data.regime === 'string' ? data.regime : null,
        problem: null,
        isDefault: false,
        serviceName: null,
      }
    })
    .sort((a, b) => a.legalName.localeCompare(b.legalName, 'pt-BR'))
}

// ---------------------------------------------------------------------------
// CEP (ViaCEP, as the app's fiscal_lookup_service): fills street, district,
// city, UF and the IBGE code the nota needs.
// ---------------------------------------------------------------------------

export const cepDigits = (value: string | null | undefined) => (value ?? '').replace(/\D/g, '')

export async function lookupPostalCode(cep: string, fetcher: typeof fetch = fetch): Promise<FiscalAddress | null> {
  const digits = cepDigits(cep)
  if (digits.length !== 8) return null
  try {
    const response = await fetcher(`https://viacep.com.br/ws/${digits}/json/`)
    if (!response.ok) return null
    const body = (await response.json()) as Record<string, unknown>
    if (body.erro) return null
    const text = (value: unknown) => (typeof value === 'string' && value.trim() ? value.trim() : null)
    return {
      postalCode: digits,
      street: text(body.logradouro),
      district: text(body.bairro),
      cityName: text(body.localidade),
      state: text(body.uf),
      cityCode: text(body.ibge),
    }
  } catch {
    return null
  }
}

/** What the CEP brought goes only where the field is still empty (never over what was typed). */
export function fillAddress(current: FiscalAddress, found: FiscalAddress): FiscalAddress {
  const next = { ...current }
  for (const [key, value] of Object.entries(found) as [keyof FiscalAddress, string | null][]) {
    if (value && !(next[key] ?? '').toString().trim()) next[key] = value
  }
  // The city's code always follows the CEP: a wrong code sends the nota to another city.
  if (found.cityCode) next.cityCode = found.cityCode
  return next
}

// ---------------------------------------------------------------------------
// The sheet's rules
// ---------------------------------------------------------------------------

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export interface DirectForm {
  /** Fields the sheet shows: the missing ones, or all after a refusal about the customer. */
  asking: RecipientField[]
  taxId: string
  email: string
  address: FiscalAddress
}

export const addressComplete = (a: FiscalAddress): boolean =>
  cepDigits(a.postalCode).length === 8 &&
  !!(a.street ?? '').trim() &&
  !!(a.number ?? '').trim() &&
  !!(a.district ?? '').trim() &&
  /^\d{7}$/.test((a.cityCode ?? '').trim()) &&
  /^[A-Za-z]{2}$/.test((a.state ?? '').trim())

export type DirectBlocker =
  | { kind: 'invoiced'; numbers: string }
  | { kind: 'zero' }
  | { kind: 'emitter'; problem: string }
  | { kind: 'taxId' }
  | { kind: 'address' }
  | { kind: 'email' }

/** What keeps "Emitir" grey, the first reason first. */
export function directBlocker(preview: DirectPreview, form: DirectForm): DirectBlocker | null {
  const invoiced = preview.orders.filter((o) => preview.invoicedOrders[o.orderId])
  if (invoiced.length) return { kind: 'invoiced', numbers: invoiced.map((o) => o.orderNumber ?? '').join(', ') }
  if (preview.value <= 0) return { kind: 'zero' }
  if (preview.emitter.problem) return { kind: 'emitter', problem: preview.emitter.problem }
  if (form.asking.includes('taxId') && !isValidTaxId(normalizeTaxId(form.taxId))) return { kind: 'taxId' }
  if (form.asking.includes('address') && !addressComplete(form.address)) return { kind: 'address' }
  if (form.asking.includes('email') && !EMAIL.test(form.email.trim())) return { kind: 'email' }
  return null
}

const trimmed = (value: string | null | undefined) => {
  const text = (value ?? '').trim()
  return text ? text : null
}

/** The `recipient` of the request: the customer picked for this nota and what was typed. */
export function recipientInput(form: DirectForm, chosenCustomerId: string | null): DirectRecipientInput | null {
  const out: DirectRecipientInput = {}
  if (chosenCustomerId) out.customerId = chosenCustomerId
  if (form.asking.includes('taxId') && trimmed(form.taxId)) out.taxId = normalizeTaxId(form.taxId)
  if (form.asking.includes('email') && trimmed(form.email)) out.email = form.email.trim()
  if (form.asking.includes('address')) {
    const a = form.address
    out.address = {
      postalCode: cepDigits(a.postalCode) || null,
      street: trimmed(a.street),
      number: trimmed(a.number),
      complement: trimmed(a.complement),
      district: trimmed(a.district),
      cityCode: trimmed(a.cityCode),
      cityName: trimmed(a.cityName),
      state: trimmed(a.state)?.toUpperCase() ?? null,
    }
  }
  return Object.keys(out).length ? out : null
}

// ---------------------------------------------------------------------------
// Sentences
// ---------------------------------------------------------------------------

const PROBLEM: Record<EmitterProblem, MessageKey> = {
  certificate: 'web.nfseDirect.problem.certificate',
  certificateExpired: 'web.nfseDirect.problem.certificateExpired',
  notEnabledInCity: 'web.nfseDirect.problem.notEnabledInCity',
  city: 'web.nfseDirect.problem.city',
  service: 'web.nfseDirect.problem.service',
  series: 'web.nfseDirect.problem.series',
  regime: 'web.nfseDirect.problem.regime',
}

/** Why a CNPJ cannot issue now, in plain words. */
export const problemText = (problem: string): string => t(PROBLEM[problem as EmitterProblem] ?? 'web.nfseDirect.problem.other')

export function meiWarningText(warning: DirectPreview['meiWarning']): string | null {
  if (warning === 'near') return t('web.nfseDirect.meiNear')
  if (warning === 'over') return t('web.nfseDirect.meiOver')
  return null
}

/**
 * What the sheet does about a failed issue: the sentence, and what it opens.
 * `fields`: the "Para" fields open (customer data); `setup`: the configuration
 * of the CNPJs helps (owner/admin get the link).
 */
export interface DirectFailure {
  text: string
  detail?: string
  fields?: boolean
  setup?: boolean
  /** The nota of the refusal (for "abrir a nota"). */
  invoiceId?: string
}

export function directFailure(error: unknown, locale: string): DirectFailure {
  if (!(error instanceof ApiError)) return { text: t(errorMessageKey(error)) }
  const details = error.details ?? {}
  switch (error.code) {
    case 'NFSE_REFUSED': {
      const refusal: DirectRefusal | null = refusalOf(details.refusal)
      const invoiceId = typeof details.invoiceId === 'string' ? details.invoiceId : undefined
      if (!refusal) return { text: t('web.nfseDirect.refusedGeneric'), invoiceId }
      const text = refusalMessage(refusal, locale) ?? t('web.nfseDirect.refusedGeneric')
      if (refusal.group === 'customerData') return { text, fields: true, invoiceId }
      if (refusal.group === 'emitterSetup' || refusal.group === 'certificate') return { text, setup: true, invoiceId }
      const detail = refusal.govText && refusal.govText !== text ? refusal.govText : undefined
      return { text: t('web.nfseDirect.refusedOther', { text }), detail, invoiceId }
    }
    case 'EMITTER_NOT_READY':
      return { text: problemText(typeof details.problem === 'string' ? details.problem : ''), setup: true }
    case 'CERT_EXPIRED':
      return { text: problemText('certificateExpired'), setup: true }
    case 'EMITTER_NOT_FOUND':
      return { text: t('web.nfseDirect.noEmitter'), setup: true }
    case 'RECIPIENT_TAX_ID_REQUIRED':
      return { text: t('web.nfseDirect.recipientTaxId'), fields: true }
    case 'ORDER_HAS_INVOICE':
      return { text: t('web.nfseDirect.orderHasInvoice') }
    case 'DAILY_LIMIT_REACHED':
      return { text: t('web.nfseDirect.dailyLimit') }
    case 'FORBIDDEN':
      if (details.reason === 'managerNotAllowed') return { text: t('web.nfseDirect.managerNotAllowed') }
      return { text: t(errorMessageKey(error)) }
    case 'SEFIN_UNAVAILABLE':
      return { text: t('web.nfseDirect.govUnavailable') }
    case 'NFSE_DIRECT_NOT_ENABLED':
      return { text: t('nfseDirectErrorNotEnabled') }
    default:
      return { text: t(errorMessageKey(error)) }
  }
}

/** The sentence after a cancel that did not go. */
export function cancelFailureText(error: unknown, locale: string): string {
  if (error instanceof ApiError) {
    if (error.code === 'CANCEL_REFUSED') {
      if (error.details?.usePortal) return t('web.nfseDirect.cancelPortal')
      const refusal = refusalOf(error.details?.refusal)
      return (refusal && refusalMessage(refusal, locale)) ?? t('web.nfseDirect.cancelPortal')
    }
    if (error.code === 'SEFIN_UNAVAILABLE') return t('web.nfseDirect.govUnavailable')
    if (error.code === 'INVOICE_NOT_CANCELABLE') return t('nfseErrorNotCancelable')
  }
  return t(errorMessageKey(error))
}
