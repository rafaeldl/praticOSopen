// Order rules shared with the app and the API. docs/web-app/contract-cases/ is
// the contract: tests/contract-cases.test.ts runs it here, following `correct`
// when a case documents an app bug. Delete what moves to the API.
export type OrderRole = 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician'

const STATUSES = ['quote', 'approved', 'progress', 'done', 'canceled']

/** Half away from zero, like Dart's roundToDouble. Math.round alone differs below zero. */
export function roundMoney(value: number): number {
  return (Math.sign(value) * Math.round(Math.abs(value) * 100)) / 100
}

export interface ProductLine {
  value?: number | null
  quantity?: number | null
  total?: number | null
}
export interface ServiceLine {
  value?: number | null
}

export function productLineTotal(product: ProductLine): number | null {
  if (product.value === null || product.value === undefined) return null
  return product.total ?? product.value * (product.quantity ?? 1)
}

export function orderTotal(
  services: ServiceLine[],
  products: ProductLine[],
  discount = 0,
): { total: number; unpricedCount: number } {
  let sum = 0
  let unpricedCount = 0
  for (const service of services) {
    if (service.value === null || service.value === undefined) unpricedCount++
    else sum += service.value
  }
  for (const product of products) {
    const line = productLineTotal(product)
    if (line === null) unpricedCount++
    else sum += line
  }
  return { total: Math.max(0, roundMoney(sum - discount)), unpricedCount }
}

export function paymentStatus(
  status: string | null | undefined,
  total: number,
  paidAmount: number,
): { payment: 'paid' | 'unpaid' | null; paid: boolean } {
  if (status === 'quote' || status === 'canceled') return { payment: null, paid: false }
  const paid = total > 0 && roundMoney(paidAmount) >= roundMoney(total)
  return { payment: paid ? 'paid' : 'unpaid', paid }
}

export function remainingBalance(total: number, paidAmount: number): number {
  return Math.max(0, roundMoney(total - paidAmount))
}

export interface Transaction {
  id?: string
  type: 'payment' | 'discount'
  amount: number
}
export interface OrderState {
  status?: string | null
  services: ServiceLine[]
  products: ProductLine[]
  total: number
  discount: number
  paidAmount: number
  payment?: string | null
  transactions: Transaction[]
}
export type PaymentOp =
  | { kind: 'addPayment'; amount: number }
  | { kind: 'addDiscount'; amount: number }
  | { kind: 'removeTransaction'; transactionId: string }
  | { kind: 'resetPayments' }
  | { kind: 'markAsFullyPaid' }

const isAsaas = (transaction: Transaction) => (transaction.id ?? '').startsWith('asaas_')
const netTotal = (order: OrderState, discount: number) =>
  Math.max(0, orderTotal(order.services, order.products, discount).total)

export function applyPaymentOp(order: OrderState, op: PaymentOp) {
  let { total, discount, paidAmount, transactions } = order
  let forcePaid = false
  switch (op.kind) {
    case 'addPayment':
      // Never above what is left to receive, compared in cents (POST /:id/payments refuses too).
      if (Math.round(op.amount * 100) > Math.round(remainingBalance(total, paidAmount) * 100)) {
        return { error: 'exceedsBalance' as const }
      }
      paidAmount = roundMoney(paidAmount + op.amount)
      transactions = [...transactions, { type: 'payment', amount: op.amount }]
      break
    case 'addDiscount':
      discount = roundMoney(discount + op.amount)
      total = netTotal(order, discount)
      transactions = [...transactions, { type: 'discount', amount: op.amount }]
      break
    case 'removeTransaction': {
      const target = transactions.find((transaction) => transaction.id === op.transactionId)
      if (!target) break
      if (isAsaas(target)) return { error: 'asaasLocked' as const }
      transactions = transactions.filter((transaction) => transaction !== target)
      if (target.type === 'payment') paidAmount = Math.max(0, roundMoney(paidAmount - target.amount))
      else {
        discount = Math.max(0, roundMoney(discount - target.amount))
        total = netTotal(order, discount)
      }
      break
    }
    case 'resetPayments':
      transactions = transactions.filter(isAsaas)
      paidAmount = roundMoney(
        transactions.reduce((sum, transaction) => sum + (transaction.type === 'payment' ? transaction.amount : 0), 0),
      )
      discount = 0
      total = netTotal(order, 0)
      break
    case 'markAsFullyPaid': {
      const remaining = remainingBalance(total, paidAmount)
      if (remaining > 0) {
        paidAmount = roundMoney(paidAmount + remaining)
        transactions = [...transactions, { type: 'payment', amount: remaining }]
      }
      forcePaid = true
      break
    }
  }
  const status = forcePaid ? { payment: 'paid' as const, paid: true } : paymentStatus(order.status, total, paidAmount)
  return { total, discount, paidAmount, ...status, remaining: remainingBalance(total, paidAmount), transactions }
}

export function allowedTransitions(role: OrderRole, isCreator: boolean, from: string): string[] {
  if ((role === 'consultant' || role === 'technician') && !isCreator) return []
  if (role === 'admin' || role === 'manager') return STATUSES.filter((status) => status !== from)
  if (role === 'consultant') return from === 'quote' ? ['approved', 'canceled'] : []
  if (from === 'quote') return isCreator ? ['approved', 'progress'] : []
  if (from === 'approved') return ['progress', 'done']
  if (from === 'progress') return ['done']
  return []
}

export function orderPermissions(role: OrderRole, isCreator: boolean, status: string) {
  const canAccess = !(role === 'consultant' || role === 'technician') || isCreator
  const quote = status === 'quote'
  const full = role === 'admin' || role === 'manager' || role === 'consultant'
  return {
    canAccess,
    canEdit: canAccess,
    canExecute: canAccess && role !== 'manager' && role !== 'consultant',
    canAssign: canAccess && (role === 'admin' || role === 'supervisor'),
    canDelete: canAccess && (role === 'admin' || quote),
    canEditMainFields: canAccess && (full || quote),
    canManageForms: canAccess && (full || (role === 'supervisor' ? status !== 'done' && status !== 'canceled' : quote)),
  }
}

/** "Receber" and "Dar desconto" (contract order-receive.json). `owner` is read as admin. */
export function receivePermissions(role: string, isCreator: boolean, useFinancial: boolean) {
  const r = role === 'owner' ? 'admin' : role
  const finance = useFinancial && (r === 'admin' || r === 'manager')
  return { canReceive: finance || (useFinancial && r === 'consultant' && isCreator), canDiscount: finance }
}

/** Local calendar day as a number (yyyymmdd), so two instants compare by day only. */
export function dayKey(date: Date): number {
  return date.getFullYear() * 10000 + (date.getMonth() + 1) * 100 + date.getDate()
}

/**
 * Late: the promised day is behind today and the order is not done or canceled.
 * By day, never by minute, in the list and in the order (contract overdue.json).
 */
export function isOverdue(status: string | null | undefined, dueDate: string | Date | null | undefined, now: Date): boolean {
  if (!dueDate || status === 'done' || status === 'canceled') return false
  const due = dueDate instanceof Date ? dueDate : new Date(dueDate)
  if (Number.isNaN(due.getTime())) return false
  return dayKey(due) < dayKey(now)
}
