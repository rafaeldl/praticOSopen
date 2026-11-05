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

import { fakeStorage, list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
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
const BUCKET = 'praticos.appspot.com';
const photoOf = (path: string) => ({
  storagePath: path,
  url: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=t`,
});

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

  test('dados para nota: grava razão social, endereço, e-mail da nota, interruptor e "Nota fiscal para"', async () => {
    seed('companies/c1/customers/rev', { name: 'Revenda', phone: '41', taxId: '11222333000181', legalName: 'REVENDA LTDA' });
    seed('companies/c1/customers/loja', { name: 'Loja Centro', createdAt: T0 });
    const res = await call('admin', 'patch', `${CU}/loja`, {
      legalName: 'LOJA CENTRO LTDA',
      fiscalAddress: { postalCode: '80010000', street: 'Rua Das Flores', number: '100', complement: null, district: 'Centro', cityCode: '4106902', cityName: 'Curitiba', state: 'pr' },
      invoiceEmail: 'fiscal@loja.com',
      autoIssueInvoice: true,
      invoiceRecipientId: 'rev',
    });
    expect(res.status).toBe(200);
    const saved = read('companies/c1/customers/loja') as any;
    expect(saved).toMatchObject({
      legalName: 'LOJA CENTRO LTDA',
      fiscalAddress: { postalCode: '80010000', cityCode: '4106902', state: 'PR' },
      invoiceEmail: 'fiscal@loja.com',
      autoIssueInvoice: true,
      invoiceRecipient: { id: 'rev', name: 'Revenda', taxId: '11222333000181' },
    });
    expect(saved.fiscalAddress).not.toHaveProperty('complement');

    const screen = await call('admin', 'get', `${CU}/loja`);
    expect(screen.body.data.customer).toMatchObject({
      legalName: 'LOJA CENTRO LTDA',
      invoiceEmail: 'fiscal@loja.com',
      autoIssueInvoice: true,
      invoiceRecipient: { id: 'rev', name: 'Revenda' },
      fiscalAddress: { cityName: 'Curitiba', complement: null },
    });
    const listed = await call('admin', 'get', CU);
    expect(listed.body.data.find((c: any) => c.id === 'rev').legalName).toBe('REVENDA LTDA');

    expect((await call('admin', 'patch', `${CU}/loja`, { invoiceRecipientId: null, fiscalAddress: null })).status).toBe(200);
    expect(read('companies/c1/customers/loja')).toMatchObject({ invoiceRecipient: null, fiscalAddress: null });
  });

  test('"Nota fiscal para" para si mesmo, inexistente ou de outra empresa: 400 e nada gravado', async () => {
    seed('companies/c1/customers/loja', { name: 'Loja', createdAt: T0 });
    for (const id of ['loja', 'nope', 'zed']) {
      const res = await call('admin', 'patch', `${CU}/loja`, { legalName: 'X', invoiceRecipientId: id });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('INVOICE_RECIPIENT_INVALID');
    }
    expect((read('companies/c1/customers/loja') as any).legalName).toBeUndefined();
  });

  test('dados para nota inválidos: 400', async () => {
    seed('companies/c1/customers/loja', { name: 'Loja', createdAt: T0 });
    for (const body of [
      { fiscalAddress: { postalCode: '8001' } },
      { fiscalAddress: { state: 'Paraná' } },
      { fiscalAddress: { other: 'x' } },
      { invoiceEmail: 'sem-arroba' },
      { autoIssueInvoice: 'sim' },
    ]) {
      expect((await call('admin', 'patch', `${CU}/loja`, body)).status).toBe(400);
    }
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

describe('foto do aparelho (device.form.photo)', () => {
  test('aceita só arquivo da pasta do próprio aparelho no bucket do projeto', async () => {
    const good = photoOf('tenants/c1/devices/uno/photo.jpg');
    expect((await call('supervisor', 'patch', `${DE}/uno`, { photo: good })).status).toBe(200);
    expect((read('companies/c1/devices/uno') as any).photo).toBe(good.url);
    for (const bad of [
      photoOf('tenants/c1/devices/gol/photo.jpg'),
      photoOf('tenants/c2/devices/uno/photo.jpg'),
      photoOf('tenants/c1/services/uno/photo.jpg'),
      photoOf('tenants/c1/devices/uno/../../x.jpg'),
      { storagePath: 'tenants/c1/devices/uno/photo.jpg', url: 'https://example.test/tenants/c1/devices/uno/photo.jpg' },
      { storagePath: 'tenants/c1/devices/uno/photo.jpg', url: `https://firebasestorage.googleapis.com/v0/b/outro.appspot.com/o/tenants%2Fc1%2Fdevices%2Funo%2Fphoto.jpg` },
      { storagePath: 'tenants/c1/devices/uno/photo.jpg', url: `http://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/tenants%2Fc1%2Fdevices%2Funo%2Fphoto.jpg` },
    ]) {
      expect((await call('admin', 'patch', `${DE}/uno`, { photo: bad })).status).toBe(400);
    }
    expect((read('companies/c1/devices/uno') as any).photo).toBe(good.url);
  });

  test('só troca: sem remover a foto (como o app)', async () => {
    expect((await call('admin', 'patch', `${DE}/uno`, { photo: null })).status).toBe(400);
  });

  test('trocar apaga o arquivo antigo da pasta, nunca o de fora ou o novo', async () => {
    seed('companies/c1/devices/uno', { name: 'Uno', photo: photoOf('tenants/c1/devices/uno/old.jpg').url });
    const res = await call('owner', 'patch', `${DE}/uno`, { photo: photoOf('tenants/c1/devices/uno/photo.jpg') });
    expect(res.status).toBe(200);
    expect(fakeStorage.deleted).toEqual(['tenants/c1/devices/uno/old.jpg']);
    fakeStorage.reset();
    // Same file again (photo.jpg overwritten): nothing deleted.
    await call('owner', 'patch', `${DE}/uno`, { photo: photoOf('tenants/c1/devices/uno/photo.jpg') });
    seed('companies/c1/devices/gol', { name: 'Gol', photo: 'https://example.test/foto.jpg' });
    await call('owner', 'patch', `${DE}/gol`, { photo: photoOf('tenants/c1/devices/gol/photo.jpg') });
    expect(fakeStorage.deleted).toEqual([]);
  });

  test('consultor, gerente e técnico não põem foto; outra empresa não acha o aparelho', async () => {
    const good = photoOf('tenants/c1/devices/uno/photo.jpg');
    for (const role of ['consultant', 'manager', 'technician'] as Role[]) {
      expect((await call(role, 'patch', `${DE}/uno`, { photo: good })).status).toBe(403);
    }
    expect((await call('other2', 'patch', `${DE}/uno`, { photo: photoOf('tenants/c2/devices/uno/photo.jpg') }, 'c2')).status).toBe(404);
    expect((read('companies/c1/devices/uno') as any).photo).toBeUndefined();
  });

  test('a foto aparece na lista e na tela do aparelho', async () => {
    const good = photoOf('tenants/c1/devices/uno/photo.jpg');
    await call('admin', 'patch', `${DE}/uno`, { photo: good });
    expect((await call('consultant', 'get', DE)).body.data.find((d: any) => d.id === 'uno').photo).toBe(good.url);
    expect((await call('consultant', 'get', `${DE}/uno`)).body.data.device.photo).toBe(good.url);
  });
});

