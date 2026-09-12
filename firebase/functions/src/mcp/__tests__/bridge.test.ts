import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { callRoute } from '../bridge';

function buildRouter(): Router {
  const router = Router();

  router.get('/ping', (req: AuthenticatedRequest, res: Response) => {
    res.json({ pong: true, companyId: req.userContext?.companyId });
  });

  router.get('/search', (req: AuthenticatedRequest, res: Response) => {
    res.json({ q: req.query.q });
  });

  router.post('/echo', (req: AuthenticatedRequest, res: Response) => {
    res.status(201).json({ received: req.body });
  });

  router.get('/boom', (_req: AuthenticatedRequest, res: Response) => {
    res.status(404).json({ error: { code: 'NOT_FOUND' } });
  });

  return router;
}

const source = {
  auth: { type: 'mcp', companyId: 'comp1', userId: 'user1' },
  userContext: { userId: 'user1', companyId: 'comp1', role: 'admin' },
} as unknown as AuthenticatedRequest;

describe('callRoute', () => {
  it('executa GET e propaga o contexto de auth', async () => {
    const result = await callRoute(buildRouter(), {
      method: 'GET',
      path: '/ping',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ pong: true, companyId: 'comp1' });
  });

  it('passa query string', async () => {
    const result = await callRoute(buildRouter(), {
      method: 'GET',
      path: '/search',
      query: { q: 'joao' },
      source,
    });

    expect(result.body).toEqual({ q: 'joao' });
  });

  it('executa POST com body e devolve o status', async () => {
    const result = await callRoute(buildRouter(), {
      method: 'POST',
      path: '/echo',
      body: { name: 'teste' },
      source,
    });

    expect(result.status).toBe(201);
    expect(result.body).toEqual({ received: { name: 'teste' } });
  });

  it('devolve status de erro sem lançar', async () => {
    const result = await callRoute(buildRouter(), {
      method: 'GET',
      path: '/boom',
      source,
    });

    expect(result.status).toBe(404);
    expect(result.body.error.code).toBe('NOT_FOUND');
  });

  it('devolve 404 quando a rota não existe', async () => {
    const result = await callRoute(buildRouter(), {
      method: 'GET',
      path: '/inexistente',
      source,
    });

    expect(result.status).toBe(404);
  });

  it('popula req.params para rotas com parâmetro dinâmico', async () => {
    const router = Router();
    router.get('/:number/details', (req: AuthenticatedRequest, res: Response) => {
      res.json({ number: req.params.number });
    });

    const result = await callRoute(router, {
      method: 'GET',
      path: '/123/details',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ number: '123' });
  });

  it('executa PATCH em rota com parâmetro e body', async () => {
    const router = Router();
    router.patch('/:number/status', (req: AuthenticatedRequest, res: Response) => {
      res.json({ number: req.params.number, status: req.body.status });
    });

    const result = await callRoute(router, {
      method: 'PATCH',
      path: '/42/status',
      body: { status: 'done' },
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ number: '42', status: 'done' });
  });

  it('executa DELETE em rota com parâmetro', async () => {
    const router = Router();
    router.delete('/:number/services/:index', (req: AuthenticatedRequest, res: Response) => {
      res.json({ number: req.params.number, index: req.params.index });
    });

    const result = await callRoute(router, {
      method: 'DELETE',
      path: '/7/services/2',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ number: '7', index: '2' });
  });

  it('passa por middlewares intermediários (ex: requireLinked) antes do handler', async () => {
    const router = Router();
    const requireLinked = (req: AuthenticatedRequest, res: Response, next: any) => {
      if (!req.userContext) {
        res.status(403).json({ error: { code: 'NOT_LINKED' } });
        return;
      }
      next();
    };

    router.get('/protected', requireLinked, (req: AuthenticatedRequest, res: Response) => {
      res.json({ ok: true, companyId: req.userContext?.companyId });
    });

    const result = await callRoute(router, {
      method: 'GET',
      path: '/protected',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ ok: true, companyId: 'comp1' });

    const unlinkedSource = {
      auth: { type: 'mcp', companyId: 'comp1', userId: 'user1' },
      userContext: undefined,
    } as unknown as AuthenticatedRequest;

    const blocked = await callRoute(router, {
      method: 'GET',
      path: '/protected',
      source: unlinkedSource,
    });

    expect(blocked.status).toBe(403);
  });

  it('captura erro lançado de forma síncrona no handler sem travar a promise', async () => {
    const router = Router();
    router.get('/throws', (_req: AuthenticatedRequest, _res: Response) => {
      throw new Error('boom sync');
    });

    const result = await callRoute(router, {
      method: 'GET',
      path: '/throws',
      source,
    });

    expect(result.status).toBe(500);
    expect(result.body.error.code).toBe('INTERNAL_ERROR');
  });
});
