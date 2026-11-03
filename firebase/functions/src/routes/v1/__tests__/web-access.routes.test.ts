import request from 'supertest';
import express from 'express';
import { createWebAccessRouter, hashEmail, isWebAccessAllowed, WebAccessConfig, WebAccessToken } from '../web-access.routes';

const EMAIL = 'Pessoa@Exemplo.test';
const verified: WebAccessToken = { uid: 'u1', email: EMAIL, email_verified: true };

function buildApp(token: WebAccessToken | Error, config: WebAccessConfig | null | Error) {
  const app = express();
  app.use(
    '/v1/app/web-access',
    createWebAccessRouter({
      verifyIdToken: jest.fn(async () => {
        if (token instanceof Error) throw token;
        return token;
      }),
      readConfig: jest.fn(async () => {
        if (config instanceof Error) throw config;
        return config;
      }),
      cacheMs: 0,
    }),
  );
  return app;
}

describe('hashEmail', () => {
  it('ignores case and spaces', () => {
    expect(hashEmail(' pessoa@exemplo.test ')).toBe(hashEmail(EMAIL));
    expect(hashEmail(EMAIL)).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('isWebAccessAllowed', () => {
  const listed = { open: false, allowedEmailHashes: [hashEmail(EMAIL)] };

  it('denies when the document does not exist', () => {
    expect(isWebAccessAllowed(verified, null)).toBe(false);
  });

  it('allows a listed, verified e-mail', () => {
    expect(isWebAccessAllowed(verified, listed)).toBe(true);
  });

  it('denies an unverified e-mail, even when listed', () => {
    expect(isWebAccessAllowed({ ...verified, email_verified: false }, listed)).toBe(false);
  });

  it('denies an account without e-mail', () => {
    expect(isWebAccessAllowed({ uid: 'u1' }, listed)).toBe(false);
  });

  it('denies who is not listed', () => {
    expect(isWebAccessAllowed({ ...verified, email: 'outra@exemplo.test' }, listed)).toBe(false);
  });

  it('open lets everyone in', () => {
    expect(isWebAccessAllowed({ uid: 'u1' }, { open: true })).toBe(true);
  });

  it('only the boolean true opens it, and a broken list denies', () => {
    expect(isWebAccessAllowed(verified, { open: 'yes', allowedEmailHashes: 'x' })).toBe(false);
  });
});

describe('GET /v1/app/web-access', () => {
  it('needs a Bearer token', async () => {
    const res = await request(buildApp(verified, null)).get('/v1/app/web-access');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rejects an invalid token', async () => {
    const res = await request(buildApp(Object.assign(new Error('x'), { code: 'auth/id-token-expired' }), null))
      .get('/v1/app/web-access')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TOKEN_EXPIRED');
  });

  it('answers allowed without exposing the list', async () => {
    const res = await request(buildApp(verified, { allowedEmailHashes: [hashEmail(EMAIL)] }))
      .get('/v1/app/web-access')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { allowed: true } });
    expect(res.headers['cache-control']).toBe('private, no-store');
  });

  it('closed by default', async () => {
    const res = await request(buildApp(verified, null)).get('/v1/app/web-access').set('Authorization', 'Bearer t');
    expect(res.body.data.allowed).toBe(false);
  });

  it('read failure is an error, not an answer', async () => {
    const res = await request(buildApp(verified, new Error('down'))).get('/v1/app/web-access').set('Authorization', 'Bearer t');
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});

describe('config cache', () => {
  it('reuses one read for a while, then reads again', async () => {
    let time = 0;
    const readConfig = jest.fn(async () => ({ open: true }));
    const app = express();
    app.use('/w', createWebAccessRouter({ verifyIdToken: async () => verified, readConfig, cacheMs: 1000, now: () => time }));
    await request(app).get('/w').set('Authorization', 'Bearer t');
    await request(app).get('/w').set('Authorization', 'Bearer t');
    expect(readConfig).toHaveBeenCalledTimes(1);
    time = 1000;
    await request(app).get('/w').set('Authorization', 'Bearer t');
    expect(readConfig).toHaveBeenCalledTimes(2);
  });
});
