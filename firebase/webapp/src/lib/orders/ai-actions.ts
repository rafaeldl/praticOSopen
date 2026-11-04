// Receber, desconto e status ditos ao assistente (order.ai.money-plan): the
// app's planAiActions (lib/screens/order/assistant/ai_actions_plan.dart). The
// model returns only what was said; balance, approve-before-receive on a quote,
// the amount above the balance and the nota warning come from here. Pure: the
// card ("Confere?") shows the plan and nothing is saved before Confirmar.
import { allowedTransitions, receivePermissions } from '@/lib/rules/order-rules'
import { orderRoleOf, totals, type Order, type OrderStatus } from './model'

export interface DraftActions {
  payment: { kind: 'full' | 'value' | 'percent' | 'leaving'; value: number | null; method: 'pix' | 'cash' | 'card' | 'other' | null; paidDate: string | null } | null
  discount: { kind: 'value' | 'percent'; value: number } | null
  status: 'approved' | 'progress' | 'done' | null
}
export type NfseMoment = 'paid' | 'completed'

export type Notice =
  | { kind: 'canceled' }
  | { kind: 'cannotDiscount' }
  | { kind: 'cannotReceive' }
  | { kind: 'nothingToReceive' }
  | { kind: 'statusDenied' }
  | { kind: 'onlyLeft'; amount: number }
  | { kind: 'pendingChecklists'; count: number }

export interface ActionsContext {
  status: OrderStatus
  total: number
  remaining: number
  showMoney: boolean
  canReceive: boolean
  canDiscount: boolean
  /** May this person move the order from `from` to `to`. */
  canChangeStatus: (from: OrderStatus, to: OrderStatus) => boolean
  pendingChecklists: number
  nfseAutoIssue: NfseMoment | null
}

export interface ActionsEdits {
  discount?: number
  payment?: number
  method?: string | null
  paidDay?: string | null
}

export interface PaymentStep {
  amount: number | null
  max: number
  method: string | null
  paidDay: string | null
  /** "Pagou tudo" not edited: the current balance at saving time. */
  settlesAll: boolean
  left: number
  paysOff: boolean
}

export interface ActionsPlan {
  discount: { amount: number; max: number } | null
  approveFirst: boolean
  payment: PaymentStep | null
  status: OrderStatus | null
  notices: Notice[]
  issuesNfse: boolean
  hasSteps: boolean
  canConfirm: boolean
  types: ('payment' | 'discount' | 'status')[]
}

const CENT = 0.009
const round = (value: number) => Math.round(value * 100) / 100
const FORWARD: OrderStatus[] = ['quote', 'approved', 'progress', 'done']

