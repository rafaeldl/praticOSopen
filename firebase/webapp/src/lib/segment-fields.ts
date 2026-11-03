// Form fields of the segment (custom_fields:customer, custom_fields:device) and
// the masks of fixed fields (customer.phone, device.serial): the same
// `segments/{id}.customFields` the app reads (SegmentConfigService,
// DynamicFieldBuilder, docs/SEGMENT_CUSTOM_FIELDS.md, FIELD_VALIDATION_MASKS.md).
import { fieldLabel, segmentDocs, type CustomField, type SegmentDoc } from './segments'

export interface FormField extends CustomField {
  type: 'text' | 'textarea' | 'number' | 'select' | 'date' | string
  required?: boolean
  min?: number
  max?: number
  minLength?: number
  pattern?: string
  placeholder?: string
  options?: string[]
  optionsI18n?: { value?: string; labels?: Record<string, string> }[]
  section?: string
  sectionI18n?: Record<string, string>
  order?: number
  masks?: string[]
  masksByCountry?: Record<string, string[]>
  keyboardType?: string
  textCapitalization?: string
}

/**
 * Global first and the segment's after, sorted by `order`. A key in both takes
 * the segment's (the app keeps both and finds the first one; same in practice:
 * no key is in both today).
 */
export function buildFields(docs: readonly (SegmentDoc | null | undefined)[]): FormField[] {
  const byKey = new Map<string, FormField>()
  for (const doc of docs) {
    for (const field of (doc?.customFields ?? []) as FormField[]) {
      if (field.key && field.type && field.type !== 'label') byKey.set(field.key, field)
    }
  }
  return [...byKey.values()]
    .map((field, index) => ({ field, index }))
    .sort((a, b) => (a.field.order ?? 999) - (b.field.order ?? 999) || a.index - b.index)
    .map(({ field }) => field)
}

export const segmentFieldList = (): FormField[] => buildFields(segmentDocs())

export function segmentField(key: string, fields = segmentFieldList()): FormField | undefined {
  return fields.find((field) => field.key === key)
}

/** Fields of a namespace the form draws, without the fixed ones (fieldsGroupedBySectionLocalized). */
export function namespaceFields(namespace: string, exclude: readonly string[], fields = segmentFieldList()): FormField[] {
  return fields.filter((field) => field.key.split('.')[0] === namespace && field.type !== 'config' && !exclude.includes(field.key))
}

/** Masks: the universal ones, else the company country's (getMasks). */
export function fieldMasks(field: FormField | undefined, country: string | null | undefined): string[] {
  if (!field) return []
  if (field.masks?.length) return field.masks
  return (country && field.masksByCountry?.[country.toUpperCase()]) || []
}

const FULL: Record<string, string> = { pt: 'pt-BR', en: 'en-US', es: 'es-ES' }

/** Section title in the person's language, "Geral" when the field has none. */
export function sectionLabel(field: FormField, locale: string, general: string): string {
  const i18n = field.sectionI18n ?? {}
  return i18n[locale] ?? i18n[FULL[locale] ?? ''] ?? i18n['pt-BR'] ?? field.section ?? general
}

/** Fields grouped by section, in order of first appearance. */
export function groupBySection(fields: FormField[], locale: string, general: string): { title: string; fields: FormField[] }[] {
  const groups = new Map<string, FormField[]>()
  for (const field of fields) {
    const title = sectionLabel(field, locale, general)
    groups.set(title, [...(groups.get(title) ?? []), field])
  }
  return [...groups.entries()].map(([title, list]) => ({ title, fields: list }))
}

export function fieldTitle(field: FormField, locale: string): string {
  return fieldLabel(field, locale) ?? field.key.split('.').pop() ?? field.key
}

/** Options of a select: value and the label in the person's language. */
export function fieldOptions(field: FormField, locale: string): { value: string; label: string }[] {
  if (field.optionsI18n?.length) {
    return field.optionsI18n
      .filter((option) => option.value)
      .map((option) => ({ value: option.value as string, label: option.labels?.[locale] ?? option.labels?.[FULL[locale] ?? ''] ?? option.labels?.['pt-BR'] ?? (option.value as string) }))
  }
  return (field.options ?? []).map((value) => ({ value, label: value }))
}

