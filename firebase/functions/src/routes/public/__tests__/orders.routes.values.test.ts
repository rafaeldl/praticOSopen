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
      permissions: ['view', 'approve', 'comment'],
      customer: { id: 'cust1', name: 'Alice Souza', phone: '+5511999998888' },
    };
    next();
  },
  requireSharePermission: () => (_req: any, _res: any, next: any) => next(),
}));

// Company document returned by db.collection('companies').doc(id).get()
let mockCompanyData: Record<string, unknown> = {};

jest.mock('../../../services/firestore.service', () => ({
  db: {
    collection: jest.fn((name: string) => ({
      doc: jest.fn(() => ({
        get: jest.fn().mockImplementation(async () => (
          name === 'companies'
            ? { exists: true, data: () => mockCompanyData }
            : { exists: false, data: () => undefined }
        )),
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
  calculateRemainingBalance: jest.fn(() => 230),
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
import router, { companyShowsValues } from '../orders.routes';

const mockGetOrder = orderService.getOrder as jest.Mock;
const mockGetCharge = chargeService.getOpenOrLatestPaidCharge as jest.Mock;
const mockGetSettings = connectionService.getPaymentSettings as jest.Mock;

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 42,
  status: 'quote',
  customer: { id: 'cust1', name: 'Alice Souza' },
  services: [
    { service: { id: 'srv1', name: 'Troca de oleo' }, value: 180, description: 'Sintetico' },
  ],
  products: [
    { product: { id: 'prd1', name: 'Filtro' }, value: 25, quantity: 2, description: null },
  ],
  total: 230,
  discount: 10,
  paidAmount: 0,
  company: { id: 'comp1', name: 'Oficina Teste' },
  createdAt: '2026-10-01T10:00:00.000Z',
};

const pendingCharge = {
  id: 'chg1',
  asaasPaymentId: 'pay_123',
  mode: 'single',
  value: 230,
  dueDate: '2026-10-07',
  status: 'pending',
  invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
  paidAsaasPaymentIds: [],
  createdBy: { id: 'user1', name: 'Rafael' },
  createdAt: '2026-10-04T12:00:00.000Z',
};

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/public/orders', router);
  return app;
}

// ---- Tests -----------------------------------------------------------------

describe('companyShowsValues', () => {
  it('shows values unless useFinancial is explicitly false', () => {
    expect(companyShowsValues(null)).toBe(true);
    expect(companyShowsValues(undefined)).toBe(true);
    expect(companyShowsValues({})).toBe(true);
    expect(companyShowsValues({ useFinancial: true })).toBe(true);
    expect(companyShowsValues({ useFinancial: false })).toBe(false);
  });
});

describe('GET /public/orders/:token — useFinancial', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetOrder.mockResolvedValue(fakeOrder);
    mockGetCharge.mockResolvedValue(pendingCharge);
    mockGetSettings.mockResolvedValue({ asaasEnabled: true, asaasConnected: true });
  });

  it('keeps every value when useFinancial is absent (old companies)', async () => {
    mockCompanyData = { name: 'Oficina Teste', country: 'BR' };

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    const { order } = res.body.data;
    expect(order.total).toBe(230);
    expect(order.discount).toBe(10);
    expect(order.paidAmount).toBe(0);
    expect(order.remainingBalance).toBe(230);
    expect(order.services[0].value).toBe(180);
    expect(order.products[0].value).toBe(25);
    expect(res.body.data.charge).toMatchObject({ status: 'pending', value: 230 });
    expect(res.body.data.showValues).toBe(true);
  });

  it('keeps every value when useFinancial is true', async () => {
    mockCompanyData = { name: 'Oficina Teste', country: 'BR', useFinancial: true };

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.order.total).toBe(230);
    expect(res.body.data.order.services[0].value).toBe(180);
    expect(res.body.data.charge).not.toBeNull();
    expect(res.body.data.showValues).toBe(true);
  });

  it('removes prices, totals, payments and the charge when useFinancial is false', async () => {
    mockCompanyData = { name: 'Oficina Teste', country: 'BR', useFinancial: false };

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    const { order } = res.body.data;
    for (const key of ['total', 'discount', 'paidAmount', 'remainingBalance']) {
      expect(order).not.toHaveProperty(key);
    }
    expect(order.services).toEqual([
      { name: 'Troca de oleo', description: 'Sintetico', deviceId: null },
    ]);
    expect(order.products).toEqual([
      { name: 'Filtro', quantity: 2, description: null, deviceId: null },
    ]);
    expect(res.body.data.charge).toBeNull();
    expect(res.body.data.showValues).toBe(false);
    // The charge is not even loaded
    expect(mockGetCharge).not.toHaveBeenCalled();
    expect(mockGetSettings).not.toHaveBeenCalled();

    const raw = JSON.stringify(res.body);
    for (const leak of ['230', '180', 'invoiceUrl', 'asaas.com']) {
      expect(raw).not.toContain(leak);
    }
  });

  it('keeps the rest of the report (items, status, company) when values are hidden', async () => {
    mockCompanyData = { name: 'Oficina Teste', country: 'BR', useFinancial: false };

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.order.number).toBe(42);
    expect(res.body.data.order.status).toBe('quote');
    expect(res.body.data.order.services).toHaveLength(1);
    expect(res.body.data.order.products).toHaveLength(1);
    expect(res.body.data.company.name).toBe('Oficina Teste');
    expect(res.body.data.permissions).toContain('approve');
  });
});
