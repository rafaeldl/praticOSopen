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

type Ranked = Pick<Order, 'stage' | 'createdAt'>

/**
 * Place of a card in a stage. Orders without one (put in progress by the app,
 * the API or before stages) count by when they were created: the same scale as
 * the server's default rank (the time), so a card can go above, between or
 * below them. Without a date either, last.
 */
export function rankIn(order: Ranked, stageId: string): number {
  if (order.stage?.id === stageId && Number.isFinite(order.stage.rank)) return order.stage.rank
  const created = order.createdAt ? Date.parse(order.createdAt) : NaN
  return Number.isNaN(created) ? Number.POSITIVE_INFINITY : created
}

/** Ordered by place in the stage; ties stay as the board read them. */
export function sortInStage<T extends Ranked>(orders: T[], stageId: string): T[] {
  return orders
    .map((order, index) => ({ order, index, rank: rankIn(order, stageId) }))
    .sort((a, b) => (a.rank === b.rank ? 0 : a.rank - b.rank) || a.index - b.index)
    .map(({ order }) => order)
}

/**
 * Rank to put a card at `index` of a column (the card itself already left out).
 * `undefined` means the end with nothing ranked around: the server stamps the
 * time.
 */
export function rankAt(column: Ranked[], index: number, stageId: string): number | undefined {
  const rankOf = (order: Ranked | undefined) => {
    const rank = order ? rankIn(order, stageId) : NaN
    return Number.isFinite(rank) ? rank : undefined
  }
  const before = rankOf(column[index - 1])
  const after = rankOf(column[index])
  if (before !== undefined && after !== undefined) return (before + after) / 2
  if (before !== undefined) return before + 1024
  if (after !== undefined) return after - 1024
  return undefined
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