// ─── Revisão do #517 ────────────────────────────────────────────────────────
describe('versão opaca no cliente e no aparelho (M1)', () => {
  test('GET devolve a versão; PATCH com a versão antiga dá 409 e não grava', async () => {
    seed('companies/c1/customers/ed', { name: 'Ed', updatedAt: '2026-10-01T10:00:00.000000' });
    const read1 = await call('admin', 'get', `${CU}/ed`);
    expect(read1.body.data.version).toBe('2026-10-01T10:00:00.000000');
    seed('companies/c1/customers/ed', { name: 'Ed no app', updatedAt: '2026-10-02T09:00:00.000000' });
    const stale = await call('admin', 'patch', `${CU}/ed`, { name: 'Edu', version: read1.body.data.version });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('CUSTOMER_CHANGED');
    expect((read('companies/c1/customers/ed') as any).name).toBe('Ed no app');
    const fresh = await call('admin', 'patch', `${CU}/ed`, { name: 'Edu', version: '2026-10-02T09:00:00.000000' });
    expect(fresh.status).toBe(200);
    expect(fresh.body.data.version).toEqual(expect.any(String));
  });

  test('aparelho: mesma regra', async () => {
    seed('companies/c1/devices/uno', { name: 'Uno', updatedAt: '2026-10-02T09:00:00.000Z' });
    expect((await call('admin', 'get', `${DE}/uno`)).body.data.version).toBe('2026-10-02T09:00:00.000Z');
    const stale = await call('admin', 'patch', `${DE}/uno`, { name: 'Uno 2', version: '2026-10-01T09:00:00.000Z' });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('DEVICE_CHANGED');
    expect((await call('admin', 'patch', `${DE}/uno`, { name: 'Uno 2', version: '2026-10-02T09:00:00.000Z' })).status).toBe(200);
  });
});

