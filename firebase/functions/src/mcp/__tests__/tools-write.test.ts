jest.mock('../bridge');

import { callRoute } from '../bridge';
import { registerWriteTools } from '../tools/write';
import { AuthenticatedRequest } from '../../models/types';

const mockCallRoute = callRoute as jest.MockedFunction<typeof callRoute>;

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

const req = {
  auth: { type: 'mcp', companyId: 'comp1', userId: 'user1' },
} as unknown as AuthenticatedRequest;

// OrderDetailResponse shape: { order: OrderDetail, formatContext }.
const orderBody = {
  status: 200,
  body: { data: { order: { number: 42, status: 'quote', total: 350 } } },
};

describe('write tools', () => {
  let logSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    logSpy.mockRestore();
  });

  it('registra as 6 tools de escrita', () => {
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    expect([...server.tools.keys()].sort()).toEqual([
      'add_order_comment',
      'add_order_item',
      'create_entity',
      'create_order',
      'update_order',
      'update_order_status',
    ]);
  });

  it('marca todas como readOnlyHint false', () => {
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    for (const [, tool] of server.tools) {
      expect(tool.config.annotations.readOnlyHint).toBe(false);
    }
  });

  it('create_order posta em /full e devolve o card', async () => {
    mockCallRoute.mockResolvedValue(orderBody);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('create_order')!.handler({
      customerId: 'cust1',
      services: [{ serviceId: 'srv1', value: 350 }],
    });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ method: 'POST', path: '/full' }),
    );
    expect(result.content[0].text).toContain('OS #42');
  });

  it('add_order_item envia para /services quando type é service', async () => {
    mockCallRoute.mockResolvedValue(orderBody);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    await server.tools.get('add_order_item')!.handler({
      orderNumber: 42,
      type: 'service',
      itemId: 'srv1',
    });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ path: '/42/services' }),
    );
  });

  it('add_order_item envia para /products quando type é product', async () => {
    mockCallRoute.mockResolvedValue(orderBody);
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    await server.tools.get('add_order_item')!.handler({
      orderNumber: 42,
      type: 'product',
      itemId: 'prod1',
      quantity: 2,
    });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ path: '/42/products' }),
    );
  });

  it('update_order_status devolve isError quando a rota falha', async () => {
    mockCallRoute.mockResolvedValue({
      status: 404,
      body: { error: { code: 'NOT_FOUND', message: 'Order not found' } },
    });
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools
      .get('update_order_status')!
      .handler({ orderNumber: 999, status: 'done' });

    expect(result.isError).toBe(true);
  });

  it('add_order_comment confirma com o número da OS', async () => {
    mockCallRoute.mockResolvedValue({
      status: 201,
      body: { data: { id: 'c1', text: 'ok' } },
    });
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('add_order_comment')!.handler({
      orderNumber: 77,
      text: 'ok',
    });

    expect(result.content[0].text).toContain('77');
  });

  it('create_entity envia para /entities/customers quando type é customer', async () => {
    mockCallRoute.mockResolvedValue({
      status: 201,
      body: {
        data: { id: 'cust1', name: 'Maria', phone: '11999999999' },
        message: 'Cliente "Maria" cadastrado',
      },
    });
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const result = await server.tools.get('create_entity')!.handler({
      type: 'customer',
      name: 'Maria',
      phone: '11999999999',
    });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ method: 'POST', path: '/entities/customers' }),
    );
    expect(result.content[0].text).toContain('Maria');
  });

  // RULING: auditWrite must not leak end-customer personal data (phone,
  // email, address) or free text into Cloud Logging. It logs an explicit
  // allowlist of identifiers, never `args` itself.
  it('auditWrite não grava telefone nem email no log de create_entity', async () => {
    mockCallRoute.mockResolvedValue({
      status: 201,
      body: {
        data: { id: 'cust2', name: 'Joana Sigilosa', phone: '11988887777' },
        message: 'Cliente "Joana Sigilosa" cadastrado',
      },
    });
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    await server.tools.get('create_entity')!.handler({
      type: 'customer',
      name: 'Joana Sigilosa',
      phone: '11988887777',
      email: 'joana.sigilosa@example.com',
    });

    const auditLines = logSpy.mock.calls.map((call) => String(call[0]));
    expect(auditLines.length).toBeGreaterThan(0);
    for (const line of auditLines) {
      expect(line).not.toContain('11988887777');
      expect(line).not.toContain('joana.sigilosa@example.com');
      expect(line).not.toContain('Joana Sigilosa');
    }
    // Sanity: the audit event itself did fire, with only identifiers.
    const parsed = auditLines.map((l) => JSON.parse(l));
    const auditEntry = parsed.find((p) => p.event === 'mcp_write' && p.tool === 'create_entity');
    expect(auditEntry).toMatchObject({ origin: 'mcp', companyId: 'comp1', userId: 'user1', type: 'customer' });
    expect(auditEntry).not.toHaveProperty('phone');
    expect(auditEntry).not.toHaveProperty('email');
    expect(auditEntry).not.toHaveProperty('name');
  });

  // RULING: the card's action buttons call update_order_status via
  // tools/call from inside the iframe. Per the MCP Apps spec (l.401), a host
  // rejects a card-originated tools/call for a tool whose visibility doesn't
  // include "app"; the omitted default is ["model", "app"] (l.397). This is
  // a regression guard, not a feature test: it already passes today because
  // no tool declares `visibility` at all. It exists to fail if someone later
  // adds `visibility: ['app']` and silently drops the tool from the model's
  // chat surface.
  it('update_order_status continua visivel ao modelo e ao card', () => {
    const server = fakeServer();
    registerWriteTools(server as any, { req });

    const meta = server.tools.get('update_order_status')!.config._meta as
      | { ui?: { visibility?: string[] } }
      | undefined;

    // Omitted visibility defaults to ["model", "app"] (MCP Apps spec).
    // Declaring ["app"] would hide the tool from the chat.
    const visibility = meta?.ui?.visibility;
    if (visibility !== undefined) {
      expect(visibility).toEqual(expect.arrayContaining(['model', 'app']));
    }
    expect(meta?.['openai/widgetAccessible' as keyof typeof meta]).toBeUndefined();
  });
});
