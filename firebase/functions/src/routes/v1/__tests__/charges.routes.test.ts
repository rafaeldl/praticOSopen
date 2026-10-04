import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/asaas/charge.service');

import * as chargeService from '../../../services/asaas/charge.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import router from '../charges.routes';

const mockService = chargeService as jest.Mocked<typeof chargeService>;

function buildApp(permissions: string[]) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', userName: 'Ana', companyId: 'comp1', role: 'manager', permissions };
    next();
  });
  app.use('/', router);
  return app;
}

const CHARGE = {
  id: 'ch1',
  asaasPaymentId: 'pay_1',
  mode: 'single' as const,
  value: 100,
  dueDate: '2026-10-07',
  status: 'pending' as const,
  invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
  paidAsaasPaymentIds: [],
  createdBy: { id: 'user1', name: 'Ana' },
  createdAt: '2026-10-04T10:00:00.000Z',
};

describe('charges.routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('cria cobrança com manage:payments', async () => {
    mockService.createOrderCharge.mockResolvedValue(CHARGE);

    const res = await request(buildApp(['manage:payments']))
      .post('/o1/charges')
      .send({ value: 100, mode: 'single' });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, data: CHARGE });
    expect(mockService.createOrderCharge).toHaveBeenCalledWith(
      'comp1',
      'o1',
      { value: 100, mode: 'single' },
      { id: 'user1', name: 'Ana' },
    );
  });

  it('sem manage:payments → 403', async () => {
    const res = await request(buildApp(['read:all', 'write:orders']))
      .post('/o1/charges')
      .send({ value: 100, mode: 'single' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
    expect(mockService.createOrderCharge).not.toHaveBeenCalled();
  });

  it('valida corpo com zod', async () => {
    const app = buildApp(['manage:payments']);
    const cases = [
      {},
      { value: -1, mode: 'single' },
      { value: 100, mode: 'pix' },
      { value: 100, mode: 'cardInstallments' },
      { value: 100, mode: 'cardInstallments', installmentCount: 13 },
      { value: 100, mode: 'single', dueDate: '07/10/2026' },
    ];
    for (const body of cases) {
      const res = await request(app).post('/o1/charges').send(body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(mockService.createOrderCharge).not.toHaveBeenCalled();
  });

  it('erro de negócio vira status e código do serviço', async () => {
    mockService.createOrderCharge.mockRejectedValue(
      new AsaasServiceError('INVALID_VALUE', 'Value exceeds the order remaining balance'),
    );
    const res = await request(buildApp(['manage:payments']))
      .post('/o1/charges')
      .send({ value: 5000, mode: 'single' });
    expect(res.status).toBe(400);
    expect(res.body.error).toEqual({ code: 'INVALID_VALUE', message: 'Value exceeds the order remaining balance' });
  });

  it('cancela cobrança', async () => {
    mockService.cancelOrderCharge.mockResolvedValue({ ...CHARGE, status: 'canceled' });
    const res = await request(buildApp(['manage:payments'])).delete('/o1/charges/ch1');
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('canceled');
    expect(mockService.cancelOrderCharge).toHaveBeenCalledWith('comp1', 'o1', 'ch1');
  });

  it('cancelar cobrança inexistente → 404', async () => {
    mockService.cancelOrderCharge.mockRejectedValue(new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found'));
    const res = await request(buildApp(['manage:payments'])).delete('/o1/charges/nope');
    expect(res.status).toBe(404);
  });

  it('cancelar sem permissão → 403', async () => {
    const res = await request(buildApp(['read:all'])).delete('/o1/charges/ch1');
    expect(res.status).toBe(403);
  });
});
