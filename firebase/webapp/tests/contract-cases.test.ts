// Runs docs/web-app/contract-cases/ against src/lib/rules/order-rules.ts and src/lib/plan-limits.ts.
// A case with `correct` documents an app bug: the web follows `correct`.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test } from 'vitest'
import {
  allowedTransitions,
  applyPaymentOp,
  orderPermissions,
  orderTotal,
  paymentStatus,
  remainingBalance,
  receivePermissions,
  isOverdue,
} from '../src/lib/rules/order-rules'
import { periodOf } from '../src/lib/finance/period'
import { isOpen } from '../src/lib/orders/model'
import { checkPlanLimit, orderMonthKey, planInForce, shouldShowPdfWatermark } from '../src/lib/plan-limits'
import { planOverview } from '../src/lib/plan-overview'
import { checkPlanFeature, featureForRole } from '../src/lib/plan-features'

const dir = resolve(process.cwd(), '../../docs/web-app/contract-cases')
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const cases = (file: string): any[] => JSON.parse(readFileSync(resolve(dir, file), 'utf8')).cases

describe('order-totals', () => {
  test.each(cases('order-totals.json'))('$id', (c) => {
    const want = c.correct ?? c.expect
    const got = orderTotal(c.given.services, c.given.products, c.given.discount)
    expect(got).toEqual({ total: want.total, unpricedCount: want.unpricedCount })
  })
})

describe('payment-status', () => {
  test.each(cases('payment-status.json'))('$id', (c) => {
    const { status, total, paidAmount } = c.given
    expect({ ...paymentStatus(status, total, paidAmount), remaining: remainingBalance(total, paidAmount) }).toEqual(
      c.expect,
    )
  })
})

describe('payment-transactions', () => {
  test.each(cases('payment-transactions.json'))('$id', (c) => {
    const want = c.correct ?? c.expect
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const got: any = applyPaymentOp(c.given.order, c.given.op)
    if (want.error) {
      expect(got.error).toBe(want.error)
      return
    }
    const { transactionIds, transactionCount, ...values } = want
    const { transactions, ...rest } = got
    expect(rest).toEqual(values)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    if (transactionIds) expect(transactions.map((t: any) => t.id)).toEqual(transactionIds)
    if (transactionCount !== undefined) expect(transactions).toHaveLength(transactionCount)
  })
})

describe('status-transitions', () => {
  test.each(cases('status-transitions.json'))('$id', (c) => {
    const { role, isCreator, from } = c.given
    expect([...allowedTransitions(role, isCreator, from)].sort()).toEqual([...c.expect.allowed].sort())
  })
})

describe('order-receive', () => {
  test.each(cases('order-receive.json'))('$id', (c) => {
    const want = c.correct ?? c.expect
    expect(receivePermissions(c.given.role, c.given.isCreator, c.given.useFinancial)).toEqual(want)
  })
})

describe('overdue', () => {
  test.each(cases('overdue.json'))('$id', (c) => {
    const want = c.correct ?? c.expect
    expect(isOverdue(c.given.status, c.given.dueDate, new Date(c.given.now))).toBe(want.overdue)
  })
})

describe('order-permissions', () => {
  test.each(cases('order-permissions.json'))('$id', (c) => {
    expect(orderPermissions(c.given.role, c.given.isCreator, c.given.status)).toEqual(c.expect)
  })
})

describe('finance-period', () => {
  test.each(cases('finance-period.json'))('$id', (c) => {
    expect(periodOf(c.given.kind, c.given.offset, c.given.today)).toEqual(c.correct ?? c.expect)
  })
})

// Clientes comes from the server (functions runs the whole case); here the Início of the web must
// count "em aberto" and "atrasada" the same way, so the two screens say the same number.
describe('customer-summary (Início do web)', () => {
  test.each(cases('customer-summary.json'))('$id', (c) => {
    const now = new Date(c.given.now)
    const got: Record<string, { open: number; late: number }> = {}
    for (const o of c.given.orders) {
      if (!o.customer || !isOpen(o)) continue
      const row = (got[o.customer] ??= { open: 0, late: 0 })
      row.open++
      if (isOverdue(o.status, o.dueDate, now)) row.late++
    }
    const want = c.correct ?? c.expect
    const expected = Object.fromEntries(
      Object.entries<{ open: number; late: number }>(want.customers)
        .filter(([, v]) => v.open > 0)
        .map(([id, v]) => [id, { open: v.open, late: v.late }]),
    )
    expect(got).toEqual(expected)
  })
})

