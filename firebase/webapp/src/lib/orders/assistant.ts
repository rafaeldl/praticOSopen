// The assistant (POST /v1/app/ai/order-assist, docs/AI_ORDER_ASSIST.md). On a
// saved order it applies at once through the item routes, marks with ✦ and
// offers Undo. It never receives, cancels or deletes (WEB_APP_DESIGN rule 9).
import { locale } from '@/i18n'
import { api, session } from '@/lib/session'
import type { Order } from './model'

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

export interface DraftItem {
  kind: 'service' | 'product'
  name: string
  value: number | null
  quantity: number
  catalogId: string | null
}

export interface Draft {
  items: DraftItem[]
  changes: { action: 'update' | 'remove'; line: { kind: 'service' | 'product'; index: number } | null; name: string }[]
  usage?: { used: number; limit: number }
}

export async function askAssistant(text: string, order: Order): Promise<Draft> {
  cached = null
  const line = (l: Order['lines'][number]) => ({
    name: l.name.slice(0, 200) || '-',
    ...(l.description && l.description !== l.name ? { description: l.description.slice(0, 200) } : {}),
    ...(typeof l.value === 'number' ? { value: l.value } : {}),
    ...(l.kind === 'product' ? { quantity: l.quantity ?? 1 } : {}),
  })
  return api<Draft>('/v1/app/ai/order-assist', {
    method: 'POST',
    body: {
      text,
      locale: locale.value,
      order: {
        services: order.lines.filter((l) => l.kind === 'service').map(line),
        products: order.lines.filter((l) => l.kind === 'product').map(line),
      },
    },
  })
}
