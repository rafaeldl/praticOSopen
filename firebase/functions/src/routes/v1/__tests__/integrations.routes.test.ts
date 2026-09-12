import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/integration-token.service');

import * as tokenService from '../../../services/integration-token.service';
import router from '../integrations.routes';

const mockService = tokenService as jest.Mocked<typeof tokenService>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', companyId: 'comp1', role };
    next();
  });
  app.use('/', router);
  return app;
}

describe('integrations.routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('cria token para admin', async () => {
    mockService.createIntegrationToken.mockResolvedValue({
      id: 'tok1',
      token: 'mcp_x',
      url: 'https://praticos.web.app/mcp/t/mcp_x',
      expiresAt: '2026-12-11T00:00:00.000Z',
    });

    const res = await request(buildApp('admin'))
      .post('/tokens')
      .send({ name: 'Meu ChatGPT' });

    expect(res.status).toBe(201);
    expect(res.body.data.url).toBe('https://praticos.web.app/mcp/t/mcp_x');
  });

  it('bloqueia técnico com 403', async () => {
    const res = await request(buildApp('technician'))
      .post('/tokens')
      .send({ name: 'Meu ChatGPT' });

    expect(res.status).toBe(403);
    expect(mockService.createIntegrationToken).not.toHaveBeenCalled();
  });

  it('exige nome', async () => {
    const res = await request(buildApp('admin')).post('/tokens').send({});
    expect(res.status).toBe(400);
  });

  it('responde 404 ao revogar token inexistente', async () => {
    mockService.revokeIntegrationToken.mockResolvedValue(false);
    const res = await request(buildApp('owner')).delete('/tokens/nope');
    expect(res.status).toBe(404);
  });
});
