import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/firestore.service', () =>
  jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
);
jest.mock('../../../services/asaas/customer-charge.service', () => ({
  ...jest.requireActual('../../../services/asaas/customer-charge.service'),
  createCustomerCharge: jest.fn(),
  cancelCustomerCharge: jest.fn(),
}));

import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import * as customerCharge from '../../../services/asaas/customer-charge.service';
import router from '../customer-payments.routes';

const mockCharge = customerCharge as jest.Mocked<typeof customerCharge>;

function buildApp(role: string, permissions: string[] = []) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'c1', userId: 'cons1' };
    r.userContext = { userId: 'cons1', userName: 'Bia', companyId: 'c1', role, permissions };
    next();
  });
  app.use('/', router);
  return app;
}

const RECEIPT = { receiptId: 'r1', paidAt: '2026-10-14T15:00:00.000Z', allocations: [{ orderId: 'o2', amount: 50 }] };

describe('customer-payments.routes', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    seed('companies/c1', { name: 'Oficina' });
    seed('companies/c1/orders/o2', {
      number: 2, status: 'done', total: 200, paidAmount: 0, transactions: [],
      customer: { id: 'cust1', name: 'João' }, createdBy: { id: 'other' }, createdAt: '2026-09-10T10:00:00.000Z',
    });
  });

  it('consultor registra recebimento em OS de outra pessoa', async () => {
    const res = await request(buildApp('consultant')).post('/cust1/receipts').send(RECEIPT);
    expect(res.status).toBe(201);
    expect(res.body.data).toEqual({ receiptId: 'r1', amount: 50 });
  });

  it('técnico não recebe → 403', async () => {
    const res = await request(buildApp('technician')).post('/cust1/receipts').send(RECEIPT);
    expect(res.status).toBe(403);
  });

  it('empresa sem valores e cobrança → 403', async () => {
    seed('companies/c1', { name: 'Oficina', useFinancial: false });
    const res = await request(buildApp('owner')).post('/cust1/receipts').send(RECEIPT);
    expect(res.status).toBe(403);
  });

  it('valor acima do aberto → 409', async () => {
    const res = await request(buildApp('consultant'))
      .post('/cust1/receipts')
      .send({ ...RECEIPT, allocations: [{ orderId: 'o2', amount: 201 }] });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('VALUE_EXCEEDS_BALANCE');
  });

  it('OS de outro cliente → 400', async () => {
    const res = await request(buildApp('consultant')).post('/cust9/receipts').send(RECEIPT);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ORDER_NOT_OF_CUSTOMER');
  });

  it('corpo inválido → 400', async () => {
    const res = await request(buildApp('consultant')).post('/cust1/receipts').send({ receiptId: 'r1', allocations: [] });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('lista as OS em aberto do cliente com o mínimo', async () => {
    const res = await request(buildApp('consultant')).get('/cust1/open-orders');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([
      { id: 'o2', number: 2, open: 200, createdAt: '2026-09-10T10:00:00.000Z', own: false },
    ]);
  });

  it('mandar cobrança exige manage:payments', async () => {
    const res = await request(buildApp('consultant', ['read:all']))
      .post('/cust1/charges')
      .send({ orderIds: ['o2'], value: 100 });
    expect(res.status).toBe(403);
    expect(mockCharge.createCustomerCharge).not.toHaveBeenCalled();
  });

  it('mandar cobrança devolve a cobrança sem os campos internos', async () => {
    mockCharge.createCustomerCharge.mockResolvedValue({
      id: 'cc1', customer: { id: 'cust1' }, asaasPaymentId: 'pay_cc', value: 100, dueDate: '2026-10-20',
      status: 'pending', invoiceUrl: 'https://x', orderIds: ['o2'], allocations: [{ orderId: 'o2', amount: 100 }],
      paidAsaasPaymentIds: [], createdBy: { id: 'cons1', name: 'Bia' }, createdAt: 'x', appliedTransactions: [],
    } as any);
    const res = await request(buildApp('manager', ['manage:payments']))
      .post('/cust1/charges')
      .send({ orderIds: ['o2'], value: 100 });
    expect(res.status).toBe(201);
    expect(res.body.data.id).toBe('cc1');
    expect(res.body.data.appliedTransactions).toBeUndefined();
  });

  it('cancelar cobrança de várias OS', async () => {
    mockCharge.cancelCustomerCharge.mockResolvedValue({ id: 'cc1', status: 'canceled' } as any);
    const res = await request(buildApp('manager', ['manage:payments'])).delete('/cust1/charges/cc1');
    expect(res.status).toBe(200);
    expect(mockCharge.cancelCustomerCharge).toHaveBeenCalledWith('c1', 'cust1', 'cc1');
  });
});
