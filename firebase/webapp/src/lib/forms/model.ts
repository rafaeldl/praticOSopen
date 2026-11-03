// Checklists (dynamic forms), pure rules. Same shapes the app reads and writes:
// lib/models/form_definition.dart (template, /companies/{cid}/forms) and
// lib/models/order_form.dart (answers of an order, /companies/{cid}/orders/{oid}/forms).
// Firestore and Storage are in data.ts.

import { WEB_PLAN_LIMITS_ENFORCED } from '@/lib/plan-limits'

export const ITEM_TYPES = ['boolean', 'select', 'checklist', 'text', 'number', 'photo_only'] as const
export type ItemType = (typeof ITEM_TYPES)[number]

export interface FormItem {
  id: string
  label: string
  type: ItemType
  /** Choices of select and checklist, as the template has them (saved as is). */
  options: string[] | null
  required: boolean
  allowPhotos: boolean
  labelI18n?: Record<string, string> | null
  optionsI18n?: Record<string, string[]> | null
}

export interface Template {
  id: string
  title: string
  description: string | null
  /** Absent counts as on (`isActive != false`), like the app and the server counter. */
  isActive: boolean
  items: FormItem[]
  titleI18n?: Record<string, string> | null
  descriptionI18n?: Record<string, string> | null
  createdAt?: string | null
  updatedAt?: string | null
}

export type FormStatus = 'pending' | 'in_progress' | 'completed'

export interface FormResponse {
  itemId: string
  value: unknown
  photoUrls: string[]
}

export interface OrderForm {
  id: string
  formDefinitionId: string
  title: string
  titleI18n?: Record<string, string> | null
  status: FormStatus
  items: FormItem[]
  responses: FormResponse[]
  deviceId: string | null
  startedAt?: string | null
  completedAt?: string | null
  updatedAt?: string | null
}

type Raw = Record<string, unknown>
const isRecord = (value: unknown): value is Raw => !!value && typeof value === 'object' && !Array.isArray(value)
const stringOr = (value: unknown, fallback: string | null = null) => (typeof value === 'string' ? value : fallback)
const strings = (value: unknown): string[] => (Array.isArray(value) ? value.map((item) => String(item)) : [])
/** Firestore Timestamp (from another writer) or the ISO text the app writes. */
const when = (value: unknown): string | null => {
  if (typeof value === 'string') return value
  if (isRecord(value) && typeof (value as { toDate?: unknown }).toDate === 'function') return ((value as unknown as { toDate(): Date }).toDate()).toISOString()
  return null
}

let fallbackIds = 0
/** Same id the app gives an item without one: random, stable for this reading. */
const newItemId = () => `w${Date.now().toString(36)}${(fallbackIds++).toString(36)}`

function normalizeItem(raw: unknown, index: number): FormItem | null {
  if (!isRecord(raw)) return null
  const type = ITEM_TYPES.includes(raw.type as ItemType) ? (raw.type as ItemType) : null
  if (!type) return null
  const id = raw.id === null || raw.id === undefined || raw.id === '' ? newItemId() : String(raw.id)
  return {
    id,
    label: stringOr(raw.label, '') || `#${index + 1}`,
    type,
    options: Array.isArray(raw.options) ? strings(raw.options) : null,
    required: raw.required === true,
    // Legacy `requiresPhoto`; the app's default is true.
    allowPhotos: typeof raw.allowPhotos === 'boolean' ? raw.allowPhotos : typeof raw.requiresPhoto === 'boolean' ? raw.requiresPhoto : true,
    labelI18n: isRecord(raw.labelI18n) ? (raw.labelI18n as Record<string, string>) : null,
    optionsI18n: isRecord(raw.optionsI18n) ? (Object.fromEntries(Object.entries(raw.optionsI18n).map(([k, v]) => [k, strings(v)])) as Record<string, string[]>) : null,
  }
}

const normalizeItems = (raw: unknown): FormItem[] =>
  (Array.isArray(raw) ? raw : []).map(normalizeItem).filter((item): item is FormItem => !!item)

/** A template as the app reads it (legacy `name` and `fields` included). */
export function normalizeTemplate(id: string, raw: Raw): Template {
  return {
    id,
    title: stringOr(raw.title) ?? stringOr(raw.name) ?? '',
    description: stringOr(raw.description),
    isActive: raw.isActive !== false,
    items: normalizeItems(raw.items ?? raw.fields),
    titleI18n: isRecord(raw.titleI18n) ? (raw.titleI18n as Record<string, string>) : null,
    descriptionI18n: isRecord(raw.descriptionI18n) ? (raw.descriptionI18n as Record<string, string>) : null,
    createdAt: when(raw.createdAt),
    updatedAt: when(raw.updatedAt),
  }
}

