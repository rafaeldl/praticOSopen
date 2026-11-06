// "Importar notas" of the NFS-e direct (issue #569, spec §4.3, the app's
// nfse_import_screen.dart): the server reads the notas the CNPJ already issued
// and proposes what to fill; nothing changes until "Importar". The batch is
// written only by the server (companies/{id}/nfseImports), read here through
// the same routes the app calls.
import { firestoreLite } from '@/lib/firebase'
import { nfseApi, session } from '@/lib/session'
import type { FiscalRegime } from './direct'

export type ImportStatus = 'reading' | 'proposed' | 'applied' | 'undone' | 'failed'
export type ImportAction = 'complete' | 'create' | 'ask'

export interface ImportGroup {
  key: string
  legalName: string
  taxId: string
  action: ImportAction
  notas: number
  customerId: string | null
  customerName: string | null
  stores: { customerId: string; customerName: string }[]
}

export interface ImportProposal {
  notas: number
  customers: number
  newCustomers: number
  completedCustomers: number
  linked: number
  historyOnly: number
  emitter: {
    legalName: string | null
    regime: FiscalRegime | null
    municipalRegistration: string | null
    service: { name: string | null; issRate: number } | null
    dpsSeries: string | null
  }
  groups: ImportGroup[]
  autoIssue: { customerId: string; customerName: string }[]
}

export interface ImportBatch {
  id: string
  emitterId: string
  status: ImportStatus
  documentsRead: number
  proposal: ImportProposal | null
  expiresAt: string | null
}

const text = (value: unknown) => (typeof value === 'string' && value.trim() ? value : null)
const num = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : 0)
const record = (value: unknown) => (value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null)
const list = (value: unknown) => (Array.isArray(value) ? value.map(record).filter((item): item is Record<string, unknown> => !!item) : [])
const STATUSES: readonly ImportStatus[] = ['reading', 'proposed', 'applied', 'undone', 'failed']
const ACTIONS: readonly ImportAction[] = ['complete', 'create', 'ask']

export function proposalOf(data: Record<string, unknown>): ImportProposal {
  const counts = record(data.counts) ?? {}
  const view = record(record(data.emitter)?.view) ?? {}
  const service = record(view.service)
  return {
    notas: num(counts.notas),
    customers: num(counts.customers),
    newCustomers: num(counts.newCustomers),
    completedCustomers: num(counts.completedCustomers),
    linked: num(counts.linked),
    historyOnly: num(counts.historyOnly),
    emitter: {
      legalName: text(view.legalName),
      regime: view.regime === 'mei' || view.regime === 'simples' ? view.regime : null,
      municipalRegistration: text(view.municipalRegistration),
      service: service ? { name: text(service.name), issRate: num(service.issRate) } : null,
      dpsSeries: text(view.dpsSeries),
    },
    groups: list(data.groups).map((g) => ({
      key: text(g.key) ?? '',
      legalName: text(g.legalName) ?? '',
      taxId: text(g.taxId) ?? '',
      action: ACTIONS.find((a) => a === g.action) ?? 'create',
      notas: num(g.notas),
      customerId: text(g.customerId),
      customerName: text(g.customerName),
      stores: list(g.stores).map((s) => ({ customerId: text(s.customerId) ?? '', customerName: text(s.customerName) ?? '' })),
    })),
    autoIssue: list(data.autoIssue).map((s) => ({ customerId: text(s.customerId) ?? '', customerName: text(s.customerName) ?? '' })),
  }
}

export function batchOf(data: Record<string, unknown>, id?: string): ImportBatch {
  const proposal = record(data.proposal)
  return {
    id: id ?? text(data.id) ?? '',
    emitterId: text(data.emitterId) ?? '',
    status: STATUSES.find((s) => s === data.status) ?? 'failed',
    documentsRead: num(record(data.read)?.documents),
    proposal: proposal ? proposalOf(proposal) : null,
    expiresAt: text(data.expiresAt),
  }
}

/** "Desfazer importação" is offered for 30 days after "Importar". */
export function canUndo(batch: ImportBatch | null, now: Date = new Date()): boolean {
  if (batch?.status !== 'applied' || !batch.expiresAt) return false
  const end = Date.parse(batch.expiresAt)
  return !Number.isNaN(end) && now.getTime() < end
}

/** The groups the owner answers ("Este é o mesmo cliente?"). */
export const toAsk = (p: ImportProposal) => p.groups.filter((g) => g.action === 'ask')

/** Groups whose CNPJ gets the notas of other stores ("Nota fiscal para"). */
export const withStores = (p: ImportProposal) => p.groups.filter((g) => g.stores.length > 0)

/** New and completed customers after the answers: "Sim" completes, anything else creates. */
export function customerCounts(p: ImportProposal, same: Record<string, boolean>): { created: number; completed: number } {
  const asked = toAsk(p)
  const yes = asked.filter((g) => same[g.key] === true).length
  return { created: p.newCustomers + asked.length - yes, completed: p.completedCustomers + yes }
}

const call = (path: string, body: unknown = {}) =>
  nfseApi<Record<string, unknown>>(`/v1/app/nfse/imports${path}`, { method: 'POST', body }).then((data) => batchOf(data ?? {}))

export const startImport = (emitterId: string) => call('', { emitterId })
export const continueImport = (batchId: string) => call(`/${encodeURIComponent(batchId)}/continue`)
export const applyImport = (batchId: string, answers: { sameCustomer: Record<string, boolean>; autoIssueCustomerIds: string[] }) =>
  call(`/${encodeURIComponent(batchId)}/apply`, { answers })
export const undoImport = (batchId: string) => call(`/${encodeURIComponent(batchId)}/undo`)

/**
 * Starts (or resumes) the reading and keeps asking until the proposal comes.
 * `onBatch` gets every step (the count of documents read); `stopped` ends it
 * when the drawer closes.
 */
export async function readUntilProposed(emitterId: string, onBatch: (batch: ImportBatch) => void, stopped: () => boolean = () => false): Promise<ImportBatch> {
  let batch = await startImport(emitterId)
  onBatch(batch)
  while (!stopped() && batch.status === 'reading') {
    batch = await continueImport(batch.id)
    onBatch(batch)
  }
  return batch
}

/** The emitter's last import (its importBatchId), for "Desfazer importação". */
export async function loadBatch(batchId: string): Promise<ImportBatch | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDoc(doc(db, 'companies', session.companyId as string, 'nfseImports', batchId))
  return snap.exists() ? batchOf(snap.data() as Record<string, unknown>, snap.id) : null
}
