// What the assistant's answer does to an order (POST /v1/app/ai/order-assist),
// the app's _applyDraft (order_screen_v2.dart): it never replaces a customer
// already chosen, a request already typed or a date already set; it never
// receives, cancels or deletes on its own (money waits for the card). Pure.
import { whatsappNumber } from '@/lib/phone'
import type { DraftActions, NfseMoment } from './ai-actions'

export interface CustomerHit { id: string; name: string; phone?: string }
export interface DeviceHit { id: string; name: string; serial?: string; manufacturer?: string }
export interface LineRef { kind: 'service' | 'product'; index: number }
export interface DraftChange {
  action: 'update' | 'remove'
  line: LineRef | null
  candidates: LineRef[]
  name: string
  value?: number
  quantity?: number
  description?: string
}
export interface DraftItem {
  kind: 'service' | 'product'
  name: string
  description?: string | null
  value: number | null
  quantity: number
  catalogId: string | null
}
export interface AssistDraft {
  transcript?: string | null
  customer: { match: CustomerHit | null; guess: { name?: string; phone?: string } | null; alternatives: CustomerHit[] } | null
  device: { match: DeviceHit | null; guess: { name?: string; serial?: string; manufacturer?: string } | null; alternatives: DeviceHit[] } | null
  items: DraftItem[]
  changes: DraftChange[]
  notes: string | null
  dueDate: string | null
  actions?: DraftActions | null
  nfseAutoIssue?: NfseMoment
  usage?: { used: number; limit: number }
}

/** Server answers from before `customer`/`device` objects: missing parts become empty. */
export function normalizeDraft(raw: Partial<AssistDraft> & Record<string, unknown>): AssistDraft {
  return {
    transcript: (raw.transcript as string | null) ?? null,
    customer: raw.customer ?? null,
    device: raw.device ?? null,
    items: raw.items ?? [],
    changes: raw.changes ?? [],
    notes: raw.notes ?? null,
    dueDate: raw.dueDate ?? null,
    actions: raw.actions ?? null,
    ...(raw.nfseAutoIssue ? { nfseAutoIssue: raw.nfseAutoIssue } : {}),
    ...(raw.usage ? { usage: raw.usage } : {}),
  }
}

export type CustomerStep =
  | { kind: 'none' }
  | { kind: 'match'; customer: CustomerHit }
  /** Nova OS: entered as "novo", registered only at the ✓ (order.ai.register-customer). */
  | { kind: 'new'; name: string; phone?: string }
  /** "Ouvi “Juliene”": the row asks which one (order.ai.ask-customer). */
  | { kind: 'ask'; name: string; phone?: string; options: CustomerHit[] }

export function customerStep(draft: AssistDraft, state: { hasCustomer: boolean; isNew: boolean; canRegister: boolean }): CustomerStep {
  const c = draft.customer
  if (state.hasCustomer || !c) return { kind: 'none' }
  if (c.match) return { kind: 'match', customer: c.match }
  const name = c.guess?.name?.trim() ?? ''
  const phone = c.guess?.phone?.trim() || undefined
  if (!name) return { kind: 'none' }
  const options = c.match ? [] : c.alternatives ?? []
  if (!options.length && state.isNew && state.canRegister) return { kind: 'new', name, ...(phone ? { phone } : {}) }
  return { kind: 'ask', name, ...(phone ? { phone } : {}), options }
}

export interface NewDevice { name: string; serial: string | null; manufacturer: string | null }
export type DeviceStep =
  | { kind: 'none' }
  | { kind: 'match'; device: DeviceHit }
  | { kind: 'new'; device: NewDevice }
  | { kind: 'ask'; label: string; device: NewDevice; options: DeviceHit[] }

/** The app's AssistantRegistration.newDevice: plate in capitals; the model, or the plate when no model was said. */
export function newDeviceOf(guess: { name?: string; serial?: string; manufacturer?: string }): NewDevice {
  const serial = guess.serial?.trim().toUpperCase() || null
  return { name: guess.name?.trim() || serial || '', serial, manufacturer: guess.manufacturer?.trim() || null }
}

