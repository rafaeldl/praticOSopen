import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';
import { createAiRouter } from '../ai.routes';
import type { OrderAssistDeps } from '../../../services/ai/order-assist.service';
import type { FormPhotoDeps } from '../../../services/ai/form-photo.service';

function fakeDeps(overrides: Partial<OrderAssistDeps> = {}): OrderAssistDeps {
  return {
    llm: { generateJson: jest.fn().mockResolvedValue('{"operations":[{"action":"add","kind":"service","name":"Polimento"}]}') },
    getSettings: jest.fn().mockResolvedValue({ enabled: true }),
    reserve: jest.fn().mockResolvedValue({ ok: true, used: 1, limit: 10, monthKey: '2026-10' }),
    release: jest.fn(),
    loadCatalog: jest.fn().mockResolvedValue({ services: [{ id: 's1', name: 'Polimento', value: 450 }], products: [] }),
    findCustomers: jest.fn().mockResolvedValue([]),
    findDevices: jest.fn().mockResolvedValue([]),
    ...overrides,
  };
}

function fakePhotoDeps(raw: string, overrides: Partial<FormPhotoDeps> = {}): FormPhotoDeps {
  return {
    llm: { generateJson: jest.fn().mockResolvedValue(raw) },
    getSettings: jest.fn().mockResolvedValue({ enabled: true }),
    reserve: jest.fn().mockResolvedValue({ ok: true, used: 2, limit: 10, monthKey: '2026-11' }),
    release: jest.fn(),
    ...overrides,
  };
}

function buildApp(
  permissions: string[],
  deps: OrderAssistDeps,
  companyId = 'comp1',
  role = 'admin',
  photoDeps: FormPhotoDeps = fakePhotoDeps('{}'),
) {
  const app = express();
  app.use(express.json({ limit: '15mb' }));
  app.use((req: Request, _res: Response, next: NextFunction) => {
    (req as any).userContext = { userId: 'u1', userName: 'Ana', companyId, role, permissions };
    next();
  });
  app.use('/', createAiRouter(() => deps, () => photoDeps));
  return app;
}

describe('GET /status', () => {
  it('on → enabled with this month\'s usage', async () => {
    const deps = fakeDeps({ getUsage: jest.fn().mockResolvedValue({ used: 3, limit: 150 }) });
    const res = await request(buildApp(['write:orders'], deps, 'tenant-B')).get('/status');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ enabled: true, usage: { used: 3, limit: 150 } });
    expect(deps.getSettings).toHaveBeenCalledWith('tenant-B');
    expect(deps.reserve).not.toHaveBeenCalled();
  });

  it('off → enabled false, no usage', async () => {
    const deps = fakeDeps({ getSettings: jest.fn().mockResolvedValue({ enabled: false }), getUsage: jest.fn() });
    const res = await request(buildApp(['write:orders'], deps)).get('/status');
    expect(res.body.data).toEqual({ enabled: false });
    expect(deps.getUsage).not.toHaveBeenCalled();
  });

  it('technician uses it too (editOrder in the app)', async () => {
    const res = await request(buildApp([], fakeDeps(), 'comp1', 'technician')).get('/status');
    expect(res.status).toBe(200);
  });

  it('unknown role → 403', async () => {
    const res = await request(buildApp([], fakeDeps(), 'comp1', 'viewer')).get('/status');
    expect(res.status).toBe(403);
  });

  it('settings failure → 500', async () => {
    const deps = fakeDeps({ getSettings: jest.fn().mockRejectedValue(new Error('boom')) });
    const res = await request(buildApp(['write:orders'], deps)).get('/status');
    expect(res.status).toBe(500);
  });
});

