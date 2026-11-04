// "Avisar o cliente?" after a status change (order.status.notify), the app's
// shouldOfferStatusShare (lib/screens/widgets/order_status_share.dart).
import type { Order, OrderStatus } from './model'

/** Statuses that offer to tell the customer. */
export const STATUSES_THAT_NOTIFY: ReadonlySet<OrderStatus> = new Set<OrderStatus>(['approved', 'progress', 'done'])

/** How long the note stays (kNotifyNoteDuration). */
export const NOTIFY_NOTE_MS = 8000

/**
 * Only approved, in progress or done; a saved order whose customer has a phone,
 * without an active link, and not asked yet for this order on this screen.
 * A link without a date counts as active, as in the app (isExpired false).
 */
export function shouldOfferStatusShare(order: Order, status: OrderStatus, asked: ReadonlySet<string>, now: Date = new Date()): boolean {
  if (!order.id) return false
  if (!STATUSES_THAT_NOTIFY.has(status)) return false
  const link = order.shareLink
  if (link?.token && !(link.expiresAt && Date.parse(link.expiresAt) < now.getTime())) return false
  if (asked.has(order.id)) return false
  return !!order.customer?.phone?.trim()
}
