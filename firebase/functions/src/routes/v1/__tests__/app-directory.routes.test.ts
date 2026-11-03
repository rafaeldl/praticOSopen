/**
 * /v1/app/customers and /v1/app/devices as the web app uses them (docs/WEB_API.md,
 * "Clientes e aparelhos"). Real bearerAuth + resolveCompanyContext over the
 * in-memory Firestore (token = uid): role and company come from server data.
 */
import { Server } from 'http';
import request from 'supertest';
import express, { Express } from 'express';

jest.mock('../../../services/firestore.service', () => ({
  ...jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

import { list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { bearerAuth } from '../../../middleware/auth.middleware';
import { resolveCompanyContext } from '../../../middleware/company.middleware';
import appCustomersRoutes from '../app-customers.routes';
import appDevicesRoutes from '../app-devices.routes';

type Role = 'owner' | 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician';
const UID: Record<Role, string> = {
  owner: 'owner1', admin: 'admin1', manager: 'mgr1', supervisor: 'sup1', consultant: 'cons1', technician: 'tech1',
};
const CU = '/v1/app/customers';
const DE = '/v1/app/devices';
const T0 = '2026-10-01T10:00:00.000Z';

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use(CU, bearerAuth, resolveCompanyContext, appCustomersRoutes);
  app.use(DE, bearerAuth, resolveCompanyContext, appDevicesRoutes);
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

function seedCompanies(c1: Record<string, unknown> = {}) {
  seed('companies/c1', { name: 'Oficina', owner: { id: 'owner1', name: 'Rafael' }, country: 'BR', ...c1 });
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

function seedOrder(id: string, data: Record<string, unknown> = {}) {
  seed(`companies/c1/orders/${id}`, {
    number: 1,
    status: 'approved',
    customer: { id: 'ana', name: 'Ana' },
    devices: [{ id: 'uno', name: 'Uno', serial: 'ABC1D23' }],
    deviceIds: ['uno'],
    services: [{ service: { id: 's1', name: 'Troca de óleo' }, description: 'Troca de óleo', value: 100 }],
    products: [],
    total: 100,
    paidAmount: 0,
    payment: 'unpaid',
    createdBy: { id: 'someone', name: 'Alguém' },
    createdAt: T0,
    updatedAt: T0,
    ...data,
  });
}

function call(role: Role | 'other2', method: 'get' | 'post' | 'patch' | 'put' | 'delete', path: string, body?: object, company = 'c1') {
  const uid = role === 'other2' ? 'other2' : UID[role];
  const req = request(server)[method](path).set('Authorization', `Bearer ${uid}`).set('X-Company-ID', company);
  return body ? req.send(body) : req;
}

beforeEach(() => {
  resetFakeDb();
  seedCompanies();
  seed('companies/c1/customers/ana', { name: 'Ana Souza', phone: '(48) 98408-7801', company: { id: 'c1' } });
  seed('companies/c1/customers/bia', { name: 'Bia', phone: '+5511900000001', taxId: '52998224725', customData: { birth: '1990-01-01' } });
  seed('companies/c2/customers/zed', { name: 'Zed' });
  seed('companies/c1/devices/uno', { name: 'Uno', serial: 'ABC1D23', manufacturer: 'Fiat', status: 'active' });
  seed('companies/c1/devices/gol', { name: 'Gol', serial: 'XYZ9876', nextMaintenanceDate: '2027-01-10', nextMaintenanceNoticeFor: '2027-01-10' });
});

// ─── Clientes ───────────────────────────────────────────────────────────────
describe('GET /customers (lista)', () => {
  test('devolve todos os clientes da empresa, sem os de outra', async () => {
    const res = await call('technician', 'get', CU);
    expect(res.status).toBe(200);
    expect(res.body.data.map((c: any) => c.id).sort()).toEqual(['ana', 'bia']);
    expect(res.body.data.find((c: any) => c.id === 'bia')).toMatchObject({ name: 'Bia', phone: '+5511900000001', taxId: '52998224725' });
  });

  test('selos: atrasada vence aberta e aberta é approved ou progress', async () => {
    seedOrder('o1', { status: 'approved', dueDate: '2020-01-01T00:00:00.000Z' });
    seedOrder('o2', { status: 'progress' });
    seedOrder('o3', { status: 'quote' });
    seedOrder('o4', { status: 'done' });
    const res = await call('admin', 'get', CU);
    expect(res.body.data.find((c: any) => c.id === 'ana')).toMatchObject({ open: 2, late: 1 });
    expect(res.body.data.find((c: any) => c.id === 'bia')).toMatchObject({ open: 0, late: 0 });
  });

  test('consultor e técnico contam só as OS que podem ver', async () => {
    seedOrder('o1', { createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('o2', { createdBy: { id: 'someone', name: 'X' } });
    seedOrder('o3', { createdBy: { id: 'someone', name: 'X' }, assignedTo: { id: 'tech1', name: 'Téo' } });
    const consultant = await call('consultant', 'get', CU);
    expect(consultant.body.data.find((c: any) => c.id === 'ana').open).toBe(1);
    expect(consultant.body.meta.partial).toBe(true);
    const technician = await call('technician', 'get', CU);
    expect(technician.body.data.find((c: any) => c.id === 'ana').open).toBe(1);
    const admin = await call('admin', 'get', CU);
    expect(admin.body.data.find((c: any) => c.id === 'ana').open).toBe(3);
    expect(admin.body.meta.partial).toBe(false);
  });
});

describe('GET /customers/:id (tela do cliente)', () => {
  beforeEach(() => {
    seedOrder('o1', { status: 'done', total: 300, paidAmount: 100, payment: 'partial', createdAt: '2026-10-02T10:00:00.000Z' });
    seedOrder('o2', { status: 'done', total: 50, paidAmount: 50, payment: 'paid', createdAt: '2026-10-03T10:00:00.000Z', createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('o3', { status: 'approved', total: 80, createdAt: '2026-10-04T10:00:00.000Z', devices: [{ id: 'gol', name: 'Gol' }], deviceIds: ['gol'] });
    seedOrder('o4', { status: 'quote', total: 999, createdAt: '2026-10-05T10:00:00.000Z' });
    seedOrder('o5', { status: 'canceled', total: 999, createdAt: '2026-10-06T10:00:00.000Z' });
  });

  test('gastou = concluídas; falta receber = fora de orçamento, cancelada e paga', async () => {
    const res = await call('admin', 'get', `${CU}/ana`);
    expect(res.status).toBe(200);
    expect(res.body.data.customer).toMatchObject({ id: 'ana', name: 'Ana Souza', phone: '(48) 98408-7801' });
    expect(res.body.data.spent).toBe(350);
    expect(res.body.data.owed).toBe(280);
    expect(res.body.data.orders.map((o: any) => o.id)).toEqual(['o5', 'o4', 'o3', 'o2', 'o1']);
    expect(res.body.data.receivable.sort()).toEqual(['o1', 'o3']);
    expect(res.body.data.devices).toEqual([
      { id: 'gol', name: 'Gol', serial: null, count: 1 },
      { id: 'uno', name: 'Uno', serial: 'ABC1D23', count: 4 },
    ]);
  });

  test('sem viewPrices não sai nenhum valor', async () => {
    const res = await call('technician', 'get', `${CU}/ana`);
    expect(res.status).toBe(200);
    expect(res.body.data.spent).toBeNull();
    expect(res.body.data.owed).toBeNull();
    expect(res.body.data.receivable).toEqual([]);
    expect(JSON.stringify(res.body.data.orders)).not.toMatch(/total|paidAmount/);
  });

  test('consultor vê só as OS que criou, recebe só nelas, e sabe que é parcial', async () => {
    const res = await call('consultant', 'get', `${CU}/ana`);
    expect(res.body.data.orders.map((o: any) => o.id)).toEqual(['o2']);
    expect(res.body.data.spent).toBe(50);
    expect(res.body.data.partial).toBe(true);
  });

  test('cliente de outra empresa ou apagado: 404', async () => {
    expect((await call('admin', 'get', `${CU}/zed`)).status).toBe(404);
    expect((await call('admin', 'get', `${CU}/nope`)).status).toBe(404);
  });

  test('traz e-mail, CPF/CNPJ, endereço e campos do segmento', async () => {
    const res = await call('technician', 'get', `${CU}/bia`);
    expect(res.body.data.customer).toMatchObject({ taxId: '52998224725', customData: { birth: '1990-01-01' } });
  });
});

describe('POST e PATCH /customers', () => {
  test('cria com CPF normalizado e campos do segmento', async () => {
    const res = await call('consultant', 'post', CU, { name: 'Carla', phone: '(48) 99999-0000', taxId: '529.982.247-25', email: 'c@x.com', address: 'Rua 1', customData: { birth: '2000-01-01' } });
    expect(res.status).toBe(201);
    const saved = read(`companies/c1/customers/${res.body.data.id}`) as any;
    expect(saved).toMatchObject({ name: 'Carla', taxId: '52998224725', customData: { birth: '2000-01-01' }, company: { id: 'c1' } });
    expect(saved.createdBy.id).toBe('cons1');
  });

  test('CPF/CNPJ inválido: 400 e nada gravado', async () => {
    const before = list('companies/c1/customers').length;
    const res = await call('admin', 'post', CU, { name: 'Carla', taxId: '111.111.111-11' });
    expect(res.status).toBe(400);
    expect(list('companies/c1/customers')).toHaveLength(before);
  });

  test('editar não mexe em createdAt/createdBy e null limpa o campo', async () => {
    seed('companies/c1/customers/ed', { name: 'Ed', phone: '1', email: 'e@x', createdAt: T0, createdBy: { id: 'owner1' } });
    const res = await call('supervisor', 'patch', `${CU}/ed`, { name: 'Edu', email: null, taxId: '11.222.333/0001-81' });
    expect(res.status).toBe(200);
    const saved = read('companies/c1/customers/ed') as any;
    expect(saved).toMatchObject({ name: 'Edu', email: null, taxId: '11222333000181', createdAt: T0, createdBy: { id: 'owner1' } });
    expect(saved.updatedBy.id).toBe('sup1');
  });

  test('gerente e técnico não cadastram nem editam', async () => {
    expect((await call('manager', 'post', CU, { name: 'X' })).status).toBe(403);
    expect((await call('technician', 'patch', `${CU}/ana`, { name: 'X' })).status).toBe(403);
  });
});

describe('DELETE /customers/:id', () => {
  test('apaga e tira o id do cliente da próxima manutenção dos aparelhos', async () => {
    seed('companies/c1/devices/gol', { name: 'Gol', nextMaintenanceDate: '2027-01-10', nextMaintenanceCustomer: { id: 'ana', name: 'Ana Souza' } });
    const res = await call('consultant', 'delete', `${CU}/ana`);
    expect(res.status).toBe(200);
    expect(read('companies/c1/customers/ana')).toBeUndefined();
    expect((read('companies/c1/devices/gol') as any).nextMaintenanceCustomer).toEqual({ name: 'Ana Souza' });
  });

  test('só quem cadastra; outra empresa ou inexistente dá 404', async () => {
    expect((await call('technician', 'delete', `${CU}/ana`)).status).toBe(403);
    expect((await call('manager', 'delete', `${CU}/ana`)).status).toBe(403);
    expect((await call('admin', 'delete', `${CU}/zed`)).status).toBe(404);
  });
});

describe('POST /customers/import', () => {
  const importId = 'a1b2c3d4-0000-4000-8000-000000000001';
  test('cria todos e repetir não duplica', async () => {
    const body = { importId, customers: [{ name: 'Rita', phone: '(47) 90000-1101' }, { name: 'Paulo', email: 'p@x.com', taxId: '52998224725' }] };
    const first = await call('admin', 'post', `${CU}/import`, body);
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ created: 2, existing: 0 });
    const again = await call('admin', 'post', `${CU}/import`, body);
    expect(again.body.data).toMatchObject({ created: 0, existing: 2 });
    expect(list('companies/c1/customers').filter((d) => (d.data as any).name === 'Rita')).toHaveLength(1);
  });

  test('linha sem nome ou CPF inválido recusa tudo; acima de 500 também', async () => {
    expect((await call('admin', 'post', `${CU}/import`, { importId, customers: [{ name: '' }] })).status).toBe(400);
    expect((await call('admin', 'post', `${CU}/import`, { importId, customers: [{ name: 'A', taxId: '123' }] })).status).toBe(400);
    const many = Array.from({ length: 501 }, (_, i) => ({ name: `C${i}` }));
    expect((await call('admin', 'post', `${CU}/import`, { importId, customers: many })).status).toBe(400);
  });

  test('só quem cadastra cliente', async () => {
    expect((await call('manager', 'post', `${CU}/import`, { importId, customers: [{ name: 'A' }] })).status).toBe(403);
  });
});

// ─── Aparelhos ──────────────────────────────────────────────────────────────
describe('GET /devices', () => {
  test('lista com situação e próxima manutenção', async () => {
    const res = await call('technician', 'get', DE);
    expect(res.status).toBe(200);
    expect(res.body.data.find((d: any) => d.id === 'uno')).toMatchObject({ name: 'Uno', serial: 'ABC1D23', manufacturer: 'Fiat', status: 'active' });
    expect(res.body.data.find((d: any) => d.id === 'gol')).toMatchObject({ nextMaintenanceDate: '2027-01-10' });
  });
});

describe('GET /devices/:id', () => {
  beforeEach(() => {
    seedOrder('o1', { status: 'done', createdAt: '2026-10-02T10:00:00.000Z', customer: { id: 'bia', name: 'Bia' } });
    seedOrder('o2', { status: 'approved', createdAt: '2026-10-05T10:00:00.000Z', customer: { id: 'ana', name: 'Ana' }, createdBy: { id: 'cons1', name: 'Caio' } });
    // Legacy order: single `device`, no deviceIds.
    seed('companies/c1/orders/old', { number: 9, status: 'done', customer: { id: 'bia', name: 'Bia' }, device: { id: 'uno', name: 'Uno' }, createdAt: '2025-01-01T10:00:00.000Z', createdBy: { id: 'someone' }, total: 10 });
  });

  test('dono = cliente da OS mais recente; OS do aparelho, também as antigas', async () => {
    const res = await call('admin', 'get', `${DE}/uno`);
    expect(res.status).toBe(200);
    expect(res.body.data.owner).toEqual({ id: 'ana', name: 'Ana' });
    expect(res.body.data.orders.map((o: any) => o.id)).toEqual(['o2', 'o1', 'old']);
    expect(res.body.data.lastService).toBe('Troca de óleo');
  });

  test('consultor abre o aparelho com as OS que criou (no app a tela dá erro)', async () => {
    const res = await call('consultant', 'get', `${DE}/uno`);
    expect(res.status).toBe(200);
    expect(res.body.data.orders.map((o: any) => o.id)).toEqual(['o2']);
    expect(res.body.data.partial).toBe(true);
  });

  test('técnico sem valores', async () => {
    const res = await call('technician', 'get', `${DE}/uno`);
    expect(res.status).toBe(200);
    expect(JSON.stringify(res.body.data.orders)).not.toMatch(/total/);
  });

  test('inexistente: 404', async () => {
    expect((await call('admin', 'get', `${DE}/nope`)).status).toBe(404);
  });
});

describe('POST e PATCH /devices', () => {
  test('série vira maiúscula; sem modelo a série é exigida', async () => {
    const res = await call('supervisor', 'post', DE, { serial: ' abc1d23 ' });
    expect(res.status).toBe(201);
    expect(read(`companies/c1/devices/${res.body.data.id}`)).toMatchObject({ serial: 'ABC1D23', name: null });
    expect((await call('supervisor', 'post', DE, { manufacturer: 'Fiat' })).status).toBe(400);
  });

  test('situação, campos do segmento e null que limpa', async () => {
    const res = await call('admin', 'patch', `${DE}/uno`, { status: 'maintenance', customData: { mileage: 98000 }, manufacturer: null });
    expect(res.status).toBe(200);
    expect(read('companies/c1/devices/uno')).toMatchObject({ status: 'maintenance', customData: { mileage: 98000 }, manufacturer: null });
    expect((await call('admin', 'patch', `${DE}/uno`, { status: 'broken' })).status).toBe(400);
  });

  test('editar não apaga a próxima manutenção', async () => {
    await call('admin', 'patch', `${DE}/gol`, { name: 'Gol G5' });
    expect(read('companies/c1/devices/gol')).toMatchObject({ name: 'Gol G5', nextMaintenanceDate: '2027-01-10' });
  });

  test('consultor, gerente e técnico não cadastram aparelho', async () => {
    for (const role of ['consultant', 'manager', 'technician'] as Role[]) {
      expect((await call(role, 'post', DE, { name: 'X' })).status).toBe(403);
    }
  });
});

describe('DELETE /devices/:id', () => {
  test('apaga; só quem edita aparelhos', async () => {
    expect((await call('consultant', 'delete', `${DE}/uno`)).status).toBe(403);
    expect((await call('supervisor', 'delete', `${DE}/uno`)).status).toBe(200);
    expect(read('companies/c1/devices/uno')).toBeUndefined();
    expect((await call('admin', 'delete', `${DE}/uno`)).status).toBe(404);
  });
});

describe('PUT /devices/:id/next-maintenance', () => {
  beforeEach(() => {
    seedOrder('o1', { status: 'done', createdAt: '2026-10-02T10:00:00.000Z', customer: { id: 'ana', name: 'Ana' }, deviceIds: ['gol'], devices: [{ id: 'gol', name: 'Gol' }] });
  });

  test('grava data, cliente e último serviço e apaga o aviso já dado', async () => {
    const res = await call('supervisor', 'put', `${DE}/gol/next-maintenance`, { date: '2099-05-31' });
    expect(res.status).toBe(200);
    const saved = read('companies/c1/devices/gol') as any;
    expect(saved).toMatchObject({ nextMaintenanceDate: '2099-05-31', nextMaintenanceCustomer: { id: 'ana', name: 'Ana' }, nextMaintenanceLastService: 'Troca de óleo' });
    expect(saved.nextMaintenanceNoticeFor).toBeUndefined();
  });

  test('sem dono conhecido mantém o cliente antigo', async () => {
    seed('companies/c1/devices/uno', { name: 'Uno', nextMaintenanceCustomer: { id: 'bia', name: 'Bia' } });
    await call('admin', 'put', `${DE}/uno/next-maintenance`, { date: '2099-01-01' });
    expect((read('companies/c1/devices/uno') as any).nextMaintenanceCustomer).toEqual({ id: 'bia', name: 'Bia' });
  });

  test('null tira data, cliente e serviço', async () => {
    seed('companies/c1/devices/gol', { name: 'Gol', nextMaintenanceDate: '2027-01-10', nextMaintenanceCustomer: { id: 'ana' }, nextMaintenanceLastService: 'X', nextMaintenanceNoticeFor: '2027-01-10' });
    await call('admin', 'put', `${DE}/gol/next-maintenance`, { date: null });
    const saved = read('companies/c1/devices/gol') as any;
    expect(saved.nextMaintenanceDate).toBeUndefined();
    expect(saved.nextMaintenanceCustomer).toBeUndefined();
    expect(saved.nextMaintenanceLastService).toBeUndefined();
    expect(saved.nextMaintenanceNoticeFor).toBeUndefined();
  });

  test('data no passado ou fora do formato: 400; sem permissão: 403', async () => {
    expect((await call('admin', 'put', `${DE}/gol/next-maintenance`, { date: '2020-01-01' })).status).toBe(400);
    expect((await call('admin', 'put', `${DE}/gol/next-maintenance`, { date: '31/05/2099' })).status).toBe(400);
    expect((await call('consultant', 'put', `${DE}/gol/next-maintenance`, { date: '2099-01-01' })).status).toBe(403);
    expect((await call('admin', 'put', `${DE}/nope/next-maintenance`, { date: '2099-01-01' })).status).toBe(404);
  });
});
