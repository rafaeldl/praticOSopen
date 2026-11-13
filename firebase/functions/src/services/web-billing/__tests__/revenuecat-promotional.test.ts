import { grantPromotional, revokePromotionals } from '../revenuecat-promotional';

const answer = (status: number) => jest.fn().mockResolvedValue({ ok: status < 300, status }) as unknown as typeof fetch;

describe('RevenueCat promotional', () => {
  it('grant posts end_time_ms to the entitlement of the app user', async () => {
    const fetchImpl = answer(201);
    await grantPromotional('c/1', 'pro', 123, 'sk_test', fetchImpl);
    const [url, init] = (fetchImpl as unknown as jest.Mock).mock.calls[0];
    expect(url).toBe('https://api.revenuecat.com/v1/subscribers/c%2F1/entitlements/pro/promotional');
    expect(JSON.parse(init.body)).toEqual({ end_time_ms: 123 });
    expect(init.headers.Authorization).toBe('Bearer sk_test');
  });

  it('revoke with nothing left to revoke (404) is not an error', async () => {
    await expect(revokePromotionals('c1', 'pro', 'sk_test', answer(404))).resolves.toBeUndefined();
  });

  it('other failures throw without the key or the app user', async () => {
    const error = await revokePromotionals('c1', 'pro', 'sk_secret', answer(500)).catch((e: Error) => e);
    expect((error as Error).message).toBe('RevenueCat revoke_promotionals failed: HTTP 500');
    await expect(grantPromotional('c1', 'pro', 1, 'sk_secret', answer(404))).rejects.toThrow('HTTP 404');
  });
});
