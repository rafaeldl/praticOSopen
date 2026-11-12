/**
 * /v1/app/orders and the receipt routes the web uses to write money, status
 * and items (docs/WEB_API.md). Real bearerAuth + resolveCompanyContext over the
 * in-memory Firestore (token = uid), so the role and company come from the
 * same server-side data as in production. Only Asaas calls are faked.
 */
import { Server } from 'http';
import request from 'supertest';
import express, { Express } from 'express';

jest.mock('../../../services/firestore.service', () => ({
  ...jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

import { fakeDb, fakeStorage, list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { bearerAuth } from '../../../middleware/auth.middleware';
import { resolveCompanyContext } from '../../../middleware/company.middleware';
import ordersRoutes from '../orders.routes';
import customerPaymentsRoutes from '../customer-payments.routes';
import * as chargeService from '../../../services/asaas/charge.service';
import { orderMonthKey, resetPaidPlansCache } from '../../../services/plan-limits.service';

let cancelOpenCharges: jest.SpyInstance;

type Role = 'owner' | 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician';
const UID: Record<Role, string> = {
  owner: 'owner1', admin: 'admin1', manager: 'mgr1', supervisor: 'sup1', consultant: 'cons1', technician: 'tech1',
};
const NAMES: Record<string, string> = {
  owner1: 'Rafael', admin1: 'Ana Admin', mgr1: 'Gil Gerente', sup1: 'Sara Supervisora', cons1: 'Caio Consultor', tech1: 'Téo Técnico',
};
const O = '/v1/app/orders';
const CU = '/v1/app/customers';
const T0 = '2026-10-01T10:00:00.000Z';
/** Download URL of a file in the project bucket, as getDownloadURL gives it. */
const storageUrl = (path: string, bucket = 'praticos.appspot.com') =>
  `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&token=t`;

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use(O, bearerAuth, resolveCompanyContext, ordersRoutes);
  app.use(CU, bearerAuth, resolveCompanyContext, customerPaymentsRoutes);
  return app;
}

/**
 * One server on the IPv4 loopback for the whole file (same reason as in
 * contract-cases.test.ts: `request(app)` can hit another local service).
 */
let server: Server;
let logSpies: jest.SpyInstance[];

beforeAll((done) => {
  logSpies = (['log', 'warn', 'error'] as const).map((m) => jest.spyOn(console, m).mockImplementation(() => undefined));
  server = buildApp().listen(0, '127.0.0.1', done);
});
afterAll((done) => {
  logSpies.forEach((s) => s.mockRestore());
  server.close(done);
});

function seedCompanies(c1: Record<string, unknown> = {}) {
  seed('companies/c1', { name: 'Oficina', owner: { id: 'owner1', name: 'Rafael' }, country: 'BR', ...c1 });
  seed('companies/c1/private/membership', {
    members: { admin1: 'admin', mgr1: 'manager', sup1: 'supervisor', cons1: 'consultant', tech1: 'technician' },
  });
  seed('companies/c2', { name: 'Outra', owner: { id: 'other2', name: 'Outro' } });
  seed('companies/c2/private/membership', { members: {} });
  for (const [role, uid] of Object.entries(UID)) {
    seed(`users/${uid}`, { name: NAMES[uid], companies: [{ company: { id: 'c1', name: 'Oficina' }, role }] });
  }
  seed('users/other2', { name: 'Outro', companies: [{ company: { id: 'c2', name: 'Outra' }, role: 'owner' }] });
  seed('companies/c1/services/s1', { name: 'Polimento', value: 100 });
  seed('companies/c1/services/s0', { name: 'Avaliação' });
  seed('companies/c1/products/p1', { name: 'Cera', value: 10 });
}

function seedOrder(id: string, data: Record<string, unknown> = {}, company = 'c1') {
  seed(`companies/${company}/orders/${id}`, {
    number: 1,
    status: 'approved',
    customer: { id: 'cust1', name: 'João' },
    device: { id: 'd1', name: 'Uno' },
    devices: [{ id: 'd1', name: 'Uno' }],
    services: [{ service: { id: 's1', name: 'Polimento', value: 100 }, description: 'Polimento', value: 100 }],
    products: [],
    total: 100,
    discount: 0,
    paidAmount: 0,
    payment: 'unpaid',
    paid: false,
    transactions: [],
    createdBy: { id: 'someone', name: 'Alguém' },
    createdAt: T0,
    updatedAt: T0,
    ...data,
  });
}

const doc = (id: string, company = 'c1') => read(`companies/${company}/orders/${id}`) as any;

function call(role: Role | 'other2', method: 'get' | 'post' | 'patch' | 'put' | 'delete', path: string, body?: object, company = 'c1') {
  const uid = role === 'other2' ? 'other2' : UID[role];
  const req = request(server)[method](path).set('Authorization', `Bearer ${uid}`).set('X-Company-ID', company);
  return body ? req.send(body) : req;
}

beforeEach(() => {
  resetFakeDb();
  jest.clearAllMocks();
  seedCompanies();
  cancelOpenCharges = jest.spyOn(chargeService, 'cancelOpenChargesForOrder').mockResolvedValue(undefined);
});
afterEach(() => cancelOpenCharges.mockRestore());

// ─── Lista ────────────────────────────────────────────────────────────────
describe('GET /orders', () => {
  beforeEach(() => {
    seedOrder('a', { number: 1, createdAt: '2026-10-01T10:00:00.000Z', createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('b', { number: 2, createdAt: '2026-10-02T10:00:00.000Z', status: 'quote', payment: null });
    seedOrder('c', { number: 3, createdAt: '2026-10-03T10:00:00.000Z', createdBy: { id: 'tech1', name: 'Téo' }, status: 'progress' });
    seedOrder('d', { number: 4, createdAt: '2026-10-04T10:00:00.000Z', createdBy: { id: 'cons1', name: 'Caio' } });
  });

  it('técnico lista só as OS que criou, sem nenhum valor', async () => {
    const res = await call('technician', 'get', O);
    expect(res.status).toBe(200);
    expect(res.body.data.map((o: any) => o.id)).toEqual(['c', 'a']);
    for (const o of res.body.data) {
      expect(o).not.toHaveProperty('total');
      expect(o).not.toHaveProperty('paidAmount');
      expect(o).not.toHaveProperty('payment');
    }
  });

  it('técnico pede as atribuídas a ele e recebe também as que outra pessoa criou (como as regras)', async () => {
    seedOrder('e', { number: 5, createdAt: '2026-10-05T10:00:00.000Z', assignedTo: { id: 'tech1', name: 'Téo' } });
    seedOrder('f', { number: 6, createdAt: '2026-10-06T10:00:00.000Z', assignedTo: { id: 'other', name: 'Outro' } });
    const res = await call('technician', 'get', `${O}?assignedTo=tech1`);
    expect(res.status).toBe(200);
    expect(res.body.data.map((o: any) => o.id)).toEqual(['e']);
    expect((await call('technician', 'get', `${O}/e`)).status).toBe(200);
    expect((await call('technician', 'get', `${O}/f`)).status).toBe(403);
    // Another person's assignment keeps the "created by me" filter; the consultant never sees by assignment.
    expect((await call('technician', 'get', `${O}?assignedTo=other`)).body.data).toEqual([]);
    seedOrder('g', { number: 7, assignedTo: { id: 'cons1', name: 'Caio' } });
    expect((await call('consultant', 'get', `${O}?assignedTo=cons1`)).body.data).toEqual([]);
    expect((await call('consultant', 'get', `${O}/g`)).status).toBe(403);
  });

  it('N1 e N3: sem filtro de dono, o técnico recebe as que criou e as atribuídas, sem repetir, paginado e sem valores', async () => {
    // e: admin's, assigned to tech1. h: created by tech1 and assigned to tech1 (must come once). f: someone else's.
    seedOrder('e', { number: 5, createdAt: '2026-10-05T10:00:00.000Z', assignedTo: { id: 'tech1', name: 'Téo' }, status: 'progress' });
    seedOrder('f', { number: 6, createdAt: '2026-10-06T10:00:00.000Z', assignedTo: { id: 'other', name: 'Outro' } });
    seedOrder('h', { number: 8, createdAt: '2026-10-08T10:00:00.000Z', createdBy: { id: 'tech1', name: 'Téo' }, assignedTo: { id: 'tech1', name: 'Téo' } });
    const all = await call('technician', 'get', O);
    expect(all.status).toBe(200);
    expect(all.body.data.map((o: any) => o.id)).toEqual(['h', 'e', 'c', 'a']);
    for (const o of all.body.data) {
      for (const field of ['total', 'paidAmount', 'payment', 'remainingBalance']) expect(o).not.toHaveProperty(field);
      expect(o.services?.[0] ?? {}).not.toHaveProperty('value');
    }
    // Pages of 2 walk the same list, no repeats, no gaps.
    const ids: string[] = [];
    let cursor = '';
    for (let i = 0; i < 4; i++) {
      const page = await call('technician', 'get', `${O}?limit=2${cursor ? `&cursor=${cursor}` : ''}`);
      ids.push(...page.body.data.map((o: any) => o.id));
      if (!page.body.pagination.hasMore) break;
      cursor = page.body.pagination.nextCursor;
    }
    expect(ids).toEqual(['h', 'e', 'c', 'a']);
    // Status filters keep the union (Paradas/Em aberto read the open ones).
    expect((await call('technician', 'get', `${O}?status=progress`)).body.data.map((o: any) => o.id)).toEqual(['e', 'c']);
    // The assigned order opens for the technician without values (N3).
    const detail = await call('technician', 'get', `${O}/e`);
    expect(detail.status).toBe(200);
    for (const field of ['total', 'paidAmount', 'payment', 'transactions']) expect(detail.body.data[field]).toBeUndefined();
    expect(detail.body.data.services[0]).not.toHaveProperty('value');
  });

  it('consultor vê o total das próprias', async () => {
    const res = await call('consultant', 'get', O);
    expect(res.body.data).toEqual([expect.objectContaining({ id: 'd', total: 100 })]);
  });

  it('dono lista todas, da mais nova para a mais velha, com cursor', async () => {
    const first = await call('owner', 'get', `${O}?limit=3`);
    expect(first.body.data.map((o: any) => o.id)).toEqual(['d', 'c', 'b']);
    expect(first.body.pagination).toMatchObject({ limit: 3, hasMore: true, total: 4 });
    const next = await call('owner', 'get', `${O}?limit=3&cursor=${first.body.pagination.nextCursor}`);
    expect(next.body.data.map((o: any) => o.id)).toEqual(['a']);
    expect(next.body.pagination).toMatchObject({ hasMore: false, nextCursor: null });
  });

  it('filtra por várias situações e ordena pela mais velha', async () => {
    const res = await call('owner', 'get', `${O}?status=approved,progress&direction=asc`);
    expect(res.body.data.map((o: any) => o.id)).toEqual(['a', 'c', 'd']);
  });

  it('cursor que não é uma OS da empresa é recusado', async () => {
    seedOrder('x', {}, 'c2');
    const res = await call('owner', 'get', `${O}?cursor=x`);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_CURSOR');
  });

  it('situação desconhecida é recusada', async () => {
    const res = await call('owner', 'get', `${O}?status=paid`);
    expect(res.status).toBe(400);
  });

  it('com Valores e cobrança desligado nenhum valor sai, nem para o dono', async () => {
    seedCompanies({ useFinancial: false });
    const res = await call('owner', 'get', O);
    expect(res.body.data[0]).not.toHaveProperty('total');
  });
});

// ─── Agenda ───────────────────────────────────────────────────────────────
describe('GET /orders por data da visita (agenda)', () => {
  beforeEach(() => {
    // v1: written by the web (UTC). v2: by the app, local time without a zone. v3: outside the range. v4: no visit.
    seedOrder('v1', { number: 11, scheduledDate: '2031-03-11T17:00:00.000Z', createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('v2', { number: 12, scheduledDate: '2031-03-10T09:30:00.000', assignedTo: { id: 'tech1', name: 'Téo' } });
    seedOrder('v3', { number: 13, scheduledDate: '2031-04-01T10:00:00.000Z' });
    seedOrder('v4', { number: 14 });
    seedOrder('v5', { number: 15, scheduledDate: '2031-03-12T10:00:00.000Z', createdBy: { id: 'cons1', name: 'Caio' } });
  });
  const range = 'sort=scheduledDate&startDate=2031-03-09T00:00:00.000Z&endDate=2031-03-16T00:00:00.000Z';

  it('lista só as OS com visita no intervalo, da mais cedo para a mais tarde', async () => {
    const res = await call('owner', 'get', `${O}?${range}`);
    expect(res.status).toBe(200);
    expect(res.body.data.map((o: any) => o.id)).toEqual(['v2', 'v1', 'v5']);
  });

  it('a hora gravada pelo app sem fuso sai como está; a do web sai em UTC', async () => {
    const res = await call('owner', 'get', `${O}?${range}`);
    const byId = Object.fromEntries(res.body.data.map((o: any) => [o.id, o]));
    expect(byId.v2.scheduledDate).toBe('2031-03-10T09:30:00.000');
    expect(byId.v1.scheduledDate).toBe('2031-03-11T17:00:00.000Z');
    expect((await call('owner', 'get', `${O}/v2`)).body.data.scheduledDate).toBe('2031-03-10T09:30:00.000');
  });

  it('técnico recebe as que criou e as atribuídas a ele, sem valores; consultor só as dele', async () => {
    const tech = await call('technician', 'get', `${O}?${range}`);
    expect(tech.body.data.map((o: any) => o.id)).toEqual(['v2', 'v1']);
    for (const o of tech.body.data) expect(o).not.toHaveProperty('total');
    // Who created each one travels: consultant and technician may change only their own (canEditOrderMainFields).
    expect(tech.body.data.find((o: any) => o.id === 'v1').createdBy).toEqual({ id: 'tech1', name: 'Téo' });
    expect((await call('consultant', 'get', `${O}?${range}`)).body.data.map((o: any) => o.id)).toEqual(['v5']);
  });

  it('filtro de pessoa pelo responsável', async () => {
    const res = await call('admin', 'get', `${O}?${range}&assignedTo=tech1`);
    expect(res.body.data.map((o: any) => o.id)).toEqual(['v2']);
  });

  it('B1: PATCH aceita a data sem fuso que o GET devolve e grava como o app grava', async () => {
    const read = await call('owner', 'get', `${O}/v2`);
    const res = await call('owner', 'patch', `${O}/v2`, { scheduledDate: read.body.data.scheduledDate, dueDate: '2031-03-31T21:00:00.000', expectedUpdatedAt: read.body.data.version });
    expect(res.status).toBe(200);
    expect(doc('v2').scheduledDate).toBe('2031-03-10T09:30:00.000');
    expect(doc('v2').dueDate).toBe('2031-03-31T21:00:00.000');
    // With a zone it is still an instant, saved in UTC.
    await call('owner', 'patch', `${O}/v1`, { scheduledDate: '2031-03-11T14:00:00-03:00' });
    expect(doc('v1').scheduledDate).toBe('2031-03-11T17:00:00.000Z');
    expect((await call('owner', 'patch', `${O}/v1`, { scheduledDate: '2031-03-11 14:00' })).status).toBe(400);
  });

  it('data impossível sem fuso dá 400 e não grava nada', async () => {
    for (const value of ['2031-13-45T99:99', '2031-02-30T10:00:00.000']) {
      const res = await call('owner', 'patch', `${O}/v2`, { scheduledDate: value });
      expect(res.status).toBe(400);
      expect(doc('v2').scheduledDate).toBe('2031-03-10T09:30:00.000');
    }
    seed('companies/c1/customers/cust1', { name: 'João' });
    const created = await call('owner', 'post', O, { customerId: 'cust1', dueDate: '2031-04-31T10:00' });
    expect(created.status).toBe(400);
  });

  it('B1: nova OS aceita visita e entrega sem fuso', async () => {
    seed('companies/c1/customers/cust1', { name: 'João' });
    const res = await call('owner', 'post', O, { customerId: 'cust1', scheduledDate: '2031-03-12T08:00:00.000', dueDate: '2031-03-13T00:00:00.000' });
    expect(res.status).toBe(201);
    const created = doc(res.body.data.id);
    expect(created.scheduledDate).toBe('2031-03-12T08:00:00.000');
    expect(created.dueDate).toBe('2031-03-13T00:00:00.000');
  });

  it('intervalo só com createdAt, scheduledDate ou dueDate', async () => {
    const res = await call('owner', 'get', `${O}?sort=number&startDate=2031-03-09T00:00:00.000Z`);
    expect(res.status).toBe(400);
  });
});

// ─── Detalhe ──────────────────────────────────────────────────────────────
describe('GET /orders/:id', () => {
  beforeEach(() => {
    seedOrder('o1', {
      createdBy: { id: 'tech1', name: 'Téo' },
      products: [{ product: { id: 'p1', name: 'Cera', value: 10 }, value: 10, quantity: 3, total: 25 }],
      total: 125,
      transactions: [{ type: 'payment', amount: 25, createdAt: T0, createdBy: { id: 'owner1', name: 'Rafael' } }],
      paidAmount: 25,
      documents: [{ id: 'doc1', type: 'receipt', url: 'https://x' }],
    });
  });

  it('técnico não recebe nenhum campo de dinheiro', async () => {
    const res = await call('technician', 'get', `${O}/o1`);
    expect(res.status).toBe(200);
    const data = res.body.data;
    for (const field of ['total', 'discount', 'paidAmount', 'remainingBalance', 'payment', 'paid', 'transactions', 'documents']) {
      expect([field, data[field]]).toEqual([field, undefined]);
    }
    expect(data.products[0]).toEqual({ id: expect.any(String), product: { id: 'p1', name: 'Cera' }, quantity: 3 });
    expect(data.services[0]).not.toHaveProperty('value');
  });

  it('quem não vê valores recebe o local e os campos do ramo da OS (sem dinheiro)', async () => {
    seedOrder('o2', {
      createdBy: { id: 'tech1', name: 'Téo' },
      address: 'Rua A, 1', latitude: -27.5, longitude: -48.5, customData: { mileageIn: 1200 },
    });
    const res = await call('technician', 'get', `${O}/o2`);
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ address: 'Rua A, 1', latitude: -27.5, longitude: -48.5, customData: { mileageIn: 1200 } });
  });

  it('dono vê valores, total da linha e transações com id (também as antigas, sem id)', async () => {
    const res = await call('owner', 'get', `${O}/o1`);
    const data = res.body.data;
    expect(data).toMatchObject({ total: 125, paidAmount: 25, remainingBalance: 100, payment: 'unpaid' });
    expect(data.products[0]).toMatchObject({ value: 10, total: 25, product: { value: 10 } });
    expect(data.transactions[0].id).toMatch(/^legacy_/);
  });

  it('o id de um item antigo continua o mesmo quando outro item sai', async () => {
    seedOrder('o2', {
      services: [
        { service: { id: 's1', name: 'Polimento' }, value: 100 },
        { service: { id: 's0', name: 'Avaliação' }, value: 50 },
      ],
      total: 150,
    });
    const before = (await call('owner', 'get', `${O}/o2`)).body.data.services;
    expect(before[0].id).not.toBe(before[1].id);
    expect((await call('owner', 'delete', `${O}/o2/items/${before[0].id}`)).status).toBe(200);
    const after = (await call('owner', 'get', `${O}/o2`)).body.data.services;
    expect(after.map((s: any) => s.id)).toEqual([before[1].id]);
  });
});

// ─── PATCH ────────────────────────────────────────────────────────────────
describe('PATCH /orders/:id', () => {
  it('técnico não muda a data de OS aprovada, mas muda a de orçamento', async () => {
    seedOrder('a', { createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('q', { createdBy: { id: 'tech1', name: 'Téo' }, status: 'quote', payment: null });
    expect((await call('technician', 'patch', `${O}/a`, { scheduledDate: '2026-11-03T10:00:00.000Z' })).status).toBe(403);
    const res = await call('technician', 'patch', `${O}/q`, { scheduledDate: '2026-11-03T10:00:00.000Z' });
    expect(res.status).toBe(200);
    expect(doc('q').scheduledDate).toBe('2026-11-03T10:00:00.000Z');
  });

  it('limpa a data com null', async () => {
    seedOrder('o1', { dueDate: '2026-11-03T10:00:00.000Z' });
    const res = await call('owner', 'patch', `${O}/o1`, { dueDate: null });
    expect(res.status).toBe(200);
    expect(doc('o1').dueDate).toBeNull();
  });

  it('responsável: gerente não atribui (sem assignOrder); supervisor grava o nome verdadeiro', async () => {
    seedOrder('o1');
    expect((await call('manager', 'patch', `${O}/o1`, { assignedTo: 'tech1' })).status).toBe(403);
    const res = await call('supervisor', 'patch', `${O}/o1`, { assignedTo: 'tech1' });
    expect(res.status).toBe(200);
    expect(doc('o1').assignedTo).toEqual({ id: 'tech1', name: 'Téo Técnico' });
    await call('supervisor', 'patch', `${O}/o1`, { assignedTo: null });
    expect(doc('o1').assignedTo).toBeNull();
  });

  it('responsável de fora da empresa é recusado', async () => {
    seedOrder('o1');
    const res = await call('owner', 'patch', `${O}/o1`, { assignedTo: 'other2' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_ASSIGNEE');
  });

  it('não grava `done` (o app não grava) e acerta a situação de pagamento', async () => {
    seedOrder('o1', { status: 'progress', paidAmount: 100 });
    await call('owner', 'patch', `${O}/o1`, { status: 'done' });
    expect(doc('o1')).toMatchObject({ status: 'done', payment: 'paid', paid: true });
    expect(doc('o1')).not.toHaveProperty('done');
    await call('owner', 'patch', `${O}/o1`, { status: 'canceled' });
    expect(doc('o1')).toMatchObject({ payment: null, paid: false });
  });

  it('expectedUpdatedAt antigo → 409, e nada muda', async () => {
    seedOrder('o1');
    const res = await call('owner', 'patch', `${O}/o1`, { status: 'progress', expectedUpdatedAt: '2026-09-01T00:00:00.000Z' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_CHANGED');
    expect(doc('o1').status).toBe('approved');
    expect((await call('owner', 'patch', `${O}/o1`, { status: 'progress', expectedUpdatedAt: T0 })).status).toBe(200);
  });
});

// ─── Itens ────────────────────────────────────────────────────────────────
describe('itens', () => {
  it('serviço do catálogo sem preço fica "sem valor" e fora do total', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/items`, { kind: 'service', catalogId: 's0' });
    expect(res.status).toBe(201);
    const added = doc('o1').services[1];
    expect(added.value).toBeNull();
    expect(added.id).toBe(res.body.data.itemId);
    expect(doc('o1').total).toBe(100);
  });

  it('produto grava o total da linha (D7) e o total vem do servidor', async () => {
    seedOrder('o1', { total: 999 });
    const res = await call('owner', 'post', `${O}/o1/items`, { kind: 'product', catalogId: 'p1', quantity: 3, value: 10, total: 25 });
    expect(res.status).toBe(201);
    expect(doc('o1').products[0]).toMatchObject({ value: 10, quantity: 3, total: 25 });
    expect(doc('o1').total).toBe(125);
    expect(res.body.data.order.total).toBe(125);
  });

  it('valor próprio exige editPrices', async () => {
    seedOrder('q', { status: 'quote', payment: null, createdBy: { id: 'cons1', name: 'Caio' } });
    expect((await call('consultant', 'post', `${O}/q/items`, { kind: 'service', catalogId: 's1', value: 1 })).status).toBe(403);
    expect((await call('consultant', 'post', `${O}/q/items`, { kind: 'product', catalogId: 'p1', quantity: 1, total: 1 })).status).toBe(403);
    const ok = await call('consultant', 'post', `${O}/q/items`, { kind: 'service', catalogId: 's1' });
    expect(ok.status).toBe(201);
    expect(doc('q').total).toBe(200);
  });

  it('técnico em OS aprovada só muda a observação do item', async () => {
    seedOrder('a', { createdBy: { id: 'tech1', name: 'Téo' } });
    const [line] = (await call('technician', 'get', `${O}/a`)).body.data.services;
    expect((await call('technician', 'patch', `${O}/a/items/${line.id}`, { description: 'Feito à mão' })).status).toBe(200);
    expect(doc('a').services[0].description).toBe('Feito à mão');
    expect((await call('technician', 'post', `${O}/a/items`, { kind: 'service', catalogId: 's1' })).status).toBe(403);
    expect((await call('technician', 'delete', `${O}/a/items/${line.id}`)).status).toBe(403);
  });

  it('editar quantidade recalcula a linha e o total; valor exige editPrices', async () => {
    seedOrder('o1', {
      services: [],
      products: [{ id: 'l1', product: { id: 'p1', name: 'Cera', value: 10 }, value: 10, quantity: 2, total: 20 }],
      total: 20,
      createdBy: { id: 'cons1', name: 'Caio' },
    });
    const res = await call('consultant', 'patch', `${O}/o1/items/l1`, { quantity: 3 });
    expect(res.status).toBe(200);
    expect(doc('o1').products[0]).toMatchObject({ quantity: 3, total: 30 });
    expect(doc('o1').total).toBe(30);
    expect((await call('consultant', 'patch', `${O}/o1/items/l1`, { value: 1 })).status).toBe(403);
    expect((await call('owner', 'patch', `${O}/o1/items/l1`, { value: null })).status).toBe(200);
    expect(doc('o1').products[0].value).toBeNull();
    expect(doc('o1').total).toBe(0);
  });

  it('item que não existe → 404', async () => {
    seedOrder('o1');
    const res = await call('owner', 'delete', `${O}/o1/items/nope`);
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('ITEM_NOT_FOUND');
  });

  it('total nunca fica negativo, e pago/a pagar acompanha o total sem emitir nota', async () => {
    seedOrder('o1', {
      services: [{ id: 'x', service: { id: 's1', name: 'A' }, value: 100 }, { id: 'y', service: { id: 's0', name: 'B' }, value: 50 }],
      total: 30, discount: 120, paidAmount: 0,
    });
    await call('owner', 'delete', `${O}/o1/items/x`);
    expect(doc('o1').total).toBe(0);

    seedOrder('o2', {
      services: [{ id: 'x', service: { id: 's1', name: 'A' }, value: 100 }, { id: 'y', service: { id: 's0', name: 'B' }, value: 50 }],
      total: 150, paidAmount: 100,
    });
    await call('owner', 'delete', `${O}/o2/items/y`);
    expect(doc('o2')).toMatchObject({ total: 100, payment: 'paid', paid: true, paymentSyncedAt: expect.any(String) });
  });

  it('aparelho do item precisa estar na OS', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/items`, { kind: 'service', catalogId: 's1', deviceId: 'd9' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_DEVICE');
  });

  it('resposta de escrita não traz valor para quem não vê preço', async () => {
    seedOrder('q', { status: 'quote', payment: null, createdBy: { id: 'tech1', name: 'Téo' } });
    const res = await call('technician', 'post', `${O}/q/items`, { kind: 'service', catalogId: 's1' });
    expect(res.status).toBe(201);
    expect(res.body.data.order).not.toHaveProperty('total');
    expect(res.body.data.order.services[1]).not.toHaveProperty('value');
    const legacy = await call('technician', 'post', `${O}/q/services`, { serviceId: 's1' });
    expect(legacy.body.data).not.toHaveProperty('newTotal');
  });

  it('duas pessoas salvando ao mesmo tempo: os dois itens ficam', async () => {
    seedOrder('o1');
    fakeDb.holdCommitsUntil(2);
    const [a, b] = await Promise.all([
      call('owner', 'post', `${O}/o1/items`, { kind: 'service', catalogId: 's0' }),
      call('admin', 'post', `${O}/o1/items`, { kind: 'product', catalogId: 'p1', quantity: 2 }),
    ]);
    expect([a.status, b.status]).toEqual([201, 201]);
    expect(doc('o1').services).toHaveLength(2);
    expect(doc('o1').products).toHaveLength(1);
    expect(doc('o1').total).toBe(120);
  });

  it('com expectedUpdatedAt, quem salva depois recebe 409 em vez de sobrescrever', async () => {
    seedOrder('o1');
    fakeDb.holdCommitsUntil(2);
    const [a, b] = await Promise.all([
      call('owner', 'post', `${O}/o1/items`, { kind: 'service', catalogId: 's0', expectedUpdatedAt: T0 }),
      call('admin', 'post', `${O}/o1/items`, { kind: 'service', catalogId: 's1', expectedUpdatedAt: T0 }),
    ]);
    expect([a.status, b.status].sort()).toEqual([201, 409]);
    expect(doc('o1').services).toHaveLength(2);
  });
});

// ─── Dinheiro ─────────────────────────────────────────────────────────────
describe('dinheiro', () => {
  const file = (path: string) => ({ url: storageUrl(path), storagePath: path, contentType: 'image/jpeg' });

  it('consultor recebe na OS que criou e não na dos outros', async () => {
    seedOrder('mine', { createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('theirs');
    expect((await call('consultant', 'post', `${O}/mine/payments`, { amount: 10 })).status).toBe(200);
    expect((await call('consultant', 'post', `${O}/theirs/payments`, { amount: 10 })).status).toBe(403);
  });

  it('grava data, forma e comprovante do pagamento', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/payments`, {
      amount: 40, paidAt: '2026-10-20T12:00:00.000Z', paymentMethod: 'pix',
      receiptFile: file('tenants/c1/orders/o1/payments/t/f.jpg'),
    });
    expect(res.status).toBe(200);
    const [t] = doc('o1').transactions;
    expect(t).toMatchObject({ amount: 40, paidAt: '2026-10-20T12:00:00.000Z', paymentMethod: 'pix', receiptDocumentId: expect.any(String) });
    expect(doc('o1').documents[0]).toMatchObject({ id: t.receiptDocumentId, type: 'receipt', linkedTransactionId: t.id });
    expect(res.body.data).toMatchObject({ paidAmount: 40, remainingBalance: 60, isFullyPaid: false });
  });

  it('comprovante fora da pasta desta OS é recusado', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/payments`, { amount: 40, receiptFile: file('tenants/c1/orders/o9/payments/t/f.jpg') });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FILE');
  });

  it('desconto tem rota própria e é só do financeiro', async () => {
    seedOrder('mine', { createdBy: { id: 'cons1', name: 'Caio' } });
    expect((await call('owner', 'post', `${O}/mine/payments`, { amount: 10, type: 'discount' })).status).toBe(400);
    expect((await call('consultant', 'post', `${O}/mine/discounts`, { amount: 10 })).status).toBe(403);
    const res = await call('manager', 'post', `${O}/mine/discounts`, { amount: 10 });
    expect(res.status).toBe(200);
    expect(doc('mine')).toMatchObject({ total: 90, discount: 10 });
  });

  it('remove pagamento, recalcula, e não remove pagamento do Asaas nem parte de recibo', async () => {
    seedOrder('o1', {
      paidAmount: 100, payment: 'paid', paid: true,
      transactions: [
        { id: 't1', type: 'payment', amount: 60, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } },
        { id: 'asaas_p1', type: 'payment', amount: 20, createdAt: T0, createdBy: { id: 'asaas', name: 'Asaas' } },
        { id: 'r1_0', type: 'payment', amount: 20, createdAt: T0, createdBy: { id: 'owner1', name: 'R' }, receiptGroupId: 'r1' },
      ],
    });
    expect((await call('owner', 'delete', `${O}/o1/payments/asaas_p1`)).body.error.code).toBe('ASAAS_LOCKED');
    expect((await call('owner', 'delete', `${O}/o1/payments/r1_0`)).body.error.code).toBe('RECEIPT_SHARE');
    const res = await call('owner', 'delete', `${O}/o1/payments/t1`);
    expect(res.status).toBe(200);
    expect(doc('o1')).toMatchObject({ paidAmount: 40, payment: 'unpaid', paid: false });
    expect(doc('o1').transactions.map((t: any) => t.id)).toEqual(['asaas_p1', 'r1_0']);
  });

  it('marcar como pago lança o saldo; zerar mantém o Asaas e tira o desconto', async () => {
    seedOrder('o1', {
      total: 90, discount: 10, paidAmount: 30,
      transactions: [
        { id: 'asaas_p1', type: 'payment', amount: 20, createdAt: T0, createdBy: { id: 'asaas', name: 'Asaas' } },
        { id: 't2', type: 'payment', amount: 10, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } },
        { id: 't3', type: 'discount', amount: 10, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } },
      ],
    });
    const paid = await call('owner', 'post', `${O}/o1/payments/mark-paid`, { paymentMethod: 'cash' });
    expect(paid.status).toBe(200);
    expect(doc('o1')).toMatchObject({ paidAmount: 90, payment: 'paid', paid: true });
    expect(doc('o1').transactions[3]).toMatchObject({ type: 'payment', amount: 60, paymentMethod: 'cash' });

    const reset = await call('owner', 'post', `${O}/o1/payments/reset`);
    expect(reset.status).toBe(200);
    expect(doc('o1')).toMatchObject({ total: 100, discount: 0, paidAmount: 20, payment: 'unpaid' });
    expect(doc('o1').transactions.map((t: any) => t.id)).toEqual(['asaas_p1']);
  });

  it('remover desconto devolve o total', async () => {
    seedOrder('o1', {
      total: 70, discount: 30,
      transactions: [{ id: 'd1', type: 'discount', amount: 30, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } }],
    });
    expect((await call('consultant', 'delete', `${O}/o1/discounts/d1`)).status).toBe(403);
    const res = await call('owner', 'delete', `${O}/o1/discounts/d1`);
    expect(res.status).toBe(200);
    expect(doc('o1')).toMatchObject({ total: 100, discount: 0, transactions: [] });
  });

  it('anexa e remove comprovante de um pagamento', async () => {
    seedOrder('o1', {
      paidAmount: 10,
      transactions: [{ id: 't1', type: 'payment', amount: 10, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } }],
    });
    const put = await call('owner', 'put', `${O}/o1/payments/t1/receipt`, { receiptFile: file('tenants/c1/orders/o1/payments/t1/a.jpg') });
    expect(put.status).toBe(200);
    const docId = doc('o1').transactions[0].receiptDocumentId;
    expect(doc('o1').documents).toEqual([expect.objectContaining({ id: docId, linkedTransactionId: 't1' })]);
    const del = await call('owner', 'delete', `${O}/o1/payments/t1/receipt`);
    expect(del.status).toBe(200);
    expect(doc('o1').transactions[0]).not.toHaveProperty('receiptDocumentId');
    expect(doc('o1').documents).toEqual([]);
    expect(fakeStorage.deleted).toEqual(['tenants/c1/orders/o1/payments/t1/a.jpg']);
  });

  it('comprovante exige attachPhotos (gerente recebe, mas não anexa) e OS que recebe (nem orçamento nem cancelada)', async () => {
    seedOrder('o1', {
      paidAmount: 10,
      transactions: [{ id: 't1', type: 'payment', amount: 10, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } }],
    });
    const receiptFile = file('tenants/c1/orders/o1/payments/t1/a.jpg');
    expect((await call('manager', 'put', `${O}/o1/payments/t1/receipt`, { receiptFile })).status).toBe(403);
    expect((await call('manager', 'delete', `${O}/o1/payments/t1/receipt`)).status).toBe(403);
    expect((await call('manager', 'post', `${O}/o1/payments`, { amount: 5, receiptFile: file('tenants/c1/orders/o1/payments/t2/b.jpg') })).status).toBe(403);
    expect((await call('manager', 'post', `${O}/o1/payments`, { amount: 5 })).status).toBe(200);
    for (const status of ['quote', 'canceled']) {
      seedOrder('o2', { status, paidAmount: 10, transactions: [{ id: 't1', type: 'payment', amount: 10, createdAt: T0, createdBy: { id: 'owner1', name: 'R' } }] });
      const put = await call('owner', 'put', `${O}/o2/payments/t1/receipt`, { receiptFile: file('tenants/c1/orders/o2/payments/t1/a.jpg') });
      expect([status, put.status]).toEqual([status, 409]);
      expect([status, (await call('owner', 'delete', `${O}/o2/payments/t1/receipt`)).status]).toEqual([status, 409]);
    }
  });

  it('com Valores e cobrança desligado ninguém mexe em dinheiro', async () => {
    seedCompanies({ useFinancial: false });
    seedOrder('o1');
    for (const [method, path] of [
      ['post', `${O}/o1/payments`], ['post', `${O}/o1/discounts`], ['post', `${O}/o1/payments/mark-paid`], ['post', `${O}/o1/payments/reset`],
    ] as const) {
      expect([path, (await call('owner', method, path, { amount: 1 })).status]).toEqual([path, 403]);
    }
  });
});

// ─── Apagar ───────────────────────────────────────────────────────────────
describe('DELETE /orders/:id', () => {
  it('técnico apaga o próprio orçamento sem dinheiro, com as subcoleções e os arquivos', async () => {
    seedOrder('q', { status: 'quote', payment: null, createdBy: { id: 'tech1', name: 'Téo' } });
    seed('companies/c1/orders/q/comments/k1', { text: 'oi' });
    const res = await call('technician', 'delete', `${O}/q`);
    expect(res.status).toBe(200);
    expect(doc('q')).toBeUndefined();
    expect(read('companies/c1/orders/q/comments/k1')).toBeUndefined();
    expect(fakeStorage.deletedPrefixes).toEqual(['tenants/c1/orders/q/']);
  });

  it('orçamento com dinheiro: só admin', async () => {
    seedOrder('q', { status: 'quote', payment: null, paidAmount: 10, createdBy: { id: 'tech1', name: 'Téo' } });
    expect((await call('technician', 'delete', `${O}/q`)).status).toBe(403);
    expect((await call('manager', 'delete', `${O}/q`)).status).toBe(403);
    expect((await call('admin', 'delete', `${O}/q`)).status).toBe(200);
  });

  it('OS com nota ativa não é apagada', async () => {
    seedOrder('o1');
    seed('companies/c1/invoices/i1', { status: 'authorized', orderIds: ['o1'] });
    const res = await call('owner', 'delete', `${O}/o1`);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ORDER_HAS_INVOICE');
    expect(doc('o1')).toBeDefined();
  });

  it('cobrança de várias OS aberta: pede para cancelar antes', async () => {
    seedOrder('o1');
    seed('companies/c1/customerCharges/cc1', { status: 'pending', orderIds: ['o1', 'o2'] });
    const res = await call('owner', 'delete', `${O}/o1`);
    expect(res.body.error.code).toBe('CUSTOMER_CHARGE_OPEN');
    expect(res.status).toBe(409);
  });

  it('cancela a cobrança aberta da OS antes de apagar; se não der, não apaga', async () => {
    seed('companies/c1/settings/payments', { asaasConnected: true });
    seedOrder('o1');
    seed('companies/c1/orders/o1/charges/ch1', { status: 'pending', asaasPaymentId: 'pay_1' });
    cancelOpenCharges.mockResolvedValueOnce(undefined);
    const failed = await call('owner', 'delete', `${O}/o1`);
    expect(failed.status).toBe(502);
    expect(doc('o1')).toBeDefined();

    cancelOpenCharges.mockImplementationOnce(async () => {
      seed('companies/c1/orders/o1/charges/ch1', { status: 'canceled', asaasPaymentId: 'pay_1' });
    });
    const res = await call('owner', 'delete', `${O}/o1`);
    expect(res.status).toBe(200);
    expect(cancelOpenCharges).toHaveBeenLastCalledWith('c1', 'o1');
    expect(doc('o1')).toBeUndefined();
  });
});

// ─── Parada ───────────────────────────────────────────────────────────────
describe('OS parada', () => {
  it('supervisor marca e retoma, com comentário interno', async () => {
    seedOrder('o1');
    const res = await call('supervisor', 'post', `${O}/o1/hold`, { reason: 'part', note: 'Bomba chega sexta' });
    expect(res.status).toBe(200);
    expect(doc('o1').onHold).toEqual({ reason: 'part', note: 'Bomba chega sexta', since: expect.any(String) });
    expect(res.body.data.order.onHold.reason).toBe('part');
    const back = await call('supervisor', 'delete', `${O}/o1/hold`);
    expect(back.status).toBe(200);
    expect(doc('o1')).not.toHaveProperty('onHold');
    const comments = list('companies/c1/orders/o1/comments').map((c) => c.data);
    expect(comments).toEqual([
      expect.objectContaining({ text: 'Marcada como parada: Esperando peça. Bomba chega sexta', isInternal: true }),
      expect.objectContaining({ text: 'Retomada no mesmo dia', isInternal: true }),
    ]);
  });

  it('consultor não marca; orçamento não fica parado; motivo precisa ser conhecido', async () => {
    seedOrder('mine', { createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('q', { status: 'quote', payment: null });
    expect((await call('consultant', 'post', `${O}/mine/hold`, { reason: 'part' })).status).toBe(403);
    expect((await call('owner', 'post', `${O}/q/hold`, { reason: 'part' })).status).toBe(409);
    expect((await call('owner', 'post', `${O}/mine/hold`, { reason: 'lunch' })).status).toBe(400);
  });
});

// ─── Etapas ───────────────────────────────────────────────────────────────
describe('etapas da OS', () => {
  const STAGES = [{ id: 'paint', name: 'Pintura', keywords: ['pint'] }, { id: 'polish', name: 'Polimento' }];
  const comments = () => list('companies/c1/orders/o1/comments').map((c) => c.data.text);

  beforeEach(() => seedCompanies({ workStages: STAGES }));

  it('aprovada entra na etapa e passa a em andamento; reordenar não comenta', async () => {
    seedOrder('o1');
    const res = await call('supervisor', 'put', `${O}/o1/stage`, { stageId: 'paint' });
    expect(res.status).toBe(200);
    expect(doc('o1')).toMatchObject({ status: 'progress', payment: 'unpaid', stage: { id: 'paint', rank: expect.any(Number), since: expect.any(String) } });
    expect(res.body.data.order.stage.id).toBe('paint');
    const since = doc('o1').stage.since;

    expect((await call('supervisor', 'put', `${O}/o1/stage`, { stageId: 'paint', rank: 1.5 })).status).toBe(200);
    expect(doc('o1').stage).toEqual({ id: 'paint', rank: 1.5, since });
    expect(comments()).toEqual(['Etapa: Pintura']);

    expect((await call('technician', 'put', `${O}/o1/stage`, { stageId: 'polish' })).status).toBe(403);
    expect((await call('owner', 'put', `${O}/o1/stage`, { stageId: 'polish', rank: -3 })).status).toBe(200);
    expect(doc('o1').stage).toMatchObject({ id: 'polish', rank: -3 });
    expect(comments()).toEqual(['Etapa: Pintura', 'Etapa: Polimento']);
  });

  it('sair de em andamento tira a etapa', async () => {
    seedOrder('o1', { status: 'progress', stage: { id: 'polish', rank: 1, since: T0 } });
    const res = await call('owner', 'patch', `${O}/o1`, { status: 'done' });
    expect(res.status).toBe(200);
    expect(doc('o1').status).toBe('done');
    expect(doc('o1')).not.toHaveProperty('stage');
    expect(res.body.data.order).not.toHaveProperty('stage');
  });

  it('recusa etapa desconhecida, orçamento, consultor e empresa sem etapas', async () => {
    seedOrder('o1');
    seedOrder('q', { status: 'quote', payment: null });
    seedOrder('mine', { createdBy: { id: 'cons1', name: 'Caio' } });
    expect((await call('owner', 'put', `${O}/o1/stage`, { stageId: 'wash' })).status).toBe(422);
    expect((await call('owner', 'put', `${O}/q/stage`, { stageId: 'paint' })).status).toBe(409);
    expect((await call('consultant', 'put', `${O}/mine/stage`, { stageId: 'paint' })).status).toBe(403);
    expect((await call('owner', 'put', `${O}/o1/stage`, {})).status).toBe(400);
    seedCompanies();
    expect((await call('owner', 'put', `${O}/o1/stage`, { stageId: 'paint' })).status).toBe(422);
    expect(doc('o1').status).toBe('approved');
    expect(doc('o1')).not.toHaveProperty('stage');
  });
});

// ─── Recibos ──────────────────────────────────────────────────────────────
describe('recibos do cliente', () => {
  const share = (receipt: string, i: number, amount: number) => ({
    id: `${receipt}_${i}`, type: 'payment', amount, createdAt: T0, createdBy: { id: 'cons1', name: 'Caio' }, receiptGroupId: receipt,
  });

  beforeEach(() => {
    seedOrder('a', { paidAmount: 100, payment: 'paid', paid: true, transactions: [share('r1', 0, 100)] });
    seedOrder('b', { paidAmount: 30, transactions: [share('r1', 1, 30)], documents: [{ id: 'receipt_r1_1', linkedTransactionId: 'r1_1' }] });
    seed('companies/c1/receipts/r1', {
      id: 'r1', customer: { id: 'cust1', name: 'João' }, amount: 130, paidAt: T0, status: 'active',
      allocations: [{ orderId: 'a', amount: 100, transactionId: 'r1_0' }, { orderId: 'b', amount: 30, transactionId: 'r1_1' }],
      createdBy: { id: 'cons1', name: 'Caio' }, createdAt: T0,
    });
    seed('companies/c1/receipts/r2', {
      id: 'r2', customer: { id: 'cust1', name: 'João' }, amount: 5, paidAt: '2026-10-05T10:00:00.000Z', status: 'active',
      allocations: [], createdBy: { id: 'mgr1', name: 'Gil' }, createdAt: T0,
    });
  });

  it('gerente vê todos; consultor só os que registrou', async () => {
    expect((await call('manager', 'get', `${CU}/cust1/receipts`)).body.data.map((r: any) => r.id)).toEqual(['r2', 'r1']);
    expect((await call('consultant', 'get', `${CU}/cust1/receipts`)).body.data.map((r: any) => r.id)).toEqual(['r1']);
    expect((await call('technician', 'get', `${CU}/cust1/receipts`)).status).toBe(403);
  });

  it('desfazer tira a parte de cada OS e marca o recibo como desfeito', async () => {
    const res = await call('consultant', 'post', `${CU}/cust1/receipts/r1/cancel`);
    expect(res.status).toBe(200);
    expect(read('companies/c1/receipts/r1')).toMatchObject({ status: 'canceled', updatedBy: { id: 'cons1' } });
    expect(doc('a')).toMatchObject({ paidAmount: 0, payment: 'unpaid', paid: false, transactions: [] });
    expect(doc('b')).toMatchObject({ paidAmount: 0, transactions: [], documents: [] });
  });

  it('consultor não desfaz recibo de outra pessoa', async () => {
    expect((await call('consultant', 'post', `${CU}/cust1/receipts/r2/cancel`)).status).toBe(403);
  });

  it('recibo do Asaas não se desfaz aqui', async () => {
    seed('companies/c1/receipts/asaas_x', { customer: { id: 'cust1' }, status: 'active', allocations: [], createdBy: { id: 'asaas' } });
    const res = await call('owner', 'post', `${CU}/cust1/receipts/asaas_x/cancel`);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ASAAS_LOCKED');
  });

  it('anexa e remove o comprovante do recibo em todas as OS', async () => {
    const receiptFile = { url: storageUrl('tenants/c1/receipts/r1/f.pdf'), storagePath: 'tenants/c1/receipts/r1/f.pdf', contentType: 'application/pdf' };
    const put = await call('consultant', 'put', `${CU}/cust1/receipts/r1/file`, { receiptFile });
    expect(put.status).toBe(200);
    expect(read('companies/c1/receipts/r1')).toMatchObject({ receiptFile: { storagePath: 'tenants/c1/receipts/r1/f.pdf' } });
    expect(doc('a').transactions[0].receiptDocumentId).toBe('receipt_r1_0');
    expect(doc('b').documents).toEqual([expect.objectContaining({ id: 'receipt_r1_1', storagePath: 'tenants/c1/receipts/r1/f.pdf' })]);
    const del = await call('consultant', 'delete', `${CU}/cust1/receipts/r1/file`);
    expect(del.status).toBe(200);
    expect(read('companies/c1/receipts/r1')).not.toHaveProperty('receiptFile');
    expect(doc('a').documents).toEqual([]);
    expect(doc('a').transactions[0]).not.toHaveProperty('receiptDocumentId');
  });
});

// ─── Outra empresa ────────────────────────────────────────────────────────
describe('outra empresa', () => {
  const RAW: Array<['get' | 'post' | 'patch' | 'put' | 'delete', string, object?]> = [
    ['get', `${O}/x`],
    ['patch', `${O}/x`, { status: 'progress' }],
    ['delete', `${O}/x`],
    ['post', `${O}/x/items`, { kind: 'service', catalogId: 's1' }],
    ['patch', `${O}/x/items/l1`, { description: 'a' }],
    ['delete', `${O}/x/items/l1`],
    ['post', `${O}/x/services`, { serviceId: 's1' }],
    ['post', `${O}/x/products`, { productId: 'p1', quantity: 1 }],
    ['post', `${O}/x/payments`, { amount: 1 }],
    ['delete', `${O}/x/payments/t1`],
    ['post', `${O}/x/payments/mark-paid`, {}],
    ['post', `${O}/x/payments/reset`, {}],
    ['put', `${O}/x/payments/t1/receipt`, { receiptFile: { url: storageUrl('tenants/c2/orders/x/payments/t1/a'), storagePath: 'tenants/c2/orders/x/payments/t1/a', contentType: 'image/png' } }],
    ['delete', `${O}/x/payments/t1/receipt`],
    ['post', `${O}/x/discounts`, { amount: 1 }],
    ['delete', `${O}/x/discounts/t1`],
    ['delete', `${O}/x/discounts`],
    ['post', `${O}/x/hold`, { reason: 'part' }],
    ['delete', `${O}/x/hold`],
    ['put', `${O}/x/stage`, { stageId: 'paint' }],
    ['get', `${CU}/cust1/receipts`],
    ['post', `${CU}/cust1/receipts/r9/cancel`],
    ['put', `${CU}/cust1/receipts/r9/file`, { receiptFile: { url: storageUrl('tenants/c2/receipts/r9/a'), storagePath: 'tenants/c2/receipts/r9/a', contentType: 'image/png' } }],
    ['delete', `${CU}/cust1/receipts/r9/file`],
  ];
  // Always three values: jest.each passes `done` to a test with more parameters than values.
  const ROUTES = RAW.map(([method, path, body]) => [method, path, body ?? null] as const);

  beforeEach(() => {
    seedOrder('x', { services: [{ id: 'l1', service: { id: 's1', name: 'A' }, value: 100 }],
      transactions: [{ id: 't1', type: 'payment', amount: 1, createdAt: T0, createdBy: { id: 'other2', name: 'O' } }] }, 'c2');
    seed('companies/c2/receipts/r9', { customer: { id: 'cust1' }, status: 'active', allocations: [], createdBy: { id: 'other2' } });
  });

  it.each(ROUTES)('%s %s: dono de c1 pedindo c2 → 403, e nada muda', async (method, path, body) => {
    const before = JSON.stringify([doc('x', 'c2'), read('companies/c2/receipts/r9')]);
    const res = await call('owner', method, path, body ?? undefined, 'c2');
    expect(res.status).toBe(403);
    expect(JSON.stringify([doc('x', 'c2'), read('companies/c2/receipts/r9')])).toBe(before);
  });

  it.each(ROUTES.filter(([, path]) => path.startsWith(O)))('%s %s: id de OS de c2 em c1 → 404', async (method, path, body) => {
    const sameCompany = body && JSON.parse(JSON.stringify(body).replace(/tenants(\/|%2F)c2(\/|%2F)/g, 'tenants$1c1$2'));
    const res = await call('owner', method, path, sameCompany ?? undefined, 'c1');
    expect(res.status).toBe(404);
    expect(doc('x', 'c2').transactions).toHaveLength(1);
  });
});

// ─── Endurecimento ────────────────────────────────────────────────────────
describe('arquivos apagados só da pasta da OS', () => {
  const by = { id: 'owner1', name: 'R' };
  const docs = [
    { id: 'own', linkedTransactionId: 't1', storagePath: 'tenants/c1/orders/o1/payments/t1/a.jpg' },
    { id: 'foreign', linkedTransactionId: 't1', storagePath: 'tenants/c2/orders/z/secret.pdf' },
    { id: 'dots', linkedTransactionId: 't1', storagePath: 'tenants/c1/orders/o1/../o2/b.jpg' },
    { id: 'sibling', linkedTransactionId: 't1', storagePath: 'tenants/c1/orders/o10/c.jpg' },
    { id: 'photo', linkedTransactionId: 't1', storagePath: 'tenants/c1/orders/o1/photos/p.jpg' },
    { id: 'otherPayment', linkedTransactionId: 't1', storagePath: 'tenants/c1/orders/o1/payments/t2/x.jpg' },
  ];
  beforeEach(() => seedOrder('o1', {
    paidAmount: 10, transactions: [{ id: 't1', type: 'payment', amount: 10, createdAt: T0, createdBy: by }], documents: docs,
  }));

  it('tirar pagamento apaga só o arquivo desta OS', async () => {
    expect((await call('owner', 'delete', `${O}/o1/payments/t1`)).status).toBe(200);
    expect(fakeStorage.deleted).toEqual(['tenants/c1/orders/o1/payments/t1/a.jpg']);
  });

  it('zerar pagamentos apaga só o arquivo desta OS', async () => {
    expect((await call('owner', 'post', `${O}/o1/payments/reset`)).status).toBe(200);
    expect(fakeStorage.deleted).toEqual(['tenants/c1/orders/o1/payments/t1/a.jpg']);
  });

  it('trocar comprovante apaga só o arquivo desta OS', async () => {
    const path = 'tenants/c1/orders/o1/payments/t1/new.jpg';
    const res = await call('owner', 'put', `${O}/o1/payments/t1/receipt`, {
      receiptFile: { url: storageUrl(path), storagePath: path, contentType: 'image/jpeg' },
    });
    expect(res.status).toBe(200);
    expect(fakeStorage.deleted).toEqual(['tenants/c1/orders/o1/payments/t1/a.jpg']);
  });
});

describe('clientTransactionId', () => {
  it('pagamento repetido com o mesmo id grava uma vez e devolve o mesmo resultado', async () => {
    seedOrder('o1');
    const body = { amount: 40, clientTransactionId: 'c0ffee00-0000-4000-8000-000000000001' };
    const first = await call('owner', 'post', `${O}/o1/payments`, body);
    const again = await call('owner', 'post', `${O}/o1/payments`, body);
    expect(first.status).toBe(200);
    expect(again.status).toBe(200);
    expect(again.body.data.transactionId).toBe('c0ffee00-0000-4000-8000-000000000001');
    expect(again.body.data).toMatchObject({ paidAmount: 40, remainingBalance: 60 });
    expect(doc('o1').transactions).toHaveLength(1);
    expect(doc('o1').paidAmount).toBe(40);
  });

  it('desconto repetido com o mesmo id grava uma vez', async () => {
    seedOrder('o1');
    const body = { amount: 10, clientTransactionId: 'c0ffee00-0000-4000-8000-000000000002' };
    expect((await call('owner', 'post', `${O}/o1/discounts`, body)).status).toBe(200);
    expect((await call('owner', 'post', `${O}/o1/discounts`, body)).status).toBe(200);
    expect(doc('o1')).toMatchObject({ total: 90, discount: 10 });
    expect(doc('o1').transactions).toHaveLength(1);
  });

  it('N2: repetir com o mesmo id depois de a resposta se perder devolve o gravado, mesmo com expectedUpdatedAt velho', async () => {
    seedOrder('o1');
    const payment = { amount: 40, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000b1', expectedUpdatedAt: T0 };
    expect((await call('owner', 'post', `${O}/o1/payments`, payment)).status).toBe(200);
    // The answer was lost: the screen still holds the old updatedAt and sends the same request.
    const again = await call('owner', 'post', `${O}/o1/payments`, payment);
    expect(again.status).toBe(200);
    expect(again.body.data).toMatchObject({ transactionId: payment.clientTransactionId, paidAmount: 40 });
    const discount = { amount: 5, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000b2', expectedUpdatedAt: doc('o1').updatedAt };
    expect((await call('owner', 'post', `${O}/o1/discounts`, discount)).status).toBe(200);
    expect((await call('owner', 'post', `${O}/o1/discounts`, discount)).status).toBe(200);
    expect(doc('o1').transactions).toHaveLength(2);
    // A new id over an old version is still refused.
    const stale = await call('owner', 'post', `${O}/o1/payments`, { amount: 1, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000b3', expectedUpdatedAt: T0 });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('ORDER_CHANGED');
  });

  it('mesmo id com outro valor ou tipo é recusado', async () => {
    seedOrder('o1');
    const id = 'c0ffee00-0000-4000-8000-000000000003';
    await call('owner', 'post', `${O}/o1/payments`, { amount: 40, clientTransactionId: id });
    const other = await call('owner', 'post', `${O}/o1/payments`, { amount: 50, clientTransactionId: id });
    expect(other.status).toBe(409);
    expect(other.body.error.code).toBe('TRANSACTION_ID_CONFLICT');
    expect((await call('owner', 'post', `${O}/o1/discounts`, { amount: 5, clientTransactionId: id })).status).toBe(409);
    expect(doc('o1').transactions).toHaveLength(1);
  });

  it('id em formato inválido é recusado', async () => {
    seedOrder('o1');
    for (const clientTransactionId of ['asaas_pay_1', 'r1_0', 'x', 'a/b']) {
      expect((await call('owner', 'post', `${O}/o1/payments`, { amount: 1, clientTransactionId })).status).toBe(400);
    }
  });
});

describe('comprovante e data do pagamento', () => {
  const path = 'tenants/c1/orders/o1/payments/t/f.jpg';
  beforeEach(() => seedOrder('o1'));

  it.each([
    ['outro host', `https://evil.example.com/v0/b/praticos.appspot.com/o/${encodeURIComponent(path)}`],
    ['outro bucket', storageUrl(path, 'other.appspot.com')],
    ['outro arquivo', storageUrl('tenants/c1/orders/o1/payments/t/other.jpg')],
  ])('URL de %s é recusada', async (_label, url) => {
    const res = await call('owner', 'post', `${O}/o1/payments`, { amount: 1, receiptFile: { url, storagePath: path, contentType: 'image/jpeg' } });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_FILE');
  });

  it('data no futuro é recusada', async () => {
    const paidAt = new Date(Date.now() + 2 * 3600 * 1000).toISOString();
    const res = await call('owner', 'post', `${O}/o1/payments`, { amount: 1, paidAt });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_PAID_AT');
  });

  it('data antes da criação da OS é recusada; no mesmo dia, mais cedo, passa', async () => {
    const before = await call('owner', 'post', `${O}/o1/payments`, { amount: 1, paidAt: '2026-09-20T10:00:00.000Z' });
    expect(before.status).toBe(400);
    expect(before.body.error.code).toBe('INVALID_PAID_AT');
    const markPaid = await call('owner', 'post', `${O}/o1/payments/mark-paid`, { paidAt: '2026-09-20T10:00:00.000Z' });
    expect(markPaid.status).toBe(400);
    expect((await call('owner', 'post', `${O}/o1/payments`, { amount: 1, paidAt: '2026-10-01T03:00:00.000Z' })).status).toBe(200);
  });
});

describe('apagar OS confere antes de cancelar a cobrança', () => {
  it('se entrou dinheiro antes da checagem final, recusa sem cancelar a cobrança', async () => {
    seed('companies/c1/settings/payments', { asaasConnected: true });
    seedOrder('q', { status: 'quote', payment: null, createdBy: { id: 'tech1', name: 'Téo' } });
    seed('companies/c1/orders/q/charges/ch1', { status: 'pending', asaasPaymentId: 'pay_1' });
    const realList = chargeService.listCharges;
    const spy = jest.spyOn(chargeService, 'listCharges').mockImplementationOnce(async (companyId, orderId) => {
      seedOrder('q', { status: 'quote', payment: null, paidAmount: 10, createdBy: { id: 'tech1', name: 'Téo' } });
      return realList(companyId, orderId);
    });
    const res = await call('manager', 'delete', `${O}/q`);
    spy.mockRestore();
    expect(res.status).toBe(403);
    expect(cancelOpenCharges).not.toHaveBeenCalled();
    expect(doc('q')).toBeDefined();
  });
});

describe('desfazer recibo com parte antiga', () => {
  it('parte sem id de transação recusa com erro claro e nada muda', async () => {
    seedOrder('a', { paidAmount: 50, transactions: [{ id: 'old', type: 'payment', amount: 50, createdAt: T0, createdBy: { id: 'cons1', name: 'Caio' } }] });
    seed('companies/c1/receipts/r3', {
      id: 'r3', customer: { id: 'cust1', name: 'João' }, amount: 50, paidAt: T0, status: 'active',
      allocations: [{ orderId: 'a', amount: 50 }], createdBy: { id: 'cons1', name: 'Caio' }, createdAt: T0,
    });
    const res = await call('owner', 'post', `${CU}/cust1/receipts/r3/cancel`);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('RECEIPT_LEGACY_SHARE');
    expect(read('companies/c1/receipts/r3')).toMatchObject({ status: 'active' });
    expect(doc('a').paidAmount).toBe(50);
  });
});

// ─── Saldo, OS sem duplicar e item avulso ─────────────────────────────────
describe('pagamento acima do que falta', () => {
  it('recusa com 409 e o saldo atual, sem gravar', async () => {
    seedOrder('o1', { paidAmount: 90 });
    const res = await call('owner', 'post', `${O}/o1/payments`, { amount: 20 });
    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'PAYMENT_EXCEEDS_BALANCE', remainingBalance: 10 });
    expect(doc('o1')).toMatchObject({ paidAmount: 90, transactions: [] });
  });

  it('o que falta exato passa, comparado em centavos', async () => {
    seedOrder('o1', { paidAmount: 90 });
    expect((await call('owner', 'post', `${O}/o1/payments`, { amount: 10 })).status).toBe(200);
    seedOrder('f', { services: [{ value: 0.3 }], total: 0.3, paidAmount: 0.1 });
    expect((await call('owner', 'post', `${O}/f/payments`, { amount: 0.2 })).status).toBe(200);
    expect(doc('f').payment).toBe('paid');
  });

  it('OS de valor 0 não recebe pagamento solto (use marcar como pago)', async () => {
    seedOrder('z', { services: [], total: 0 });
    expect((await call('owner', 'post', `${O}/z/payments`, { amount: 10 })).status).toBe(409);
    expect((await call('owner', 'post', `${O}/z/payments/mark-paid`, {})).status).toBe(200);
  });

  it('dois recebimentos ao mesmo tempo não passam do total', async () => {
    seedOrder('o1');
    const [a, b] = await Promise.all([
      call('owner', 'post', `${O}/o1/payments`, { amount: 60 }),
      call('manager', 'post', `${O}/o1/payments`, { amount: 60 }),
    ]);
    expect([a.status, b.status].sort()).toEqual([200, 409]);
    expect(doc('o1').paidAmount).toBe(60);
    expect(doc('o1').transactions).toHaveLength(1);
  });

  it('repetir com o mesmo clientTransactionId depois de quitar devolve o resultado anterior', async () => {
    seedOrder('o1');
    const body = { amount: 100, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000aa' };
    expect((await call('owner', 'post', `${O}/o1/payments`, body)).status).toBe(200);
    const again = await call('owner', 'post', `${O}/o1/payments`, body);
    expect(again.status).toBe(200);
    expect(doc('o1').transactions).toHaveLength(1);
  });
});

describe('clientOrderId', () => {
  beforeEach(() => seed('companies/c1/customers/cust1', { name: 'João', phone: '+5548999990000' }));
  const body = { customerId: 'cust1', clientOrderId: 'c0ffee00-0000-4000-8000-0000000000bb' };

  it('repetir com o mesmo id devolve a mesma OS sem criar outra', async () => {
    const first = await call('owner', 'post', O, body);
    expect(first.status).toBe(201);
    const again = await call('owner', 'post', O, body);
    expect(again.status).toBe(200);
    expect(again.body.data).toEqual(first.body.data);
    expect(list('companies/c1/orders')).toHaveLength(1);
  });

  it('id usado por outra pessoa é recusado', async () => {
    expect((await call('owner', 'post', O, body)).status).toBe(201);
    const other = await call('admin', 'post', O, body);
    expect(other.status).toBe(409);
    expect(other.body.error.code).toBe('ORDER_ID_CONFLICT');
    expect(list('companies/c1/orders')).toHaveLength(1);
  });

  it('id em formato inválido é recusado', async () => {
    expect((await call('owner', 'post', O, { ...body, clientOrderId: 'a/b' })).status).toBe(400);
  });
});

describe('item avulso', () => {
  it('serviço sem catálogo com descrição e valor entra no total', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/items`, { kind: 'service', description: 'Troca de óleo', value: 80 });
    expect(res.status).toBe(201);
    expect(doc('o1').services[1]).toMatchObject({ id: res.body.data.itemId, description: 'Troca de óleo', value: 80, service: null });
    expect(doc('o1').total).toBe(180);
  });

  it('produto avulso calcula a linha por quantidade', async () => {
    seedOrder('o1');
    const res = await call('owner', 'post', `${O}/o1/items`, { kind: 'product', description: 'Filtro', value: 10, quantity: 2 });
    expect(res.status).toBe(201);
    expect(doc('o1').products[0]).toMatchObject({ description: 'Filtro', value: 10, quantity: 2, total: 20, product: null });
    expect(doc('o1').total).toBe(120);
  });

  it('sem valor fica "sem valor"; valor próprio exige editPrices', async () => {
    seedOrder('q', { status: 'quote', payment: null, createdBy: { id: 'cons1', name: 'Caio' } });
    expect((await call('consultant', 'post', `${O}/q/items`, { kind: 'service', description: 'Avaliação', value: 30 })).status).toBe(403);
    const ok = await call('consultant', 'post', `${O}/q/items`, { kind: 'service', description: 'Avaliação' });
    expect(ok.status).toBe(201);
    expect(doc('q').services[1]).toMatchObject({ description: 'Avaliação', value: null });
    expect(doc('q').total).toBe(100);
  });

  it('sem catálogo e sem descrição é recusado', async () => {
    seedOrder('o1');
    expect((await call('owner', 'post', `${O}/o1/items`, { kind: 'service', value: 10 })).status).toBe(400);
    expect((await call('owner', 'post', `${O}/o1/items`, { kind: 'service', description: '  ', value: 10 })).status).toBe(400);
  });
});

// ─── Versão da OS (revisao-pr515-3 A1) ──────────────────────────────────────
// The app writes updatedAt as local time without a zone (Dart toIso8601String, microseconds),
// older documents carry a Timestamp, and many have none. `version` is the stored value as is
// (a Timestamp as its millis): the client sends it back unchanged and nothing is converted by zone.
// Run with TZ=America/Sao_Paulo and TZ=UTC.
describe('versão da OS (expectedUpdatedAt opaco)', () => {
  const LOCAL = '2026-10-01T09:00:00.123456';
  const STAMP = { seconds: 1790000000, nanoseconds: 123000000 };
  const DUE = '2026-12-01T12:00:00.000Z';

  it('GET devolve version cru: texto sem fuso continua texto, Timestamp vira millis, sem campo é null', async () => {
    seedOrder('l', { updatedAt: LOCAL });
    seedOrder('t', { updatedAt: STAMP });
    seedOrder('n', { updatedAt: undefined });
    expect((await call('owner', 'get', `${O}/l`)).body.data.version).toBe(LOCAL);
    expect((await call('owner', 'get', `${O}/t`)).body.data.version).toBe('1790000000123');
    expect((await call('owner', 'get', `${O}/n`)).body.data.version ?? null).toBeNull();
    const list = await call('owner', 'get', O);
    expect(list.body.data.find((o: any) => o.id === 'l').version).toBe(LOCAL);
  });

  it('OS salva pelo app (sem fuso, microssegundos): pagamento, desconto, PATCH e itens com o version devolvido passam', async () => {
    seedOrder('l', { updatedAt: LOCAL, status: 'done' });
    const version = (await call('owner', 'get', `${O}/l`)).body.data.version;
    const paid = await call('owner', 'post', `${O}/l/payments`, { amount: 10, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000c1', expectedUpdatedAt: version });
    expect(paid.status).toBe(200);
    const next = paid.body.data.order.version;
    expect(typeof next).toBe('string');
    expect((await call('owner', 'post', `${O}/l/discounts`, { amount: 5, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000c2', expectedUpdatedAt: next })).status).toBe(200);
    seedOrder('m', { updatedAt: LOCAL, status: 'approved' });
    expect((await call('owner', 'patch', `${O}/m`, { dueDate: DUE, expectedUpdatedAt: LOCAL })).status).toBe(200);
    seedOrder('i', { updatedAt: LOCAL, status: 'quote', payment: null });
    expect((await call('owner', 'post', `${O}/i/items`, { kind: 'service', catalogId: 's1', expectedUpdatedAt: LOCAL })).status).toBe(201);
  });

  it('R1: o web guarda a versão do servidor (…Z), o app grava texto sem fuso, e o envio com a versão velha dá 409', async () => {
    seedOrder('r', { updatedAt: T0, status: 'done', total: 200, paidAmount: 0 });
    // 1. The web saw the server's version.
    const seen = (await call('owner', 'get', `${O}/r`)).body.data.version;
    expect(seen).toBe(T0);
    // 2. The app books R$ 100 and saves local time without a zone.
    seed('companies/c1/orders/r', { ...doc('r'), paidAmount: 100, payment: 'unpaid', updatedAt: '2026-10-01T10:05:00.123456',
      transactions: [{ id: 'app-1', type: 'payment', amount: 100, createdAt: '2026-10-01T10:05:00.123456' }] });
    // 3. A screen still on the old version sends the same R$ 100.
    const late = await call('owner', 'post', `${O}/r/payments`, { amount: 100, clientTransactionId: 'c0ffee00-0000-4000-8000-0000000000c4', expectedUpdatedAt: seen });
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('ORDER_CHANGED');
    expect(doc('r').paidAmount).toBe(100);
    // The same for PATCH and items.
    expect((await call('owner', 'patch', `${O}/r`, { dueDate: DUE, expectedUpdatedAt: seen })).status).toBe(409);
    // Text without a zone read as an instant by a browser is not the version either.
    const converted = new Date(Date.UTC(2026, 9, 1, 13, 5, 0, 123)).toISOString();
    expect((await call('owner', 'patch', `${O}/r`, { dueDate: DUE, expectedUpdatedAt: converted })).status).toBe(409);
  });

  it('Timestamp: millis e ISO com Z do mesmo instante passam; outro instante dá 409', async () => {
    seedOrder('t', { updatedAt: STAMP, status: 'done' });
    expect((await call('owner', 'patch', `${O}/t`, { dueDate: DUE, expectedUpdatedAt: '1790000000123' })).status).toBe(200);
    seedOrder('u', { updatedAt: STAMP, status: 'done' });
    expect((await call('owner', 'patch', `${O}/u`, { dueDate: DUE, expectedUpdatedAt: new Date(1790000000123).toISOString() })).status).toBe(200);
    seedOrder('v', { updatedAt: STAMP, status: 'done' });
    expect((await call('owner', 'patch', `${O}/v`, { dueDate: DUE, expectedUpdatedAt: '1790000000000' })).status).toBe(409);
  });

  it('outra versão dá 409 (com Z e sem fuso); OS sem updatedAt não recusa', async () => {
    seedOrder('z', { updatedAt: T0, status: 'done' });
    expect((await call('owner', 'patch', `${O}/z`, { dueDate: DUE, expectedUpdatedAt: '2026-10-01T10:00:01.000Z' })).status).toBe(409);
    seedOrder('w', { updatedAt: '2026-10-01T09:00:00.000', status: 'done' });
    expect((await call('owner', 'patch', `${O}/w`, { dueDate: DUE, expectedUpdatedAt: '2026-10-01T09:00:00.001' })).status).toBe(409);
    seedOrder('n', { updatedAt: undefined, status: 'done' });
    expect((await call('owner', 'patch', `${O}/n`, { dueDate: DUE, expectedUpdatedAt: T0 })).status).toBe(200);
  });
});

// ─── Busca por número (revisao-pr515-3 A4) ─────────────────────────────────
describe('GET /orders?number=', () => {
  it('acha pelo número só a OS que a pessoa vê, projetada sem valores para quem não vê', async () => {
    seedOrder('mine', { number: 42, createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('given', { number: 43, assignedTo: { id: 'tech1', name: 'Téo' } });
    seedOrder('other', { number: 44 });
    const found = await call('technician', 'get', `${O}?number=42`);
    expect(found.status).toBe(200);
    expect(found.body.data.map((o: any) => o.id)).toEqual(['mine']);
    expect(found.body.data[0]).not.toHaveProperty('total');
    expect((await call('technician', 'get', `${O}?number=43`)).body.data.map((o: any) => o.id)).toEqual(['given']);
    expect((await call('technician', 'get', `${O}?number=44`)).body.data).toEqual([]);
    expect((await call('supervisor', 'get', `${O}?number=44`)).body.data.map((o: any) => o.id)).toEqual(['other']);
    expect((await call('technician', 'get', `${O}?number=abc`)).status).toBe(400);
  });

  it('R2: com mais de 10 OS repetidas no número, a da pessoa não fica de fora', async () => {
    for (let i = 0; i < 120; i++) seedOrder(`dup${String(i).padStart(3, '0')}`, { number: 77 });
    seedOrder('zz-mine', { number: 77, createdBy: { id: 'tech1', name: 'Téo' } });
    expect((await call('technician', 'get', `${O}?number=77`)).body.data.map((o: any) => o.id)).toEqual(['zz-mine']);
  });
});

// ─── União do técnico (revisao-pr515-3 A2, A3) ─────────────────────────────
describe('união do técnico: mesma ordem da Firestore', () => {
  it('datas iguais desempatam pelo id; texto pela ordem lexical; a OS repetida na virada da página aparece uma vez; sem total', async () => {
    const same = '2026-10-05T10:00:00.000Z';
    seedOrder('a1', { createdAt: same, createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('b2', { createdAt: same, assignedTo: { id: 'tech1', name: 'Téo' } });
    seedOrder('c3', { createdAt: same, createdBy: { id: 'tech1', name: 'Téo' }, assignedTo: { id: 'tech1', name: 'Téo' } });
    seedOrder('d4', { createdAt: '2026-10-04T10:00:00.000Z', assignedTo: { id: 'tech1', name: 'Téo' } });
    // Lexical order of text (as Firestore): "10:00:00Z" > "10:00:00.500Z" ('Z' > '.'), so desc puts e5 first.
    seedOrder('e5', { createdAt: '2026-10-03T10:00:00Z', createdBy: { id: 'tech1', name: 'Téo' } });
    seedOrder('f6', { createdAt: '2026-10-03T10:00:00.500Z', assignedTo: { id: 'tech1', name: 'Téo' } });
    const expected = ['c3', 'b2', 'a1', 'd4', 'e5', 'f6'];
    for (const size of [1, 2, 3]) {
      const ids: string[] = [];
      let cursor = '';
      for (let i = 0; i < 10; i++) {
        const page = await call('technician', 'get', `${O}?limit=${size}${cursor ? `&cursor=${cursor}` : ''}`);
        expect(page.body.pagination).not.toHaveProperty('total');
        ids.push(...page.body.data.map((o: any) => o.id));
        if (!page.body.pagination.hasMore) break;
        cursor = page.body.pagination.nextCursor;
      }
      expect([size, ids]).toEqual([size, expected]);
    }
  });
});

// ─── OS por mês (#723) ───────────────────────────────────────────────────

describe('POST /orders: OS do mês (limite suave)', () => {
  const thisMonth = () => orderMonthKey(new Date());
  beforeEach(() => {
    resetPaidPlansCache();
    seed('companies/c1/customers/cust1', { name: 'João' });
  });
  afterAll(() => resetPaidPlansCache());

  it('Free no segundo mês acima do limite: 402 PLAN_LIMIT, o mesmo corpo do app e da web', async () => {
    seed('config/paidPlans', { enabled: true });
    seedCompanies({ subscription: { plan: 'free', usage: { ordersMonth: thisMonth(), ordersThisMonth: 10, ordersLastMonth: 12 } } });
    const res = await call('admin', 'post', O, { customerId: 'cust1' });
    expect(res.status).toBe(402);
    expect(res.body.error).toMatchObject({ code: 'PLAN_LIMIT', resource: 'order', limit: 10, usage: 10, plan: 'free' });
    expect(list('companies/c1/orders')).toHaveLength(0);
  });

  it('primeiro mês acima do limite: cria (mês de folga)', async () => {
    seed('config/paidPlans', { enabled: true });
    seedCompanies({ subscription: { plan: 'free', usage: { ordersMonth: thisMonth(), ordersThisMonth: 10, ordersLastMonth: 2 } } });
    expect((await call('admin', 'post', O, { customerId: 'cust1' })).status).toBe(201);
  });

  it('chave desligada: cria sem contar', async () => {
    seedCompanies({ subscription: { plan: 'free', usage: { ordersMonth: thisMonth(), ordersThisMonth: 50, ordersLastMonth: 50 } } });
    expect((await call('admin', 'post', O, { customerId: 'cust1' })).status).toBe(201);
  });

  it('um pedido inválido continua 400, antes do limite', async () => {
    seed('config/paidPlans', { enabled: true });
    seedCompanies({ subscription: { plan: 'free', usage: { ordersMonth: thisMonth(), ordersThisMonth: 10, ordersLastMonth: 12 } } });
    expect((await call('admin', 'post', O, {})).status).toBe(400);
  });
});
