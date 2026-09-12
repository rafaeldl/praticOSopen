/**
 * Bridge integration check against REAL /bot routers.
 *
 * bridge.test.ts covers callRoute's own contract against purpose-built toy
 * routers. This file exercises the same callRoute against the actual Express
 * routers every MCP tool will dispatch through — src/routes/bot/summary.routes
 * and src/routes/bot/orders.routes — with only the service layer mocked,
 * following the mocking style used in
 * src/routes/bot/__tests__/summary.routes.test.ts (jest.mock the service
 * module, import the router after the mocks are set up).
 *
 * orders.routes.ts has no `/:number/details` route (that pattern lives in
 * orders-management.routes.ts); the parameterised-path case below uses the
 * multi-digit `GET /:number` route that does exist on orders.routes.ts —
 * same path-matching behavior the bridge needs to survive.
 */

jest.mock('../../services/analytics.service');
jest.mock('../../services/order.service');

import { AuthenticatedRequest } from '../../models/types';
import { callRoute } from '../bridge';
import * as analyticsService from '../../services/analytics.service';
import * as orderService from '../../services/order.service';

import summaryRoutes from '../../routes/bot/summary.routes';
import ordersRoutes from '../../routes/bot/orders.routes';

const mockAnalyticsService = analyticsService as jest.Mocked<typeof analyticsService>;
const mockOrderService = orderService as jest.Mocked<typeof orderService>;

const source = {
  auth: { type: 'mcp', companyId: 'comp1', userId: 'user1' },
  userContext: { userId: 'user1', userName: 'Joao', companyId: 'comp1', role: 'admin' },
} as unknown as AuthenticatedRequest;

describe('callRoute against real /bot routers', () => {
  beforeEach(() => jest.clearAllMocks());

  it('resolves a plain GET path and returns the handler body (summary.routes /today)', async () => {
    mockAnalyticsService.getTodaySummary.mockResolvedValue({ newOrders: 3 } as any);

    const result = await callRoute(summaryRoutes, {
      method: 'GET',
      path: '/today',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body).toEqual({ success: true, data: { data: { newOrders: 3 } } });
  });

  it('propagates req.userContext.companyId from source to the service call (summary.routes /today)', async () => {
    mockAnalyticsService.getTodaySummary.mockResolvedValue({} as any);

    await callRoute(summaryRoutes, {
      method: 'GET',
      path: '/today',
      source,
    });

    expect(mockAnalyticsService.getTodaySummary).toHaveBeenCalledWith('comp1');
  });

  it('populates req.params on a parameterised path and reaches the right handler (orders.routes GET /:number)', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue({ id: 'ord1', number: 4821, status: 'quote' } as any);

    const result = await callRoute(ordersRoutes, {
      method: 'GET',
      path: '/4821',
      source,
    });

    expect(result.status).toBe(200);
    expect(result.body.data.order.number).toBe(4821);
    // req.params.number arrived as the string '4821' and was parsed to a
    // number before reaching the service — proves real path-to-regexp
    // matching, not a hand-rolled path parser.
    expect(mockOrderService.getOrderByNumber).toHaveBeenCalledWith('comp1', 4821);
  });

  it('delivers a query string passed via options.query as req.query (orders.routes GET /list)', async () => {
    mockOrderService.listOrders.mockResolvedValue({ data: [], total: 0, hasMore: false });

    const result = await callRoute(ordersRoutes, {
      method: 'GET',
      path: '/list',
      query: { status: 'quote' },
      source,
    });

    expect(result.status).toBe(200);
    expect(mockOrderService.listOrders).toHaveBeenCalledWith(
      'comp1',
      expect.objectContaining({ status: 'quote' }),
    );
  });

  it('returns 404 without throwing for an unmatched path', async () => {
    const result = await callRoute(ordersRoutes, {
      method: 'GET',
      path: '/does/not/exist',
      source,
    });

    expect(result.status).toBe(404);
  });
});
