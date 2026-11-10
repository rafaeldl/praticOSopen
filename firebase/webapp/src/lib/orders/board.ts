// What the board leaves out so it shows the work of now, not the history
// (docs/WEB_APP.md, "Quadro"): concluded orders after a week, and quotes nobody
// answered for three months. Nothing is archived: both stay in the list
// (filters Concluídas and Todas), and the stale quotes can be canceled at once.
import type { Order } from './model'

/** Days a concluded order stays in the Concluída column. */
export const BOARD_DONE_DAYS = 7
/** Days without a change after which a quote leaves the Orçamento column. */
export const STALE_QUOTE_DAYS = 90

const DAY_MS = 86_400_000

const time = (iso: string | null | undefined) => (iso ? Date.parse(iso) : Number.NaN)

/**
 * Concluded in the last BOARD_DONE_DAYS days, by `completedAt` (written by the
 * server on every conclusion, the same field as the TV). Orders concluded
 * before the field existed have none: they are old, and stay out.
 */
export function isRecentDone(order: Order, now: Date): boolean {
  if (order.status !== 'done') return false
  const at = time(order.completedAt)
  return !Number.isNaN(at) && now.getTime() - at < BOARD_DONE_DAYS * DAY_MS
}

/** Start of the Concluída window, as the server writes completedAt (UTC ISO). */
export function doneSinceIso(now: Date): string {
  return new Date(now.getTime() - BOARD_DONE_DAYS * DAY_MS).toISOString()
}

/** Last time the quote moved: the last change, or its creation. */
export function quoteIdleSince(order: Order): string | null {
  return order.updatedAt ?? order.createdAt ?? null
}

/** A quote with no change in STALE_QUOTE_DAYS days. */
export function isStaleQuote(order: Order, now: Date): boolean {
  if (order.status !== 'quote') return false
  const at = time(quoteIdleSince(order))
  return !Number.isNaN(at) && now.getTime() - at >= STALE_QUOTE_DAYS * DAY_MS
}

/** Whole months a quote has been idle (at least 3 when it is stale). */
export function idleMonths(order: Order, now: Date): number {
  const at = time(quoteIdleSince(order))
  if (Number.isNaN(at)) return 0
  return Math.floor((now.getTime() - at) / (30 * DAY_MS))
}

export interface BoardRows {
  /** The cards of the columns. */
  cards: Order[]
  /** Quotes left out of the Orçamento column, idle longest first. */
  staleQuotes: Order[]
}

/** Splits what the board read: older concluded orders go away, stale quotes go aside. */
export function boardRows(rows: Order[], now: Date): BoardRows {
  const cards: Order[] = []
  const staleQuotes: Order[] = []
  for (const order of rows) {
    if (order.status === 'done' && !isRecentDone(order, now)) continue
    if (isStaleQuote(order, now)) staleQuotes.push(order)
    else cards.push(order)
  }
  staleQuotes.sort((a, b) => time(quoteIdleSince(a)) - time(quoteIdleSince(b)))
  return { cards, staleQuotes }
}
