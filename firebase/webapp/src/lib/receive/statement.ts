// "Mandar extrato" (pay.customer.statement): what a customer still owes, order
// by order, as a WhatsApp message and a PDF. The same content as the app
// (lib/services/pdf/customer_statement_pdf.dart). Pure: texts come resolved, so
// vitest covers it without i18n.
import type { Order } from '@/lib/orders/model'
import { toCents, type OpenOrder } from './model'

export interface StatementItem {
  name: string
  quantity: number
  /** Line total (quantity × unit value). */
  value: number
}

export interface StatementOrder {
  number: number | null
  /** ISO date the order was opened. */
  date: string | null
  /** Concluída, still being done, or null when the status was not read (someone else's order). */
  completed: boolean | null
  /** "Fiat Uno · ABC-1234", several joined with ", ", or the first service. */
  device: string | null
  items: StatementItem[]
  discount: number
  total: number
  paid: number
  open: number
}

const round = (value: number) => Math.round(value * 100) / 100

/** A full order (read with values). */
export function statementOrderOf(order: Order): StatementOrder {
  const items = order.lines
    .filter((line) => line.name.trim() || (line.total ?? line.value ?? 0) > 0)
    .map((line) => {
      const quantity = line.kind === 'product' ? (line.quantity ?? 1) : 1
      return { name: line.name.trim(), quantity, value: line.total ?? (line.value ?? 0) * quantity }
    })
  const devices = order.devices.map((d) => [d.name?.trim(), d.serial?.trim()].filter(Boolean).join(' · ')).filter(Boolean)
  const firstService = order.lines.find((line) => line.kind === 'service' && line.name.trim())?.name.trim() ?? null
  const total = order.total ?? 0
  const paid = Math.min(order.paidAmount ?? 0, total)
  return {
    number: order.number ?? null,
    date: order.createdAt ?? null,
    completed: order.status === 'done',
    device: devices.length ? devices.join(', ') : firstService,
    items,
    discount: order.discount ?? 0,
    total,
    paid,
    open: Math.max(round(total - paid), 0),
  }
}

/** An order known only by number, date and balance (someone else's, or not readable). */
export function statementLightOf(order: OpenOrder): StatementOrder {
  return { number: order.number, date: order.createdAt, completed: null, device: null, items: [], discount: 0, total: order.open, paid: 0, open: order.open }
}

export const statementTotal = (orders: readonly StatementOrder[]): number => orders.reduce((sum, o) => sum + toCents(o.open), 0) / 100

export interface StatementTexts {
  hello: (name: string) => string
  orderNumber: (number: string) => string
  openLine: (amount: string) => string
  inProgress: string
  totalOpen: (amount: string) => string
  money: (value: number) => string
  /** Day and month (dd/mm) for the message. */
  dayMonth: (iso: string) => string
}

/** The WhatsApp message: hello, one block per order and the total owed. */
export function statementText(orders: readonly StatementOrder[], texts: StatementTexts, customerName: string): string {
  const lines = [texts.hello(customerName)]
  for (const order of orders) {
    const head = [
      texts.orderNumber(order.number === null ? '-' : String(order.number)),
      order.date ? texts.dayMonth(order.date) : '',
      order.device ?? '',
      order.completed === false ? texts.inProgress : '',
    ].filter(Boolean)
    lines.push('', head.join(' · '), texts.openLine(texts.money(order.open)))
  }
  lines.push('', texts.totalOpen(texts.money(statementTotal(orders))))
  return lines.join('\n')
}
