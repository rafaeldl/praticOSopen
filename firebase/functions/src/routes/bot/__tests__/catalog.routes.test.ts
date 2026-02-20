import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/catalog.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));

import * as catalogService from '../../../services/catalog.service';

const mockCatalogService = catalogService as jest.Mocked<typeof catalogService>;

// ---- Import router after mocks --------------------------------------------
import router from '../catalog.routes';

// ---- Tests -----------------------------------------------------------------

describe('Bot Catalog Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /search --------------------------------------------------------

  describe('GET /search', () => {
    it('returns formatContext', async () => {
      mockCatalogService.searchServices.mockResolvedValue([]);
      mockCatalogService.searchProducts.mockResolvedValue([]);

      const app = buildApp(router);
      const res = await request(app).get('/search?q=test');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.formatContext.country).toBe('BR');
    });

    it('does NOT return message', async () => {
      mockCatalogService.searchServices.mockResolvedValue([]);
      mockCatalogService.searchProducts.mockResolvedValue([]);

      const app = buildApp(router);
      const res = await request(app).get('/search?q=test');

      expect(res.body.data.message).toBeUndefined();
    });

    it('returns raw data: services array, products array, query', async () => {
      mockCatalogService.searchServices.mockResolvedValue([
        { id: 's1', name: 'Test Service', value: 50 },
      ] as any);
      mockCatalogService.searchProducts.mockResolvedValue([
        { id: 'p1', name: 'Test Product', value: 30 },
      ] as any);

      const app = buildApp(router);
      const res = await request(app).get('/search?q=test');

      expect(Array.isArray(res.body.data.services)).toBe(true);
      expect(Array.isArray(res.body.data.products)).toBe(true);
      expect(res.body.data.query).toBe('test');
    });
  });
});
