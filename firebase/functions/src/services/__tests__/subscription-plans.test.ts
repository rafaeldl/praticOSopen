import {
  PLAN_LIMITS,
  buildGraceSubscription,
  getNextMonthReset,
  getPlanLimits,
  isGraceActive,
  resolveSubscriptionState,
  tableVersionOf,
  planRow,
} from '../subscription-plans';
import type { RcEntitlement, RcSubscriber, RcSubscription } from '../revenuecat.client';
import type { Subscription } from '../../models/types';

const NOW = new Date('2026-10-07T12:00:00.000Z');
const FUTURE = '2026-11-07T12:00:00Z';
const LATER = '2026-11-14T12:00:00Z';
const PAST = '2026-10-01T12:00:00Z';
const USAGE = { photosThisMonth: 12, formTemplatesActive: 2, usersActive: 3, usageResetAt: '2026-11-01T00:00:00.000Z' };

function entitlement(product: string, expires: string | null = FUTURE): RcEntitlement {
  return { expires_date: expires, product_identifier: product, store: 'app_store' };
}

function storeSub(overrides: Partial<RcSubscription> = {}): RcSubscription {
  return {
    unsubscribe_detected_at: null,
    billing_issues_detected_at: null,
    grace_period_expires_date: null,
    store: 'app_store',
    expires_date: FUTURE,
    ...overrides,
  };
}

function subscriber(
  entitlements: Record<string, RcEntitlement>,
  subscriptions: Record<string, RcSubscription> = {},
): RcSubscriber {
  return { entitlements, subscriptions };
}

describe('resolveSubscriptionState', () => {
  it('is free/expired without entitlements', () => {
    expect(resolveSubscriptionState(subscriber({}), NOW)).toEqual({
      plan: 'free',
      status: 'expired',
      expiresAt: null,
      store: null,
    });
  });

  it('maps an active entitlement to its plan', () => {
    const s = subscriber({ pro: entitlement('praticos_pro_monthly') }, { praticos_pro_monthly: storeSub() });

    expect(resolveSubscriptionState(s, NOW)).toEqual({
      plan: 'pro',
      status: 'active',
      expiresAt: FUTURE,
      store: 'app_store',
    });
  });

  it('picks the highest active entitlement', () => {
    const s = subscriber(
      {
        starter: entitlement('praticos_starter_monthly'),
        business: entitlement('praticos_business_monthly', LATER),
      },
      {
        praticos_starter_monthly: storeSub(),
        praticos_business_monthly: storeSub({ expires_date: LATER }),
      },
    );

    expect(resolveSubscriptionState(s, NOW)).toMatchObject({ plan: 'business', expiresAt: LATER });
  });

  it('ignores expired entitlements', () => {
    const s = subscriber(
      {
        business: entitlement('praticos_business_monthly', PAST),
        starter: entitlement('praticos_starter_monthly'),
      },
      {
        praticos_business_monthly: storeSub({ expires_date: PAST }),
        praticos_starter_monthly: storeSub(),
      },
    );

    expect(resolveSubscriptionState(s, NOW)).toMatchObject({ plan: 'starter', status: 'active' });
  });

  it('treats a null expires_date as active with no expiry', () => {
    const s = subscriber({ pro: entitlement('praticos_pro_monthly', null) }, { praticos_pro_monthly: storeSub() });

    expect(resolveSubscriptionState(s, NOW)).toMatchObject({ plan: 'pro', status: 'active', expiresAt: null });
  });

  it('is cancelled when auto-renew was turned off', () => {
    const s = subscriber(
      { starter: entitlement('praticos_starter_monthly') },
      { praticos_starter_monthly: storeSub({ unsubscribe_detected_at: PAST }) },
    );

    expect(resolveSubscriptionState(s, NOW)).toMatchObject({ plan: 'starter', status: 'cancelled', expiresAt: FUTURE });
  });

  it('is past_due on billing issues, even if also unsubscribed', () => {
    const s = subscriber(
      { pro: entitlement('praticos_pro_monthly') },
      { praticos_pro_monthly: storeSub({ billing_issues_detected_at: PAST, unsubscribe_detected_at: PAST }) },
    );

    expect(resolveSubscriptionState(s, NOW)).toMatchObject({ plan: 'pro', status: 'past_due' });
  });

  it('keeps access during the store grace period', () => {
    const s = subscriber(
      { pro: entitlement('praticos_pro_monthly', PAST) },
      {
        praticos_pro_monthly: storeSub({
          expires_date: PAST,
          billing_issues_detected_at: PAST,
          grace_period_expires_date: FUTURE,
        }),
      },
    );

    expect(resolveSubscriptionState(s, NOW)).toEqual({
      plan: 'pro',
      status: 'past_due',
      expiresAt: FUTURE,
      store: 'app_store',
    });
  });

  it('maps the store', () => {
    const play = subscriber(
      { pro: entitlement('praticos_pro_monthly') },
      { praticos_pro_monthly: storeSub({ store: 'play_store' }) },
    );
    const stripe = subscriber(
      { pro: entitlement('praticos_pro_monthly') },
      { praticos_pro_monthly: storeSub({ store: 'stripe' }) },
    );

    expect(resolveSubscriptionState(play, NOW).store).toBe('play_store');
    expect(resolveSubscriptionState(stripe, NOW).store).toBeNull();
  });

  it('falls back to the product id for unknown entitlement ids', () => {
    const byProduct = subscriber({ 'Rafsoft Pro': entitlement('praticos_pro_monthly') });
    const unknown = subscriber({ other: entitlement('unknown_product') });

    expect(resolveSubscriptionState(byProduct, NOW).plan).toBe('pro');
    expect(resolveSubscriptionState(unknown, NOW).plan).toBe('free');
  });

  it('strips the Play base plan suffix (productId:basePlanId) in the product fallback', () => {
    const play = subscriber(
      { 'Rafsoft Pro': { ...entitlement('praticos_pro_monthly:monthly'), store: 'play_store' } },
      { 'praticos_pro_monthly:monthly': storeSub({ store: 'play_store' }) },
    );

    expect(resolveSubscriptionState(play, NOW)).toMatchObject({ plan: 'pro', store: 'play_store' });
  });
});

