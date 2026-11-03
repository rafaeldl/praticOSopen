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
