import request from 'supertest';
import express from 'express';

const authenticate = (req: any, _res: any, next: any) => {
  req.auth = { type: 'mcp', companyId: 'comp1', userId: 'user1' };
  req.userContext = {
    userId: 'user1',
    userName: 'Test User',
    companyId: 'comp1',
    companyName: 'Test Co',
    role: 'admin',
    permissions: ['read:all', 'write:all'],
  };
  next();
};

const rejectToken = (_req: any, res: any) => {
  res.status(401).json({
    jsonrpc: '2.0',
    error: { code: -32001, message: 'Invalid or expired connection token' },
    id: null,
  });
};

const mockMcpAuth = jest.fn(authenticate);

jest.mock('../auth', () => ({
  mcpAuth: (req: any, res: any, next: any) => mockMcpAuth(req, res, next),
}));

// Small budget so the wiring test can exhaust it in a few requests.
jest.mock('../token-guard', () => {
  const actual = jest.requireActual('../token-guard');
  return {
    ...actual,
    createUnknownTokenGuard: (options: any) =>
      actual.createUnknownTokenGuard({ ...options, maxUnknownPerWindow: 3 }),
  };
});

jest.mock('../bridge', () => ({
  callRoute: jest.fn().mockResolvedValue({
    status: 200,
    body: { data: { newOrders: 3, completedOrders: 2, revenue: 500 } },
  }),
}));

jest.mock('../server', () => {
  const actual = jest.requireActual('../server');
  return {
    ...actual,
    buildMcpServer: jest.fn(actual.buildMcpServer),
  };
});

import mcpRouter from '../router';
import { buildMcpServer } from '../server';

const mockBuildMcpServer = buildMcpServer as jest.MockedFunction<typeof buildMcpServer>;

const app = express();
app.use(express.json());
app.use('/mcp', mcpRouter);

const rpc = (method: string, params?: unknown) =>
  request(app)
    .post('/mcp/t/mcp_fake')
    .set('Accept', 'application/json, text/event-stream')
    .send({ jsonrpc: '2.0', id: 1, method, params });

describe('mcp router', () => {
  afterEach(() => {
    mockMcpAuth.mockClear();
    mockBuildMcpServer.mockClear();
  });

  it('responde ao initialize', async () => {
    const res = await rpc('initialize', {
      protocolVersion: '2025-06-18',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' },
    });

    expect(res.status).toBe(200);
    expect(res.text).toContain('praticos');
  });

  it('lista a tool get_today_summary', async () => {
    const res = await rpc('tools/list');
    expect(res.text).toContain('get_today_summary');
  });

  it('marca a resposta como no-store, no-transform', async () => {
    const res = await rpc('tools/list');
    expect(res.headers['cache-control']).toContain('no-store');
    expect(res.headers['cache-control']).toContain('no-transform');
  });

  it('marca a rejeicao de auth (401) como no-store, no-transform tambem', async () => {
    mockMcpAuth.mockImplementationOnce(rejectToken);

    const res = await rpc('tools/list');

    expect(res.status).toBe(401);
    expect(res.headers['cache-control']).toContain('no-store');
    expect(res.headers['cache-control']).toContain('no-transform');
  });

  it.each(['get', 'delete', 'put', 'patch'] as const)(
    'responde 405 com Allow: POST para %s, sem autenticar',
    async (method) => {
      const res = await request(app)[method]('/mcp/t/mcp_fake')
        .set('Accept', 'application/json, text/event-stream');

      expect(res.status).toBe(405);
      expect(res.headers.allow).toBe('POST');
      expect(res.headers['cache-control']).toBe('no-store, no-transform');
      expect(res.body).toEqual({
        jsonrpc: '2.0',
        error: { code: -32000, message: 'Method not allowed.' },
        id: null,
      });
      expect(mockMcpAuth).not.toHaveBeenCalled();
    },
  );

  it('retorna erro JSON-RPC 500 (sem travar) quando buildMcpServer lanca', async () => {
    mockBuildMcpServer.mockImplementationOnce(() => {
      throw new Error('malformed tool schema');
    });

    const res = await rpc('tools/list');

    expect(res.status).toBe(500);
    const body = JSON.parse(res.text);
    expect(body.jsonrpc).toBe('2.0');
    expect(body.error).toBeDefined();
    expect(res.headers['cache-control']).toContain('no-store');
  });

  it('barra tokens desconhecidos acima do teto antes do mcpAuth, sem derrubar token conectado', async () => {
    // Authenticates mcp_fake, so it is a known token from here on.
    expect((await rpc('tools/list')).status).toBe(200);

    const unknown = (i: number) =>
      request(app)
        .post(`/mcp/t/mcp_unknown_${i}`)
        .set('Accept', 'application/json, text/event-stream')
        .send({ jsonrpc: '2.0', id: 1, method: 'tools/list' });

    mockMcpAuth.mockImplementation(rejectToken);
    try {
      let res = await unknown(0);
      for (let i = 1; i < 5 && res.status !== 429; i++) {
        res = await unknown(i);
      }
      expect(res.status).toBe(429);
      expect(res.headers['cache-control']).toContain('no-store');

      const authCalls = mockMcpAuth.mock.calls.length;
      expect((await unknown(5)).status).toBe(429);
      expect(mockMcpAuth.mock.calls.length).toBe(authCalls);
    } finally {
      mockMcpAuth.mockImplementation(authenticate);
    }

    expect((await rpc('tools/list')).status).toBe(200);
  });
});
