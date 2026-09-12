import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/order.service');
jest.mock('../../../services/share-token.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));

import * as orderService from '../../../services/order.service';
import * as shareTokenService from '../../../services/share-token.service';
import { Order } from '../../../models/types';
const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockShareTokenService = shareTokenService as jest.Mocked<typeof shareTokenService>;

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

type ListOrdersResult = Awaited<ReturnType<typeof orderService.listOrders>>;

function makeOrder(number: number): Order {
  return {
    id: `ord${number}`,
    number,
    status: 'approved',
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
}

function listResult(data: Order[], total: number = data.length): ListOrdersResult {
  return { data, total, hasMore: data.length < total };
}

// ---- Tests -----------------------------------------------------------------

describe('Bot Orders Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /list ----------------------------------------------------------

  describe('GET /list', () => {
    it('does NOT return formatContext', async () => {
      mockOrderService.listOrders.mockResolvedValue({ data: [], total: 0 } as any);

      const app = buildApp(router);
      const res = await request(app).get('/list');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      // formatContext is served only by GET /bot/link/context
      expect(res.body.data.formatContext).toBeUndefined();
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

    describe('pagination', () => {
      const listCallParams = () => mockOrderService.listOrders.mock.calls[0][1];

      it('defaults to limit 10 and offset 0 when not sent (WhatsApp bot behavior)', async () => {
        mockOrderService.listOrders.mockResolvedValue(listResult([]));

        const res = await request(buildApp(router)).get('/list');

        expect(res.status).toBe(200);
        expect(mockOrderService.listOrders).toHaveBeenCalledWith(
          'comp1',
          expect.objectContaining({ limit: 10, offset: 0 }),
        );
      });

      it('honors the requested limit and returns every order', async () => {
        const orders = Array.from({ length: 30 }, (_, i) => makeOrder(i + 1));
        mockOrderService.listOrders.mockResolvedValue(listResult(orders, 42));

        const res = await request(buildApp(router)).get('/list?limit=30&status=approved');

        expect(listCallParams()).toEqual({ status: 'approved', limit: 30, offset: 0 });
        expect(res.body.data.orders).toHaveLength(30);
        expect(res.body.data.count).toBe(42);
      });

      it('honors the requested offset', async () => {
        mockOrderService.listOrders.mockResolvedValue(listResult([makeOrder(21)], 21));

        await request(buildApp(router)).get('/list?limit=20&offset=20');

        expect(listCallParams()).toEqual(expect.objectContaining({ limit: 20, offset: 20 }));
      });

      it('caps limit at 50', async () => {
        mockOrderService.listOrders.mockResolvedValue(listResult([]));

        await request(buildApp(router)).get('/list?limit=100000');

        expect(listCallParams().limit).toBe(50);
      });

      it('caps offset at 1000', async () => {
        mockOrderService.listOrders.mockResolvedValue(listResult([]));

        await request(buildApp(router)).get('/list?offset=100000');

        expect(listCallParams().offset).toBe(1000);
      });

      it.each(['abc', '0', '-5', '1.5', '10abc', ''])(
        'falls back to the default limit for invalid value %p',
        async (value) => {
          mockOrderService.listOrders.mockResolvedValue(listResult([]));

          await request(buildApp(router)).get(`/list?limit=${encodeURIComponent(value)}`);

          expect(listCallParams().limit).toBe(10);
        },
      );

      it('falls back to the default limit when limit is repeated', async () => {
        mockOrderService.listOrders.mockResolvedValue(listResult([]));

        await request(buildApp(router)).get('/list?limit=30&limit=40');

        expect(listCallParams().limit).toBe(10);
      });

      it.each(['abc', '-1', '2.5'])(
        'falls back to offset 0 for invalid value %p',
        async (value) => {
          mockOrderService.listOrders.mockResolvedValue(listResult([]));

          await request(buildApp(router)).get(`/list?offset=${encodeURIComponent(value)}`);

          expect(listCallParams().offset).toBe(0);
        },
      );
    });
  });

  // ----- GET /:number -------------------------------------------------------

  describe('GET /:number', () => {
    it('does NOT return formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);

      const app = buildApp(router);
      const res = await request(app).get('/1');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      // formatContext is served only by GET /bot/link/context
      expect(res.body.data.formatContext).toBeUndefined();
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
    it('returns full order detail with previousStatus, newStatus, formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockOrderService.updateOrder.mockResolvedValue(true as any);
      mockShareTokenService.getTokensForOrder.mockResolvedValue([]);

      const app = buildApp(router);
      const res = await request(app)
        .patch('/1/status')
        .send({ status: 'progress' });

      expect(res.status).toBe(200);
      expect(res.body.data.previousStatus).toBe('approved');
      expect(res.body.data.newStatus).toBe('progress');
      expect(res.body.data.order).toBeDefined();
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
