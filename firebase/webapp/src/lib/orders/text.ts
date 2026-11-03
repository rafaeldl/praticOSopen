// Words for orders: status, lateness, dates and segment labels. Keys stay
// literal so the build keeps them (docs/WEB_APP.md, Contrato gerado).
import { t, type MessageKey } from '@/i18n'
import { formatDayMonth, formatMoney, formatTime } from '@/lib/format'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { hasTime, holdDays, isActive, lateness, relativeDay, type HoldReason, type Order, type OrderStatus } from './model'

const tr = (key: MessageKey) => t(key)
export const country = () => session.company?.country

const STATUS_LABEL: Record<OrderStatus, string> = {
  quote: 'status.quote',
  approved: 'status.approved',
  progress: 'status.in_progress',
  done: 'status.completed',
  canceled: 'status.cancelled',
}

/** Status name with the segment's label ("Na oficina" for automotive). */
export function statusText(status: OrderStatus): string {
  return resolveLabel(STATUS_LABEL[status], segmentLabels(), tr)
}

/** "Veículo" / "Aparelho" / "Equipamento". */
export const deviceLabel = () => resolveLabel('device._entity', segmentLabels(), tr)
/** "OS" unless the segment renames the order. */
export function orderShort(): string {
  return segmentLabels()['service_order._entity'] ?? t('orderShort')
}
export const orderName = () => resolveLabel('service_order._entity', segmentLabels(), tr)
/** "OS 186" (order.detail.title). */
export const orderTitle = (order: Pick<Order, 'number'>) => t('orderNumberTitle', { order: orderShort(), number: order.number ?? '' })

export function money(value: number | null | undefined): string {
  return formatMoney(value ?? 0, country())
}

export function holdReasonText(reason: HoldReason): string {
  switch (reason) {
    case 'part':
      return t('orderHoldReasonPart')
    case 'customer':
      return t('orderHoldReasonCustomer')
    case 'authorization':
      return t('orderHoldReasonAuthorization')
    default:
      return t('orderHoldReasonOther')
  }
}

/** "Atrasada 3 dias" / "há 2 meses" / "há 1 ano" (home.row.overdue). */
export function lateText(order: Order, now: Date): string | null {
  const late = lateness(order, now)
  if (!late) return null
  if (late.unit === 'years') return t('orderLateYears', { count: late.count })
  if (late.unit === 'months') return t('orderLateMonths', { count: late.count })
  return t('orderLateDays', { count: late.count })
}

/** "Esperando peça · Parada há 3 dias" (home.row.hold, order.hold.view). */
export function holdText(order: Order, now: Date): string | null {
  const days = holdDays(order, now)
  if (days === null || !order.onHold) return null
  return `${holdReasonText(order.onHold.reason)} · ${t('orderHoldSince', { count: days })}`
}

/** "hoje", "amanhã", or "15/10". */
export function dayWord(iso: string, now: Date): string {
  const relative = relativeDay(iso, now)
  if (relative === 'today') return t('today').toLocaleLowerCase()
  if (relative === 'tomorrow') return t('tomorrow').toLocaleLowerCase()
  if (relative === 'yesterday') return t('yesterday').toLocaleLowerCase()
  return formatDayMonth(iso, country())
}

/** "hoje, 17:00"; midnight shows the day only. */
export function whenText(iso: string, now: Date): string {
  const day = dayWord(iso, now)
  return hasTime(iso) ? t('orderDayAtTime', { day, time: formatTime(iso, country()) }) : day
}

/** "Na oficina · entrega 15/10 · visita 14/10" (home.row.status-line): dates only on an active order. */
export function statusLine(order: Order): string {
  let text = statusText(order.status)
  const c = country()
  if (isActive(order) || order.status === 'quote') {
    if (order.dueDate) text = t('orderStatusDue', { status: text, date: formatDayMonth(order.dueDate, c) })
    if (order.scheduledDate) text = t('orderStatusVisit', { status: text, date: formatDayMonth(order.scheduledDate, c) })
  }
  return text
}

/**
 * "Quando" of the list on a wide screen: the visit (with the hour) or the delivery,
 * on an order still to do; late when the delivery passed. The status column then
 * shows only the status (statusLine keeps the dates where the column is not there).
 */
export function whenCell(order: Order, now: Date): { text: string; late: boolean } | null {
  if (!isActive(order) && order.status !== 'quote') return null
  if (order.scheduledDate) return { text: t('web.orders.whenVisit', { when: whenText(order.scheduledDate, now) }), late: false }
  if (order.dueDate) return { text: t('web.orders.whenDue', { when: whenText(order.dueDate, now) }), late: !!lateness(order, now) }
  return null
}

/** The phrase under the header (order.detail.overdue-line / remaining-line). */
export function headerPhrase(order: Order, now: Date, remaining: number | null): { text: string; late: boolean } | null {
  if (order.status === 'done' && remaining && remaining > 0) return { text: t('orderRemainingToReceive', { amount: money(remaining) }), late: false }
  if (order.status === 'canceled' || order.status === 'done' || !order.dueDate) return null
  const late = lateness(order, now)
  if (late) return { text: t('orderDueLatePhrase', { when: whenText(order.dueDate, now) }), late: true }
  return { text: t('orderDuePhrase', { when: whenText(order.dueDate, now) }), late: false }
}

export function lineKindText(kind: 'service' | 'product'): string {
  return kind === 'service' ? t('orderItemKindService') : t('orderItemKindPart')
}
