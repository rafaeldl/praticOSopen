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
import router from '../analytics.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeSummary = {
  period: { start: '2026-02-01', end: '2026-02-20' },
  orders: { total: 10, byStatus: { quote: 2, approved: 3, progress: 2, done: 2, canceled: 1 } },
  revenue: { total: 1000, paid: 500, unpaid: 500, discount: 0 },
  topCustomers: [],
  topServices: [],
};

// ---- Tests -----------------------------------------------------------------

describe('Bot Analytics Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /financial -----------------------------------------------------

  describe('GET /financial', () => {
    it('does NOT return formatContext', async () => {
      mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeSummary as any);

      const app = buildApp(router);
      const res = await request(app).get('/financial');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      // formatContext is served only by GET /bot/link/context
      expect(res.body.data.formatContext).toBeUndefined();
    });

    it('does NOT return message', async () => {
      mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeSummary as any);

      const app = buildApp(router);
      const res = await request(app).get('/financial');

      expect(res.body.data.message).toBeUndefined();
    });

    it('period label is ISO format for period=month', async () => {
      mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeSummary as any);

      const app = buildApp(router);
      const res = await request(app).get('/financial?period=month');

      expect(res.body.data.summary.period.label).toMatch(/^\d{4}-\d{2}$/);
    });

    it('does NOT return formatContext even when companyCountry=US', async () => {
      mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeSummary as any);

      const app = buildApp(router, { companyCountry: 'US' });
      const res = await request(app).get('/financial');

      // Country -> currency/locale mapping is covered by format.utils.test.ts
      expect(res.body.data.formatContext).toBeUndefined();
    });
  });
});