export function deviceStep(draft: AssistDraft, state: { devices: { id?: string | null; serial?: string | null }[]; isNew: boolean; canRegister: boolean }): DeviceStep {
  const d = draft.device
  if (!d) return { kind: 'none' }
  if (d.match) return state.devices.some((x) => x.id === d.match?.id) ? { kind: 'none' } : { kind: 'match', device: d.match }
  if (!d.guess) return { kind: 'none' }
  const device = newDeviceOf(d.guess)
  const options = d.alternatives ?? []
  const known = !!device.serial && state.devices.some((x) => (x.serial ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '') === device.serial?.replace(/[^A-Z0-9]/g, ''))
  if (known) return { kind: 'none' }
  if (state.isNew && state.canRegister && (device.serial || (device.name && !options.length))) return { kind: 'new', device }
  const label = [d.guess.name?.trim(), device.serial].filter(Boolean).join(' · ')
  return label ? { kind: 'ask', label, device, options } : { kind: 'none' }
}

/**
 * The line a change means: the one the server named, or null when it asks
 * (`candidates` that still exist). The index is into the lines that were sent.
 */
export function changeTarget<T>(change: DraftChange, sent: { services: T[]; products: T[] }): { line: T | null; candidates: T[] } {
  const at = (ref: LineRef) => (ref.kind === 'product' ? sent.products : sent.services)[ref.index] ?? null
  if (change.line) return { line: at(change.line), candidates: [] }
  const candidates = change.candidates.map(at).filter((line): line is NonNullable<typeof line> => line !== null) as T[]
  return { line: null, candidates }
}

/** "pronto sexta": a day without a time is 18:00, like the app; as the date-time field's value. */
export function dueFromDraft(dueDate: string | null): string {
  if (!dueDate) return ''
  if (/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) return `${dueDate}T18:00`
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(dueDate) ? dueDate : ''
}

/** Which note goes under the bar (keys of the app, no sentence per field). */
export function noteKey(result: { filled: boolean; hasActions: boolean; isNew: boolean; onlyChanges: boolean }):
  'orderAssistantNothingFound' | 'aiActionsAfterSave' | 'orderAssistantChanged' | 'orderAssistantFilled' | 'orderAssistantApplied' | null {
  if (!result.filled) return result.hasActions ? null : 'orderAssistantNothingFound'
  if (result.isNew && result.hasActions) return 'aiActionsAfterSave'
  if (result.onlyChanges) return 'orderAssistantChanged'
  return result.isNew ? 'orderAssistantFilled' : 'orderAssistantApplied'
}

/** "Restam N usos" from 80% of the month's limit. */
export function usesLeft(usage: { used: number; limit: number } | undefined): number | null {
  if (!usage || usage.limit <= 0 || usage.used < usage.limit * 0.8) return null
  return Math.max(0, usage.limit - usage.used)
}

/**
 * The ✓ on the current customer in "Qual cliente?" (customer.picker.choose),
 * the app's currentCustomerId: by id; an old record without id (or an id no
 * longer in the list) by the same name plus the same phone, or a single name.
 * When in doubt, no ✓.
 */
export function currentCustomerId(
  current: { id?: string | null; name?: string | null; phone?: string | null } | null | undefined,
  customers: readonly { id: string; name: string; phone?: string | null }[],
  country?: string | null,
): string | null {
  if (!current) return null
  if (current.id && customers.some((c) => c.id === current.id)) return current.id
  const key = (name: string | null | undefined) => (name ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
  const name = key(current.name)
  if (!name) return null
  const sameName = customers.filter((c) => c.id && key(c.name) === name)
  if (!sameName.length) return null
  const phone = whatsappNumber(current.phone, country)
  if (!phone) return sameName.length === 1 ? (sameName[0] as { id: string }).id : null
  const samePhone = sameName.filter((c) => whatsappNumber(c.phone, country) === phone)
  if (samePhone.length) return samePhone.length === 1 ? (samePhone[0] as { id: string }).id : null
  const only = sameName.length === 1 ? sameName[0] : null
  return only && !whatsappNumber(only.phone, country) ? only.id : null
}

/**
 * The price the assistant may put on a line: the one said only for who edits
 * prices (the ✓ would send the catalog's anyway); otherwise the catalog's.
 */
export function assistValue(said: number | null | undefined, catalog: number | null, editPrices: boolean): number | null {
  return editPrices ? (said ?? catalog) : catalog
}
