import express, { Request, Response } from 'express';
import request from 'supertest';
import { configureTrustProxy } from './trust-proxy.utils';
import {
  createPublicOrdersLimiters,
  isTrustedSsrRequest,
  SSR_SECRET_HEADER,
} from './public-rate-limit.utils';

const SECRET = 'test-ssr-secret-0123456789abcdef';
const SSR_IP = '34.34.231.157';

function buildApp(secret: string | undefined) {
  const app = express();
  configureTrustProxy(app);
  app.use(
    '/public/orders',
    ...createPublicOrdersLimiters(() => secret, { ipMax: 2, tokenMax: 2, failedFuseMax: 2 }),
  );
  // Stand-in for shareTokenAuth: made-up tokens are rejected
  app.get('/public/orders/:token', (req: Request, res: Response) => {
    if (String(req.params.token).startsWith('bad')) {
      res.status(401).json({ success: false });
      return;
    }
    res.json({ success: true });
  });
  return app;
}

describe('isTrustedSsrRequest', () => {
  const req = (value?: string) =>
    ({ headers: value === undefined ? {} : { [SSR_SECRET_HEADER]: value } }) as unknown as Request;

  it('accepts only the exact configured secret', () => {
    expect(isTrustedSsrRequest(req(SECRET), SECRET)).toBe(true);
    expect(isTrustedSsrRequest(req(`${SECRET}x`), SECRET)).toBe(false);
    expect(isTrustedSsrRequest(req('wrong'), SECRET)).toBe(false);
    expect(isTrustedSsrRequest(req(), SECRET)).toBe(false);
  });

  it('trusts nothing when no secret is configured', () => {
    expect(isTrustedSsrRequest(req(''), '')).toBe(false);
    expect(isTrustedSsrRequest(req(''), undefined)).toBe(false);
    expect(isTrustedSsrRequest(req('anything'), undefined)).toBe(false);
  });
});

describe('public orders rate limiting', () => {
  it('does not share one IP bucket between visitors loaded through the SSR', async () => {
    const app = buildApp(SECRET);
    for (const token of ['ST_a', 'ST_b', 'ST_c', 'ST_d']) {
      const res = await request(app)
        .get(`/public/orders/${token}`)
        .set('X-Forwarded-For', SSR_IP)
        .set(SSR_SECRET_HEADER, SECRET);
      expect(res.status).toBe(200);
    }
  });

  it('limits SSR requests per share token', async () => {
    const app = buildApp(SECRET);
    const hit = () => request(app)
      .get('/public/orders/ST_same')
      .set('X-Forwarded-For', SSR_IP)
      .set(SSR_SECRET_HEADER, SECRET);

    expect((await hit()).status).toBe(200);
    expect((await hit()).status).toBe(200);
    expect((await hit()).status).toBe(429);

    // Another link is not affected
    const other = await request(app)
      .get('/public/orders/ST_other')
      .set('X-Forwarded-For', SSR_IP)
      .set(SSR_SECRET_HEADER, SECRET);
    expect(other.status).toBe(200);
  });

  it('caps SSR requests for unknown tokens without counting successful loads', async () => {
    const app = buildApp(SECRET);
    const hit = (token: string) => request(app)
      .get(`/public/orders/${token}`)
      .set('X-Forwarded-For', SSR_IP)
      .set(SSR_SECRET_HEADER, SECRET);

    expect((await hit('ST_ok1')).status).toBe(200);
    expect((await hit('ST_ok2')).status).toBe(200);
    expect((await hit('ST_ok3')).status).toBe(200);

    expect((await hit('bad1')).status).toBe(401);
    expect((await hit('bad2')).status).toBe(401);
    expect((await hit('bad3')).status).toBe(429);
  });

  it('keeps the per-IP limit for direct callers, even with a forged secret', async () => {
    const app = buildApp(SECRET);
    const hit = (token: string, secret?: string) => {
      const req = request(app).get(`/public/orders/${token}`).set('X-Forwarded-For', '203.0.113.7');
      return secret === undefined ? req : req.set(SSR_SECRET_HEADER, secret);
    };

    expect((await hit('ST_a')).status).toBe(200);
    expect((await hit('ST_b', 'guess')).status).toBe(200);
    expect((await hit('ST_c', '')).status).toBe(429);

    // Another client is not affected
    const other = await request(app).get('/public/orders/ST_a').set('X-Forwarded-For', '198.51.100.9');
    expect(other.status).toBe(200);
  });

  it('falls back to the per-IP limit for everyone when no secret is configured', async () => {
    const app = buildApp(undefined);
    const hit = (token: string) => request(app)
      .get(`/public/orders/${token}`)
      .set('X-Forwarded-For', SSR_IP)
      .set(SSR_SECRET_HEADER, '');

    expect((await hit('ST_a')).status).toBe(200);
    expect((await hit('ST_b')).status).toBe(200);
    expect((await hit('ST_c')).status).toBe(429);
  });
});
