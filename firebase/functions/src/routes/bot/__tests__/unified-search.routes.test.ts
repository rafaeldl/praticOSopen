import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/customer.service');
jest.mock('../../../services/device.service');
jest.mock('../../../services/catalog.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../utils/validation.utils', () => {
  const actual = jest.requireActual('../../../utils/validation.utils');
  return {
    ...actual,
    validateInput: (_schema: any, data: any) => ({ success: true, data }),
  };
});

import * as deviceService from '../../../services/device.service';
import * as customerService from '../../../services/customer.service';
const mockDeviceService = deviceService as jest.Mocked<typeof deviceService>;
const mockCustomerService = customerService as jest.Mocked<typeof customerService>;

import router from '../unified-search.routes';

describe('Bot Unified Search Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /unified — deviceSerial', () => {
    it('returns available:null when search by deviceSerial misses', async () => {
      // Plate searches are exact-match. When the plate isn't in the catalog,
      // returning a fallback list of all-devices misled the bot into picking
      // an unrelated id as if it matched the plate. The bot must use inline
      // device:{...} (find-or-create) instead.
      mockDeviceService.findDeviceBySerial.mockResolvedValue(null);
      // Ensure searchDevices is NOT used as fallback for serial searches
      mockDeviceService.searchDevices = jest.fn().mockResolvedValue([
        { id: 'unrelated-1', name: 'Some Other Car', serial: 'XYZ0000' },
      ]);

      const app = buildApp(router);
      const res = await request(app)
        .post('/unified')
        .send({ deviceSerial: 'RKZ1J37' });

      expect(res.status).toBe(200);
      expect(res.body.data.device.exact).toBeNull();
      expect(res.body.data.device.suggestions).toEqual([]);
      expect(res.body.data.device.available).toBeNull();
      // Critical: the all-devices fallback must NOT be invoked for serial searches
      expect(mockDeviceService.searchDevices).not.toHaveBeenCalledWith('comp1', '', expect.any(Number));
    });

    it('still returns exact match when serial does match', async () => {
      mockDeviceService.findDeviceBySerial.mockResolvedValue({
        id: 'd-match', name: 'Jeep Compass', serial: 'RKZ1J37',
      } as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/unified')
        .send({ deviceSerial: 'RKZ1J37' });

      expect(res.status).toBe(200);
      expect(res.body.data.device.exact).toEqual({
        id: 'd-match',
        name: 'Jeep Compass',
        serial: 'RKZ1J37',
      });
      expect(res.body.data.device.available).toBeNull();
    });

    it('still returns available fallback for name-based device search', async () => {
      // Name-based searches keep the available fallback (legitimate UX hint).
      mockDeviceService.searchDevices = jest.fn(async (_companyId: string, query: string) => {
        if (query === '') {
          return [{ id: 'avail-1', name: 'Some Car', serial: 'AAA0001' }] as any;
        }
        return [];
      });

      const app = buildApp(router);
      const res = await request(app)
        .post('/unified')
        .send({ device: 'NonExistent Brand' });

      expect(res.status).toBe(200);
      expect(res.body.data.device.exact).toBeNull();
      expect(res.body.data.device.suggestions).toEqual([]);
      expect(res.body.data.device.available).toEqual([
        { id: 'avail-1', name: 'Some Car', serial: 'AAA0001' },
      ]);
    });
  });

  describe('POST /unified — customer', () => {
    it('available list still returned for customer name search misses', async () => {
      // Customer search isn't affected by the fix.
      mockCustomerService.searchCustomers = jest.fn(async (_c: string, query: string) => {
        if (query === '') {
          return [{ id: 'cust-1', name: 'Alice', phone: '+5548999990000' }] as any;
        }
        return [];
      });

      const app = buildApp(router);
      const res = await request(app)
        .post('/unified')
        .send({ customer: 'NonExistentName' });

      expect(res.status).toBe(200);
      expect(res.body.data.customer.available).toBeTruthy();
      expect(res.body.data.customer.available.length).toBeGreaterThan(0);
    });
  });
});
