import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
);
jest.mock('../../../middleware/app-permission.middleware', () => ({
  requireOrderAccess: () => (_req: Request, _res: Response, next: NextFunction) => next(),
}));

import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import router from '../share.routes';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    (req as any).auth = { type: 'bearer', companyId: 'c1', userId: 'u1' };
    next();
  });
  app.use('/', router);
  return app;
}

const token = (id: string, createdAt: string, extra: Record<string, unknown> = {}) => ({
  token: id, orderId: 'o1', companyId: 'c1', permissions: ['view', 'approve'],
  customer: { id: 'cu1', name: 'Cliente' }, createdBy: { id: 'u1', name: 'U' },
  createdAt, expiresAt: '2099-01-01T00:00:00.000Z', viewCount: 0, ...extra,
});

describe('GET /v1/orders/:orderId/share (lista que o app usa)', () => {
  beforeEach(() => {
    resetFakeDb();
    // Newest link already expired; an older one was replaced (revoked) but
    // has not expired yet. The app takes the first one not expired.
    seed('links/share/tokens/ST_new', token('ST_new', '2026-11-03T10:00:00.000Z', { expiresAt: '2026-11-03T11:00:00.000Z' }));
    seed('links/share/tokens/ST_old', token('ST_old', '2026-11-01T10:00:00.000Z', { revokedAt: '2026-11-03T10:00:00.000Z' }));
  });

  it('não devolve link revogado, para nenhuma versão do app compartilhar link que não abre', async () => {
    const res = await request(buildApp()).get('/o1/share');

    expect(res.status).toBe(200);
    expect(res.body.data.map((t: { token: string }) => t.token)).toEqual(['ST_new']);
  });
});

describe('DELETE /v1/orders/:orderId/share/:token', () => {
  beforeEach(() => {
    resetFakeDb();
    seed('companies/c1/orders/o1', { shareLink: { token: 'ST_a' } });
    seed('companies/c1/orders/o2', { shareLink: { token: 'ST_b' } });
    seed('links/share/tokens/ST_a', token('ST_a', '2026-11-01T10:00:00.000Z'));
    seed('links/share/tokens/ST_b', token('ST_b', '2026-11-01T10:00:00.000Z', { orderId: 'o2' }));
  });

  it('desativa o link da própria OS', async () => {
    const res = await request(buildApp()).delete('/o1/share/ST_a');
    expect(res.status).toBe(200);
  });

  it('recusa com 404 o link de outra OS da mesma empresa e não mexe nele', async () => {
    const res = await request(buildApp()).delete('/o1/share/ST_b');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
    const other = await request(buildApp()).get('/o2/share');
    expect(other.body.data.map((t: { token: string }) => t.token)).toEqual(['ST_b']);
  });
});
