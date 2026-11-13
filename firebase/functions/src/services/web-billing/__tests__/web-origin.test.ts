jest.mock('../../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../../firestore.service';
import { FakeFirestore } from '../../../__tests__/helpers/fake-firestore';
import { expireSubscriptions, syncCompanySubscription } from '../../subscription.service';
import { webOriginFor } from '../web-origin';
import type { RcSubscriber } from '../../revenuecat.client';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

const NOW = new Date('2026-11-13T15:00:00.000Z');
const END = '2026-12-19T03:00:00Z';
const USAGE = { photosThisMonth: 3, formTemplatesActive: 0, usersActive: 1, usageResetAt: '2026-12-01T00:00:00.000Z' };

function promo(plan = 'pro', expires = END): RcSubscriber {
  const product = `rc_promo_${plan}_custom`;
  return {
    original_app_user_id: 'c1',
    entitlements: { [plan]: { expires_date: expires, product_identifier: product } },
    subscriptions: {
      [product]: { store: 'promotional', expires_date: expires, unsubscribe_detected_at: null, billing_issues_detected_at: null },
    },
  };
}

function storeSub(plan = 'business'): RcSubscriber {
  const product = `praticos_${plan}_monthly`;
  return {
    original_app_user_id: 'c1',
    entitlements: { [plan]: { expires_date: END, product_identifier: product, store: 'app_store' } },
    subscriptions: {
      [product]: { store: 'app_store', expires_date: END, unsubscribe_detected_at: null, billing_issues_detected_at: null },
    },
  };
}

function seed(status: string) {
  fake.seed('companies/c1', { name: 'Oficina', subscription: { plan: 'free', status: 'active', usage: USAGE } });
  fake.seed('companies/c1/private/webBilling', {
    status,
    plan: 'pro',
    cycle: 'monthly',
    billingType: 'CREDIT_CARD',
    value: 119.9,
    environment: 'sandbox',
    asaasCustomerId: 'cus_1',
    asaasSubscriptionId: 'sub_1',
    createdAt: '2026-11-10T00:00:00Z',
    createdBy: 'u1',
  });
}

const subscription = () => fake.read('companies/c1')?.subscription as Record<string, unknown>;

beforeEach(() => fake.reset());

describe('sync writes the origin web (Dart and TS read store "web")', () => {
  it('promotional backed by an active web record → source store, store web, renews', async () => {
    seed('active');
    await syncCompanySubscription('c1', { fetchSubscriber: async () => promo(), now: NOW });
    expect(subscription()).toMatchObject({ plan: 'pro', status: 'active', source: 'store', store: 'web', expiresAt: END, usage: USAGE });
  });

  it('cancelled web record → cancelled until the end', async () => {
    seed('cancelled');
    await syncCompanySubscription('c1', { fetchSubscriber: async () => promo(), now: NOW });
    expect(subscription()).toMatchObject({ plan: 'pro', status: 'cancelled', store: 'web' });
  });

  it('a promotional given by hand keeps store null', async () => {
    fake.seed('companies/c1', { name: 'Oficina' });
    await syncCompanySubscription('c1', { fetchSubscriber: async () => promo(), now: NOW });
    expect(subscription()).toMatchObject({ plan: 'pro', store: null });
  });

  it('the daily job keeps a valid web plan (store web, not Free)', async () => {
    seed('active');
    fake.seed('companies/c1', {
      name: 'Oficina',
      subscription: { plan: 'pro', status: 'active', source: 'store', store: 'web', expiresAt: '2026-11-12T03:00:00Z', usage: USAGE },
    });
    const result = await expireSubscriptions(NOW, { fetchSubscriber: async () => promo() });
    expect(result).toEqual({ expired: 0, checked: 1, errors: 0 });
    expect(subscription()).toMatchObject({ plan: 'pro', store: 'web', expiresAt: END });
  });
});

describe('store purchase while the web renews', () => {
  it('stops the Asaas recurrence and the store plan wins', async () => {
    seed('active');
    const deleteSubscription = jest.fn().mockResolvedValue(undefined);
    const state = await webOriginFor(
      'c1',
      storeSub(),
      { plan: 'business', status: 'active', expiresAt: END, store: 'app_store' },
      NOW,
      () => ({ client: { deleteSubscription } as never, environment: 'sandbox' }),
    );
    expect(state.store).toBe('app_store');
    expect(deleteSubscription).toHaveBeenCalledWith('sub_1');
    expect(fake.read('companies/c1/private/webBilling')).toMatchObject({ status: 'cancelled', cancelReason: 'store' });
  });

  it('without the Asaas key it logs and keeps the store state', async () => {
    seed('active');
    const state = await webOriginFor('c1', storeSub(), { plan: 'business', status: 'active', expiresAt: END, store: 'app_store' }, NOW, () => null);
    expect(state.store).toBe('app_store');
    expect(fake.read('companies/c1/private/webBilling')).toMatchObject({ status: 'active' });
  });
});
