import {
  addCycle,
  applyWebOrigin,
  checkoutBlock,
  decideBillingAction,
  invoiceSettingsFor,
  parseWebCheckoutConfig,
  periodEndOf,
  refundEligible,
  saoPauloDate,
  storeOverlapsWeb,
  subscriptionIdOf,
  webOffer,
  type WebBillingRecord,
} from '../web-billing-rules';
import type { RcSubscriber } from '../../revenuecat.client';
import type { Subscription } from '../../../models/types';

const NOW = new Date('2026-11-13T15:00:00.000Z');
const LIMITS = { photosPerMonth: -1, formTemplates: -1, users: 5, ordersPerMonth: -1, pdfWatermark: false };
const USAGE = { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1, usageResetAt: '2026-12-01T00:00:00.000Z' };

const RECORD: WebBillingRecord = {
  status: 'active',
  plan: 'pro',
  cycle: 'monthly',
  billingType: 'CREDIT_CARD',
  value: 119.9,
  environment: 'sandbox',
  asaasCustomerId: 'cus_1',
  asaasSubscriptionId: 'sub_1',
  createdAt: '2026-11-10T12:00:00.000Z',
  createdBy: 'u1',
  firstPaidAt: '2026-11-10T12:05:00.000Z',
};

function sub(partial: Partial<Subscription>): Subscription {
  return { plan: 'pro', status: 'active', limits: LIMITS, usage: USAGE, ...partial };
}

function promoSubscriber(plan: string, store = 'promotional'): RcSubscriber {
  const product = `rc_promo_${plan}_custom`;
  return {
    entitlements: { [plan]: { expires_date: '2026-12-18T03:00:00Z', product_identifier: product, store } },
    subscriptions: {
      [product]: { store, expires_date: '2026-12-18T03:00:00Z', unsubscribe_detected_at: null, billing_issues_detected_at: null },
    },
  };
}

describe('dates', () => {
  it('São Paulo day, not UTC', () => {
    expect(saoPauloDate(new Date('2026-11-14T01:00:00Z'))).toBe('2026-11-13');
  });

  it('adds a month, clamping the 31st, and a year', () => {
    expect(addCycle('2026-11-13', 'monthly')).toBe('2026-12-13');
    expect(addCycle('2026-12-20', 'monthly')).toBe('2027-01-20');
    expect(addCycle('2027-01-31', 'monthly')).toBe('2027-02-28');
    expect(addCycle('2028-02-29', 'yearly')).toBe('2029-02-28');
    expect(addCycle('2026-11-13', 'yearly')).toBe('2027-11-13');
  });

  it('plan ends 5 days after the next due date, end of day in São Paulo', () => {
    const { nextDueDate, endMs } = periodEndOf('2026-11-13', 'monthly');
    expect(nextDueDate).toBe('2026-12-13');
    expect(new Date(endMs).toISOString()).toBe('2026-12-19T03:00:00.000Z');
  });
});

describe('config and offer', () => {
  it('everything off by default; monthly card only, yearly with Pix/boleto/card', () => {
    const config = parseWebCheckoutConfig(null);
    expect(config).toEqual({
      enabled: false,
      yearlyEnabled: false,
      billingTypes: { monthly: ['CREDIT_CARD'], yearly: ['PIX', 'BOLETO', 'CREDIT_CARD'] },
      invoice: null,
    });
  });

  it('only true turns it on; unknown methods are dropped', () => {
    const config = parseWebCheckoutConfig({ enabled: 'yes', billingTypes: { monthly: ['PIX', 'CASH'] } });
    expect(config.enabled).toBe(false);
    expect(config.billingTypes.monthly).toEqual(['PIX']);
  });

  it('yearly is offered only when yearlyEnabled (store parity)', () => {
    const monthlyOnly = webOffer(parseWebCheckoutConfig({ enabled: true }));
    expect(monthlyOnly.cycles).toEqual(['monthly']);
    expect(monthlyOnly.plans.find((p) => p.plan === 'pro')?.prices).toEqual({ monthly: 119.9 });
    const both = webOffer(parseWebCheckoutConfig({ enabled: true, yearlyEnabled: true }));
    expect(both.plans.map((p) => p.prices)).toEqual([
      { monthly: 59.9, yearly: 599 },
      { monthly: 119.9, yearly: 1199 },
      { monthly: 249.9, yearly: 2499 },
    ]);
    expect(both.guaranteeDays).toBe(7);
  });

  it('invoice config: service name with its id or code, and an ISS rate; anything else is off', () => {
    const name = 'Licenciamento de programas';
    expect(parseWebCheckoutConfig({}).invoice).toBeNull();
    expect(parseWebCheckoutConfig({ invoice: { municipalServiceId: 'svc_1', municipalServiceName: name } }).invoice).toBeNull();
    expect(parseWebCheckoutConfig({ invoice: { municipalServiceId: 'svc_1', iss: 2 } }).invoice).toBeNull();
    expect(parseWebCheckoutConfig({ invoice: { municipalServiceName: name, iss: 2 } }).invoice).toBeNull();
    expect(parseWebCheckoutConfig({ invoice: { municipalServiceId: 'svc_1', municipalServiceName: name, iss: 40 } }).invoice).toBeNull();
    expect(parseWebCheckoutConfig({ invoice: { municipalServiceId: ' svc_1 ', municipalServiceName: name, iss: 2, observations: '' } }).invoice).toEqual({
      municipalServiceId: 'svc_1',
      iss: 2,
      municipalServiceCode: undefined,
      municipalServiceName: name,
      federalServiceTaxCode: undefined,
      nbsCode: undefined,
      observations: undefined,
    });
  });

  it('invoice settings: one NFS-e per paid charge, no retention, only the fields given', () => {
    expect(invoiceSettingsFor({ municipalServiceCode: '1.05', municipalServiceName: 'Licenciamento', iss: 2, nbsCode: '1.1502' })).toEqual({
      municipalServiceCode: '1.05',
      municipalServiceName: 'Licenciamento',
      effectiveDatePeriod: 'ON_PAYMENT_CONFIRMATION',
      receivedOnly: true,
      deductions: 0,
      updatePayment: false,
      taxes: { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0, nbsCode: '1.1502' },
    });
  });
});