export function planAiActions(actions: DraftActions, ctx: ActionsContext, edits: ActionsEdits = {}): ActionsPlan {
  const notices: Notice[] = []
  const notice = (n: Notice) => {
    if (!notices.some((x) => x.kind === n.kind)) notices.push(n)
  }
  const empty: ActionsPlan = { discount: null, approveFirst: false, payment: null, status: null, notices, issuesNfse: false, hasSteps: false, canConfirm: false, types: [] }
  if (ctx.status === 'canceled') {
    notice({ kind: 'canceled' })
    return empty
  }
  let balance = round(ctx.remaining)
  let discount: ActionsPlan['discount'] = null
  if (actions.discount && ctx.showMoney) {
    if (!ctx.canDiscount) notice({ kind: 'cannotDiscount' })
    else if (balance <= CENT) notice({ kind: 'nothingToReceive' })
    else {
      const asked = edits.discount ?? (actions.discount.kind === 'percent' ? round((ctx.total * actions.discount.value) / 100) : actions.discount.value)
      const amount = Math.min(round(asked), balance)
      if (amount > 0) {
        discount = { amount, max: balance }
        balance = round(balance - amount)
      }
    }
  }
  let approveFirst = false
  let payment: PaymentStep | null = null
  const said = actions.payment
  if (said && ctx.showMoney) {
    if (!ctx.canReceive) notice({ kind: 'cannotReceive' })
    else if (balance <= CENT) notice({ kind: 'nothingToReceive' })
    else if (ctx.status === 'quote' && !ctx.canChangeStatus('quote', 'approved')) notice({ kind: 'statusDenied' })
    else {
      approveFirst = ctx.status === 'quote'
      let amount: number | null =
        edits.payment ??
        (said.kind === 'full'
          ? balance
          : said.value === null
            ? null
            : said.kind === 'percent'
              ? round((balance * said.value) / 100)
              : said.kind === 'leaving'
                ? round(balance - said.value)
                : said.value)
      if (amount !== null && amount <= 0) amount = null
      if (amount !== null && amount > balance + CENT) {
        notice({ kind: 'onlyLeft', amount: balance })
        amount = balance
      }
      const left = amount === null ? balance : round(balance - amount)
      payment = {
        amount,
        max: balance,
        method: edits.method !== undefined ? edits.method : said.method,
        paidDay: edits.paidDay !== undefined ? edits.paidDay : said.paidDate,
        settlesAll: said.kind === 'full' && edits.payment === undefined,
        left,
        paysOff: amount !== null && left <= CENT,
      }
    }
  }
  let status: OrderStatus | null = null
  if (actions.status) {
    const current = approveFirst ? 'approved' : ctx.status
    const from = FORWARD.indexOf(current)
    const to = FORWARD.indexOf(actions.status)
    if (to > from) {
      if (!ctx.canChangeStatus(current, actions.status)) notice({ kind: 'statusDenied' })
      else if (actions.status === 'done' && ctx.pendingChecklists > 0) notice({ kind: 'pendingChecklists', count: ctx.pendingChecklists })
      else status = actions.status
    }
  }
  const issuesNfse = ctx.nfseAutoIssue === 'paid' ? !!payment?.paysOff : ctx.nfseAutoIssue === 'completed' ? status === 'done' : false
  const hasSteps = !!discount || approveFirst || !!payment || !!status
  const types: ActionsPlan['types'] = []
  if (payment) types.push('payment')
  if (discount) types.push('discount')
  if (status || approveFirst) types.push('status')
  return { discount, approveFirst, payment, status, notices, issuesNfse, hasSteps, canConfirm: hasSteps && (!payment || (payment.amount ?? 0) > 0), types }
}

/** The context of one saved order for this person (same rules as the order's own buttons). */
export function contextOf(order: Order, role: string | null | undefined, uid: string | null, useFinancial: boolean, pendingChecklists: number, nfseAutoIssue: NfseMoment | null): ActionsContext {
  const r = orderRoleOf(role)
  const isCreator = !!uid && order.createdBy?.id === uid
  const money = r ? receivePermissions(r, isCreator, useFinancial) : { canReceive: false, canDiscount: false }
  const sums = totals(order)
  return {
    status: order.status,
    total: sums.total,
    remaining: sums.remaining,
    showMoney: order.showsMoney && useFinancial,
    canReceive: money.canReceive && order.showsMoney,
    canDiscount: money.canDiscount && order.showsMoney,
    canChangeStatus: (from, to) => !!r && (allowedTransitions(r, isCreator, from) as string[]).includes(to),
    pendingChecklists,
    nfseAutoIssue,
  }
}

/** Runner steps, in the app's order (order.ai.money-run): discount, approve, payment, status. */
export type StepName = 'discount' | 'approve' | 'payment' | 'status'
export function stepsOf(plan: ActionsPlan): StepName[] {
  const steps: StepName[] = []
  if (plan.discount) steps.push('discount')
  if (plan.approveFirst) steps.push('approve')
  if (plan.payment && (plan.payment.amount ?? 0) > 0) steps.push('payment')
  if (plan.status) steps.push('status')
  return steps
}

/** The amount to send: the current balance for "pagou tudo" or when the balance went down. */
export function paymentAmount(step: PaymentStep, currentRemaining: number): number {
  const amount = step.amount ?? 0
  return step.settlesAll || amount > currentRemaining + CENT ? round(currentRemaining) : amount
}
