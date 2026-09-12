/**
 * Fix round 1, item 2: proves the order card wiring through the REAL SDK
 * dispatch path, not by calling a tool's handler function directly.
 *
 * tools-read-routing.test.ts / tools-write-routing.test.ts build a fake
 * `{ registerTool }` object and call `server.tools.get(name)!.handler(args)`
 * — that never touches the SDK's `McpServer` request routing, its Zod
 * validation of `CallToolResult`/`ListToolsResult`, or its `_meta` handling.
 * A tool could silently lose `_meta: orderCardMeta()` (removed from a
 * registerTool config) or `orderResult` could revert to plain `ok(...)`, and
 * all 230 pre-existing tests would still pass, because none of them read the
 * result through an actual MCP `Client`.
 *
 * This file wires `buildMcpServer(req)` (the same function `router.ts` uses
 * in production) to a real `Client` over `InMemoryTransport.createLinkedPair`
 * and calls `client.listTools()` / `client.callTool()` — the exact same
 * request/response path a browser-hosted card or the ChatGPT/Claude runtime
 * uses. This also settles whether SDK 1.30's Zod schemas
 * (`ToolSchema`/`CallToolResultSchema`) pass `_meta` and `structuredContent`
 * through for a tool with no `outputSchema` — they do, because both fields
 * are declared explicitly on those schemas (`_meta: z.record(...).optional()`
 * on `ToolSchema`; `structuredContent` and the inherited loose-object
 * `_meta` on `CallToolResultSchema`), not extra client-side speculation.
 */

jest.mock('../../services/customer.service');
jest.mock('../../services/device.service');
jest.mock('../../services/catalog.service');
jest.mock('../../services/order.service');
jest.mock('../../services/share-token.service');
jest.mock('../../services/comment.service');

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { buildMcpServer } from '../server';
import { ORDER_CARD_URI } from '../widgets/order-card';
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

import * as customerService from '../../services/customer.service';
import * as catalogService from '../../services/catalog.service';
import * as orderService from '../../services/order.service';
import * as shareTokenService from '../../services/share-token.service';
import * as deviceService from '../../services/device.service';

const mockCustomerService = customerService as jest.Mocked<typeof customerService>;
const mockCatalogService = catalogService as jest.Mocked<typeof catalogService>;
const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockShareTokenService = shareTokenService as jest.Mocked<typeof shareTokenService>;
// deviceService is mocked (registerReadTools/registerWriteTools import it
// transitively) but none of the 5 order tools under test call it directly.
void deviceService;

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

const orderForGet = orderFixture({
  id: 'order-42',
  number: 42,
  status: 'progress',
  total: 230,
  customer: { id: 'cust-9987', name: 'Zylphoria Nonstandard' },
});

const orderForCreate = orderFixture({
  id: 'order-6173',
  number: 6173,
  status: 'quote',
  total: 999.5,
  customer: { id: 'cust-9987', name: 'Zylphoria Nonstandard' },
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

const orderForAddItem = orderFixture({
  id: 'order-7001',
  number: 7001,
  status: 'quote',
  total: 350,
  customer: { id: 'cust-service', name: 'Cliente Servico Adicionado' },
});

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

const ORDER_CARD_TOOLS = [
  'get_order',
  'create_order',
  'update_order_status',
  'update_order',
  'add_order_item',
] as const;

async function connectClient() {
  const server = buildMcpServer(req);
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: 'order-card-dispatch-test', version: '1.0.0' });
  await Promise.all([client.connect(clientTransport), server.connect(serverTransport)]);
  return { client, server };
}

describe('order card through the real SDK dispatch (tools/list + tools/call)', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    mockCustomerService.getCustomer.mockResolvedValue(fakeCustomer);
    mockCustomerService.toCustomerAggr.mockReturnValue({
      id: fakeCustomer.id,
      name: fakeCustomer.name,
      phone: fakeCustomer.phone,
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
    mockOrderService.updateOrder.mockResolvedValue(true);

    mockShareTokenService.getTokensForOrder.mockResolvedValue([activeToken]);
  });

  it('tools/list expoe _meta.ui.resourceUri nas 5 tools que retornam OS, e em nenhuma outra', async () => {
    const { client } = await connectClient();
    const { tools } = await client.listTools();

    for (const name of ORDER_CARD_TOOLS) {
      const tool = tools.find((t) => t.name === name);
      expect(tool).toBeDefined();
      const meta = tool!._meta as { ui?: { resourceUri?: string } } | undefined;
      expect(meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
      expect((tool!._meta as any)?.['openai/outputTemplate']).toBe(ORDER_CARD_URI);
      expect(meta?.ui && 'visibility' in meta.ui).toBe(false);
    }

    const withoutCard = tools.filter((t) => !(ORDER_CARD_TOOLS as readonly string[]).includes(t.name));
    expect(withoutCard.length).toBeGreaterThan(0);
    for (const tool of withoutCard) {
      expect((tool._meta as any)?.ui?.resourceUri).toBeUndefined();
    }
  });

  it('get_order via tools/call real devolve o card (resourceUri + structuredContent.order)', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForGet);
    const { client } = await connectClient();

    const result: any = await client.callTool({ name: 'get_order', arguments: { orderNumber: 42 } });

    expect(result.isError).not.toBe(true);
    expect(result._meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
    expect(result.structuredContent.order.number).toBe(42);
    expect(result.content[0].text).toContain('#42');
  });

  it('create_order via tools/call real devolve o card', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForCreate);
    const { client } = await connectClient();

    const result: any = await client.callTool({
      name: 'create_order',
      arguments: { customerId: 'cust-9987', services: [{ serviceId: 'srv-4471' }] },
    });

    expect(result.isError).not.toBe(true);
    expect(result._meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
    expect(result.structuredContent.order.number).toBe(6173);
  });

  it('update_order_status via tools/call real devolve o card', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForStatus);
    const { client } = await connectClient();

    const result: any = await client.callTool({
      name: 'update_order_status',
      arguments: { orderNumber: 5510, status: 'progress' },
    });

    expect(result.isError).not.toBe(true);
    expect(result._meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
    expect(result.structuredContent.order.number).toBe(5510);
  });

  it('update_order via tools/call real devolve o card', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForUpdate);
    const { client } = await connectClient();

    const result: any = await client.callTool({
      name: 'update_order',
      arguments: { orderNumber: 3391, dueDate: '2026-10-01T00:00:00.000Z' },
    });

    expect(result.isError).not.toBe(true);
    expect(result._meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
    expect(result.structuredContent.order.number).toBe(3391);
  });

  it('add_order_item via tools/call real devolve o card', async () => {
    mockOrderService.getOrderByNumber.mockResolvedValue(orderForAddItem);
    const { client } = await connectClient();

    const result: any = await client.callTool({
      name: 'add_order_item',
      arguments: { orderNumber: 7001, type: 'service', itemId: 'srv-4471' },
    });

    expect(result.isError).not.toBe(true);
    expect(result._meta?.ui?.resourceUri).toBe(ORDER_CARD_URI);
    expect(result.structuredContent.order.number).toBe(7001);
  });
});