export const fieldName = (field: FormField) => field.key.split('.').pop() as string

/**
 * Value of a field in `customData`: by field name, else by the whole key (old
 * records). The web writes only the field name (customer.form.custom-fields).
 */
export function readCustom(data: Record<string, unknown> | null | undefined, field: FormField): unknown {
  if (!data) return undefined
  return data[fieldName(field)] ?? data[field.key]
}

/** customData to save: one entry per field name, legacy keys dropped, empty values out. Null when empty. */
export function writeCustom(
  current: Record<string, unknown> | null | undefined,
  fields: FormField[],
  values: Record<string, unknown>,
): Record<string, unknown> | null {
  const out: Record<string, unknown> = { ...(current ?? {}) }
  for (const field of fields) {
    delete out[field.key]
    const value = values[fieldName(field)]
    if (value === undefined || value === null || value === '') delete out[fieldName(field)]
    else out[fieldName(field)] = value
  }
  return Object.keys(out).length ? out : null
}

export type FieldError = 'required' | 'minLength' | 'pattern' | 'number' | 'min' | 'max' | null

/**
 * DynamicFieldBuilder's checks. `required` holds for every type here: the app
 * skips it on textarea, select and date, which lets a required field pass empty
 * (fatia 03, item 46; not copied).
 */
export function validateField(field: FormField, value: unknown): FieldError {
  const empty = value === undefined || value === null || value === ''
  if (empty) return field.required ? 'required' : null
  if (field.type === 'number') {
    if (typeof value !== 'number' || !Number.isInteger(value)) return 'number'
    if (typeof field.min === 'number' && value < field.min) return 'min'
    if (typeof field.max === 'number' && value > field.max) return 'max'
    return null
  }
  if (field.type === 'text' && typeof value === 'string') {
    if (typeof field.minLength === 'number' && value.length < field.minLength) return 'minLength'
    if (field.pattern && !safeTest(field.pattern, value)) return 'pattern'
  }
  return null
}

function safeTest(pattern: string, value: string): boolean {
  try {
    return new RegExp(pattern).test(value)
  } catch {
    return true
  }
}

/**
 * Applies a mask of easy_mask (the app's TextInputMask): 9 digit, A letter, N
 * letter or digit, X any, `\` escapes. With several masks, the shortest that
 * holds what was typed (phone with 8 or 9 digits).
 */
export function applyMask(text: string, masks: readonly string[]): string {
  if (!masks.length) return text
  const tokens = (mask: string) => {
    const list: { token?: RegExp; fixed?: string }[] = []
    for (let i = 0; i < mask.length; i++) {
      const char = mask[i] as string
      if (char === '\\') list.push({ fixed: mask[++i] ?? '' })
      else if (char === '9') list.push({ token: /\d/ })
      else if (char === 'A') list.push({ token: /[A-Za-z]/ })
      else if (char === 'N') list.push({ token: /[A-Za-z0-9]/ })
      else if (char === 'X') list.push({ token: /./ })
      else list.push({ fixed: char })
    }
    return list
  }
  const typed = [...text].filter((char) => /[A-Za-z0-9]/.test(char))
  const sorted = masks.map(tokens).sort((a, b) => a.filter((t) => t.token).length - b.filter((t) => t.token).length)
  // The first mask whose tokens take what was typed, in order, without dropping a character (plate AAA-9999 or AAA9N99).
  const fits = (list: ReturnType<typeof tokens>) => {
    const slots = list.filter((part) => part.token)
    return slots.length >= typed.length && typed.every((char, index) => slots[index]!.token!.test(char))
  }
  const mask =
    sorted.find(fits) ?? sorted.find((list) => list.filter((t) => t.token).length >= typed.length) ?? (sorted[sorted.length - 1] as ReturnType<typeof tokens>)
  let out = ''
  let at = 0
  for (const part of mask) {
    if (at >= typed.length) break
    if (part.fixed !== undefined) {
      out += part.fixed
      continue
    }
    while (at < typed.length && !part.token!.test(typed[at] as string)) at++
    if (at < typed.length) out += typed[at++]
  }
  return out
}
