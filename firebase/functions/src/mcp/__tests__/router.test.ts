import request from 'supertest';
import express from 'express';

const mockMcpAuth = jest.fn((req: any, _res: any, next: any) => {
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
});

jest.mock('../auth', () => ({
  mcpAuth: (req: any, res: any, next: any) => mockMcpAuth(req, res, next),
}));

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
    mockMcpAuth.mockImplementationOnce((_req: any, res: any) => {
      res.status(401).json({
        jsonrpc: '2.0',
        error: { code: -32001, message: 'Invalid or expired connection token' },
        id: null,
      });
    });

    const res = await rpc('tools/list');

    expect(res.status).toBe(401);
    expect(res.headers['cache-control']).toContain('no-store');
    expect(res.headers['cache-control']).toContain('no-transform');
  });

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
});