export function normalizeOrderForm(id: string, raw: Raw): OrderForm {
  const status = raw.status === 'in_progress' || raw.status === 'completed' ? raw.status : 'pending'
  return {
    id,
    formDefinitionId: stringOr(raw.formDefinitionId, '') as string,
    title: stringOr(raw.title, '') as string,
    titleI18n: isRecord(raw.titleI18n) ? (raw.titleI18n as Record<string, string>) : null,
    status,
    items: normalizeItems(raw.items),
    responses: normalizeResponses(raw.responses),
    deviceId: stringOr(raw.deviceId),
    startedAt: when(raw.startedAt),
    completedAt: when(raw.completedAt),
    updatedAt: when(raw.updatedAt),
  }
}

export function normalizeResponses(raw: unknown): FormResponse[] {
  return (Array.isArray(raw) ? raw : [])
    .filter(isRecord)
    .map((item) => ({ itemId: String(item.itemId ?? ''), value: item.value ?? null, photoUrls: strings(item.photoUrls) }))
    .filter((item) => item.itemId)
}

// ── Texts in the person's language (getLocalizedTitle / Label / Options) ──

const pick = (map: Record<string, string> | null | undefined, locale: string, fallback: string) => map?.[locale] ?? map?.pt ?? fallback
export const titleOf = (form: { title: string; titleI18n?: Record<string, string> | null }, locale: string) => pick(form.titleI18n, locale, form.title)
export const descriptionOf = (template: Template, locale: string) => (template.description === null ? null : pick(template.descriptionI18n, locale, template.description))
export const labelOf = (item: FormItem, locale: string) => pick(item.labelI18n, locale, item.label)
export function optionsOf(item: FormItem, locale: string): string[] {
  return item.optionsI18n?.[locale] ?? item.optionsI18n?.pt ?? item.options ?? []
}
/** An answer is saved with the template's option and shown translated. */
export function optionText(item: FormItem, original: string, locale: string): string {
  const index = (item.options ?? []).indexOf(original)
  const shown = optionsOf(item, locale)
  return index >= 0 && index < shown.length ? (shown[index] as string) : original
}

// ── Answers ──

export const responseOf = (form: OrderForm, itemId: string) => form.responses.find((response) => response.itemId === itemId)

/** isFormItemAnswered: photos for a photo question, a non-empty value for the others. */
export function isAnswered(item: FormItem, response: FormResponse | undefined): boolean {
  if (!response) return false
  if (item.type === 'photo_only') return response.photoUrls.length > 0
  const value = response.value
  if (value === null || value === undefined) return false
  if (Array.isArray(value)) return value.length > 0
  return String(value).trim().length > 0
}

export const missingCount = (form: OrderForm) => form.items.filter((item) => !isAnswered(item, responseOf(form, item.id))).length
export const answeredCount = (form: OrderForm) => form.items.length - missingCount(form)
export function firstUnanswered(form: OrderForm, after = -1): number | null {
  for (let i = after + 1; i < form.items.length; i++) if (!isAnswered(form.items[i] as FormItem, responseOf(form, (form.items[i] as FormItem).id))) return i
  return null
}
/** Required questions without an answer (on a photo question, a photo counts). */
export const requiredMissing = (form: OrderForm) => form.items.filter((item) => item.required && !isAnswered(item, responseOf(form, item.id)))
/** "Concluir assim mesmo": something answered, something missing, nothing required open. */
export function canFinishAnyway(form: OrderForm): boolean {
  const missing = missingCount(form)
  return form.status !== 'completed' && missing > 0 && missing < form.items.length && requiredMissing(form).length === 0
}

export type AnswerChange =
  | { kind: 'value'; itemId: string; value: unknown }
  | { kind: 'addPhotos'; itemId: string; urls: string[] }
  | { kind: 'removePhoto'; itemId: string; url: string }

/**
 * Applies one change to the responses read inside the transaction. Only the
 * item answered changes, and within it only the part touched: a new value keeps
 * the photos someone else added, a photo keeps the value. So two people on the
 * same checklist (app and web) never erase each other's answers.
 */
export function applyChange(responses: FormResponse[], change: AnswerChange): FormResponse[] {
  const next = responses.map((response) => ({ ...response, photoUrls: [...response.photoUrls] }))
  let current = next.find((response) => response.itemId === change.itemId)
  if (!current) {
    if (change.kind === 'removePhoto') return next
    current = { itemId: change.itemId, value: null, photoUrls: [] }
    next.push(current)
  }
  if (change.kind === 'value') current.value = change.value
  else if (change.kind === 'addPhotos') current.photoUrls = [...current.photoUrls, ...change.urls.filter((url) => !current!.photoUrls.includes(url))]
  else current.photoUrls = current.photoUrls.filter((url) => url !== change.url)
  return next
}

