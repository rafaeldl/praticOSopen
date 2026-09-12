import request from 'supertest';
import express from 'express';

jest.mock('../auth', () => ({
  mcpAuth: (req: any, _res: any, next: any) => {
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
  },
}));

jest.mock('../bridge', () => ({
  callRoute: jest.fn().mockResolvedValue({
    status: 200,
    body: { data: { newOrders: 3, completedOrders: 2, revenue: 500 } },
  }),
}));

import mcpRouter from '../router';

const app = express();
app.use(express.json());
app.use('/mcp', mcpRouter);

const rpc = (method: string, params?: unknown) =>
  request(app)
    .post('/mcp/t/mcp_fake')
    .set('Accept', 'application/json, text/event-stream')
    .send({ jsonrpc: '2.0', id: 1, method, params });

describe('mcp router', () => {
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

  it('marca a resposta como no-store', async () => {
    const res = await rpc('tools/list');
    expect(res.headers['cache-control']).toContain('no-store');
  });
});
