jest.mock('../../../services/subscription.service', () => ({ syncCompanySubscription: jest.fn() }));
jest.mock('../../../services/revenuecat.client', () => ({ fetchSubscriber: jest.fn() }));

import request from 'supertest';
import express from 'express';
import { syncCompanySubscription } from '../../../services/subscription.service';
import { fetchSubscriber } from '../../../services/revenuecat.client';
import router, { collectCompanyIds, verifyWebhookAuth } from '../revenuecat.routes';

const mockSync = syncCompanySubscription as jest.Mock;
const mockFetch = fetchSubscriber as jest.Mock;
const AUTH = 'Bearer whk_revenuecat_test_value';
const API_KEY = 'sk_revenuecat_test_value';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/webhooks/revenuecat', router);
  return app;
}

function payload(overrides: Record<string, unknown> = {}) {
  return {
    api_version: '1.0',
    event: {
      id: 'evt_1',
      type: 'RENEWAL',
      app_user_id: 'c1',
      product_id: 'marker_body_must_not_be_logged',
      ...overrides,
    },
  };
}

function post(body: unknown, authorization: string | null = AUTH) {
  const req = request(buildApp()).post('/webhooks/revenuecat');
  return authorization === null ? req.send(body as object) : req.set('Authorization', authorization).send(body as object);
}

describe('verifyWebhookAuth', () => {
  it('accepts the exact configured value', () => {
    expect(verifyWebhookAuth(AUTH, AUTH)).toBe(true);
  });

  it('rejects a missing header', () => {
    expect(verifyWebhookAuth(undefined, AUTH)).toBe(false);
    expect(verifyWebhookAuth('', AUTH)).toBe(false);
  });

  it('rejects a wrong value of the same length', () => {
    expect(verifyWebhookAuth('Bearer whk_revenuecat_test_valuX', AUTH)).toBe(false);
  });

  it('rejects a value of a different length', () => {
    expect(verifyWebhookAuth(`${AUTH}x`, AUTH)).toBe(false);
    expect(verifyWebhookAuth('Bearer', AUTH)).toBe(false);
  });

  it('rejects everything when the secret is empty', () => {
    expect(verifyWebhookAuth('', '')).toBe(false);
    expect(verifyWebhookAuth('anything', undefined)).toBe(false);
  });
});

describe('collectCompanyIds', () => {
  it('uses app_user_id', () => {
    expect(collectCompanyIds({ type: 'RENEWAL', app_user_id: 'c1' })).toEqual(['c1']);
  });

  it('includes both sides of a TRANSFER without duplicates', () => {
    expect(
      collectCompanyIds({ type: 'TRANSFER', app_user_id: 'c2', transferred_from: ['c1'], transferred_to: ['c2'] }),
    ).toEqual(['c2', 'c1']);
  });

  it('drops anonymous and invalid ids', () => {
    expect(
      collectCompanyIds({ type: 'TRANSFER', app_user_id: '$RCAnonymousID:abc', transferred_to: ['a/b', ''] }),
    ).toEqual([]);
  });
});

describe('POST /webhooks/revenuecat', () => {
  let logSpies: jest.SpyInstance[];

  beforeEach(() => {
    process.env.REVENUECAT_WEBHOOK_AUTH = AUTH;
    process.env.REVENUECAT_SECRET_API_KEY = API_KEY;
    mockSync.mockReset();
    mockSync.mockResolvedValue('updated');
    mockFetch.mockReset();
    logSpies = (['log', 'info', 'warn', 'error'] as const).map((level) =>
      jest.spyOn(console, level).mockImplementation(() => undefined));
  });

  afterEach(() => {
    const logged = logSpies.flatMap((spy) => spy.mock.calls).map((call) => JSON.stringify(call)).join('\n');
    expect(logged).not.toContain('whk_revenuecat_test_value');
    expect(logged).not.toContain(API_KEY);
    expect(logged).not.toContain('marker_body_must_not_be_logged');
    logSpies.forEach((spy) => spy.mockRestore());
    delete process.env.REVENUECAT_WEBHOOK_AUTH;
    delete process.env.REVENUECAT_SECRET_API_KEY;
  });

  it('responds 500 and processes nothing when the auth secret is not configured', async () => {
    delete process.env.REVENUECAT_WEBHOOK_AUTH;

    const res = await post(payload());

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('NOT_CONFIGURED');
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('responds 500 when the RevenueCat API key is not configured', async () => {
    delete process.env.REVENUECAT_SECRET_API_KEY;

    const res = await post(payload());

    expect(res.status).toBe(500);
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('responds 401 without Authorization', async () => {
    const res = await post(payload(), null);

    expect(res.status).toBe(401);
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('responds 401 with a wrong Authorization', async () => {
    const res = await post(payload(), 'Bearer wrong');

    expect(res.status).toBe(401);
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('responds 400 without an event', async () => {
    const res = await post({ api_version: '1.0' });

    expect(res.status).toBe(400);
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('syncs the company with a fetcher bound to the secret API key', async () => {
    const res = await post(payload());

    expect(res.status).toBe(200);
    expect(mockSync).toHaveBeenCalledTimes(1);
    expect(mockSync).toHaveBeenCalledWith('c1', { fetchSubscriber: expect.any(Function) });

    mockFetch.mockResolvedValue({ entitlements: {}, subscriptions: {} });
    await mockSync.mock.calls[0][1].fetchSubscriber('c1');
    expect(mockFetch).toHaveBeenCalledWith('c1', API_KEY);
  });

  it.each([
    'INITIAL_PURCHASE',
    'RENEWAL',
    'CANCELLATION',
    'UNCANCELLATION',
    'NON_RENEWING_PURCHASE',
    'SUBSCRIPTION_PAUSED',
    'BILLING_ISSUE',
    'PRODUCT_CHANGE',
    'EXPIRATION',
    'SUBSCRIPTION_EXTENDED',
    'TEST',
  ])('syncs on %s', async (type) => {
    const res = await post(payload({ type }));

    expect(res.status).toBe(200);
    expect(mockSync).toHaveBeenCalledWith('c1', expect.any(Object));
  });

  it('acknowledges events without a company id', async () => {
    const res = await post(payload({ app_user_id: '$RCAnonymousID:abc' }));

    expect(res.status).toBe(200);
    expect(mockSync).not.toHaveBeenCalled();
  });

  it('acknowledges events for unknown companies', async () => {
    mockSync.mockResolvedValue('company_not_found');

    const res = await post(payload());

    expect(res.status).toBe(200);
  });

  it('syncs both companies on TRANSFER', async () => {
    const res = await post(payload({ type: 'TRANSFER', app_user_id: 'c2', transferred_from: ['c1'], transferred_to: ['c2'] }));

    expect(res.status).toBe(200);
    expect(mockSync.mock.calls.map((call) => call[0])).toEqual(['c2', 'c1']);
  });

  it('responds 500 when the sync fails so RevenueCat retries', async () => {
    mockSync.mockRejectedValue(new Error('RevenueCat GET /subscribers failed: HTTP 503'));

    const res = await post(payload());

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});