describe('checkoutBlock', () => {
  it('blocks a store subscription in force', () => {
    expect(checkoutBlock(sub({ source: 'store', store: 'app_store', expiresAt: '2026-12-01T00:00:00Z' }), null, NOW)).toBe(
      'STORE_SUBSCRIPTION_ACTIVE',
    );
    expect(checkoutBlock(sub({ source: 'store', store: 'play_store', status: 'cancelled', expiresAt: '2026-12-01T00:00:00Z' }), null, NOW)).toBe(
      'STORE_SUBSCRIPTION_ACTIVE',
    );
  });

  it('lets an expired store plan, the courtesy and Free buy', () => {
    expect(checkoutBlock(sub({ source: 'store', store: 'app_store', expiresAt: '2026-11-01T00:00:00Z' }), null, NOW)).toBeNull();
    expect(checkoutBlock(sub({ source: 'grace', store: null, expiresAt: '2026-12-07T00:00:00Z' }), null, NOW)).toBeNull();
    expect(checkoutBlock(sub({ plan: 'free' }), null, NOW)).toBeNull();
    expect(checkoutBlock(undefined, null, NOW)).toBeNull();
  });

  it('blocks a second web subscription while one renews; a cancelled one may buy again', () => {
    const web = sub({ source: 'store', store: 'web', expiresAt: '2026-12-18T03:00:00Z' });
    expect(checkoutBlock(web, RECORD, NOW)).toBe('WEB_SUBSCRIPTION_ACTIVE');
    expect(checkoutBlock(web, { ...RECORD, status: 'cancelled' }, NOW)).toBeNull();
    expect(checkoutBlock(undefined, { ...RECORD, status: 'pending' }, NOW)).toBeNull();
  });

  it('sends companies outside Brazil to the app; no country counts as Brazil', () => {
    expect(checkoutBlock(undefined, null, NOW, 'US')).toBe('OUTSIDE_BRAZIL');
    expect(checkoutBlock(undefined, null, NOW, 'pt')).toBe('OUTSIDE_BRAZIL');
    expect(checkoutBlock(undefined, null, NOW, 'BR')).toBeNull();
    expect(checkoutBlock(undefined, null, NOW, 'br')).toBeNull();
    expect(checkoutBlock(undefined, null, NOW, null)).toBeNull();
    expect(checkoutBlock(undefined, null, NOW, '')).toBeNull();
  });

  it('a store or renewing web subscriber abroad keeps the block that lets them manage it', () => {
    expect(checkoutBlock(sub({ source: 'store', store: 'app_store', expiresAt: '2026-12-01T00:00:00Z' }), null, NOW, 'US')).toBe(
      'STORE_SUBSCRIPTION_ACTIVE',
    );
    expect(checkoutBlock(sub({ source: 'store', store: 'web', expiresAt: '2026-12-18T03:00:00Z' }), RECORD, NOW, 'US')).toBe(
      'WEB_SUBSCRIPTION_ACTIVE',
    );
  });
});

describe('refundEligible (7-day guarantee)', () => {
  it('within 7 days of the first payment', () => {
    expect(refundEligible(RECORD, NOW)).toBe(true);
    expect(refundEligible({ ...RECORD, status: 'cancelled' }, NOW)).toBe(true);
  });
  it('not after 7 days, not unpaid, not refunded', () => {
    expect(refundEligible({ ...RECORD, firstPaidAt: '2026-11-06T14:59:00.000Z' }, NOW)).toBe(false);
    expect(refundEligible({ ...RECORD, status: 'pending', firstPaidAt: undefined }, NOW)).toBe(false);
    expect(refundEligible({ ...RECORD, status: 'refunded' }, NOW)).toBe(false);
    expect(refundEligible(null, NOW)).toBe(false);
  });
});