describe('POST /order-assist', () => {
  it('returns the draft', async () => {
    const res = await request(buildApp(['write:all'], fakeDeps())).post('/order-assist').send({ text: 'polimento' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.items[0]).toMatchObject({ name: 'Polimento', catalogId: 's1', value: 450 });
    expect(res.body.data.usage).toEqual({ used: 1, limit: 10 });
  });

  it('technician fills the order with the AI (editOrder in the app)', async () => {
    const res = await request(buildApp([], fakeDeps(), 'comp1', 'technician')).post('/order-assist').send({ text: 'polimento' });
    expect(res.status).toBe(200);
  });

  it('unknown role → 403, nothing counted', async () => {
    const deps = fakeDeps();
    const res = await request(buildApp([], deps, 'comp1', 'viewer')).post('/order-assist').send({ text: 'x' });
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

describe('POST /form-photo', () => {
  const fuelBody = {
    photo: { mimeType: 'image/jpeg', data: 'aGVsbG8=' },
    question: { label: 'Nível de combustível', type: 'select', options: ['Reserva', '1/2', 'Cheio'] },
    locale: 'pt',
  };
  const modelSays = (fields: Record<string, unknown>) =>
    JSON.stringify({ answer: null, note: null, optionNotes: [], photoNote: null, photoIssue: 'none', confident: true, ...fields });
  const post = (photoDeps: FormPhotoDeps, body: unknown = fuelBody, role = 'admin', companyId = 'comp1') =>
    request(buildApp(role === 'admin' ? ['write:orders'] : [], fakeDeps(), companyId, role, photoDeps)).post('/form-photo').send(body as object);

  it('returns the answer and the usage', async () => {
    const res = await post(fakePhotoDeps(modelSays({ answer: 'Cheio', note: 'Ponteiro no máximo' })));
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      success: true,
      data: { answer: 'Cheio', note: 'Ponteiro no máximo', confident: true, usage: { used: 2, limit: 10 } },
    });
  });

  it('option the question does not have → no answer', async () => {
    const res = await post(fakePhotoDeps(modelSays({ answer: '3/4', note: 'Ponteiro perto do cheio' })));
    expect(res.status).toBe(200);
    expect(res.body.data).not.toHaveProperty('answer');
    expect(res.body.data.note).toBe('Ponteiro perto do cheio');
  });

  it('confident false → no answer', async () => {
    const res = await post(fakePhotoDeps(modelSays({ answer: 'Cheio', confident: false, photoIssue: 'blurry' })));
    expect(res.body.data).toEqual({ confident: false, photoIssue: 'blurry', usage: { used: 2, limit: 10 } });
  });

  it('technician reads the photo too (editOrder in the app); unknown role → 403, nothing counted', async () => {
    expect((await post(fakePhotoDeps(modelSays({})), fuelBody, 'technician')).status).toBe(200);
    const deps = fakePhotoDeps(modelSays({}));
    const res = await post(deps, fuelBody, 'viewer');
    expect(res.status).toBe(403);
    expect(deps.reserve).not.toHaveBeenCalled();
  });

  it('invalid photo or body → 400, nothing counted', async () => {
    const deps = fakePhotoDeps(modelSays({}));
    for (const body of [
      {},
      { ...fuelBody, photo: { mimeType: 'image/jpeg', data: '%%%' } },
      { ...fuelBody, photo: { mimeType: 'text/plain', data: 'aGVsbG8=' } },
      { ...fuelBody, companyId: 'other' },
      { ...fuelBody, device: { name: 'Uno', plate: 'ABC1D23' } },
    ]) {
      const res = await post(deps, body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(deps.reserve).not.toHaveBeenCalled();
  });

  it('AI off → 403 AI_DISABLED', async () => {
    const res = await post(fakePhotoDeps(modelSays({}), { getSettings: jest.fn().mockResolvedValue({ enabled: false }) }));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('AI_DISABLED');
  });

  it('quota full → 429 AI_QUOTA_EXCEEDED with details', async () => {
    const deps = fakePhotoDeps(modelSays({}), {
      reserve: jest.fn().mockResolvedValue({ ok: false, used: 10, limit: 10, monthKey: '2026-11' }),
    });
    const res = await post(deps);
    expect(res.status).toBe(429);
    expect(res.body.error).toMatchObject({ code: 'AI_QUOTA_EXCEEDED', details: { used: 10, limit: 10 } });
    expect(deps.llm.generateJson).not.toHaveBeenCalled();
  });

  it('model down → 503 AI_UNAVAILABLE', async () => {
    const res = await post(fakePhotoDeps('not json'));
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('AI_UNAVAILABLE');
  });

  it('uses the company from the auth context and logs no content', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => undefined);
    const deps = fakePhotoDeps(modelSays({ answer: 'Cheio', note: 'Ponteiro no máximo' }));
    await post(deps, fuelBody, 'admin', 'tenant-B');
    expect(deps.getSettings).toHaveBeenCalledWith('tenant-B');
    const lines = log.mock.calls.map((c) => c.join(' ')).join('\n');
    expect(lines).toMatch(/\[aiFormPhoto\] company=tenant-B type=select ms=\d+/);
    expect(lines).not.toMatch(/Cheio|Ponteiro|combustível|aGVsbG8/);
    log.mockRestore();
  });
});