// Same cases as the app (test/contract/plan_limits_cases_test.dart) and the server
// (plan-limits.cases.test.ts): the web reads the subscription with src/lib/plan-limits.ts.
describe('plan-limits', () => {
  const DAY_MS = 24 * 60 * 60 * 1000
  const doc = JSON.parse(readFileSync(resolve(dir, 'plan-limits.json'), 'utf8'))

  test('runs in web', () => expect(doc.runsIn).toContain('web'))

  test.each(cases('plan-limits.json'))('$id', (c) => {
    const { given } = c
    const want = { ...(c.correct ?? c.expect), ...c.divergesIn?.web }
    const now = new Date()
    const subscription =
      given.subscription === null || given.expiresInDays === undefined
        ? given.subscription
        : { ...given.subscription, expiresAt: new Date(now.getTime() + given.expiresInDays * DAY_MS).toISOString() }
    if (given.kind === 'watermark') {
      expect({ watermark: shouldShowPdfWatermark(subscription, given.paidPlansEnabled, now) }).toEqual(want)
      return
    }
    if (given.kind === 'planInForce') {
      const { plan, version, row } = planInForce(subscription, now)
      const got: Record<string, unknown> = { plan, version, ...row }
      expect(Object.fromEntries(Object.keys(want).map((key) => [key, got[key]]))).toEqual(want)
      return
    }
    const result: Record<string, unknown> = { ...checkPlanLimit({ subscription, resource: given.resource, usage: given.usage, adding: given.adding, lastMonthUsage: given.lastMonthUsage, enforced: given.paidPlansEnabled, now }) }
    expect(Object.fromEntries(Object.keys(want).map((key) => [key, result[key]]))).toEqual(want)
  })
})

// Features of each plan (#724): the same cases as the app (plan_features_cases_test.dart)
// and the server (plan-features.service.test.ts), over src/lib/plan-features.ts.
describe('plan-features', () => {
  const DAY_MS = 24 * 60 * 60 * 1000
  const doc = JSON.parse(readFileSync(resolve(dir, 'plan-features.json'), 'utf8'))

  test('runs in web', () => expect(doc.runsIn).toContain('web'))

  test.each(cases('plan-features.json'))('$id', (c) => {
    const { given } = c
    const want = { ...(c.correct ?? c.expect), ...c.divergesIn?.web }
    if (given.kind === 'role') {
      expect({ feature: featureForRole(given.role) }).toEqual(want)
      return
    }
    const now = new Date()
    const subscription =
      given.subscription === null || given.expiresInDays === undefined
        ? given.subscription
        : { ...given.subscription, expiresAt: new Date(now.getTime() + given.expiresInDays * DAY_MS).toISOString() }
    const result: Record<string, unknown> = { ...checkPlanFeature({ subscription, feature: given.feature, enforced: given.paidPlansEnabled, now }) }
    expect(Object.fromEntries(Object.keys(want).map((key) => [key, result[key]]))).toEqual(want)
  })
})

// Same cases as the app (test/contract/plan_overview_cases_test.dart): the Plan screen (#725).
describe('plan-overview', () => {
  const DAY_MS = 24 * 60 * 60 * 1000
  const doc = JSON.parse(readFileSync(resolve(dir, 'plan-overview.json'), 'utf8'))

  test('runs in web', () => expect(doc.runsIn).toContain('web'))

  test.each(cases('plan-overview.json'))('$id', (c) => {
    const { given } = c
    const now = new Date()
    const subscription = {
      ...given.subscription,
      ...(given.expiresInDays === undefined ? {} : { expiresAt: new Date(now.getTime() + given.expiresInDays * DAY_MS).toISOString() }),
      usage: { ordersMonth: orderMonthKey(now), ordersThisMonth: given.orders.thisMonth, ordersLastMonth: given.orders.lastMonth },
    }
    const got = planOverview({ subscription, people: given.people, cnpjs: given.cnpjs, enforced: given.paidPlansEnabled, now })
    expect({
      plan: got.plan,
      rows: got.rows,
      notice: got.notice === null ? null : { kind: got.notice, resource: got.notice.startsWith('orders') ? 'orders' : 'people' },
      next: got.next,
    }).toEqual(c.expect)
  })
})