describe('decideBillingAction', () => {
  const paid = (event: string, extra: Record<string, unknown> = {}) => ({
    id: 'evt_1',
    event,
    payment: { id: 'pay_1', subscription: 'sub_1', value: 119.9, dueDate: '2026-11-13', ...extra },
  });

  it('confirmed and received grant until next due date + grace', () => {
    for (const name of ['PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED']) {
      expect(decideBillingAction(paid(name), RECORD)).toEqual({
        kind: 'grant',
        paymentId: 'pay_1',
        dueDate: '2026-11-13',
        nextDueDate: '2026-12-13',
        endMs: Date.parse('2026-12-19T03:00:00.000Z'),
        value: 119.9,
      });
    }
  });

  it('yearly grants a year', () => {
    const action = decideBillingAction(paid('PAYMENT_CONFIRMED'), { ...RECORD, cycle: 'yearly' });
    expect(action).toMatchObject({ kind: 'grant', nextDueDate: '2027-11-13' });
  });

  it('never grants a refunded payment again', () => {
    const record = { ...RECORD, payments: { pay_1: { status: 'refunded' as const, value: 119.9, dueDate: '2026-11-13' } } };
    expect(decideBillingAction(paid('PAYMENT_RECEIVED'), record).kind).toBe('none');
    expect(decideBillingAction(paid('PAYMENT_RECEIVED'), { ...RECORD, status: 'refunded' }).kind).toBe('none');
  });

  it('refund and chargeback revoke; overdue does nothing', () => {
    expect(decideBillingAction(paid('PAYMENT_REFUNDED'), RECORD)).toEqual({ kind: 'revoke', paymentId: 'pay_1', reason: 'refund' });
    expect(decideBillingAction(paid('PAYMENT_CHARGEBACK_REQUESTED'), RECORD)).toEqual({
      kind: 'revoke',
      paymentId: 'pay_1',
      reason: 'chargeback',
    });
    expect(decideBillingAction(paid('PAYMENT_OVERDUE'), RECORD).kind).toBe('none');
    expect(decideBillingAction(paid('PAYMENT_CREATED'), RECORD).kind).toBe('none');
  });

  it('subscription deleted marks cancelled once', () => {
    const event = { id: 'evt_2', event: 'SUBSCRIPTION_DELETED', subscription: { id: 'sub_1' } };
    expect(decideBillingAction(event, RECORD)).toEqual({ kind: 'markCancelled' });
    expect(decideBillingAction(event, { ...RECORD, status: 'cancelled' }).kind).toBe('none');
  });

  it('finds the subscription id in the payment or the subscription', () => {
    expect(subscriptionIdOf(paid('PAYMENT_CONFIRMED'))).toBe('sub_1');
    expect(subscriptionIdOf({ id: 'e', event: 'SUBSCRIPTION_DELETED', subscription: { id: 'sub_9' } })).toBe('sub_9');
    expect(subscriptionIdOf({ id: 'e', event: 'PAYMENT_CONFIRMED', payment: { id: 'p' } })).toBeNull();
    expect(subscriptionIdOf({ id: 'e', event: 'X', payment: { id: 'p', subscription: '../x' } })).toBeNull();
  });
});

describe('applyWebOrigin', () => {
  const state = { plan: 'pro' as const, status: 'active' as const, expiresAt: '2026-12-18T03:00:00Z', store: null };

  it('promotional backed by the web record → store web', () => {
    expect(applyWebOrigin(state, promoSubscriber('pro'), RECORD)).toEqual({ ...state, store: 'web' });
  });

  it('cancelled web record → status cancelled (valid until the end)', () => {
    expect(applyWebOrigin(state, promoSubscriber('pro'), { ...RECORD, status: 'cancelled' })).toEqual({
      ...state,
      store: 'web',
      status: 'cancelled',
    });
  });

  it('a promotional granted by hand stays as it was', () => {
    expect(applyWebOrigin(state, promoSubscriber('pro'), null)).toBe(state);
    expect(applyWebOrigin(state, promoSubscriber('pro'), { ...RECORD, plan: 'starter' })).toBe(state);
    expect(applyWebOrigin(state, promoSubscriber('pro'), { ...RECORD, status: 'refunded' })).toBe(state);
    expect(applyWebOrigin(state, promoSubscriber('pro'), { ...RECORD, status: 'pending' })).toBe(state);
  });

  it('a store plan is never turned into web', () => {
    const store = { ...state, store: 'app_store' as const };
    expect(applyWebOrigin(store, promoSubscriber('pro', 'app_store'), RECORD)).toBe(store);
    expect(storeOverlapsWeb(store, RECORD)).toBe(true);
    expect(storeOverlapsWeb(store, { ...RECORD, status: 'cancelled' })).toBe(false);
    expect(storeOverlapsWeb(state, RECORD)).toBe(false);
  });
});
