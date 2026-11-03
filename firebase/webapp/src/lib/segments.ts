// Labels per business segment, same order as lib/services/segment_config_service.dart:
// segment custom label, then i18n, then English. `segments/global` comes first and
// the company's segment overrides it.
import { reactive } from 'vue'
import { firestoreClient } from './firebase'
import type { MessageKey } from '@/generated/message-keys'

export interface CustomField {
  key: string
  type?: string
  labels?: Record<string, string>
}

export interface SegmentDoc {
  customFields?: CustomField[]
}

/** Label keys of the app (_getFromArb) that have a message here. */
export const LABEL_MESSAGES: Record<string, MessageKey> = {
  'customer._entity': 'customer',
  'customer._entity_plural': 'customers',
  'device._entity': 'device',
  'device._entity_plural': 'devices',
  'service_order._entity': 'order',
  'service_order._entity_plural': 'orders',
  'customer.name': 'name',
  'customer.phone': 'phone',
  'customer.email': 'email',
  'customer.address': 'address',
  'device.brand': 'brand',
  'device.model': 'model',
  'device.serial': 'serialNumber',
  'device.description': 'description',
  'device.notes': 'notes',
  'status.quote': 'statusQuote',
  'status.approved': 'statusApproved',
  'status.in_progress': 'statusInProgress',
  'status.completed': 'statusCompleted',
  'status.cancelled': 'statusCancelled',
}

const FULL_LOCALE: Record<string, string> = { pt: 'pt-BR', en: 'en-US', es: 'es-ES' }

/** Same fallback as CustomField.getLabel: exact locale, full locale of the language, pt-BR, en-US. */
export function fieldLabel(field: CustomField, locale: string): string | null {
  const labels = field.labels ?? {}
  const language = locale.split(/[-_]/)[0] ?? ''
  return (
    labels[locale] ??
    labels[FULL_LOCALE[language] ?? ''] ??
    labels[language] ??
    labels['pt-BR'] ??
    labels['en-US'] ??
    Object.values(labels)[0] ??
    null
  )
}

/** Later documents win, so pass [global, segment]. */
export function buildLabels(docs: (SegmentDoc | null | undefined)[], locale: string): Record<string, string> {
  const labels: Record<string, string> = {}
  for (const doc of docs) {
    for (const field of doc?.customFields ?? []) {
      const text = fieldLabel(field, locale)
      if (field.key && text) labels[field.key] = text
    }
  }
  return labels
}

export function resolveLabel(
  key: string,
  labels: Record<string, string>,
  translate: (key: MessageKey) => string,
  english?: string,
): string {
  const custom = labels[key]
  if (custom) return custom
  const message = LABEL_MESSAGES[key]
  if (message) return translate(message)
  return english ?? key
}

const state = reactive({
  loadedKey: '',
  labels: {} as Record<string, string>,
})

async function readSegment(id: string): Promise<SegmentDoc | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const snapshot = await getDoc(doc(db, 'segments', id))
  return snapshot.exists() ? (snapshot.data() as SegmentDoc) : null
}

/** Loads labels once per segment and language. Failure keeps i18n, never blocks a screen. */
export async function loadSegmentLabels(segmentId: string | null | undefined, locale: string): Promise<void> {
  const id = segmentId || 'global'
  const key = `${id}|${locale}`
  if (state.loadedKey === key) return
  state.loadedKey = key
  try {
    const [global, segment] = await Promise.all([
      id === 'global' ? null : readSegment('global'),
      readSegment(id),
    ])
    if (state.loadedKey === key) state.labels = buildLabels([global, segment], locale)
  } catch (error) {
    console.warn('segments: labels not loaded', error)
    if (state.loadedKey === key) state.labels = {}
  }
}

export function segmentLabels(): Record<string, string> {
  return state.labels
}
