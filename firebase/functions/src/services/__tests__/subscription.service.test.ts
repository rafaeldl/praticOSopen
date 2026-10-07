jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { expireSubscriptions, resetMonthlyUsage, syncCompanySubscription } from '../subscription.service';
import { PLAN_LIMITS } from '../subscription-plans';
import type { RcSubscriber, RcSubscription } from '../revenuecat.client';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

const NOW = new Date('2026-10-07T12:00:00.000Z');
const FUTURE = '2026-11-07T12:00:00Z';
const PAST = '2026-10-01T12:00:00Z';
const USAGE = { photosThisMonth: 12, formTemplatesActive: 2, usersActive: 3, usageResetAt: '2026-11-01T00:00:00.000Z' };
const EMPTY: RcSubscriber = { entitlements: {}, subscriptions: {}, original_app_user_id: 'c1' };
const GRACE = {
  plan: 'pro',
  status: 'active',
  source: 'grace',
  store: null,
  expiresAt: FUTURE,
  limits: PLAN_LIMITS.pro,
  usage: USAGE,
};

function activeSubscriber(plan: 'starter' | 'pro' | 'business', overrides: Partial<RcSubscription> = {}): RcSubscriber {
  const product = `praticos_${plan}_monthly`;
  return {
    original_app_user_id: 'c1',
    entitlements: { [plan]: { expires_date: FUTURE, product_identifier: product, store: 'app_store' } },
    subscriptions: {
      [product]: {
        unsubscribe_detected_at: null,
        billing_issues_detected_at: null,
        store: 'app_store',
        expires_date: FUTURE,
        ...overrides,
      },
    },
  };
}

function seedCompany(id: string, subscription?: Record<string, unknown>) {
  fake.seed(`companies/${id}`, { name: `Company ${id}`, ...(subscription ? { subscription } : {}) });
}

function subscriptionOf(id: string) {
  return fake.read(`companies/${id}`)?.subscription as Record<string, unknown> | undefined;
}

