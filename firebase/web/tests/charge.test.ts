import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  getChargeView,
  formatChargeDueDate,
  shouldRefreshCharge,
  isSafeInvoiceUrl,
  type PublicOrderCharge,
} from '../utils/charge.ts'

const pending: PublicOrderCharge = {
  status: 'pending',
  value: 150.5,
  dueDate: '2026-10-07',
  mode: 'single',
  invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
}

test('pending charge renders the pay button with the invoice url', () => {
  assert.deepEqual(getChargeView(pending), {
    kind: 'pay',
    value: 150.5,
    dueDate: '2026-10-07',
    invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    installmentCount: null,
  })
})

test('card installments expose the installment count', () => {
  const view = getChargeView({ ...pending, mode: 'cardInstallments', installmentCount: 3 })
  assert.equal(view.kind, 'pay')
  assert.equal(view.kind === 'pay' ? view.installmentCount : 0, 3)
})

test('pending charge with an unsafe invoice url renders nothing', () => {
  assert.deepEqual(getChargeView({ ...pending, invoiceUrl: 'javascript:alert(1)' }), { kind: 'none' })
  assert.deepEqual(getChargeView({ ...pending, invoiceUrl: 'http://asaas.com/i/x' }), { kind: 'none' })
  assert.deepEqual(getChargeView({ ...pending, invoiceUrl: 'https://evil.example.com/i/x' }), { kind: 'none' })
})

test('isSafeInvoiceUrl accepts only https on asaas.com or its subdomains', () => {
  assert.equal(isSafeInvoiceUrl('https://asaas.com/i/x'), true)
  assert.equal(isSafeInvoiceUrl('https://www.asaas.com/i/x'), true)
  assert.equal(isSafeInvoiceUrl('https://sandbox.asaas.com/i/x'), true)
  assert.equal(isSafeInvoiceUrl('https://evil.example.com/asaas.com'), false)
  assert.equal(isSafeInvoiceUrl('https://asaas.com.evil.io/i/x'), false)
  assert.equal(isSafeInvoiceUrl('https://notasaas.com/i/x'), false)
  assert.equal(isSafeInvoiceUrl('https://asaas.com@evil.io/i/x'), false)
  assert.equal(isSafeInvoiceUrl('http://asaas.com/i/x'), false)
  assert.equal(isSafeInvoiceUrl(''), false)
  assert.equal(isSafeInvoiceUrl(undefined), false)
})

test('overdue and paid charges render their messages', () => {
  assert.deepEqual(getChargeView({ ...pending, status: 'overdue' }), { kind: 'overdue' })
  assert.deepEqual(getChargeView({ ...pending, status: 'paid' }), { kind: 'paid', value: pending.value })
})

test('missing charge renders nothing', () => {
  assert.deepEqual(getChargeView(null), { kind: 'none' })
  assert.deepEqual(getChargeView(undefined), { kind: 'none' })
})

test('formats the due date per language without timezone shift', () => {
  assert.equal(formatChargeDueDate('2026-10-07', 'pt'), '07/10/2026')
  assert.equal(formatChargeDueDate('2026-10-07', 'en'), '10/07/2026')
  assert.equal(formatChargeDueDate('2026-10-07', 'es'), '07/10/2026')
  assert.equal(formatChargeDueDate('invalid', 'pt'), 'invalid')
})

test('refreshes only while the charge can still change', () => {
  assert.equal(shouldRefreshCharge(pending), true)
  assert.equal(shouldRefreshCharge({ ...pending, status: 'overdue' }), true)
  assert.equal(shouldRefreshCharge({ ...pending, status: 'paid' }), false)
  assert.equal(shouldRefreshCharge(null), false)
})
