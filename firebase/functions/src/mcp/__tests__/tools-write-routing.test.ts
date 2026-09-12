/**
 * Routing check for the 6 write tools against the REAL /bot routers.
 *
 * tools-write.test.ts mocks `callRoute` itself, so a wrong `path`/router pair
 * would pass silently — the mock just echoes back whatever the test told it
 * to expect. This file uses the real `callRoute` (Task 3) dispatching into
 * the real Express routers registered by `registerWriteTools`, mocking only
 * the service layer beneath them (same style as tools-read-routing.test.ts).
 *
 * Every assertion checks for a distinctive value (an order number, a
 * customer name) that no wrong unwrap or wrong router could produce by
 * accident — asserting only "not 404" would have let a wrong `body.data`
 * path through silently, exactly like Task 6's first pass.
 */

jest.mock('../../services/customer.service');
jest.mock('../../services/device.service');
jest.mock('../../services/catalog.service');
jest.mock('../../services/order.service');
jest.mock('../../services/share-token.service');
jest.mock('../../services/comment.service');

import { registerWriteTools } from '../tools/write';
import {
  AuthenticatedRequest,
  Customer,
  Service,
  Product,
  Order,
  ShareToken,
  CompanyAggr,
  UserAggr,
} from '../../models/types';
import type { OrderComment } from '../../models/types';

import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as catalogService from '../../services/catalog.service';
import * as orderService from '../../services/order.service';
import * as shareTokenService from '../../services/share-token.service';
import * as commentService from '../../services/comment.service';

const mockCustomerService = customerService as jest.Mocked<typeof customerService>;
const mockCatalogService = catalogService as jest.Mocked<typeof catalogService>;
const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockShareTokenService = shareTokenService as jest.Mocked<typeof shareTokenService>;
const mockCommentService = commentService as jest.Mocked<typeof commentService>;
// deviceService is mocked but only toDeviceAggr/createDevice are touched by
// these paths, both indirectly via jest.mock's auto-mock defaults.
void deviceService;

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

// Distinctive, non-default values throughout: a value a wrong unwrap or wrong
// router could never happen to produce, so asserting on it in the tool's
// text output locks in both the router/path AND the response unwrap.
const fakeCustomer: Customer = {
  id: 'cust-9987',
  name: 'Zylphoria Nonstandard',
  phone: '11999999999',
  company,
  createdAt: now,
  createdBy,
};

const fakeService: Service = {
  id: 'srv-4471',
  name: 'Troca de óleo sintético',
  value: 350,
  company,
  createdAt: now,
  createdBy,
};

const fakeProduct: Product = {
  id: 'prod-5582',
  name: 'Filtro de ar premium',
  value: 88,
  company,
  createdAt: now,
  createdBy,
};

// One order fixture per tool so each assertion can only pass if that tool's
// own unwrap pulled the right object off `body.data.order`.
function orderFixture(overrides: Partial<Order>): Order {
  return {
    id: 'order-id',
    number: 0,
    total: 0,
    discount: 0,
    status: 'quote',
    done: false,
    paid: false,
    payment: 'unpaid',
    paidAmount: 0,
    company,
    createdAt: now,
    createdBy,
    ...overrides,
  };
}

const orderForCreate = orderFixture({
  id: 'order-6173',
  number: 6173,
  status: 'quote',
  total: 999.5,
  customer: { id: 'cust-9987', name: 'Zylphoria Nonstandard', phone: '11999999999' },
});

const orderForStatus = orderFixture({
  id: 'order-5510',
  number: 5510,
  status: 'approved',
  total: 420,
  customer: { id: 'cust-status', name: 'Cliente StatusMutante' },
});

const orderForUpdate = orderFixture({
  id: 'order-3391',
  number: 3391,
  status: 'progress',
  total: 210,
  customer: { id: 'cust-update', name: 'Cliente Atualizavel' },
});

const orderForAddService = orderFixture({
  id: 'order-7001',
  number: 7001,
  status: 'quote',
  total: 350,
  customer: { id: 'cust-service', name: 'Cliente Servico Adicionado' },
});

const orderForAddProduct = orderFixture({
  id: 'order-7002',
  number: 7002,
  status: 'quote',
  total: 176,
  customer: { id: 'cust-product', name: 'Cliente Produto Adicionado' },
});

const orderForComment = orderFixture({
  id: 'order-9001',
  number: 9001,
  status: 'quote',
  total: 100,
  customer: { id: 'cust-comment', name: 'Cliente Comentado' },
});

