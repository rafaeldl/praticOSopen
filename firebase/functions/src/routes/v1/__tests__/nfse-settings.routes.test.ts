import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/nfse/emitter-settings.service', () => ({
  ...jest.requireActual('../../../services/nfse/emitter-settings.service'),
  updateNfseSettings: jest.fn(async (_c: string, update: Record<string, unknown>) => update),
  updateEmitter: jest.fn(),
}));

import { updateNfseSettings } from '../../../services/nfse/emitter-settings.service';
import router from '../nfse-settings.routes';

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    (req as any).userContext = { userId: 'u1', userName: 'Ana', companyId: 'c1', role, permissions: [] };
    next();
  });
  app.use('/', router);
  return app;
}

describe('nfse-settings.routes: managerCanIssue (issue #560)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  it('only the owner decides whether managers issue notas', async () => {
    expect((await request(buildApp('admin')).put('/settings').send({ managerCanIssue: false })).status).toBe(403);
    expect(updateNfseSettings).not.toHaveBeenCalled();
    const res = await request(buildApp('owner')).put('/settings').send({ managerCanIssue: false });
    expect(res.status).toBe(200);
    expect(updateNfseSettings).toHaveBeenCalledWith('c1', { managerCanIssue: false });
  });

  it('admins keep changing the other settings', async () => {
    expect((await request(buildApp('admin')).put('/settings').send({ autoIssue: 'never' })).status).toBe(200);
  });
});