describe('syncCompanySubscription', () => {
  beforeEach(() => fake.reset());

  it('returns company_not_found without calling RevenueCat', async () => {
    const fetchSubscriber = jest.fn();

    await expect(syncCompanySubscription('missing', { fetchSubscriber, now: NOW })).resolves.toBe('company_not_found');
    expect(fetchSubscriber).not.toHaveBeenCalled();
  });

  it('writes the plan fields from RevenueCat and keeps usage', async () => {
    seedCompany('c1', { plan: 'free', status: 'active', limits: PLAN_LIMITS.free, usage: USAGE });
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('pro'));

    await expect(syncCompanySubscription('c1', { fetchSubscriber, now: NOW })).resolves.toBe('updated');

    expect(fetchSubscriber).toHaveBeenCalledWith('c1');
    expect(subscriptionOf('c1')).toEqual({
      plan: 'pro',
      status: 'active',
      source: 'store',
      store: 'app_store',
      expiresAt: FUTURE,
      limits: PLAN_LIMITS.pro,
      rcSubscriberId: 'c1',
      updatedAt: NOW.toISOString(),
      usage: USAGE,
    });
    expect(fake.read('companies/c1')?.name).toBe('Company c1');
  });

  it('keeps the plan as cancelled until expiresAt', async () => {
    seedCompany('c1', { plan: 'starter', status: 'active', source: 'store', usage: USAGE });
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('starter', { unsubscribe_detected_at: PAST }));

    await syncCompanySubscription('c1', { fetchSubscriber, now: NOW });

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'starter', status: 'cancelled', expiresAt: FUTURE, usage: USAGE });
  });

  it('marks billing issues as past_due', async () => {
    seedCompany('c1', { plan: 'pro', status: 'active', source: 'store', usage: USAGE });
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('pro', { billing_issues_detected_at: PAST }));

    await syncCompanySubscription('c1', { fetchSubscriber, now: NOW });

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'pro', status: 'past_due' });
  });

  it('drops to Free/expired without an active entitlement', async () => {
    seedCompany('c1', { plan: 'pro', status: 'active', source: 'store', expiresAt: PAST, limits: PLAN_LIMITS.pro, usage: USAGE });
    const fetchSubscriber = jest.fn().mockResolvedValue(EMPTY);

    await expect(syncCompanySubscription('c1', { fetchSubscriber, now: NOW })).resolves.toBe('updated');

    expect(subscriptionOf('c1')).toEqual({
      plan: 'free',
      status: 'expired',
      source: 'store',
      store: null,
      expiresAt: null,
      limits: PLAN_LIMITS.free,
      rcSubscriberId: 'c1',
      updatedAt: NOW.toISOString(),
      usage: USAGE,
    });
  });

  it('keeps an active grace period when RevenueCat has no entitlement', async () => {
    seedCompany('c1', GRACE);
    const fetchSubscriber = jest.fn().mockResolvedValue(EMPTY);

    await expect(syncCompanySubscription('c1', { fetchSubscriber, now: NOW })).resolves.toBe('grace_kept');

    expect(subscriptionOf('c1')).toEqual(GRACE);
  });

  it('replaces the grace period when the company subscribes', async () => {
    seedCompany('c1', GRACE);
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('business'));

    await syncCompanySubscription('c1', { fetchSubscriber, now: NOW });

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'business', source: 'store', limits: PLAN_LIMITS.business, usage: USAGE });
  });

  it('downgrades an expired grace period', async () => {
    seedCompany('c1', { ...GRACE, expiresAt: PAST });
    const fetchSubscriber = jest.fn().mockResolvedValue(EMPTY);

    await expect(syncCompanySubscription('c1', { fetchSubscriber, now: NOW })).resolves.toBe('updated');

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'free', status: 'expired', source: 'store', usage: USAGE });
  });

  it('creates the subscription map when the company had none', async () => {
    seedCompany('c1');
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('pro'));

    await syncCompanySubscription('c1', { fetchSubscriber, now: NOW });

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'pro', status: 'active', source: 'store' });
    expect(subscriptionOf('c1')?.usage).toBeUndefined();
  });

  it('propagates RevenueCat errors without writing', async () => {
    seedCompany('c1', GRACE);
    const fetchSubscriber = jest.fn().mockRejectedValue(new Error('RevenueCat GET /subscribers failed: HTTP 503'));

    await expect(syncCompanySubscription('c1', { fetchSubscriber, now: NOW })).rejects.toThrow('HTTP 503');

    expect(subscriptionOf('c1')).toEqual(GRACE);
  });
});

describe('resetMonthlyUsage', () => {
  const RUN_AT = new Date('2026-11-01T03:00:00.000Z');

  beforeEach(() => fake.reset());

  it('zeroes photosThisMonth of every company that has a subscription', async () => {
    // usageResetAt in the future: the old query (usageResetAt <= now) skipped this company.
    seedCompany('a', { plan: 'free', status: 'active', usage: { ...USAGE, usageResetAt: '2027-05-01T00:00:00.000Z' } });
    seedCompany('b', GRACE);
    seedCompany('c');

    await expect(resetMonthlyUsage(RUN_AT)).resolves.toBe(2);

    for (const id of ['a', 'b']) {
      expect(subscriptionOf(id)?.usage).toEqual({
        photosThisMonth: 0,
        formTemplatesActive: 2,
        usersActive: 3,
        usageResetAt: '2026-12-01T00:00:00.000Z',
      });
    }
    expect(subscriptionOf('b')).toMatchObject({ plan: 'pro', source: 'grace', expiresAt: FUTURE });
    expect(fake.read('companies/c')).toEqual({ name: 'Company c' });
  });

  it('writes more companies than fit in one batch', async () => {
    for (let i = 0; i < 450; i++) {
      seedCompany(`c${i}`, { plan: 'free', status: 'active', usage: USAGE });
    }

    await expect(resetMonthlyUsage(RUN_AT)).resolves.toBe(450);

    expect(subscriptionOf('c0')?.usage).toMatchObject({ photosThisMonth: 0 });
    expect(subscriptionOf('c449')?.usage).toMatchObject({ photosThisMonth: 0 });
  });
});

