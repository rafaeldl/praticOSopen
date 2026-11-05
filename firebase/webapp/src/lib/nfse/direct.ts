// NFS-e direct (docs/NFSE_DIRECT.md): the company's fiscal emitters, read live
// from Firestore (written only by the server), and the setup routes of the
// nfseApi. The certificate password goes only in the upload request; nothing
// here keeps it.
import { firestoreClient, firestoreLite } from '@/lib/firebase'
import { nfseApi, session } from '@/lib/session'

export type FiscalRegime = 'mei' | 'simples'
export type CertificateStatus = 'active' | 'pending' | 'expired' | 'deleted'
export type AutoIssue = 'never' | 'selectedCustomers' | 'allOrders'
export const AUTO_ISSUE: readonly AutoIssue[] = ['never', 'selectedCustomers', 'allOrders']

/** Separators the server accepts (DESCRIPTION_SEPARATORS). */
export const SEPARATORS = [', ', ' - ', ' / ', '; '] as const

/** Version of the terms shown; must match NFSE_CERTIFICATE_TERMS_VERSION on the server. */
export const TERMS_VERSION = '2026-11-05'

/** The MEI's annual limit (the server keeps its own copy for the warning). */
export const MEI_LIMIT = 81000

/** Days before the end when the certificate turns amber (the server's first notice). */
export const WARNING_DAYS = 30

/** A .pfx is a few KB; the server takes up to ~64 KB. */
export const MAX_CERTIFICATE_BYTES = 64 * 1024

export interface Emitter {
  id: string
  taxId: string
  legalName: string
  regime: FiscalRegime
  cityName: string
  municipalRegistration: string | null
  enabledInCity: boolean
  service: { nationalCode: string; name: string; issRate: number; municipalCode?: string | null; nbs?: string | null } | null
  descriptionStyle: { uppercase: boolean; separator: string }
  certificate: { notAfter: string | null; uploadedAt: string | null; uploadedBy: string | null; status: CertificateStatus } | null
  totals: { year: number; yearValue: number; month: number; monthValue: number } | null
  /** The last "Importar notas" applied (null: never imported, or undone). */
  importBatchId: string | null
}

export interface DirectSettings {
  defaultEmitterId: string | null
  autoIssue: AutoIssue
}

const text = (value: unknown) => (typeof value === 'string' ? value : null)
const num = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : 0)
const record = (value: unknown) => (value && typeof value === 'object' ? (value as Record<string, unknown>) : null)

export function emitterOf(id: string, data: Record<string, unknown>): Emitter {
  const service = record(data.service)
  const style = record(data.descriptionStyle)
  const cert = record(data.certificate)
  const totals = record(data.totals)
  return {
    id,
    taxId: text(data.taxId) ?? '',
    legalName: text(data.legalName) ?? '',
    regime: data.regime === 'mei' ? 'mei' : 'simples',
    cityName: text(data.cityName) ?? '',
    municipalRegistration: text(data.municipalRegistration),
    enabledInCity: data.enabledInCity === true,
    service: service
      ? {
          nationalCode: text(service.nationalCode) ?? '',
          name: text(service.name) ?? '',
          issRate: num(service.issRate),
          municipalCode: text(service.municipalCode),
          nbs: text(service.nbs),
        }
      : null,
    descriptionStyle: { uppercase: style?.uppercase === true, separator: text(style?.separator) ?? ', ' },
    certificate: cert
      ? {
          notAfter: text(cert.notAfter),
          uploadedAt: text(cert.uploadedAt),
          uploadedBy: text(record(cert.uploadedBy)?.name),
          status: (['active', 'pending', 'expired', 'deleted'] as const).find((s) => s === cert.status) ?? 'deleted',
        }
      : null,
    totals: totals ? { year: num(totals.year), yearValue: num(totals.yearValue), month: num(totals.month), monthValue: num(totals.monthValue) } : null,
    importBatchId: text(data.importBatchId),
  }
}

export function settingsOf(data: Record<string, unknown> | undefined): DirectSettings {
  const auto = AUTO_ISSUE.find((value) => value === data?.autoIssue) ?? 'never'
  return { defaultEmitterId: text(data?.defaultEmitterId), autoIssue: auto }
}

export type CertificateState = 'valid' | 'expiring' | 'expired' | 'pending' | 'missing'

const DAY = 24 * 60 * 60 * 1000

