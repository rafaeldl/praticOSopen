// "O que o cliente pediu" (order.new.request, order.request.edit): the segment's
// field `service_order.observation`, the same one the app reads and writes
// (lib/screens/widgets/order_custom_fields.dart: orderRequestField,
// customFieldValue, applyCustomFieldValue). Segments without the field keep the
// request as the order's first internal comment, as the app does.
import { isoOf } from './model'
import { firestoreClient } from '@/lib/firebase'
import { fieldName, readCustom, segmentFieldList, type FormField } from '@/lib/segment-fields'
import { session } from '@/lib/session'

export const REQUEST_KEY = 'service_order.observation'

/** The segment's request field, or undefined when the segment has none. */
export function requestField(fields: readonly FormField[] = segmentFieldList()): FormField | undefined {
  return fields.find((field) => field.key === REQUEST_KEY)
}

/** The request saved in the field (new key first, then the old full key), trimmed. */
export function readRequest(data: Record<string, unknown> | null | undefined, field: FormField): string {
  const value = readCustom(data, field)
  return value === undefined || value === null ? '' : String(value).trim()
}

/** customData with the request set (taken out when empty); the old full key dropped; null when nothing is left. */
export function withRequest(data: Record<string, unknown> | null | undefined, field: FormField, text: string): Record<string, unknown> | null {
  const next: Record<string, unknown> = { ...(data ?? {}) }
  const value = text.trim()
  if (value) next[fieldName(field)] = value
  else delete next[fieldName(field)]
  delete next[field.key]
  return Object.keys(next).length ? next : null
}

interface CommentLike {
  text?: unknown
  source?: unknown
  isInternal?: unknown
  deleted?: unknown
  author?: { userId?: unknown } | null
  createdAt?: unknown
}

/** How long after the order the old Nova OS wrote its request comment (it went right after the order got its id). */
const LEGACY_WINDOW_MS = 5 * 60_000

/**
 * The request the web's Nova OS used to save as a comment (before #order.request.edit):
 * the order's earliest comment, internal, from the web, by who created the order, written
 * within minutes of it. Read only to show it while the field is empty; the comment stays.
 */
export function legacyRequest(order: { createdAt?: string | null; createdBy?: { id?: string } | null }, comments: readonly CommentLike[]): string {
  const created = order.createdAt ? Date.parse(order.createdAt) : NaN
  const creator = order.createdBy?.id
  if (Number.isNaN(created) || !creator) return ''
  const dated = comments
    .map((comment) => ({ comment, at: Date.parse(isoOf(comment.createdAt) ?? '') }))
    .filter((item) => !Number.isNaN(item.at))
    .sort((a, b) => a.at - b.at)
  const first = dated[0]
  if (!first) return ''
  const { comment, at } = first
  const text = typeof comment.text === 'string' ? comment.text.trim() : ''
  const fits =
    text &&
    comment.deleted !== true &&
    comment.source === 'web' &&
    comment.isInternal === true &&
    comment.author?.userId === creator &&
    at >= created - 60_000 &&
    at - created <= LEGACY_WINDOW_MS
  return fits ? text : ''
}

/** Reads the order's comments once to find the old request (legacyRequest); empty on any failure. */
export async function loadLegacyRequest(order: { id: string; createdAt?: string | null; createdBy?: { id?: string } | null }): Promise<string> {
  try {
    const [db, { collection, getDocs }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
    const snapshot = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', order.id, 'comments'))
    return legacyRequest(order, snapshot.docs.map((doc) => doc.data() as CommentLike))
  } catch (error) {
    console.warn('order request: old comment not read', error)
    return ''
  }
}
