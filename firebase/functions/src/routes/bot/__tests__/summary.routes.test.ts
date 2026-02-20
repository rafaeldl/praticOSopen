import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/analytics.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));

import * as analyticsService from '../../../services/analytics.service';

const mockAnalyticsService = analyticsService as jest.Mocked<typeof analyticsService>;

// ---- Import router after mocks --------------------------------------------
import router from '../summary.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeTodayData = {
  newOrders: 3,
  completedOrders: 2,
  revenue: 500,
};

const fakePendingData = {
  toApprove: [],
  dueToday: [],
  unpaid: [],
  overdue: [],
};

// ---- Tests -----------------------------------------------------------------

describe('Bot Summary Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /today ---------------------------------------------------------

  describe('GET /today', () => {
    it('returns formatContext', async () => {
      mockAnalyticsService.getTodaySummary.mockResolvedValue(fakeTodayData as any);

      const app = buildApp(router);
      const res = await request(app).get('/today');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeDefined();
    });

    it('does NOT return message', async () => {
      mockAnalyticsService.getTodaySummary.mockResolvedValue(fakeTodayData as any);

      const app = buildApp(router);
      const res = await request(app).get('/today');

      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- GET /pending -------------------------------------------------------

  describe('GET /pending', () => {
    it('returns formatContext', async () => {
      mockAnalyticsService.getPendingItems.mockResolvedValue(fakePendingData as any);

      const app = buildApp(router);
      const res = await request(app).get('/pending');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeDefined();
    });
  });
});
