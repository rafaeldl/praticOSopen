import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/order.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));

import * as orderService from '../../../services/order.service';
const mockOrderService = orderService as jest.Mocked<typeof orderService>;

// ---- Import router after mocks --------------------------------------------
import router from '../orders.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 1,
  status: 'approved',
  customer: { id: 'c1', name: 'Alice' },
  device: { id: 'd1', name: 'iPhone' },
  services: [],
  products: [],
  photos: [{ id: 'p1', url: 'u1', storagePath: 's1' }],
  transactions: [{ id: 't1' }],
  total: 100,
  discount: 0,
  paidAmount: 0,
  done: false,
  paid: false,
  payment: 'unpaid',
  company: { id: 'comp1', name: 'Test Co' },
  createdAt: '2026-01-01',
  createdBy: { id: 'user1', name: 'Test User' },
};

// ---- Tests -----------------------------------------------------------------

describe('Bot Orders Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /list ----------------------------------------------------------

  describe('GET /list', () => {
    it('returns formatContext with correct shape', async () => {
      mockOrderService.listOrders.mockResolvedValue({ data: [], total: 0 } as any);

      const app = buildApp(router);
      const res = await request(app).get('/list');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.formatContext).toEqual({
        country: 'BR',
        locale: 'pt-BR',
        currency: 'BRL',
      });
    });

    it('does NOT return formattedList or message', async () => {
      mockOrderService.listOrders.mockResolvedValue({ data: [], total: 0 } as any);

      const app = buildApp(router);
      const res = await request(app).get('/list');

      expect(res.body.data.formattedList).toBeUndefined();
      expect(res.body.data.message).toBeUndefined();
    });

    it('returns orders as raw array with photosCount instead of photos', async () => {
      mockOrderService.listOrders.mockResolvedValue({
        data: [fakeOrder],
        total: 1,
      } as any);

      const app = buildApp(router);
      const res = await request(app).get('/list');

      expect(res.body.data.orders).toHaveLength(1);
      const order = res.body.data.orders[0];
      expect(order.photosCount).toBe(1);
      expect(order.photos).toBeUndefined();
      expect(order.transactions).toBeUndefined();
    });
  });

  // ----- GET /:number -------------------------------------------------------

  describe('GET /:number', () => {
    it('returns formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);

      const app = buildApp(router);
      const res = await request(app).get('/1');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.formatContext.country).toBe('BR');
    });

    it('does NOT return message', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);

      const app = buildApp(router);
      const res = await request(app).get('/1');

      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- PATCH /:number/status ----------------------------------------------

  describe('PATCH /:number/status', () => {
    it('returns raw data with previousStatus, newStatus, formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockOrderService.updateOrder.mockResolvedValue(true as any);

      const app = buildApp(router);
      const res = await request(app)
        .patch('/1/status')
        .send({ status: 'progress' });

      expect(res.status).toBe(200);
      expect(res.body.data.previousStatus).toBe('approved');
      expect(res.body.data.newStatus).toBe('progress');
      expect(res.body.data.formatContext).toBeDefined();
    });

    it('returns allowedTransitions on invalid transition', async () => {
      const doneOrder = { ...fakeOrder, status: 'done' };
      mockOrderService.getOrderByNumber.mockResolvedValue(doneOrder as any);

      const app = buildApp(router);
      const res = await request(app)
        .patch('/1/status')
        .send({ status: 'approved' });

      expect(res.status).toBe(400);
      expect(res.body.error.allowedTransitions).toEqual([]);
    });
  });
});
