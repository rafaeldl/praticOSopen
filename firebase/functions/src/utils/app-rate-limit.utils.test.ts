import { Server } from 'http';
import express, { NextFunction, Request, Response } from 'express';
import cors from 'cors';
import request from 'supertest';
import { API_CORS_OPTIONS, createAppLimiters, noStore } from './app-rate-limit.utils';

/** bearerAuth stand-in: the user comes from the token, like the real one. */
function fakeBearer(req: Request, _res: Response, next: NextFunction) {
  const token = (req.headers.authorization ?? '').replace('Bearer ', '');
  if (token) (req as Request & { auth?: { userId: string } }).auth = { userId: token };
  next();
}

function buildApp(userMax: number, ipMax: number) {
  const { ipLimiter, userLimiter } = createAppLimiters({ userMax, ipMax });
  const app = express();
  app.use(cors(API_CORS_OPTIONS));
  app.use('/v1/app', ipLimiter, fakeBearer, userLimiter, (_req: Request, res: Response) => {
    res.json({ ok: true });
  });
  return app;
}

let server: Server;
afterEach((done) => {
  if (server) server.close(done);
  else done();
});

function listen(userMax: number, ipMax: number): Promise<void> {
  return new Promise((resolve) => {
    server = buildApp(userMax, ipMax).listen(0, '127.0.0.1', () => resolve());
  });
}

describe('app rate limit', () => {
  it('conta por usuário: duas pessoas do mesmo escritório (mesmo IP) não se travam', async () => {
    await listen(3, 100);
    for (let i = 0; i < 3; i++) {
      expect((await request(server).get('/v1/app/x').set('Authorization', 'Bearer ana')).status).toBe(200);
    }
    expect((await request(server).get('/v1/app/x').set('Authorization', 'Bearer ana')).status).toBe(429);
    expect((await request(server).get('/v1/app/x').set('Authorization', 'Bearer bia')).status).toBe(200);
  });

  it('antes do token, um limite largo por IP segura enxurrada de tokens inventados', async () => {
    await listen(100, 4);
    for (let i = 0; i < 4; i++) {
      expect((await request(server).get('/v1/app/x').set('Authorization', `Bearer fake${i}`)).status).toBe(200);
    }
    expect((await request(server).get('/v1/app/x').set('Authorization', 'Bearer fake9')).status).toBe(429);
  });
});

describe('CORS', () => {
  it('aceita X-Company-Id no preflight do app web', async () => {
    await listen(10, 10);
    const res = await request(server)
      .options('/v1/app/x')
      .set('Origin', 'https://praticos.web.app')
      .set('Access-Control-Request-Method', 'PATCH')
      .set('Access-Control-Request-Headers', 'authorization,x-company-id,content-type');
    expect(res.status).toBe(204);
    expect(res.headers['access-control-allow-headers'].toLowerCase()).toContain('x-company-id');
  });
});

describe('noStore (revisão #520 B3)', () => {
  it('respostas de /v1/app saem com Cache-Control: private, no-store, também as de erro', async () => {
    const app = express();
    app.use('/v1/app', noStore, (req: Request, res: Response) => {
      if (req.path === '/fail') res.status(403).json({ success: false });
      else res.json({ ok: true, value: 120 });
    });
    await new Promise<void>((resolve) => (server = app.listen(0, '127.0.0.1', () => resolve())));
    expect((await request(server).get('/v1/app/services')).headers['cache-control']).toBe('private, no-store');
    expect((await request(server).get('/v1/app/fail')).headers['cache-control']).toBe('private, no-store');
  });
});