describe('getPlanLimits', () => {
  it('returns a copy of the plan limits', () => {
    const limits = getPlanLimits('pro');
    expect(limits).toEqual(PLAN_LIMITS.pro);

    limits.users = 99;

    expect(PLAN_LIMITS.pro.users).toBe(5);
  });
});

describe('getNextMonthReset', () => {
  it('returns the first day of the next month at 00:00 UTC', () => {
    expect(getNextMonthReset(new Date('2026-12-15T10:00:00Z'))).toBe('2027-01-01T00:00:00.000Z');
    expect(getNextMonthReset(new Date('2026-10-31T23:59:59Z'))).toBe('2026-11-01T00:00:00.000Z');
  });
});

describe('isGraceActive', () => {
  const grace = (expiresAt: string | null): Subscription => ({
    plan: 'pro',
    status: 'active',
    source: 'grace',
    expiresAt,
    limits: PLAN_LIMITS.pro,
    usage: USAGE,
  });

  it('is true for a grace period that has not ended', () => {
    expect(isGraceActive(grace(FUTURE), NOW)).toBe(true);
  });

  it('is false after the end, without expiresAt, for store subscriptions and without subscription', () => {
    expect(isGraceActive(grace(PAST), NOW)).toBe(false);
    expect(isGraceActive(grace(null), NOW)).toBe(false);
    expect(isGraceActive({ ...grace(FUTURE), source: 'store' }, NOW)).toBe(false);
    expect(isGraceActive(undefined, NOW)).toBe(false);
  });
});