describe('o que o cliente tem antes de apagar (M2)', () => {
  test('conta todas as OS, recibos e cobranças, também as que o papel não vê', async () => {
    seedOrder('o1', { createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('o2', { createdBy: { id: 'someone', name: 'X' } });
    seed('companies/c1/receipts/r1', { customer: { id: 'ana', name: 'Ana' }, status: 'active' });
    seed('companies/c1/customerCharges/k1', { customer: { id: 'ana', name: 'Ana' } });
    seed('companies/c1/receipts/r2', { customer: { id: 'bia', name: 'Bia' }, status: 'active' });
    const res = await call('consultant', 'get', `${CU}/ana`);
    expect(res.body.data.orders.map((o: any) => o.id)).toEqual(['o1']);
    expect(res.body.data.links).toEqual({ orders: 2, receipts: 1, charges: 1 });
  });
});

describe('cliente com muitas OS (B2)', () => {
  test('as 500 mais recentes, em ordem, com aviso de que cortou', async () => {
    for (let i = 0; i < 501; i++) seedOrder(`m${String(i).padStart(3, '0')}`, { createdAt: new Date(Date.UTC(2026, 0, 1) + i * 60000).toISOString() });
    const res = await call('admin', 'get', `${CU}/ana`);
    expect(res.body.data.orders).toHaveLength(500);
    expect(res.body.data.orders[0].id).toBe('m500');
    expect(res.body.data.ordersTruncated).toBe(true);
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

  test('com orderId, cliente e serviço principal vêm dessa OS (o do veículo, ou o sem veículo), e grava updatedAt/updatedBy', async () => {
    seedOrder('o2', {
      status: 'done', createdAt: '2026-09-01T10:00:00.000Z', customer: { id: 'caio', name: 'Caio', phone: '1' }, deviceIds: ['gol', 'uno'],
      devices: [{ id: 'gol', name: 'Gol' }, { id: 'uno', name: 'Uno' }],
      services: [{ service: { id: 's9', name: 'Freio do Uno' }, deviceId: 'uno' }, { service: { id: 's8', name: 'Revisão geral' } }],
    });
    const res = await call('admin', 'put', `${DE}/gol/next-maintenance`, { date: '2099-05-31', orderId: 'o2' });
    expect(res.status).toBe(200);
    const saved = read('companies/c1/devices/gol') as any;
    expect(saved).toMatchObject({ nextMaintenanceCustomer: { id: 'caio', name: 'Caio' }, nextMaintenanceLastService: 'Revisão geral' });
    expect(typeof saved.updatedAt).toBe('string');
    expect(saved.updatedBy).toMatchObject({ id: expect.any(String) });
  });

  test('orderId de OS que não tem o veículo é recusado', async () => {
    seedOrder('o3', { status: 'done', customer: { id: 'caio', name: 'Caio' }, deviceIds: ['uno'], devices: [{ id: 'uno', name: 'Uno' }] });
    const res = await call('admin', 'put', `${DE}/gol/next-maintenance`, { date: '2099-05-31', orderId: 'o3' });
    expect(res.status).toBe(400);
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
