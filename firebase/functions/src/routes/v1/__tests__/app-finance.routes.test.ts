/**
 * /v1/app/finance as the web app uses it (docs/WEB_API.md, "Financeiro"):
 * the numbers of the Financeiro tab, the report and Receber come from the
 * server, never from thousands of orders read in the browser. Real bearerAuth +
 * resolveCompanyContext over the in-memory Firestore (token = uid).
 */
import { Server } from 'http';
import request from 'supertest';
import express, { Express } from 'express';

jest.mock('../../../services/firestore.service', () => ({
  ...jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { bearerAuth } from '../../../middleware/auth.middleware';
import { resolveCompanyContext } from '../../../middleware/company.middleware';
import financeRoutes from '../app-finance.routes';
import { financeReport, financeSummary, receivableOrders } from '../../../services/app-finance.service';

type Role = 'owner' | 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician';
const UID: Record<Role, string> = {
  owner: 'owner1', admin: 'admin1', manager: 'mgr1', supervisor: 'sup1', consultant: 'cons1', technician: 'tech1',
};
const FI = '/v1/app/finance';

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use(FI, bearerAuth, resolveCompanyContext, financeRoutes);
  return app;
}

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

function seedCompany(fields: Record<string, unknown> = {}) {
  seed('companies/c1', { name: 'Oficina', owner: { id: 'owner1', name: 'Rafael' }, country: 'BR', ...fields });
  seed('companies/c1/private/membership', {
    members: { admin1: 'admin', mgr1: 'manager', sup1: 'supervisor', cons1: 'consultant', tech1: 'technician' },
  });
  seed('companies/c2', { name: 'Outra', owner: { id: 'other2', name: 'Outro' } });
  seed('companies/c2/private/membership', { members: {} });
  for (const [role, uid] of Object.entries(UID)) {
    seed(`users/${uid}`, { name: uid, companies: [{ company: { id: 'c1', name: 'Oficina' }, role }] });
  }
  seed('users/other2', { name: 'Outro', companies: [{ company: { id: 'c2', name: 'Outra' }, role: 'owner' }] });
}

function order(id: string, data: Record<string, unknown>, company = 'c1') {
  seed(`companies/${company}/orders/${id}`, {
    number: Number(id.replace(/\D/g, '')) || 1,
    status: 'done',
    customer: { id: 'ana', name: 'Ana' },
    devices: [{ id: 'uno', name: 'Uno', serial: 'ABC1D23' }],
    services: [{ service: { id: 's1', name: 'Troca de óleo' }, description: 'Troca de óleo', value: 100 }],
    products: [],
    total: 100,
    paidAmount: 0,
    payment: 'unpaid',
    createdBy: { id: 'someone', name: 'Alguém' },
    createdAt: '2026-03-10T15:00:00.000Z',
    updatedAt: '2026-03-10T15:00:00.000Z',
    ...data,
  });
}

function call(role: Role | 'other2', path: string, company = 'c1') {
  const uid = role === 'other2' ? 'other2' : UID[role];
  return request(server).get(path).set('Authorization', `Bearer ${uid}`).set('X-Company-ID', company);
}

beforeEach(() => {
  resetFakeDb();
  seedCompany();
  // March 2026, São Paulo.
  order('o1', {
    status: 'done', total: 300, paidAmount: 300, payment: 'paid',
    products: [{ product: { id: 'p1', name: 'Filtro' }, value: 50, quantity: 2, total: 100 }],
    services: [{ service: { id: 's1', name: 'Troca de óleo' }, value: 200 }],
    transactions: [{ id: 't1', type: 'payment', amount: 300, paidAt: '2026-03-12T12:00:00.000Z', createdAt: '2026-03-12T12:00:00.000Z' }],
    lastPaymentAt: '2026-03-12T12:00:00.000Z',
  });
  // Created in February, paid in March: received in March, sold in February.
  order('o2', {
    customer: { id: 'bia', name: 'Bia' }, createdAt: '2026-02-20T15:00:00.000Z', total: 80, paidAmount: 80, payment: 'paid',
    transactions: [{ id: 't2', type: 'payment', amount: 80, paidAt: '2026-03-02T12:00:00.000Z' }],
    lastPaymentAt: '2026-03-02T12:00:00.000Z',
  });
  // Last day of March, written by the app (local time, no zone).
  order('o3', { status: 'approved', createdAt: '2026-03-31T23:30:00.000123', total: 50, payment: 'unpaid' });
  // April in São Paulo.
  order('o4', { status: 'approved', createdAt: '2026-04-01T03:00:00.000Z', total: 999, payment: 'unpaid' });
  // Done with a balance, old: in A receber.
  order('o5', { customer: { id: 'bia', name: 'Bia' }, createdAt: '2025-12-01T15:00:00.000Z', total: 120, paidAmount: 20, payment: 'partial' });
  // Running with a down payment.
  order('o6', { status: 'progress', createdAt: '2026-01-05T15:00:00.000Z', total: 200, paidAmount: 50, payment: 'partial' });
  // Approved outside the app, no payment field.
  order('o7', { status: 'approved', createdAt: '2026-01-06T15:00:00.000Z', total: 70, payment: null });
  order('q1', { status: 'quote', total: 500, payment: null });
  // Another company: never in c1's numbers.
  order('x1', { total: 777, paidAmount: 0, payment: 'unpaid' }, 'c2');
});

describe('GET /finance/summary', () => {
  it('gives the numbers of the month, the last day included, by the company zone', async () => {
    const res = await call('admin', `${FI}/summary?month=2026-03`);
    expect(res.status).toBe(200);
    const data = res.body.data;
    expect(data.from).toBe('2026-03-01');
    expect(data.to).toBe('2026-03-31');
    expect(data.zone).toBe('America/Sao_Paulo');
    expect(data.received.total).toBe(380);
    expect(data.received.orders.map((o: { id: string }) => o.id)).toEqual(['o1', 'o2']);
    expect(data.received.orders[0].amount).toBe(300);
    // o1 (300) + o3 (50, last day, app format); o4 is April, q1 a quote.
    expect(data.sold.total).toBe(350);
    expect(data.sold.orders.map((o: { id: string }) => o.id)).toEqual(['o3', 'o1']);
    expect(data.receivable).toMatchObject({ total: 250, owed: 100, depositOwed: 150, customers: 2 });
    expect(data.receivable.debtors.map((d: { key: string }) => d.key)).toEqual(['bia']);
    expect(data.progress.orders.map((o: { id: string }) => o.id)).toEqual(['o7', 'o3', 'o4']);
    expect(data.progress.total).toBe(1119);
    expect(JSON.stringify(data)).not.toContain('777');
  });

  it('rows carry what the screen shows, never the raw items', async () => {
    const res = await call('manager', `${FI}/summary?month=2026-03`);
    expect(res.status).toBe(200);
    const row = res.body.data.sold.orders.find((o: { id: string }) => o.id === 'o1');
    expect(row).toEqual({
      id: 'o1', number: 1, status: 'done', customer: { id: 'ana', name: 'Ana' }, device: 'Uno',
      total: 300, paid: 300, open: 0, createdAt: '2026-03-10T15:00:00.000Z', amount: 300,
    });
  });

  it('defaults to the current month and refuses a bad one', async () => {
    expect((await call('admin', `${FI}/summary`)).status).toBe(200);
    expect((await call('admin', `${FI}/summary?month=2026-13`)).status).toBe(400);
    expect((await call('admin', `${FI}/summary?month=ontem`)).status).toBe(400);
  });

  it('uses the zone the browser asks for only when it is of the company country', async () => {
    const manaus = await call('admin', `${FI}/summary?month=2026-03&zone=America/Manaus`);
    expect(manaus.body.data.zone).toBe('America/Manaus');
    const tokyo = await call('admin', `${FI}/summary?month=2026-03&zone=Asia/Tokyo`);
    expect(tokyo.body.data.zone).toBe('America/Sao_Paulo');
  });

  it('a company in Manaus paid at 00:30 of the 1st: received in that month (M1 of #525)', async () => {
    // lastPaymentAt reads the app's zoneless text as -03:00 (03:30Z); the month starts at 04:00Z in Manaus.
    order('m1', {
      createdAt: '2026-10-20T15:00:00.000Z', total: 70, paidAmount: 70, payment: 'paid',
      transactions: [{ id: 'tm', type: 'payment', amount: 70, paidAt: '2026-11-01T00:30:00.000' }],
      lastPaymentAt: '2026-11-01T03:30:00.000Z',
    });
    const res = await call('admin', `${FI}/summary?month=2026-11&zone=America/Manaus`);
    expect(res.body.data.zone).toBe('America/Manaus');
    expect(res.body.data.received.orders.map((o: { id: string }) => o.id)).toEqual(['m1']);
    expect(res.body.data.received.total).toBe(70);
    // And not in October, the month before.
    const october = await call('admin', `${FI}/summary?month=2026-10&zone=America/Manaus`);
    expect(october.body.data.received.orders.map((o: { id: string }) => o.id)).not.toContain('m1');
  });

  it.each(['supervisor', 'consultant', 'technician'] as Role[])('%s gets 403', async (role) => {
    const res = await call(role, `${FI}/summary?month=2026-03`);
    expect(res.status).toBe(403);
    expect(JSON.stringify(res.body)).not.toMatch(/total|300/);
  });

  it('nobody gets numbers with "Valores e cobrança" off', async () => {
    seedCompany({ useFinancial: false });
    for (const role of ['owner', 'admin', 'manager'] as Role[]) {
      expect((await call(role, `${FI}/summary?month=2026-03`)).status).toBe(403);
      expect((await call(role, `${FI}/report?from=2026-03-01&to=2026-03-31`)).status).toBe(403);
      expect((await call(role, `${FI}/receivable`)).status).toBe(403);
    }
  });

  it('a member of another company gets 403 for c1', async () => {
    expect((await call('other2', `${FI}/summary?month=2026-03`)).status).toBe(403);
  });
});

describe('reading limit (B2 of #525)', () => {
  it('never reads more than the limit, all the queries of one answer together', async () => {
    const period = { from: '2026-03-01', to: '2026-03-31', zone: 'America/Sao_Paulo' };
    const all = await financeSummary('c1', period);
    expect(all.truncated).toBe(false);
    for (const max of [1, 2, 3, 4, 5]) {
      const cut = await financeSummary('c1', period, max);
      expect(cut.read).toBeLessThanOrEqual(max);
      expect(cut.truncated).toBe(true);
    }
    const report = await financeReport('c1', period, 1);
    expect(report.read).toBeLessThanOrEqual(1);
    expect(report.truncated).toBe(true);
    const receivable = await receivableOrders('c1', period.zone, 1);
    expect(receivable.read).toBeLessThanOrEqual(1);
    expect(receivable.truncated).toBe(true);
  });
});

describe('GET /finance/report', () => {
  it('totals, composition, rankings and orders of the period', async () => {
    const res = await call('owner', `${FI}/report?from=2026-03-01&to=2026-03-31`);
    expect(res.status).toBe(200);
    const r = res.body.data;
    expect(r).toMatchObject({ from: '2026-03-01', to: '2026-03-31', revenue: 350, paid: 300, remaining: 50, count: 2, paidCount: 1 });
    expect(r.composition).toEqual({ services: 300, products: 100 });
    expect(r.customers).toEqual([{ id: 'ana', name: 'Ana', total: 350, paid: 300, remaining: 50, count: 2 }]);
    expect(r.services[0]).toEqual({ name: 'Troca de óleo', total: 300, count: 2, quantity: 2 });
    expect(r.products).toEqual([{ name: 'Filtro', total: 100, count: 1, quantity: 2 }]);
    expect(r.orders.map((o: { id: string }) => o.id)).toEqual(['o3', 'o1']);
    expect(r.orders[1].payment).toBe('paid');
  });

  it('the last day of a custom period is included', async () => {
    const res = await call('admin', `${FI}/report?from=2026-03-31&to=2026-03-31`);
    expect(res.body.data.orders.map((o: { id: string }) => o.id)).toEqual(['o3']);
  });

  it('a customer filter keeps the ranking and the payment filter lists every unpaid', async () => {
    order('o8', { customer: { id: 'bia', name: 'Bia' }, total: 40, paidAmount: 10, payment: 'partial' });
    const bia = (await call('admin', `${FI}/report?from=2026-03-01&to=2026-03-31&customer=bia`)).body.data;
    expect(bia.revenue).toBe(40);
    expect(bia.customers.map((c: { id: string }) => c.id)).toEqual(['ana', 'bia']);
    const unpaid = (await call('admin', `${FI}/report?from=2026-03-01&to=2026-03-31&payment=unpaid`)).body.data;
    expect(unpaid.orders.map((o: { id: string }) => o.id).sort()).toEqual(['o3', 'o8']);
    expect(unpaid.revenue).toBe(390);
  });

  it('refuses a bad period', async () => {
    expect((await call('admin', `${FI}/report?from=2026-03-31&to=2026-03-01`)).status).toBe(400);
    expect((await call('admin', `${FI}/report?from=2026-02-30&to=2026-03-01`)).status).toBe(400);
    expect((await call('admin', `${FI}/report?from=2026-03-01`)).status).toBe(400);
    expect((await call('admin', `${FI}/report?from=2026-03-01&to=2026-03-31&payment=maybe`)).status).toBe(400);
  });

  it.each(['supervisor', 'consultant', 'technician'] as Role[])('%s gets 403', async (role) => {
    expect((await call(role, `${FI}/report?from=2026-03-01&to=2026-03-31`)).status).toBe(403);
  });
});

describe('GET /finance/receivable', () => {
  it('every order that still owes, oldest first, read on the server', async () => {
    const res = await call('admin', `${FI}/receivable`);
    expect(res.status).toBe(200);
    expect(res.body.data.orders.map((o: { id: string }) => o.id)).toEqual(['o5', 'o6']);
    expect(res.body.data.orders[0]).toMatchObject({ id: 'o5', open: 100, status: 'done', customer: { id: 'bia', name: 'Bia' } });
    expect(res.body.data.truncated).toBe(false);
  });

  it.each(['supervisor', 'consultant', 'technician'] as Role[])('%s gets 403', async (role) => {
    expect((await call(role, `${FI}/receivable`)).status).toBe(403);
  });
});
