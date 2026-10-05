import express from 'express';
import request from 'supertest';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../middleware/share-token.middleware', () => ({
  shareTokenAuth: (req: any, _res: any, next: any) => {
    req.shareTokenAuth = {
      type: 'shareToken',
      token: req.params.token,
      companyId: 'comp1',
      orderId: 'ord1',
      permissions: ['view'],
      customer: { id: 'cust1', name: 'Alice Souza', phone: '+5511999998888' },
    };
    next();
  },
  requireSharePermission: () => (_req: any, _res: any, next: any) => next(),
}));

jest.mock('../../../services/firestore.service', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn().mockResolvedValue({
          exists: true,
          data: () => ({ name: 'Oficina Teste', country: 'BR' }),
        }),
      })),
    })),
  },
  getTenantCollection: jest.fn(),
}));

jest.mock('../../../services/share-token.service', () => ({}));
jest.mock('../../../services/notification.service', () => ({}));
jest.mock('../../../services/comment.service', () => ({
  getCustomerVisibleComments: jest.fn().mockResolvedValue([]),
}));
jest.mock('../../../services/order.service', () => ({
  getOrder: jest.fn(),
  calculateRemainingBalance: jest.fn(() => 100),
}));
jest.mock('../../../services/asaas/charge.service', () => ({
  getOpenOrLatestPaidCharge: jest.fn(),
}));
jest.mock('../../../services/asaas/connection.service', () => ({
  getPaymentSettings: jest.fn(),
}));

import * as orderService from '../../../services/order.service';
import * as chargeService from '../../../services/asaas/charge.service';
import * as connectionService from '../../../services/asaas/connection.service';
import { OrderCharge } from '../../../models/asaas.types';
import router from '../orders.routes';

const mockGetOrder = orderService.getOrder as jest.Mock;
const mockGetCharge = chargeService.getOpenOrLatestPaidCharge as jest.Mock;
const mockGetSettings = connectionService.getPaymentSettings as jest.Mock;

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 42,
  status: 'done',
  customer: { id: 'cust1', name: 'Alice Souza' },
  services: [],
  products: [],
  total: 100,
  discount: 0,
  paidAmount: 0,
  company: { id: 'comp1', name: 'Oficina Teste' },
  createdAt: '2026-10-01T10:00:00.000Z',
};

function makeCharge(overrides: Partial<OrderCharge> = {}): OrderCharge {
  return {
    id: 'chg1',
    asaasPaymentId: 'pay_123',
    mode: 'single',
    value: 100,
    dueDate: '2026-10-07',
    status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    paidAsaasPaymentIds: [],
    createdBy: { id: 'user1', name: 'Rafael' },
    createdAt: '2026-10-04T12:00:00.000Z',
    ...overrides,
  };
}

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/public/orders', router);
  return app;
}

// ---- Tests -----------------------------------------------------------------

