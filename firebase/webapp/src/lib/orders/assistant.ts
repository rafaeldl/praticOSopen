// The assistant (POST /v1/app/ai/order-assist, docs/AI_ORDER_ASSIST.md). On a
// saved order it applies at once through the item routes, marks with ✦ and
// offers Undo. It never receives, cancels or deletes (WEB_APP_DESIGN rule 9).
import { locale } from '@/i18n'
import { api, session } from '@/lib/session'
import type { Order } from './model'
import { normalizeDraft, type AssistDraft } from './assist-draft'

export interface AssistStatus {
  enabled: boolean
  usage?: { used: number; limit: number }
}

let cached: { companyId: string; at: number; value: AssistStatus } | null = null

/** Kept 5 minutes per company and cleared after each request (order.ai.status). */
export async function assistStatus(): Promise<AssistStatus> {
  const companyId = session.companyId as string
  if (cached && cached.companyId === companyId && Date.now() - cached.at < 300_000) return cached.value
  const value = await api<AssistStatus>('/v1/app/ai/status')
  cached = { companyId, at: Date.now(), value }
  return value
}

export type { AssistDraft as Draft, DraftItem } from './assist-draft'

/** A line as the server reads it (name, description, value, quantity of parts; up to 50 of each). */
export interface AssistLine {
  kind: 'service' | 'product'
  name: string
  description?: string | null
  value?: number | null
  quantity?: number
}

/**
 * Asks with the text, the photos (base64 JPEG, assist-photo.ts) and the lines
 * on screen, in their order: the answer's changes point at them by index.
 */
export async function requestAssist(input: { text?: string; photos?: { mimeType: string; data: string }[]; lines: AssistLine[] }): Promise<AssistDraft> {
  cached = null
  const line = (l: AssistLine) => ({
    name: l.name.slice(0, 200) || '-',
    ...(l.description && l.description !== l.name ? { description: l.description.slice(0, 200) } : {}),
    ...(typeof l.value === 'number' ? { value: l.value } : {}),
    ...(l.kind === 'product' && (l.quantity ?? 1) > 0 ? { quantity: l.quantity ?? 1 } : {}),
  })
  const services = input.lines.filter((l) => l.kind === 'service').slice(0, 50).map(line)
  const products = input.lines.filter((l) => l.kind === 'product').slice(0, 50).map(line)
  const raw = await api<Record<string, unknown>>('/v1/app/ai/order-assist', {
    method: 'POST',
    body: {
      ...(input.text?.trim() ? { text: input.text.trim() } : {}),
      ...(input.photos?.length ? { photos: input.photos } : {}),
      locale: locale.value,
      ...(services.length || products.length ? { order: { services, products } } : {}),
    },
  })
  return normalizeDraft(raw)
}

export async function askAssistant(text: string, order: Order, photos?: { mimeType: string; data: string }[]): Promise<AssistDraft> {
  return requestAssist({ text, photos, lines: order.lines.map((l) => ({ kind: l.kind, name: l.name, description: l.description, value: l.value, quantity: l.quantity })) })
}
