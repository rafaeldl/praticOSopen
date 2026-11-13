// Web checkout (issue #664, docs/WEB_CHECKOUT.md): what the Plano screen offers
// and what the checkout form allows. The server decides; the web only reads.
import { describe, expect, test, vi } from 'vitest'

const apiMock = vi.fn()
vi.mock('../src/lib/session', () => ({ api: (...args: unknown[]) => apiMock(...args) }))

import {
  billingEntry,
  cancelBilling,
  canBuy,
  methodsFor,
  monthlyEquivalent,
  startCheckout,
  type WebBillingView,
} from '../src/lib/settings/billing'
import { codeMessageKey } from '../src/lib/api'

const OFFER = {
  plans: [{ plan: 'pro' as const, prices: { monthly: 119.9 } }],
  cycles: ['monthly' as const],
  billingTypes: { monthly: ['CREDIT_CARD' as const] },
  guaranteeDays: 7,
}
const view = (partial: Partial<WebBillingView>): WebBillingView => ({ enabled: true, offer: OFFER, block: null, subscription: null, ...partial })
const SUB = {
  status: 'active' as const,
  plan: 'pro' as const,
  cycle: 'monthly' as const,
  billingType: 'CREDIT_CARD' as const,
  value: 119.9,
  paidUntil: '2026-12-19T03:00:00.000Z',
  nextDueDate: '2026-12-13',
  checkoutUrl: null,
  refundEligible: true,
}

describe('billingEntry', () => {
  test('nothing while the switch is off or the server refused', () => {
    expect(billingEntry(null)).toBe('hidden')
    expect(billingEntry(view({ enabled: false, offer: null }))).toBe('hidden')
  })

  test('store subscriber: change it in the app, no buy button', () => {
    expect(billingEntry(view({ block: 'STORE_SUBSCRIPTION_ACTIVE' }))).toBe('store')
    expect(billingEntry(view({ enabled: false, block: 'STORE_SUBSCRIPTION_ACTIVE' }))).toBe('store')
  })

  test('a web subscription is shown even after the switch goes off (cancel, refund)', () => {
    expect(billingEntry(view({ enabled: false, offer: null, subscription: SUB, block: 'WEB_SUBSCRIPTION_ACTIVE' }))).toBe('subscription')
    expect(billingEntry(view({ subscription: { ...SUB, status: 'refunded' } }))).toBe('buy')
  })

  test('outside Brazil: subscribe in the app, only while the switch is on', () => {
    expect(billingEntry(view({ block: 'OUTSIDE_BRAZIL' }))).toBe('app')
    expect(billingEntry(view({ enabled: false, offer: null, block: 'OUTSIDE_BRAZIL' }))).toBe('hidden')
    expect(canBuy(view({ block: 'OUTSIDE_BRAZIL' }))).toBe(false)
  })

  test('buy when on and free to buy', () => {
    expect(billingEntry(view({}))).toBe('buy')
  })
})

describe('checkout form', () => {
  test('only without a block', () => {
    expect(canBuy(view({}))).toBe(true)
    expect(canBuy(view({ block: 'WEB_SUBSCRIPTION_ACTIVE' }))).toBe(false)
    expect(canBuy(view({ block: 'STORE_SUBSCRIPTION_ACTIVE' }))).toBe(false)
    expect(canBuy(view({ enabled: false }))).toBe(false)
  })

  test('methods come from the server per cycle', () => {
    expect(methodsFor(OFFER, 'monthly')).toEqual(['CREDIT_CARD'])
    expect(methodsFor(OFFER, 'yearly')).toEqual([])
    expect(methodsFor(null, 'monthly')).toEqual([])
  })

  test('yearly price per month, in cents', () => {
    expect(monthlyEquivalent(599)).toBe(49.92)
    expect(monthlyEquivalent(1199)).toBe(99.92)
    expect(monthlyEquivalent(2499)).toBe(208.25)
  })

  test('calls the billing API', async () => {
    apiMock.mockResolvedValue({ checkoutUrl: 'https://sandbox.asaas.com/i/1' })
    const body = { plan: 'pro' as const, cycle: 'monthly' as const, billingType: 'CREDIT_CARD' as const, name: 'X', taxId: '11222333000181', email: 'a@b.co', postalCode: '88015100', addressNumber: '100' }
    await startCheckout(body)
    expect(apiMock).toHaveBeenCalledWith('/v1/app/billing/checkout', { method: 'POST', body })
    await cancelBilling(true)
    expect(apiMock).toHaveBeenCalledWith('/v1/app/billing/cancel', { method: 'POST', body: { refund: true } })
  })

  test('server codes have their own sentences', () => {
    expect(codeMessageKey('STORE_SUBSCRIPTION_ACTIVE')).toBe('web.error.storeSubscription')
    expect(codeMessageKey('WEB_SUBSCRIPTION_ACTIVE')).toBe('web.error.webSubscription')
    expect(codeMessageKey('OUTSIDE_BRAZIL')).toBe('web.error.outsideBrazil')
    expect(codeMessageKey('REFUND_NOT_ALLOWED')).toBe('web.error.refundExpired')
    expect(codeMessageKey('WEB_CHECKOUT_DISABLED')).toBe('web.error.checkoutClosed')
  })
})