describe('GET /public/orders/:token — charge', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetOrder.mockResolvedValue(fakeOrder);
    mockGetSettings.mockResolvedValue({ asaasEnabled: true, asaasConnected: true });
  });

  it('returns charge null when the order has no charge', async () => {
    mockGetCharge.mockResolvedValue(null);

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(mockGetCharge).toHaveBeenCalledWith('comp1', 'ord1');
    expect(res.body.data.charge).toBeNull();
  });

  it('exposes only the public fields of a pending single charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge());

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.charge).toEqual({
      status: 'pending',
      value: 100,
      dueDate: '2026-10-07',
      mode: 'single',
      invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    });
    const raw = JSON.stringify(res.body);
    expect(raw).not.toContain('pay_123');
    expect(raw).not.toContain('chg1');
    expect(raw).not.toContain('paidAsaasPaymentIds');
  });

  it('includes installmentCount for a paid card-installments charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({
      mode: 'cardInstallments',
      installmentCount: 3,
      asaasInstallmentId: 'ins_1',
      status: 'paid',
      paidAt: '2026-10-05T09:00:00.000Z',
      paidAsaasPaymentIds: ['pay_1', 'pay_2', 'pay_3'],
    }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge).toEqual({
      status: 'paid',
      value: 100,
      dueDate: '2026-10-07',
      mode: 'cardInstallments',
      installmentCount: 3,
      invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    });
  });

  it('shows an overdue charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({ status: 'overdue' }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge.status).toBe('overdue');
  });

  it.each(['canceled', 'refunded'] as const)('hides a %s charge', async (status) => {
    mockGetCharge.mockResolvedValue(makeCharge({ status }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.charge).toBeNull();
  });

  it('returns charge null and still 200 when loading the charge fails', async () => {
    mockGetCharge.mockRejectedValue(new Error('firestore down'));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.order.number).toBe(42);
    expect(res.body.data.charge).toBeNull();
  });

  it('exposes exactly the allowed keys, even with every internal field set', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({
      mode: 'cardInstallments',
      installmentCount: 2,
      asaasInstallmentId: 'ins_9',
      status: 'paid',
      paidAt: '2026-10-05T09:00:00.000Z',
      paidAsaasPaymentIds: ['pay_a', 'pay_b'],
      appliedTransactions: [{
        id: 'asaas_pay_a',
        type: 'payment',
        amount: 50,
        createdAt: '2026-10-05T09:00:00.000Z',
        createdBy: { id: 'system', name: 'Asaas' },
      }],
      refundedAsaasPaymentIds: ['pay_refunded'],
    }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(Object.keys(res.body.data.charge).sort()).toEqual(
      ['dueDate', 'installmentCount', 'invoiceUrl', 'mode', 'status', 'value'],
    );
    const raw = JSON.stringify(res.body);
    for (const secret of ['ins_9', 'pay_a', 'pay_b', 'pay_refunded', 'asaas_pay_a', 'createdBy', '2026-10-04T12:00', 'paidAt', 'appliedTransactions', 'refundedAsaasPaymentIds']) {
      expect(raw).not.toContain(secret);
    }
  });

  it('omits installmentCount for a single charge even if the field is set', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({ installmentCount: 1 }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge).not.toHaveProperty('installmentCount');
  });

  it('shows a partially paid installment plan as paid (R1)', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({
      mode: 'cardInstallments',
      installmentCount: 3,
      asaasInstallmentId: 'ins_1',
      status: 'pending',
      paidAsaasPaymentIds: ['pay_1'],
    }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge).toEqual({
      status: 'paid',
      value: 100,
      dueDate: '2026-10-07',
      mode: 'cardInstallments',
      installmentCount: 3,
      invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    });
  });

  it.each(['pending', 'overdue'] as const)(
    'hides a %s charge when Asaas is disconnected (R2)',
    async (status) => {
      mockGetSettings.mockResolvedValue({ asaasEnabled: true, asaasConnected: false });
      mockGetCharge.mockResolvedValue(makeCharge({ status }));

      const res = await request(buildApp()).get('/public/orders/tok123');

      expect(res.status).toBe(200);
      expect(mockGetSettings).toHaveBeenCalledWith('comp1');
      expect(res.body.data.charge).toBeNull();
    },
  );

  it('still shows a paid charge when Asaas is disconnected (R2)', async () => {
    mockGetSettings.mockResolvedValue({ asaasEnabled: false, asaasConnected: false });
    mockGetCharge.mockResolvedValue(makeCharge({ status: 'paid', paidAt: '2026-10-05T09:00:00.000Z' }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge.status).toBe('paid');
  });

  it('returns charge null and still 200 when loading payment settings fails', async () => {
    mockGetSettings.mockRejectedValue(new Error('firestore down'));
    mockGetCharge.mockResolvedValue(makeCharge());

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.order.number).toBe(42);
    expect(res.body.data.charge).toBeNull();
  });
});