describe('expireSubscriptions', () => {
  beforeEach(() => fake.reset());

  it('moves an ended grace period to Free when RevenueCat has no entitlement', async () => {
    seedCompany('c1', { ...GRACE, expiresAt: PAST });
    const fetchSubscriber = jest.fn().mockResolvedValue(EMPTY);

    await expect(expireSubscriptions(NOW, { fetchSubscriber })).resolves.toMatchObject({ expired: 1 });

    expect(fetchSubscriber).toHaveBeenCalledWith('c1');
    expect(subscriptionOf('c1')).toMatchObject({
      plan: 'free',
      status: 'expired',
      source: 'store',
      limits: PLAN_LIMITS.free,
      usage: USAGE,
    });
  });

  it('keeps a renewed subscription whose webhook was missed', async () => {
    seedCompany('c1', { plan: 'pro', status: 'active', source: 'store', expiresAt: PAST, limits: PLAN_LIMITS.pro, usage: USAGE });
    const fetchSubscriber = jest.fn().mockResolvedValue(activeSubscriber('pro'));

    await expect(expireSubscriptions(NOW, { fetchSubscriber })).resolves.toMatchObject({ expired: 0 });

    expect(subscriptionOf('c1')).toMatchObject({ plan: 'pro', status: 'active', expiresAt: FUTURE });
  });

  it('skips Free companies and subscriptions that have not ended', async () => {
    seedCompany('free1', { plan: 'free', status: 'active', usage: USAGE });
    seedCompany('pro1', { plan: 'pro', status: 'cancelled', source: 'store', expiresAt: FUTURE, usage: USAGE });
    seedCompany('pro2', { plan: 'pro', status: 'active', source: 'store', expiresAt: null, usage: USAGE });
    const fetchSubscriber = jest.fn();

    await expect(expireSubscriptions(NOW, { fetchSubscriber })).resolves.toMatchObject({ expired: 0 });

    expect(fetchSubscriber).not.toHaveBeenCalled();
  });

  it('continues after a RevenueCat failure on one company', async () => {
    seedCompany('broken', { ...GRACE, expiresAt: PAST });
    seedCompany('c1', { ...GRACE, expiresAt: PAST });
    const fetchSubscriber = jest.fn(async (id: string) => {
      if (id === 'broken') throw new Error('RevenueCat GET /subscribers failed: HTTP 503');
      return EMPTY;
    });
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(expireSubscriptions(NOW, { fetchSubscriber })).resolves.toEqual({ expired: 1, checked: 2, errors: 1 });

    expect(subscriptionOf('broken')).toMatchObject({ plan: 'pro', source: 'grace' });
    expect(subscriptionOf('c1')).toMatchObject({ plan: 'free' });
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  it('processes every company under concurrency when some fail', async () => {
    for (let i = 0; i < 23; i++) seedCompany(`c${i}`, { ...GRACE, expiresAt: PAST });
    let inFlight = 0;
    let maxInFlight = 0;
    const fetchSubscriber = jest.fn(async (id: string) => {
      inFlight++;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((resolve) => setTimeout(resolve, 1));
      inFlight--;
      if (id === 'c3' || id === 'c11') throw new Error('HTTP 503');
      return EMPTY;
    });
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(expireSubscriptions(NOW, { fetchSubscriber })).resolves.toEqual({ expired: 21, checked: 23, errors: 2 });

    expect(fetchSubscriber).toHaveBeenCalledTimes(23);
    expect(maxInFlight).toBeLessThanOrEqual(5);
    expect(maxInFlight).toBeGreaterThan(1);
    expect(subscriptionOf('c3')).toMatchObject({ plan: 'pro' });
    expect(subscriptionOf('c22')).toMatchObject({ plan: 'free' });
    errorSpy.mockRestore();
  });
});
