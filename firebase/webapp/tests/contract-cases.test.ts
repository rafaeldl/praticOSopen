// Runs docs/web-app/contract-cases/ against src/lib/rules/order-rules.ts.
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