// Active token so buildOrderDetail() doesn't fall through to
// generateShareToken() (also mocked, but this keeps the fixtures focused on
// what each test is actually locking in).
const activeToken: ShareToken = {
  token: 'tok-active',
  orderId: 'order-any',
  companyId: 'comp1',
  permissions: ['view', 'approve', 'comment'],
  customer: { id: 'cust-9987', name: 'Zylphoria Nonstandard' },
  createdAt: now,
  expiresAt: '2099-01-01T00:00:00.000Z',
  createdBy,
  viewCount: 0,
};

function assertRouteResolved(result: any) {
  expect(result.content[0].text).not.toContain('No route for');
  expect(result.isError).not.toBe(true);
}

describe('write tools routing (real callRoute, real routers)', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCustomerService.getCustomer.mockResolvedValue(fakeCustomer);
    mockCustomerService.toCustomerAggr.mockReturnValue({
      id: fakeCustomer.id,
      name: fakeCustomer.name,
      phone: fakeCustomer.phone,
    });
    mockCustomerService.createCustomer.mockResolvedValue({
      id: 'cust-new-1',
      customer: { id: 'cust-new-1', name: 'Cliente Cadastro Distintivo', phone: '11977776666' },
    });

    mockCatalogService.getService.mockResolvedValue(fakeService);
    mockCatalogService.getProduct.mockResolvedValue(fakeProduct);

    mockOrderService.findRecentOrderByCustomer.mockResolvedValue(null);
    mockOrderService.createOrder.mockResolvedValue({
      id: orderForCreate.id,
      number: orderForCreate.number,
      status: orderForCreate.status,
    });
    mockOrderService.addServiceToOrderByNumber.mockResolvedValue({ success: true, newTotal: 350 });
    mockOrderService.addProductToOrderByNumber.mockResolvedValue({ success: true, newTotal: 176 });
    mockOrderService.updateOrder.mockResolvedValue(true);

    mockShareTokenService.getTokensForOrder.mockResolvedValue([activeToken]);

    mockCommentService.addComment.mockResolvedValue({
      id: 'comment-1',
      text: 'ok',
      authorType: 'internal',
      author: { name: 'Joao' },
      source: 'bot',
      isInternal: true,
      createdAt: now,
    } as OrderComment);
  });

  it('create_order resolves via orders-management.routes POST /full', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForCreate);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('create_order')!.handler({
      customerId: 'cust-9987',
      services: [{ serviceId: 'srv-4471' }],
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('#6173');
    expect(result.content[0].text).toContain('Zylphoria Nonstandard');
  });

  it('update_order_status resolves via orders.routes PATCH /:number/status (NOT orders-management)', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForStatus);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('update_order_status')!.handler({
      orderNumber: 5510,
      status: 'progress',
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('#5510');
    expect(result.content[0].text).toContain('Cliente StatusMutante');
  });

  it('update_order resolves via orders-management.routes PATCH /:number', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForUpdate);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('update_order')!.handler({
      orderNumber: 3391,
      dueDate: '2026-10-01T00:00:00.000Z',
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('#3391');
    expect(result.content[0].text).toContain('Cliente Atualizavel');
  });

  it('add_order_item resolves via orders-management.routes POST /:number/services', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForAddService);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('add_order_item')!.handler({
      orderNumber: 7001,
      type: 'service',
      itemId: 'srv-4471',
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('#7001');
    expect(result.content[0].text).toContain('Cliente Servico Adicionado');
  });

  it('add_order_item resolves via orders-management.routes POST /:number/products', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForAddProduct);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('add_order_item')!.handler({
      orderNumber: 7002,
      type: 'product',
      itemId: 'prod-5582',
      quantity: 2,
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('#7002');
    expect(result.content[0].text).toContain('Cliente Produto Adicionado');
  });

  it('add_order_comment resolves via comments.routes POST /:number/comments', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForComment);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('add_order_comment')!.handler({
      orderNumber: 9001,
      text: 'Cliente confirmou horario de retirada',
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('9001');
  });

  it('create_entity resolves via entities.routes POST /entities/customers', async () => {
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('create_entity')!.handler({
      type: 'customer',
      name: 'Cliente Cadastro Distintivo',
      phone: '11977776666',
    });

    assertRouteResolved(result);
    expect(result.content[0].text).toContain('Cliente Cadastro Distintivo');
  });
});
