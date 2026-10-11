import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';
import { createAiRouter } from '../ai.routes';
import type { OrderAssistDeps } from '../../../services/ai/order-assist.service';

function fakeDeps(overrides: Partial<OrderAssistDeps> = {}): OrderAssistDeps {
  return {
    llm: { generateJson: jest.fn().mockResolvedValue('{"items":[{"kind":"service","name":"Polimento"}]}') },
    getSettings: jest.fn().mockResolvedValue({ enabled: true }),
    reserve: jest.fn().mockResolvedValue({ ok: true, used: 1, limit: 10, monthKey: '2026-10' }),
    release: jest.fn(),
    loadCatalog: jest.fn().mockResolvedValue({ services: [{ id: 's1', name: 'Polimento', value: 450 }], products: [] }),
    findCustomers: jest.fn().mockResolvedValue([]),
    findDeviceBySerial: jest.fn().mockResolvedValue(null),
    findDevices: jest.fn().mockResolvedValue([]),
    ...overrides,
  };
}

function buildApp(permissions: string[], deps: OrderAssistDeps, companyId = 'comp1') {
  const app = express();
  app.use(express.json({ limit: '15mb' }));
  app.use((req: Request, _res: Response, next: NextFunction) => {
    (req as any).userContext = { userId: 'u1', userName: 'Ana', companyId, role: 'admin', permissions };
    next();
  });
  app.use('/', createAiRouter(() => deps));
  return app;
}

describe('POST /order-assist', () => {
  it('returns the draft', async () => {
    const res = await request(buildApp(['write:all'], fakeDeps())).post('/order-assist').send({ text: 'polimento' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.items[0]).toMatchObject({ name: 'Polimento', catalogId: 's1', value: 450 });
    expect(res.body.data.usage).toEqual({ used: 1, limit: 10 });
  });

  it('technician (no write:orders) → 403', async () => {
    const deps = fakeDeps();
    const res = await request(buildApp(['read:assigned', 'write:orders:status'], deps)).post('/order-assist').send({ text: 'x' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
    expect(deps.reserve).not.toHaveBeenCalled();
  });

  it('invalid body → 400 VALIDATION_ERROR, nothing counted', async () => {
    const deps = fakeDeps();
    const app = buildApp(['write:orders'], deps);
    for (const body of [{}, { text: 'x', companyId: 'other' }, { photos: [{ mimeType: 'image/jpeg', data: '%%%' }] }]) {
      const res = await request(app).post('/order-assist').send(body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(deps.reserve).not.toHaveBeenCalled();
  });

  it('pilot off → 403 AI_DISABLED', async () => {
    const res = await request(buildApp(['write:orders'], fakeDeps({ getSettings: jest.fn().mockResolvedValue({ enabled: false }) })))
      .post('/order-assist')
      .send({ text: 'x' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('AI_DISABLED');
  });

  it('quota exceeded → 429 AI_QUOTA_EXCEEDED with details', async () => {
    const deps = fakeDeps({ reserve: jest.fn().mockResolvedValue({ ok: false, used: 10, limit: 10, monthKey: '2026-10' }) });
    const res = await request(buildApp(['write:orders'], deps)).post('/order-assist').send({ text: 'x' });
    expect(res.status).toBe(429);
    expect(res.body.error).toMatchObject({ code: 'AI_QUOTA_EXCEEDED', details: { used: 10, limit: 10 } });
  });

  it('uses the company from the auth context (tenant isolation)', async () => {
    const deps = fakeDeps();
    await request(buildApp(['write:orders'], deps, 'tenant-B')).post('/order-assist').send({ text: 'x' });
    expect(deps.getSettings).toHaveBeenCalledWith('tenant-B');
    expect(deps.loadCatalog).toHaveBeenCalledWith('tenant-B');
  });

  it('model down → 503 AI_UNAVAILABLE', async () => {
    const deps = fakeDeps({ llm: { generateJson: jest.fn().mockResolvedValue('not json') } });
    const res = await request(buildApp(['write:orders'], deps)).post('/order-assist').send({ text: 'x' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('AI_UNAVAILABLE');
  });
});