describe('buildGraceSubscription', () => {
  const EXPIRES = new Date('2026-12-06T12:00:00.000Z');

  it('grants the old Pro until expiresAt to a company without subscription', () => {
    const grace = buildGraceSubscription(undefined, EXPIRES);

    expect(grace).toMatchObject({
      plan: 'pro',
      status: 'active',
      source: 'grace',
      store: null,
      expiresAt: '2026-12-06T12:00:00.000Z',
      // Old Pro (owner's decision, #726): no order limit, 5 people, every feature.
      limits: { ordersPerMonth: -1, photosPerMonth: -1, formTemplates: -1, users: 5, pdfWatermark: false },
      tableVersion: '1',
      usage: { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1 },
    });
  });

  it('keeps the existing usage', () => {
    const existing: Subscription = { plan: 'free', status: 'active', limits: PLAN_LIMITS.free, usage: USAGE };

    expect(buildGraceSubscription(existing, EXPIRES)?.usage).toEqual(USAGE);
  });

  it('returns null when the company has an active paid store subscription', () => {
    const paid: Subscription = {
      plan: 'starter',
      status: 'cancelled',
      source: 'store',
      expiresAt: FUTURE,
      limits: PLAN_LIMITS.starter,
      usage: USAGE,
    };

    expect(buildGraceSubscription(paid, EXPIRES)).toBeNull();
  });

  it('grants grace over an expired store subscription', () => {
    const expired: Subscription = {
      plan: 'free',
      status: 'expired',
      source: 'store',
      expiresAt: null,
      limits: PLAN_LIMITS.free,
      usage: USAGE,
    };

    expect(buildGraceSubscription(expired, EXPIRES)).toMatchObject({ plan: 'pro', source: 'grace', usage: USAGE });
  });

  it('returns null for a legacy paid subscription without source', () => {
    const legacy: Subscription = { plan: 'business', status: 'active', limits: PLAN_LIMITS.business, usage: USAGE };

    expect(buildGraceSubscription(legacy, EXPIRES, NOW)).toBeNull();
    expect(buildGraceSubscription({ ...legacy, expiresAt: FUTURE }, EXPIRES, NOW)).toBeNull();
  });

  it('grants grace over a legacy paid subscription with expired status', () => {
    const legacy: Subscription = { plan: 'pro', status: 'expired', limits: PLAN_LIMITS.pro, usage: USAGE };

    expect(buildGraceSubscription(legacy, EXPIRES, NOW)).toMatchObject({ plan: 'pro', source: 'grace', usage: USAGE });
  });

  it('treats a usage-only subscription (no plan) as Free: grants grace and keeps usage', () => {
    const usageOnly = { usage: { formTemplates: 1 } } as unknown as Subscription;

    expect(buildGraceSubscription(usageOnly, EXPIRES, NOW)).toMatchObject({
      plan: 'pro',
      source: 'grace',
      usage: { formTemplates: 1 },
    });
  });

  it('grants grace over a legacy paid subscription with a past expiresAt', () => {
    const legacy: Subscription = {
      plan: 'starter',
      status: 'active',
      expiresAt: PAST,
      limits: PLAN_LIMITS.starter,
      usage: USAGE,
    };

    expect(buildGraceSubscription(legacy, EXPIRES, NOW)).toMatchObject({ plan: 'pro', source: 'grace' });
  });
});

describe('tableVersionOf (#726)', () => {
  it('a paid subscription without tableVersion was bought before the current table', () => {
    expect(tableVersionOf({ plan: 'starter', source: 'store' })).toBe('1');
    expect(tableVersionOf({ plan: 'pro' })).toBe('1');
    expect(tableVersionOf({ plan: 'business', source: 'store' })).toBe('1');
  });

  it('the courtesy keeps the old Pro (owner, #726)', () => {
    expect(tableVersionOf({ plan: 'pro', source: 'grace' })).toBe('1');
  });

  it('Free and no subscription follow the current table', () => {
    expect(tableVersionOf({ plan: 'free' })).toBe('2');
    expect(tableVersionOf({ plan: 'enterprise' })).toBe('2');
    expect(tableVersionOf(undefined)).toBe('2');
  });

  it('a written version wins; an unknown one is the current', () => {
    expect(tableVersionOf({ plan: 'starter', tableVersion: '2' })).toBe('2');
    // Free always follows the current table (decision of 2026-11-13).
    expect(tableVersionOf({ plan: 'free', tableVersion: '1' })).toBe('2');
    expect(tableVersionOf({ plan: 'pro', tableVersion: '1' })).toBe('1');
    expect(tableVersionOf({ plan: 'starter', tableVersion: '99' })).toBe('2');
  });

  it('the old Starter keeps 3 people and every feature, and gets the new numbers', () => {
    const row = planRow('starter', tableVersionOf({ plan: 'starter', source: 'store' }));
    expect(row.users).toBe(3);
    expect(row.ordersPerMonth).toBe(-1);
    expect(row.photosPerMonth).toBe(-1);
    expect(row.formTemplates).toBe(-1);
    expect(row.aiPerMonth).toBe(1000);
    expect(row.aiPerDay).toBe(-1);
    // Table 1 listed no feature (every one allowed): it keeps no list.
    expect(row.features).toEqual([]);
  });
});
