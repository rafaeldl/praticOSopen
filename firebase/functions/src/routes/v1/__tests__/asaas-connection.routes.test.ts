import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/asaas/connection.service');

import * as connectionService from '../../../services/asaas/connection.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import router from '../asaas-connection.routes';

const mockService = connectionService as jest.Mocked<typeof connectionService>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', userName: 'Ana', companyId: 'comp1', role, permissions: [] };
    next();
  });
  app.use('/', router);
  return app;
}

const CONNECTED = {
  asaasEnabled: true,
  asaasConnected: true,
  asaasAccountName: 'Oficina da Ana',
  asaasEnvironment: 'sandbox' as const,
};

describe('asaas-connection.routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('conecta para admin', async () => {
    mockService.connectAsaas.mockResolvedValue(CONNECTED);

    const res = await request(buildApp('admin')).post('/connect').send({ apiKey: '$aact_hmlg_k' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: CONNECTED });
    expect(mockService.connectAsaas).toHaveBeenCalledWith('comp1', '$aact_hmlg_k', { id: 'user1', name: 'Ana' });
  });

  it('bloqueia gerente e técnico com 403', async () => {
    for (const role of ['manager', 'technician']) {
      const res = await request(buildApp(role)).post('/connect').send({ apiKey: '$aact_hmlg_k' });
      expect(res.status).toBe(403);
    }
    expect(mockService.connectAsaas).not.toHaveBeenCalled();
  });

  it('exige apiKey', async () => {
    const res = await request(buildApp('owner')).post('/connect').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('chave inválida → 400 ASAAS_INVALID_API_KEY', async () => {
    mockService.connectAsaas.mockRejectedValue(new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: 'x' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ASAAS_INVALID_API_KEY');
  });

  it('empresa fora do piloto → 403 ASAAS_NOT_ENABLED', async () => {
    mockService.connectAsaas.mockRejectedValue(new AsaasServiceError('ASAAS_NOT_ENABLED', 'Asaas is not enabled'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: '$aact_hmlg_k' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ASAAS_NOT_ENABLED');
  });

  it('erro inesperado → 500 sem detalhes', async () => {
    mockService.connectAsaas.mockRejectedValue(new Error('$aact_hmlg_k leaked'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: '$aact_hmlg_k' });
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('aact');
  });

  it('desconecta para owner', async () => {
    mockService.disconnectAsaas.mockResolvedValue(undefined);
    const res = await request(buildApp('owner')).delete('/connect');
    expect(res.status).toBe(200);
    expect(mockService.disconnectAsaas).toHaveBeenCalledWith('comp1');
  });

  it('GET /settings devolve o estado da conexão', async () => {
    mockService.getPaymentSettings.mockResolvedValue(CONNECTED);
    const res = await request(buildApp('admin')).get('/settings');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual(CONNECTED);
  });
});
