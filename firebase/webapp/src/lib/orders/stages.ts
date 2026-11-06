// Work stages (docs/WORK_STAGES.md): where an in-progress order is in the shop
// (Pintura, Polimento). The company lists them in `workStages`; an empty list
// turns them off and the board stays one column per status.
import type { Order, OrderLine } from './model'
import { session } from '@/lib/session'

export interface WorkStage {
  id: string
  name: string
  /** Words of a service name that send the order to this stage ("pint", "polim"). */
  keywords?: string[]
}

/** The company's stages as stored, dropping entries without an id or a name (same as the server's workStagesOf). */
export function stagesOf(raw: unknown): WorkStage[] {
  if (!Array.isArray(raw)) return []
  return raw
    .filter((stage): stage is { id: string; name: string; keywords?: unknown } => typeof stage?.id === 'string' && !!stage.id && typeof stage.name === 'string' && !!stage.name.trim())
    .map((stage) => ({
      id: stage.id,
      name: stage.name.trim(),
      ...(Array.isArray(stage.keywords) ? { keywords: stage.keywords.filter((word): word is string => typeof word === 'string' && !!word.trim()) } : {}),
    }))
}

/** Stages of the open company. */
export const workStages = (): WorkStage[] => stagesOf(session.company?.workStages)

/**
 * Stage column of an in-progress order: its stage, or the first one when it has
 * none (moved by the app, the API or before stages) or one the company removed.
 */
export function stageIdOf(order: Pick<Order, 'status' | 'stage'>, stages: WorkStage[]): string | null {
  if (order.status !== 'progress' || !stages.length) return null
  return stages.some((stage) => stage.id === order.stage?.id) ? order.stage!.id : stages[0]!.id
}

/** Ordered by rank; orders without a place in that stage go last, newest first as the board read them. */
export function sortInStage<T extends Pick<Order, 'stage'>>(orders: T[], stageId: string): T[] {
  const rank = (order: T) => (order.stage?.id === stageId && Number.isFinite(order.stage.rank) ? order.stage.rank : Number.POSITIVE_INFINITY)
  return orders
    .map((order, index) => ({ order, index }))
    .sort((a, b) => rank(a.order) - rank(b.order) || a.index - b.index)
    .map(({ order }) => order)
}

/**
 * Rank to put a card at `index` of a column (the card itself already left out).
 * `undefined` means the end: the server stamps the time, larger than any rank
 * the board makes.
 */
export function rankAt(column: Pick<Order, 'stage'>[], index: number, stageId: string): number | undefined {
  const rankOf = (order: Pick<Order, 'stage'> | undefined) =>
    order?.stage?.id === stageId && Number.isFinite(order.stage.rank) ? order.stage.rank : undefined
  const before = rankOf(column[index - 1])
  const after = rankOf(column[index])
  if (before !== undefined && after !== undefined) return (before + after) / 2
  if (before !== undefined) return before + 1024
  if (after !== undefined) return after - 1024
  // Only cards with no place around: first of the column, or the end.
  return index === 0 && column.length > 0 ? 0 : undefined
}

const fold = (text: string) => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

function matches(line: Pick<OrderLine, 'name' | 'description'>, stage: WorkStage): boolean {
  const text = fold(`${line.name ?? ''} ${line.description ?? ''}`)
  return (stage.keywords ?? []).some((word) => text.includes(fold(word.trim())))
}

/** Services of the order done in this stage; all of them when the stage has no words or none matches. */
export function linesForStage(order: Pick<Order, 'lines'>, stage: WorkStage): OrderLine[] {
  const services = order.lines.filter((line) => line.kind === 'service')
  const own = services.filter((line) => matches(line, stage))
  return own.length ? own : services
}

/** First stage (in the company's order) that one of the services points to: "Próxima: Pintura". */
export function suggestedStage(order: Pick<Order, 'lines'>, stages: WorkStage[]): WorkStage | null {
  const services = order.lines.filter((line) => line.kind === 'service')
  return stages.find((stage) => services.some((line) => matches(line, stage))) ?? null
}
