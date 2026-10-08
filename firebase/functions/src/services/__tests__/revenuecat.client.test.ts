import { fetchSubscriber } from '../revenuecat.client';

interface Call {
  url: string;
  init: RequestInit;
}

function fakeFetch(status: number, body: unknown) {
  const calls: Call[] = [];
  const impl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(body === undefined ? '' : JSON.stringify(body), { status });
  }) as unknown as typeof fetch;
  return { impl, calls };
}

const SUBSCRIBER = {
  original_app_user_id: 'c1',
  entitlements: {
    pro: { expires_date: '2026-11-07T12:00:00Z', product_identifier: 'praticos_pro_monthly', store: 'app_store' },
  },
  subscriptions: {
    praticos_pro_monthly: {
      unsubscribe_detected_at: null,
      billing_issues_detected_at: null,
      store: 'app_store',
      expires_date: '2026-11-07T12:00:00Z',
    },
  },
};

describe('fetchSubscriber', () => {
  it('GETs /v1/subscribers/{id} with the secret key and returns the subscriber', async () => {
    const { impl, calls } = fakeFetch(200, { request_date: '2026-10-07T12:00:00Z', subscriber: SUBSCRIBER });

    await expect(fetchSubscriber('c1', 'sk_test_key', impl)).resolves.toEqual(SUBSCRIBER);

    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe('https://api.revenuecat.com/v1/subscribers/c1');
    expect(calls[0].init.method).toBe('GET');
    expect(calls[0].init.headers).toEqual({ Authorization: 'Bearer sk_test_key', Accept: 'application/json' });
    expect(calls[0].init.signal).toBeDefined();
  });

  it('encodes the app user id', async () => {
    const { impl, calls } = fakeFetch(200, { subscriber: SUBSCRIBER });

    await fetchSubscriber('a/b c', 'sk_test_key', impl);

    expect(calls[0].url).toBe('https://api.revenuecat.com/v1/subscribers/a%2Fb%20c');
  });

  it('defaults missing entitlements and subscriptions to empty maps', async () => {
    const { impl } = fakeFetch(201, { subscriber: { original_app_user_id: 'c1' } });

    await expect(fetchSubscriber('c1', 'sk_test_key', impl)).resolves.toEqual({
      original_app_user_id: 'c1',
      entitlements: {},
      subscriptions: {},
    });
  });

  it('throws on non-2xx without exposing the key', async () => {
    const { impl } = fakeFetch(503, { message: 'unavailable' });

    const error = await fetchSubscriber('c1', 'sk_test_key', impl).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toBe('RevenueCat GET /subscribers failed: HTTP 503');
    expect((error as Error).message).not.toContain('sk_test_key');
  });

  it('throws when the body has no subscriber', async () => {
    const { impl } = fakeFetch(200, { request_date: '2026-10-07T12:00:00Z' });

    await expect(fetchSubscriber('c1', 'sk_test_key', impl)).rejects.toThrow(
      'RevenueCat GET /subscribers returned no subscriber',
    );
  });
});