/** The first answer moves pending to in_progress; a completed checklist stays completed. */
export function statusAfter(status: FormStatus, responses: FormResponse[]): FormStatus {
  return status === 'pending' && responses.length > 0 ? 'in_progress' : status
}

/** A completed checklist takes no new answer until it is reopened. */
export const acceptsAnswer = (status: FormStatus) => status !== 'completed'

/** Photo formats the app and the PDF show. */
export const PHOTO_TYPES = 'image/jpeg,image/png,image/webp'
/** storage.rules: under 10 MB. */
export const MAX_PHOTO = 10 * 1024 * 1024
export function splitPhotos(files: File[]): { ok: File[]; refused: number } {
  const types = PHOTO_TYPES.split(',')
  const ok = files.filter((file) => types.includes(file.type) && file.size < MAX_PHOTO)
  return { ok, refused: files.length - ok.length }
}

/** Number answers: validated by the company's way of writing numbers, saved as typed (the app saves text). */
export function numberAnswer(text: string, parse: (text: string) => number | null): string | null {
  const trimmed = text.trim()
  if (!trimmed) return ''
  return parse(trimmed) === null ? null : trimmed
}

/** Answer in words: "Sim", the option, "Óleo, Filtro", the text, "2 fotos". */
export function answerText(item: FormItem, response: FormResponse | undefined, locale: string, words: { yes: string; no: string; photos: (count: number) => string }): string | null {
  const value = response?.value
  switch (item.type) {
    case 'boolean':
      return typeof value === 'boolean' ? (value ? words.yes : words.no) : null
    case 'select':
      return value === null || value === undefined || value === '' ? null : optionText(item, String(value), locale)
    case 'checklist':
      return Array.isArray(value) && value.length ? value.map((option) => optionText(item, String(option), locale)).join(', ') : null
    case 'photo_only': {
      const count = response?.photoUrls.length ?? 0
      return count ? words.photos(count) : null
    }
    default: {
      const text = value === null || value === undefined ? '' : String(value).trim()
      return text || null
    }
  }
}

// ── Template editor ──

/** Choice and multiple choice need 2 or more options, one per line (empty lines ignored). */
export const optionLines = (text: string) => text.split('\n').map((line) => line.trim()).filter(Boolean)
export function questionProblem(label: string, type: ItemType, optionsText: string): 'label' | 'options' | null {
  if (!label.trim()) return 'label'
  if ((type === 'select' || type === 'checklist') && optionLines(optionsText).length < 2) return 'options'
  return null
}

/** What is missing to save: the name, a question, or both. */
export function saveProblem(title: string, items: FormItem[]): 'both' | 'name' | 'question' | null {
  const name = !title.trim()
  const question = items.length === 0
  return name && question ? 'both' : name ? 'name' : question ? 'question' : null
}

/**
 * A question after editing. The translations only stay while the text does not
 * change; "Só foto" is never required.
 */
export function editedItem(before: FormItem | null, input: { id: string; label: string; type: ItemType; optionsText: string; required: boolean; allowPhotos: boolean }): FormItem {
  const label = input.label.trim()
  const options = input.type === 'select' || input.type === 'checklist' ? optionLines(input.optionsText) : null
  const sameOptions = !!before && JSON.stringify(before.options ?? null) === JSON.stringify(options)
  return {
    id: input.id,
    label,
    type: input.type,
    options,
    required: input.type === 'photo_only' ? false : input.required,
    allowPhotos: input.type === 'photo_only' ? true : input.allowPhotos,
    labelI18n: before && before.label === label ? (before.labelI18n ?? null) : null,
    optionsI18n: before && sameOptions ? (before.optionsI18n ?? null) : null,
  }
}

/** Moves the question at `from` one step up (-1) or down (+1). */
export function moveItem<T>(items: T[], from: number, step: -1 | 1): T[] {
  const to = from + step
  if (to < 0 || to >= items.length) return items
  const next = [...items]
  const [moved] = next.splice(from, 1)
  next.splice(to, 0, moved as T)
  return next
}

/** One item as FormItemDefinition.toJson writes it: every key, nulls included. */
export const itemDoc = (item: FormItem) => ({
  id: item.id,
  label: item.label,
  type: item.type,
  options: item.options,
  required: item.required,
  allowPhotos: item.allowPhotos,
  labelI18n: item.labelI18n ?? null,
  optionsI18n: item.optionsI18n ?? null,
})

