import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/order.service');
jest.mock('../../../services/customer.service');
jest.mock('../../../services/device.service');
jest.mock('../../../services/catalog.service');
jest.mock('../../../services/share-token.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));
jest.mock('../../../utils/validation.utils', () => {
  const actual = jest.requireActual('../../../utils/validation.utils');
  return {
    ...actual,
    validateInput: (_schema: any, data: any) => ({ success: true, data }),
  };
});

import * as orderService from '../../../services/order.service';
import * as customerService from '../../../services/customer.service';
import * as deviceService from '../../../services/device.service';
import * as catalogService from '../../../services/catalog.service';
import * as shareTokenService from '../../../services/share-token.service';

const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockCustomerService = customerService as jest.Mocked<typeof customerService>;
const mockDeviceService = deviceService as jest.Mocked<typeof deviceService>;
const mockCatalogService = catalogService as jest.Mocked<typeof catalogService>;
const mockShareTokenService = shareTokenService as jest.Mocked<typeof shareTokenService>;

// ---- Import router after mocks --------------------------------------------
import router from '../orders-management.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 1,
  status: 'approved',
  customer: { id: 'c1', name: 'Alice' },
  device: { id: 'd1', name: 'iPhone' },
  services: [{ service: { id: 's1', name: 'Screen Fix' }, value: 50, description: '' }],
  products: [{ product: { id: 'p1', name: 'Screen' }, value: 30, quantity: 1, description: '' }],
  photos: [],
  total: 80,
  discount: 0,
  paidAmount: 0,
  done: false,
  paid: false,
  payment: 'unpaid',
  dueDate: null,
  scheduledDate: null,
  company: { id: 'comp1', name: 'Test Co' },
  createdAt: '2026-01-01',
  createdBy: { id: 'user1', name: 'Test User' },
};

const fakeCustomer = { id: 'c1', name: 'Alice', phone: '+5548999990000' };
const fakeService = { id: 's1', name: 'Screen Fix', value: 50 };
const fakeProduct = { id: 'p1', name: 'Screen', value: 30 };

// ---- Tests -----------------------------------------------------------------

describe('Bot Orders Management Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockCustomerService.toCustomerAggr = jest.fn((c: any) => ({ id: c.id, name: c.name }));
    mockDeviceService.toDeviceAggr = jest.fn((d: any) => ({ id: d.id, name: d.name }));
  });

  // ----- POST /full ---------------------------------------------------------

  describe('POST /full', () => {
    it('returns raw data with formatContext, without message', async () => {
      mockCustomerService.getCustomer.mockResolvedValue(fakeCustomer as any);
      mockOrderService.createOrder.mockResolvedValue({ id: 'ord2', number: 2, status: 'quote' } as any);
      mockOrderService.getOrderByNumber.mockResolvedValue({ ...fakeOrder, number: 2 } as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/full')
        .send({ customerId: 'c1' });

      expect(res.status).toBe(201);
      expect(res.body.data.orderNumber).toBe(2);
      expect(res.body.data.services).toBeDefined();
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- POST /:number/services ---------------------------------------------

  describe('POST /:number/services', () => {
    it('returns serviceName, value, formatContext, without message', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockCatalogService.getService.mockResolvedValue(fakeService as any);
      mockOrderService.addServiceToOrderByNumber.mockResolvedValue({ success: true, newTotal: 130 } as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/services')
        .send({ serviceId: 's1' });

      expect(res.status).toBe(200);
      expect(res.body.data.serviceName).toBe('Screen Fix');
      expect(res.body.data.value).toBe(50);
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- POST /:number/products ---------------------------------------------

  describe('POST /:number/products', () => {
    it('returns productName, quantity, formatContext, without message', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockCatalogService.getProduct.mockResolvedValue(fakeProduct as any);
      mockOrderService.addProductToOrderByNumber.mockResolvedValue({ success: true, newTotal: 110 } as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/products')
        .send({ productId: 'p1', quantity: 2 });

      expect(res.status).toBe(200);
      expect(res.body.data.productName).toBe('Screen');
      expect(res.body.data.quantity).toBe(2);
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- DELETE /:number/services/:index ------------------------------------

  describe('DELETE /:number/services/:index', () => {
    it('returns removedServiceName and formatContext, without message', async () => {
      mockOrderService.removeServiceFromOrder.mockResolvedValue({
        success: true,
        removedService: { service: { name: 'Screen Fix' }, value: 50 },
        newTotal: 30,
      } as any);

      const app = buildApp(router);
      const res = await request(app).delete('/1/services/0');

      expect(res.status).toBe(200);
      expect(res.body.data.removedServiceName).toBe('Screen Fix');
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- DELETE /:number/products/:index ------------------------------------

  describe('DELETE /:number/products/:index', () => {
    it('returns removedProductName and formatContext, without message', async () => {
      mockOrderService.removeProductFromOrder.mockResolvedValue({
        success: true,
        removedProduct: { product: { name: 'Screen' }, value: 30 },
        newTotal: 50,
      } as any);

      const app = buildApp(router);
      const res = await request(app).delete('/1/products/0');

      expect(res.status).toBe(200);
      expect(res.body.data.removedProductName).toBe('Screen');
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });
  });

  // ----- GET /:number/details -----------------------------------------------

  describe('GET /:number/details', () => {
    it('returns order data with formatContext, without message', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockShareTokenService.getTokensForOrder.mockResolvedValue([]);

      const app = buildApp(router);
      const res = await request(app).get('/1/details');

      expect(res.status).toBe(200);
      expect(res.body.data.order.number).toBe(1);
      expect(res.body.data.formatContext).toBeDefined();
      expect(res.body.data.message).toBeUndefined();
    });

    it('formatContext reflects companyCountry from request', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockShareTokenService.getTokensForOrder.mockResolvedValue([]);

      const app = buildApp(router, { companyCountry: 'FR' });
      const res = await request(app).get('/1/details');

      expect(res.body.data.formatContext.currency).toBe('EUR');
      expect(res.body.data.formatContext.locale).toBe('fr-FR');
    });
  });
});
