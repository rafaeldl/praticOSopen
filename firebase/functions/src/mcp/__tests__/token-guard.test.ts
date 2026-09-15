import express, { NextFunction, Request, Response } from 'express';
import request from 'supertest';
import { createUnknownTokenGuard, UnknownTokenGuardOptions } from '../token-guard';

function buildApp(overrides: Partial<UnknownTokenGuardOptions> = {}) {
  let clock = 0;
  const guard = createUnknownTokenGuard({
    windowMs: 60_000,
    maxUnknownPerWindow: 2,
    knownTokenTtlMs: 600_000,
    maxKnownTokens: 100,
    now: () => clock,
    ...overrides,
  });

  // Stand-in for mcpAuth: tokens starting with "valid" authenticate.
  const auth = jest.fn((req: Request, res: Response, next: NextFunction) => {
    if (String(req.params.token).startsWith('valid')) {
      next();
      return;
    }
    res.status(401).json({ error: 'invalid' });
  });

  const app = express();
  app.post('/t/:token', guard.limitUnknownTokens, auth, guard.rememberToken, (_req: Request, res: Response) => {
    res.json({ ok: true });
  });

  return {
    post: (token: string) => request(app).post(`/t/${token}`),
    auth,
    advance: (ms: number) => {
      clock += ms;
    },
  };
}

describe('unknown token guard', () => {
  it('barra tokens desconhecidos acima do teto antes de chegar no auth', async () => {
    const { post, auth } = buildApp();

    expect((await post('bad1')).status).toBe(401);
    expect((await post('bad2')).status).toBe(401);

    const blocked = await post('bad3');
    expect(blocked.status).toBe(429);
    expect(blocked.headers['retry-after']).toBe('60');
    expect(blocked.body.error.message).toBe('Too many requests');
    expect(auth).toHaveBeenCalledTimes(2);
  });

  it('continua atendendo token que ja autenticou quando o teto estoura', async () => {
    const { post } = buildApp();

    expect((await post('valid1')).status).toBe(200);
    expect((await post('bad1')).status).toBe(401);
    expect((await post('bad2')).status).toBe(429);

    expect((await post('valid1')).status).toBe(200);
    expect((await post('valid1')).status).toBe(200);
  });

  it('libera o teto quando a janela termina', async () => {
    const { post, advance } = buildApp();

    await post('bad1');
    await post('bad2');
    expect((await post('bad3')).status).toBe(429);

    advance(60_000);
    expect((await post('bad4')).status).toBe(401);
  });

  it('esquece o token depois do TTL', async () => {
    const { post, advance } = buildApp({ windowMs: 3_600_000 });

    expect((await post('valid1')).status).toBe(200);
    expect((await post('bad1')).status).toBe(401);

    advance(600_000);
    expect((await post('valid1')).status).toBe(429);
  });

  it('descarta o token autenticado ha mais tempo quando o conjunto enche', async () => {
    const { post } = buildApp({ maxUnknownPerWindow: 3, maxKnownTokens: 2 });

    await post('validA');
    await post('validB');
    await post('validC');

    expect((await post('validA')).status).toBe(429);
    expect((await post('validB')).status).toBe(200);
    expect((await post('validC')).status).toBe(200);
  });
});