/** The order's copy of a template (FormsService.addFormToOrder), without the id. */
export function orderFormDoc(template: Template, deviceId: string | null, now: string) {
  return {
    formDefinitionId: template.id,
    title: template.title,
    status: 'pending' as FormStatus,
    items: template.items.map(itemDoc),
    responses: [],
    startedAt: now,
    completedAt: null,
    updatedAt: now,
    titleI18n: template.titleI18n ?? null,
    deviceId,
  }
}

// ── Lists ──

const fold = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim()
export const byTitle = (a: Template, b: Template) => fold(a.title).localeCompare(fold(b.title))
/** Picker search: title and description, contains, without accents or case. */
export function templateMatches(template: Template, query: string, locale: string): boolean {
  const q = fold(query)
  return !q || fold(titleOf(template, locale)).includes(q) || fold(descriptionOf(template, locale) ?? '').includes(q)
}

/** Active templates, `isActive != false` (what the app shows and the server counts). */
export const activeCount = (templates: Template[]) => templates.filter((template) => template.isActive).length

/**
 * Ready-made ones of the segment not yet in the company: the first access copies
 * them with the segment's id, "Usar" with a new id and the same title.
 */
export function readyNotCopied(ready: Template[], company: Template[]): Template[] {
  const ids = new Set(company.map((template) => template.id))
  const titles = new Set(company.map((template) => fold(template.title)))
  return ready.filter((template) => template.isActive && !ids.has(template.id) && !titles.has(fold(template.title)))
}

/**
 * "Qual checklist?" as the app (form_selection_screen): the company's active
 * ones and the segment's ready-made ones, which go straight into the order
 * (no copy, any role that adds checklists). A ready one already copied shows once.
 */
export function pickerGroups(company: Template[], ready: Template[] | null): { company: Template[]; ready: Template[] } {
  return {
    company: company.filter((template) => template.isActive).sort(byTitle),
    ready: ready ? readyNotCopied(ready, company).sort(byTitle) : [],
  }
}

export const hasPhotoQuestion = (template: Template) => template.items.some((item) => item.type === 'photo_only')

// ── Plan limit (FeatureGateService.canCreateFormTemplate) ──

const PLAN_LIMITS: Record<string, number> = { free: 1, starter: 3, pro: 10, business: -1 }

/**
 * Active checklists the plan allows: the stored limits (or the plan's) while
 * the plan is in force, Free's after it expires. -1 is no limit.
 */
export function planLimit(subscription: unknown, now: Date): number {
  const sub = isRecord(subscription) ? subscription : {}
  const plan = typeof sub.plan === 'string' && sub.plan in PLAN_LIMITS ? sub.plan : 'free'
  const expires = typeof sub.expiresAt === 'string' ? new Date(sub.expiresAt) : when(sub.expiresAt) ? new Date(when(sub.expiresAt) as string) : null
  const inForce = !expires || Number.isNaN(expires.getTime()) || expires > now ? plan : 'free'
  if (inForce !== plan) return PLAN_LIMITS[inForce] as number
  const stored = isRecord(sub.limits) ? sub.limits.formTemplates : undefined
  return typeof stored === 'number' ? stored : (PLAN_LIMITS[plan] as number)
}

// No plan limit in the browser, as the app (lib/plan-limits.ts).
export { WEB_PLAN_LIMITS_ENFORCED }

/** Active checklists allowed here: -1 (no limit) unless plan limits are enforced. */
export function activeLimit(subscription: unknown, now: Date, enforced = WEB_PLAN_LIMITS_ENFORCED): number {
  return enforced ? planLimit(subscription, now) : -1
}

/** One more active checklist fits? Counted from the list (`isActive != false`), never from the stored counter. */
export const fitsOneMore = (active: number, limit: number) => limit === -1 || active + 1 <= limit

// ── Who does what on an order's checklists ──

export interface FormsAccess {
  /** Add and remove checklists (canManageOrderForms). */
  manage: boolean
  /** Answer, add and remove photos, finish (fillForms). */
  fill: boolean
  /** Reopen a completed one: admin, manager and supervisor (canReopenCompletedForms). */
  reopen: boolean
}

/**
 * `canManage` is the order's (orderPermissions().canManageForms); `canFill` is
 * the permission fillForms of the contract. The app lets the manager answer
 * even without it; the web follows the contract, so the manager reads and reopens.
 */
export function formsAccess(role: string | null | undefined, canManage: boolean, canFill: boolean, canSeeOrder: boolean): FormsAccess {
  const r = role === 'owner' ? 'admin' : role
  return {
    manage: canSeeOrder && canManage,
    fill: canSeeOrder && canFill,
    reopen: canSeeOrder && (r === 'admin' || r === 'manager' || r === 'supervisor'),
  }
}
