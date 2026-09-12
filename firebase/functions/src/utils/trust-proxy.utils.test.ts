import express, { Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import request from 'supertest';
import { configureTrustProxy, TRUST_PROXY_HOPS } from './trust-proxy.utils';

function buildApp({ trustProxy }: { trustProxy: boolean }) {
  const app = express();
  if (trustProxy) configureTrustProxy(app);

  // Same keyGenerator shape as publicLimiter in index.ts
  const limiter = rateLimit({
    windowMs: 60 * 1000,
    max: 2,
    keyGenerator: (req: Request) => req.ip || 'unknown',
  });

  app.get('/ip', (req: Request, res: Response) => {
    res.json({ ip: req.ip });
  });
  app.get('/limited', limiter, (_req: Request, res: Response) => {
    res.json({ ok: true });
  });
  return app;
}

describe('trust proxy configuration', () => {
  it('never trusts every proxy', () => {
    expect(TRUST_PROXY_HOPS).not.toBe(true);
    expect(Number.isInteger(TRUST_PROXY_HOPS)).toBe(true);
    expect(TRUST_PROXY_HOPS).toBeGreaterThan(0);
  });

  it('without it, req.ip is the proxy socket address and X-Forwarded-For is ignored', async () => {
    const res = await request(buildApp({ trustProxy: false }))
      .get('/ip')
      .set('X-Forwarded-For', '203.0.113.7');

    expect(res.body.ip).not.toBe('203.0.113.7');
  });

  it('takes req.ip from the X-Forwarded-For entry appended by the Google front end', async () => {
    const res = await request(buildApp({ trustProxy: true }))
      .get('/ip')
      .set('X-Forwarded-For', '203.0.113.7');

    expect(res.body.ip).toBe('203.0.113.7');
  });

  it('ignores a client-forged X-Forwarded-For prefix', async () => {
    const res = await request(buildApp({ trustProxy: true }))
      .get('/ip')
      .set('X-Forwarded-For', '1.2.3.4, 203.0.113.7');

    expect(res.body.ip).toBe('203.0.113.7');
  });

  it('rate limits each client IP independently', async () => {
    const app = buildApp({ trustProxy: true });
    const hit = (ip: string) => request(app).get('/limited').set('X-Forwarded-For', ip);

    expect((await hit('203.0.113.7')).status).toBe(200);
    expect((await hit('203.0.113.7')).status).toBe(200);
    expect((await hit('203.0.113.7')).status).toBe(429);

    // Another client is not affected by the first one exhausting its quota
    expect((await hit('198.51.100.9')).status).toBe(200);

    // Rotating a forged prefix does not give the abusive client a fresh quota
    expect((await hit('9.9.9.9, 203.0.113.7')).status).toBe(429);
  });

  // express-rate-limit only runs its trust proxy validations inside its
  // *default* keyGenerator (the limiters in index.ts use custom ones), so this
  // uses the default to prove the setting passes the library's own checks.
  describe('express-rate-limit validations', () => {
    async function erlCodesLogged({ trustProxy }: { trustProxy: boolean }) {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
      try {
        const app = express();
        if (trustProxy) configureTrustProxy(app);
        app.get('/', rateLimit({ windowMs: 60 * 1000, max: 2 }), (_req: Request, res: Response) => {
          res.json({ ok: true });
        });

        await request(app).get('/').set('X-Forwarded-For', '203.0.113.7');

        return [...errorSpy.mock.calls, ...warnSpy.mock.calls]
          .flat()
          .map((arg) => (arg as { code?: string })?.code)
          .filter((code): code is string => !!code?.startsWith('ERR_ERL'));
      } finally {
        errorSpy.mockRestore();
        warnSpy.mockRestore();
      }
    }

    it('flag X-Forwarded-For without trust proxy (control)', async () => {
      expect(await erlCodesLogged({ trustProxy: false })).toContain('ERR_ERL_UNEXPECTED_X_FORWARDED_FOR');
    });

    it('report nothing with the configured hop count', async () => {
      expect(await erlCodesLogged({ trustProxy: true })).toEqual([]);
    });
  });
});