export function certificateState(emitter: Emitter, now: Date = new Date()): CertificateState {
  const cert = emitter.certificate
  if (!cert || cert.status === 'deleted') return 'missing'
  if (cert.status === 'pending') return 'pending'
  const end = cert.notAfter ? Date.parse(cert.notAfter) : NaN
  if (cert.status === 'expired' || Number.isNaN(end) || end <= now.getTime()) return 'expired'
  return end - now.getTime() < WARNING_DAYS * DAY ? 'expiring' : 'valid'
}

export function daysLeft(emitter: Emitter, now: Date = new Date()): number {
  const end = emitter.certificate?.notAfter ? Date.parse(emitter.certificate.notAfter) : NaN
  return Number.isNaN(end) ? 0 : Math.ceil((end - now.getTime()) / DAY)
}

/** The default: the one in settings, else the only one. */
export function defaultEmitterId(emitters: Emitter[], settings: DirectSettings): string | null {
  if (settings.defaultEmitterId && emitters.some((e) => e.id === settings.defaultEmitterId)) return settings.defaultEmitterId
  return emitters.length === 1 ? (emitters[0]?.id ?? null) : null
}

export function stylePreview(style: { uppercase: boolean; separator: string }, services: string[]): string {
  const joined = services.join(style.separator)
  return style.uppercase ? joined.toUpperCase() : joined
}

/**
 * The two services the "Estilo da descrição" sample shows: the company's own
 * (most used first), or the neutral pair when it has fewer than two.
 */
export function sampleServices(names: string[], neutral: [string, string]): string[] {
  const own = [...new Set(names.map((name) => name.trim()).filter(Boolean))].slice(0, 2)
  return own.length === 2 ? own : neutral
}

/** Why a picked file cannot be a certificate, or null. */
export function certificateFileProblem(file: { name: string; size: number }): 'type' | 'size' | null {
  if (!/\.(pfx|p12)$/i.test(file.name)) return 'type'
  if (file.size === 0 || file.size > MAX_CERTIFICATE_BYTES) return 'size'
  return null
}

export async function fileToBase64(file: Blob): Promise<string> {
  const bytes = new Uint8Array(await file.arrayBuffer())
  let binary = ''
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  return btoa(binary)
}

/** settings/payments.nfseDirectEnabled (members read it). */
export async function directEnabled(): Promise<boolean> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDoc(doc(db, 'companies', session.companyId as string, 'settings', 'payments'))
  return snap.data()?.nfseDirectEnabled === true
}

/** The emitters and settings/nfse, live. Returns the unsubscribe. */
export async function watchDirect(
  onEmitters: (emitters: Emitter[]) => void,
  onSettings: (settings: DirectSettings) => void,
  onError: () => void,
): Promise<() => void> {
  const [db, { collection, doc, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const company = session.companyId as string
  const stopEmitters = onSnapshot(
    collection(db, 'companies', company, 'fiscalEmitters'),
    (snap) =>
      onEmitters(
        snap.docs
          .map((d) => emitterOf(d.id, d.data() as Record<string, unknown>))
          .sort((a, b) => a.legalName.localeCompare(b.legalName, 'pt-BR')),
      ),
    () => onError(),
  )
  const stopSettings = onSnapshot(
    doc(db, 'companies', company, 'settings', 'nfse'),
    (snap) => onSettings(settingsOf(snap.data() as Record<string, unknown> | undefined)),
    () => onSettings(settingsOf(undefined)),
  )
  return () => {
    stopEmitters()
    stopSettings()
  }
}

export async function uploadCertificate(file: Blob, password: string, emitterId?: string | null) {
  const body = { pfxBase64: await fileToBase64(file), password, termsVersion: TERMS_VERSION }
  return emitterId
    ? nfseApi<Record<string, unknown>>(`/v1/app/nfse/emitters/${encodeURIComponent(emitterId)}/certificate`, { method: 'PUT', body })
    : nfseApi<Record<string, unknown>>('/v1/app/nfse/emitters/certificate', { method: 'POST', body })
}

export const deleteCertificate = (emitterId: string) =>
  nfseApi<Record<string, unknown>>(`/v1/app/nfse/emitters/${encodeURIComponent(emitterId)}/certificate`, { method: 'DELETE' })

export const updateEmitter = (
  emitterId: string,
  body: { municipalRegistration?: string | null; service?: Emitter['service']; descriptionStyle?: Emitter['descriptionStyle'] },
) => nfseApi<Record<string, unknown>>(`/v1/app/nfse/setup/emitters/${encodeURIComponent(emitterId)}`, { method: 'PATCH', body })

export const updateDirectSettings = (body: { defaultEmitterId?: string; autoIssue?: AutoIssue }) =>
  nfseApi<Record<string, unknown>>('/v1/app/nfse/setup/settings', { method: 'PUT', body })
