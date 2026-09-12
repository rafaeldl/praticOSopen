/**
 * Routing check for the 7 read tools against the REAL /bot routers.
 *
 * tools-read.test.ts mocks `callRoute` itself, so a wrong `path`/router pair
 * would pass silently — the mock just echoes back whatever the test told it
 * to expect. This file uses the real `callRoute` (Task 3) dispatching into
 * the real Express routers registered by `registerReadTools`, mocking only
 * the service layer beneath them (same style as
 * src/routes/bot/__tests__/summary.routes.test.ts and
 * src/mcp/__tests__/bridge-integration.test.ts). If a tool's router/path
 * pair is wrong, the real router returns 404 and this test fails.
 */

jest.mock('../../services/customer.service');
jest.mock('../../services/device.service');
jest.mock('../../services/catalog.service');
jest.mock('../../services/order.service');
jest.mock('../../services/analytics.service');
jest.mock('../../services/share-token.service');

import { registerReadTools } from '../tools/read';
import {
  AuthenticatedRequest,
  Customer,
  Device,
  Service,
  Product,
  Order,
  CompanyAggr,
  UserAggr,
  AnalyticsSummary,
} from '../../models/types';
import type { TodaySummaryData } from '../../services/analytics.service';
import type { PendingItems } from '../../models/types';

import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as catalogService from '../../services/catalog.service';
import * as orderService from '../../services/order.service';
import * as analyticsService from '../../services/analytics.service';
import * as shareTokenService from '../../services/share-token.service';

const mockCustomerService = customerService as jest.Mocked<typeof customerService>;
const mockDeviceService = deviceService as jest.Mocked<typeof deviceService>;
const mockCatalogService = catalogService as jest.Mocked<typeof catalogService>;
const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockAnalyticsService = analyticsService as jest.Mocked<typeof analyticsService>;
const mockShareTokenService = shareTokenService as jest.Mocked<typeof shareTokenService>;

type Handler = (args: any) => Promise<any>;

function fakeServer() {
  const tools = new Map<string, { config: any; handler: Handler }>();
  return {
    tools,
    registerTool(name: string, config: any, handler: Handler) {
      tools.set(name, { config, handler });
    },
  };
}

const company: CompanyAggr = { id: 'comp1', name: 'Empresa Teste' };
const createdBy: UserAggr = { id: 'user1', name: 'Joao' };
const now = '2026-09-12T10:00:00.000Z';

const req = {
  auth: { type: 'mcp', companyId: 'comp1', userId: 'user1' },
  userContext: {
    userId: 'user1',
    userName: 'Joao',
    companyId: 'comp1',
    companyName: 'Empresa Teste',
    role: 'admin',
    permissions: ['read:all', 'write:all'],
  },
} as unknown as AuthenticatedRequest;

const fakeCustomer: Customer = {
  id: 'cust-1',
  name: 'Cliente Teste',
  phone: '11999999999',
  company,
  createdAt: now,
  createdBy,
};

const fakeDevice: Device = {
  id: 'dev-1',
  name: 'Fiat Uno',
  serial: 'ABC1D23',
  company,
  createdAt: now,
  createdBy,
};

const fakeService: Service = {
  id: 'srv-1',
  name: 'Troca de óleo',
  value: 150,
  company,
  createdAt: now,
  createdBy,
};

const fakeProduct: Product = {
  id: 'prod-1',
  name: 'Filtro',
  value: 40,
  company,
  createdAt: now,
  createdBy,
};

const fakeOrder: Order = {
  id: 'order-1',
  number: 42,
  total: 230,
  discount: 0,
  status: 'progress',
  done: false,
  paid: false,
  payment: 'unpaid',
  paidAmount: 0,
  company,
  createdAt: now,
  createdBy,
};

const fakeTodaySummary: TodaySummaryData = {
  totalOrders: 10,
  toApprove: 3,
  dueToday: 2,
  unpaidAmount: 500,
  revenue: 1200,
  ordersCreatedToday: 5,
};

const fakePendingItems: PendingItems = {
  toApprove: [],
  dueToday: [],
  unpaid: [],
  overdue: [],
};

const fakeAnalyticsSummary: AnalyticsSummary = {
  period: { start: '2026-09-01', end: '2026-09-30' },
  orders: {
    total: 10,
    byStatus: { quote: 2, approved: 3, progress: 1, done: 4, canceled: 0 },
  },
  revenue: { total: 12500, paid: 9000, unpaid: 3500, discount: 0 },
  topCustomers: [],
  topServices: [],
};

// Signature the tell-tale 404 shape from callRoute's fallback in bridge.ts
// (`No route for ${method} ${path}`) would leave in a tool's text output.
function assertRouteResolved(result: any) {
  expect(result.content[0].text).not.toContain('No route for');
  expect(result.isError).not.toBe(true);
}

describe('read tools routing (real callRoute, real routers)', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCustomerService.searchCustomers.mockResolvedValue([fakeCustomer]);
    mockCustomerService.listCustomers.mockResolvedValue({ data: [fakeCustomer], total: 1, hasMore: false });

    mockDeviceService.searchDevices.mockResolvedValue([fakeDevice]);
    mockDeviceService.listDevices.mockResolvedValue({ data: [fakeDevice], total: 1, hasMore: false });

    mockCatalogService.searchServices.mockResolvedValue([fakeService]);
    mockCatalogService.listServices.mockResolvedValue({ data: [fakeService], total: 1, hasMore: false });
    mockCatalogService.searchProducts.mockResolvedValue([fakeProduct]);
    mockCatalogService.listProducts.mockResolvedValue({ data: [fakeProduct], total: 1, hasMore: false });

    mockOrderService.listOrders.mockResolvedValue({ data: [fakeOrder], total: 1, hasMore: false });
    mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder);

    mockAnalyticsService.getTodaySummary.mockResolvedValue(fakeTodaySummary);
    mockAnalyticsService.getPendingItems.mockResolvedValue(fakePendingItems);
    mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeAnalyticsSummary);

    mockShareTokenService.getTokensForOrder.mockResolvedValue([]);
  });

  it('search resolves (unified-search.routes POST /unified)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('search')!.handler({ customer: 'Cliente Teste' });

    assertRouteResolved(result);
  });

  it('list_orders resolves (orders.routes GET /list)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_orders')!.handler({});

    assertRouteResolved(result);
  });

  it('get_order resolves (orders-management.routes GET /:number/details)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_order')!.handler({ orderNumber: 42 });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('OS #42');
  });

  it('get_today_summary resolves (summary.routes GET /today)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_today_summary')!.handler({});

    assertRouteResolved(result);
  });

  it('get_pending_orders resolves (summary.routes GET /pending)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_pending_orders')!.handler({});

    assertRouteResolved(result);
  });

  it('get_revenue resolves (analytics.routes GET /financial)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_revenue')!.handler({});

    assertRouteResolved(result);
  });

  it('list_entities resolves (entities.routes GET /entities/customers)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_entities')!.handler({ type: 'customer' });

    assertRouteResolved(result);
  });
});
