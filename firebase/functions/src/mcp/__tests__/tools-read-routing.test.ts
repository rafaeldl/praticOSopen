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
import type { PendingItems, PendingOrder } from '../../models/types';
import { money } from '../format/order';

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

// Distinctive, non-default values throughout this file: a fallback path
// (formatSummary's `?? 0`, formatRevenue reading the wrong nesting level,
// etc.) can never produce these by accident, so asserting on them in the
// tool's text output actually locks in the unwrap path — not just "the
// route didn't 404".
const fakeCustomer: Customer = {
  id: 'cust-9987',
  name: 'Zylphoria Nonstandard',
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

// Separate fixture for list_orders (orderService.listOrders), distinct from
// fakeOrder (used by getOrderByNumber for get_order) so each tool's assertion
// can only pass if its own unwrap path pulled the right object.
const fakeOrderForList: Order = {
  id: 'order-7734',
  number: 7734,
  total: 987.65,
  discount: 0,
  status: 'progress',
  done: false,
  paid: false,
  payment: 'unpaid',
  paidAmount: 0,
  customer: { id: 'cust-list', name: 'Cliente Improvavel' },
  company,
  createdAt: now,
  createdBy,
};

const fakeTodaySummary: TodaySummaryData = {
  totalOrders: 10,
  toApprove: 11,
  dueToday: 2,
  unpaidAmount: 500,
  revenue: 12345.67,
  ordersCreatedToday: 37,
};

const pendingToApprove: PendingOrder = {
  id: 'pending-1',
  number: 5551,
  customer: { id: 'cust-p1', name: 'Cliente Aprovar' },
  device: { id: 'dev-p1', name: 'Aparelho Aprovar' },
  total: 321,
  createdAt: now,
};

const pendingOverdue: PendingOrder = {
  id: 'pending-2',
  number: 8882,
  customer: { id: 'cust-p2', name: 'Cliente Vencido' },
  device: { id: 'dev-p2', name: 'Aparelho Vencido' },
  total: 654,
  remainingBalance: 654,
  daysOverdue: 5,
  createdAt: now,
};

const fakePendingItems: PendingItems = {
  toApprove: [pendingToApprove],
  dueToday: [],
  unpaid: [],
  overdue: [pendingOverdue],
};

const fakeAnalyticsSummary: AnalyticsSummary = {
  period: { start: '2026-09-01', end: '2026-09-30' },
  orders: {
    total: 10,
    byStatus: { quote: 2, approved: 3, progress: 1, done: 4, canceled: 0 },
  },
  revenue: { total: 12345.67, paid: 9999.99, unpaid: 2345.68, discount: 0 },
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

    mockOrderService.listOrders.mockResolvedValue({ data: [fakeOrderForList], total: 1, hasMore: false });
    mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder);

    mockAnalyticsService.getTodaySummary.mockResolvedValue(fakeTodaySummary);
    mockAnalyticsService.getPendingItems.mockResolvedValue(fakePendingItems);
    mockAnalyticsService.getAnalyticsSummary.mockResolvedValue(fakeAnalyticsSummary);

    mockShareTokenService.getTokensForOrder.mockResolvedValue([]);
  });

  it('search resolves and returns the real customer (unified-search.routes POST /unified)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('search')!.handler({ customer: 'Cliente Teste' });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('cust-9987');
    expect(result.content[0].text).toContain('Zylphoria Nonstandard');
  });

  it('list_orders resolves and returns the real order (orders.routes GET /list)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_orders')!.handler({});

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('7734');
    expect(result.content[0].text).toContain('Cliente Improvavel');
    expect(result.content[0].text).toContain(money(987.65));
  });

  it('get_order resolves (orders-management.routes GET /:number/details)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_order')!.handler({ orderNumber: 42 });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('OS #42');
  });

  it('get_today_summary resolves and returns the real summary (summary.routes GET /today)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_today_summary')!.handler({});

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('37');
    expect(result.content[0].text).toContain('11');
    expect(result.content[0].text).toContain(money(12345.67));
  });

  it('get_pending_orders resolves and returns both buckets (summary.routes GET /pending)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_pending_orders')!.handler({});

    assertRouteResolved(result);
    const text = result.content[0].text;
    expect(text).toContain('Aguardando aprovação');
    expect(text).toContain('5551');
    expect(text).toContain('Vencido');
    expect(text).toContain('8882');
  });

  it('get_revenue resolves and returns the real figures (analytics.routes GET /financial)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_revenue')!.handler({});

    assertRouteResolved(result);
    const text = result.content[0].text;
    expect(text).toContain(money(12345.67));
    expect(text).toContain(money(9999.99));
    expect(text).toContain(money(2345.68));
  });

  it('list_entities resolves and returns the real customer (entities.routes GET /entities/customers)', async () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_entities')!.handler({ type: 'customer' });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('cust-9987');
    expect(result.content[0].text).toContain('Zylphoria Nonstandard');
  });

  it('list_order_photos resolves against photos.routes (GET /:number/photos)', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue({
      id: 'order-1',
      number: 42,
      photos: [
        {
          id: 'photo-uuid-1',
          url: 'https://storage.googleapis.com/test/photo-uuid-1.jpg',
          storagePath: 'tenants/c1/orders/o1/photos/photo-uuid-1.jpg',
          description: 'Foto do painel',
          createdAt: new Date(),
          createdBy: { id: 'u1', name: 'Tecnico Teste' },
        },
      ],
    } as any);

    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_order_photos')!.handler({ orderNumber: 42 });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('photo-uuid-1');
    expect(result.content[0].text).toContain('Foto do painel');
  });
});
