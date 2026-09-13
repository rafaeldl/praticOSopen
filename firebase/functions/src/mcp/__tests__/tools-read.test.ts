jest.mock('../bridge');

import { callRoute } from '../bridge';
import { registerReadTools } from '../tools/read';
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

const req = { auth: { type: 'mcp', companyId: 'comp1' } } as unknown as AuthenticatedRequest;

describe('read tools', () => {
  beforeEach(() => jest.clearAllMocks());

  it('registra as 8 tools de consulta', () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    expect([...server.tools.keys()].sort()).toEqual([
      'get_order',
      'get_pending_orders',
      'get_revenue',
      'get_today_summary',
      'list_entities',
      'list_order_photos',
      'list_orders',
      'search',
    ]);
  });

  it('marca todas como readOnlyHint', () => {
    const server = fakeServer();
    registerReadTools(server as any, { req });

    for (const [, tool] of server.tools) {
      expect(tool.config.annotations.readOnlyHint).toBe(true);
    }
  });

  it('search envia os termos como POST para /unified', async () => {
    mockCallRoute.mockResolvedValue({ status: 200, body: { data: {} } });
    const server = fakeServer();
    registerReadTools(server as any, { req });

    await server.tools.get('search')!.handler({ customer: 'João' });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        method: 'POST',
        path: '/unified',
        body: { customer: 'João' },
      }),
    );
  });

  it('get_order busca pelo número da OS', async () => {
    mockCallRoute.mockResolvedValue({
      status: 200,
      body: { data: { order: { number: 42, total: 100 } } },
    });
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_order')!.handler({ orderNumber: 42 });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ method: 'GET', path: '/42/details' }),
    );
    expect(result.content[0].text).toContain('OS #42');
  });

  it('devolve isError quando a rota falha', async () => {
    mockCallRoute.mockResolvedValue({
      status: 404,
      body: { error: { code: 'NOT_FOUND', message: 'Order not found' } },
    });
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('get_order')!.handler({ orderNumber: 999 });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain('Order not found');
  });

  it('list_orders respeita o limite máximo de 50', async () => {
    mockCallRoute.mockResolvedValue({ status: 200, body: { data: { orders: [] } } });
    const server = fakeServer();
    registerReadTools(server as any, { req });

    await server.tools.get('list_orders')!.handler({ limit: 500 });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ query: expect.objectContaining({ limit: '50' }) }),
    );
  });

  it('list_order_photos busca fotos pelo número da OS', async () => {
    mockCallRoute.mockResolvedValue({
      status: 200,
      body: {
        data: {
          photos: [
            {
              id: 'photo-1',
              url: 'https://storage.googleapis.com/test/photo-1.jpg',
              description: 'Dano lateral',
              createdBy: 'João',
            },
          ],
        },
      },
    });
    const server = fakeServer();
    registerReadTools(server as any, { req });

    const result = await server.tools.get('list_order_photos')!.handler({ orderNumber: 42 });

    expect(mockCallRoute).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ method: 'GET', path: '/42/photos' }),
    );
    expect(result.content[0].text).toContain('photo-1');
    expect(result.content[0].text).toContain('Dano lateral');
  });
});
