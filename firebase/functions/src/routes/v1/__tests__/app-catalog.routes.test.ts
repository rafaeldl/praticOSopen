/**
 * /v1/app/services and /v1/app/products as the web app uses them (docs/WEB_API.md,
 * "Catálogo"). Real bearerAuth + resolveCompanyContext over the in-memory
 * Firestore (token = uid): role and company come from server data.
 *
 * The rule that matters most: without `viewPrices` no price leaves the server,
 * and writing a price needs `editPrices` on top of manageServices/manageProducts.
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
import { catalogRoutes } from '../app-catalog.routes';

type Role = 'owner' | 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician';
const UID: Record<Role, string> = {
  owner: 'owner1', admin: 'admin1', manager: 'mgr1', supervisor: 'sup1', consultant: 'cons1', technician: 'tech1',
};
const SV = '/v1/app/services';
const PR = '/v1/app/products';
const T0 = '2026-10-01T10:00:00.000Z';
const BUCKET = 'praticos.appspot.com';
const photoOf = (path: string) => ({
  storagePath: path,
  url: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=t`,
});

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use(SV, bearerAuth, resolveCompanyContext, catalogRoutes('service'));
  app.use(PR, bearerAuth, resolveCompanyContext, catalogRoutes('product'));
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
    services: [],
    products: [],
    total: 0,
    createdBy: { id: 'someone', name: 'Alguém' },
    createdAt: T0,
    updatedAt: T0,
    ...data,
  });
}

function call(role: Role | 'other2', method: 'get' | 'post' | 'patch' | 'delete', path: string, body?: object, company = 'c1') {
  const uid = role === 'other2' ? 'other2' : UID[role];
  const req = request(server)[method](path).set('Authorization', `Bearer ${uid}`).set('X-Company-ID', company);
  return body ? req.send(body) : req;
}

beforeEach(() => {
  resetFakeDb();
  fakeStorage.reset();
  seedCompanies();
  seed('companies/c1/services/s1', { name: 'Troca de óleo', value: 120, photo: null, updatedAt: '2026-10-02T09:00:00.000Z', createdAt: T0, createdBy: { id: 'owner1', name: 'Rafael' } });
  seed('companies/c1/services/s2', { name: 'alinhamento', value: null });
  seed('companies/c1/products/p1', { name: 'Filtro de óleo', value: 35.5, customData: { brand: 'Tecfil' } });
  seed('companies/c2/services/z1', { name: 'De outra empresa', value: 999 });
});

// ─── Leitura ────────────────────────────────────────────────────────────────
describe('GET (lista)', () => {
  test('quem vê valores recebe nome, preço, foto, campos do ramo e versão; sem os de outra empresa', async () => {
    const res = await call('consultant', 'get', SV);
    expect(res.status).toBe(200);
    expect(res.body.data.map((i: any) => i.id).sort()).toEqual(['s1', 's2']);
    expect(res.body.data.find((i: any) => i.id === 's1')).toMatchObject({ name: 'Troca de óleo', value: 120, photo: null, version: '2026-10-02T09:00:00.000Z' });
    expect(res.body.data.find((i: any) => i.id === 's2').value).toBeNull();
    expect(res.body.meta).toMatchObject({ total: 2, prices: true });
    const products = await call('admin', 'get', PR);
    expect(products.body.data[0]).toMatchObject({ id: 'p1', value: 35.5, customData: { brand: 'Tecfil' } });
  });

  test('sem viewPrices (supervisor) nenhum preço sai, nem como null', async () => {
    const res = await call('supervisor', 'get', SV);
    expect(res.status).toBe(200);
    expect(res.body.meta.prices).toBe(false);
    for (const item of res.body.data) expect(item).not.toHaveProperty('value');
    expect(JSON.stringify(res.body)).not.toContain('120');
  });

  test('"Valores e cobrança" desligado: nem o dono recebe preço', async () => {
    seedCompanies({ useFinancial: false });
    const res = await call('owner', 'get', SV);
    expect(res.body.meta.prices).toBe(false);
    expect(res.body.data.find((i: any) => i.id === 's1')).not.toHaveProperty('value');
  });

  test('técnico não lê o catálogo (sem viewServices e viewProducts)', async () => {
    expect((await call('technician', 'get', SV)).status).toBe(403);
    expect((await call('technician', 'get', PR)).status).toBe(403);
    expect((await call('technician', 'get', `${SV}/s1`)).status).toBe(403);
  });

  test('GET /:id segue a mesma projeção; outra empresa ou inexistente: 404', async () => {
    const admin = await call('admin', 'get', `${SV}/s1`);
    expect(admin.body.data).toMatchObject({ id: 's1', value: 120, version: '2026-10-02T09:00:00.000Z' });
    const supervisor = await call('supervisor', 'get', `${SV}/s1`);
    expect(supervisor.body.data).not.toHaveProperty('value');
    expect((await call('admin', 'get', `${SV}/z1`)).status).toBe(404);
    expect((await call('admin', 'get', `${SV}/nope`)).status).toBe(404);
  });
});

describe('mais usados (catalog.list.most-used)', () => {
  test('top por tipo nas últimas 50 OS, empate pelo uso mais recente; consultor conta só as que criou', async () => {
    seed('companies/c1/services/s3', { name: 'Revisão', value: 300 });
    seedOrder('o1', { services: [{ service: { id: 's2' } }, { service: { id: 's1' } }], products: [{ product: { id: 'p1' } }], createdBy: { id: 'cons1', name: 'Caio' } });
    seedOrder('o2', { services: [{ service: { id: 's2' } }], createdAt: '2026-10-02T10:00:00.000Z' });
    seedOrder('o3', { services: [{ service: { id: 's3' } }, { service: { id: 's3' } }], createdAt: '2026-10-03T10:00:00.000Z' });
    const admin = await call('admin', 'get', SV);
    expect(admin.body.meta.mostUsed).toEqual(['s3', 's2', 's1']);
    // Products never mix with services (the app adds both kinds before filtering).
    expect((await call('admin', 'get', PR)).body.meta.mostUsed).toEqual(['p1']);
    const consultant = await call('consultant', 'get', SV);
    expect(consultant.body.meta.mostUsed).toEqual(['s2', 's1']);
  });

  test('item apagado do catálogo não entra na lista', async () => {
    seedOrder('o1', { services: [{ service: { id: 'gone' } }, { service: { id: 's1' } }] });
    expect((await call('admin', 'get', SV)).body.meta.mostUsed).toEqual(['s1']);
  });
});

// ─── Escrita ────────────────────────────────────────────────────────────────
describe('POST', () => {
  test('cria com nome sem espaços nas pontas, preço, auditoria e empresa da sessão', async () => {
    const res = await call('admin', 'post', SV, { name: '  Lavagem  ', value: 80, customData: { warranty: '90 dias' } });
    expect(res.status).toBe(201);
    const saved = read(`companies/c1/services/${res.body.data.id}`) as any;
    expect(saved).toMatchObject({ name: 'Lavagem', nameLower: 'lavagem', value: 80, photo: null, customData: { warranty: '90 dias' }, company: { id: 'c1' }, createdBy: { id: 'admin1' } });
    expect(saved.keywords).toEqual(expect.arrayContaining(['lavagem']));
    expect(res.body.data.version).toBe(saved.updatedAt);
  });

  test('sem preço grava null; preço com mais de 2 casas arredonda ao centavo (nunca 100 vezes menor)', async () => {
    const empty = await call('admin', 'post', PR, { name: 'Junta' });
    expect((read(`companies/c1/products/${empty.body.data.id}`) as any).value).toBeNull();
    const priced = await call('admin', 'post', PR, { name: 'Vela', value: 150 });
    expect((read(`companies/c1/products/${priced.body.data.id}`) as any).value).toBe(150);
    const cents = await call('admin', 'post', PR, { name: 'Arruela', value: 1.005 });
    expect((read(`companies/c1/products/${cents.body.data.id}`) as any).value).toBe(1.01);
  });

  test('nome vazio, preço negativo ou texto: 400 e nada gravado', async () => {
    expect((await call('admin', 'post', SV, { name: '   ' })).status).toBe(400);
    expect((await call('admin', 'post', SV, { name: 'X', value: -1 })).status).toBe(400);
    expect((await call('admin', 'post', SV, { name: 'X', value: '80' })).status).toBe(400);
    expect(list('companies/c1/services')).toHaveLength(2);
  });

  test('só quem tem manageServices/manageProducts cadastra (gerente, supervisor e consultor não)', async () => {
    for (const role of ['manager', 'supervisor', 'consultant', 'technician'] as const) {
      expect((await call(role, 'post', SV, { name: 'X' })).status).toBe(403);
      expect((await call(role, 'post', PR, { name: 'X' })).status).toBe(403);
    }
    expect((await call('owner', 'post', SV, { name: 'X' })).status).toBe(201);
  });

  test('preço exige editPrices: com "Valores e cobrança" desligado o admin cadastra só sem preço', async () => {
    seedCompanies({ useFinancial: false });
    const priced = await call('admin', 'post', SV, { name: 'Com preço', value: 10 });
    expect(priced.status).toBe(403);
    expect(list('companies/c1/services')).toHaveLength(2);
    expect((await call('admin', 'post', SV, { name: 'Sem preço' })).status).toBe(201);
    // `value: null` is still a price write.
    expect((await call('admin', 'post', SV, { name: 'Nulo', value: null })).status).toBe(403);
  });
});

describe('PATCH', () => {
  test('edita nome e preço sem mexer em createdAt/createdBy', async () => {
    const res = await call('admin', 'patch', `${SV}/s1`, { name: 'Troca de óleo e filtro', value: 150 });
    expect(res.status).toBe(200);
    const saved = read('companies/c1/services/s1') as any;
    expect(saved).toMatchObject({ name: 'Troca de óleo e filtro', value: 150, createdAt: T0, createdBy: { id: 'owner1' }, updatedBy: { id: 'admin1' } });
    expect(res.body.data.version).toBe(saved.updatedAt);
  });

  test('sem editPrices: editar o nome mantém o preço guardado; mandar preço dá 403', async () => {
    seedCompanies({ useFinancial: false });
    expect((await call('admin', 'patch', `${SV}/s1`, { name: 'Novo nome' })).status).toBe(200);
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
    expect((await call('admin', 'patch', `${SV}/s1`, { value: 1 })).status).toBe(403);
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
  });

  test('versão antiga: 409 CATALOG_ITEM_CHANGED e nada gravado', async () => {
    const stale = await call('admin', 'patch', `${SV}/s1`, { value: 1, version: '2026-10-01T09:00:00.000Z' });
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('CATALOG_ITEM_CHANGED');
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
    expect((await call('admin', 'patch', `${SV}/s1`, { value: 1, version: '2026-10-02T09:00:00.000Z' })).status).toBe(200);
  });

  test('customData vazio vira null; nome vazio dá 400', async () => {
    await call('admin', 'patch', `${PR}/p1`, { customData: {} });
    expect((read('companies/c1/products/p1') as any).customData).toBeNull();
    expect((await call('admin', 'patch', `${PR}/p1`, { name: '' })).status).toBe(400);
  });

  test('foto: só arquivo da pasta do próprio item no bucket do projeto', async () => {
    const good = photoOf('tenants/c1/services/s1/photo.jpg');
    expect((await call('admin', 'patch', `${SV}/s1`, { photo: good })).status).toBe(200);
    expect((read('companies/c1/services/s1') as any).photo).toBe(good.url);
    for (const bad of [
      photoOf('tenants/c1/services/s2/photo.jpg'),
      photoOf('tenants/c2/services/s1/photo.jpg'),
      photoOf('tenants/c1/services/s1/../../x.jpg'),
      { storagePath: 'tenants/c1/services/s1/photo.jpg', url: 'https://example.test/tenants/c1/services/s1/photo.jpg' },
      { storagePath: 'tenants/c1/services/s1/photo.jpg', url: `http://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/tenants%2Fc1%2Fservices%2Fs1%2Fphoto.jpg` },
    ]) {
      const res = await call('admin', 'patch', `${SV}/s1`, { photo: bad });
      expect(res.status).toBe(400);
    }
    expect((read('companies/c1/services/s1') as any).photo).toBe(good.url);
  });

  test('inexistente ou de outra empresa: 404; sem permissão: 403', async () => {
    expect((await call('admin', 'patch', `${SV}/z1`, { name: 'X' })).status).toBe(404);
    expect((await call('manager', 'patch', `${SV}/s1`, { name: 'X' })).status).toBe(403);
  });
});

describe('DELETE', () => {
  test('apaga o item e a foto; as OS ficam com a cópia', async () => {
    seedOrder('o1', { services: [{ service: { id: 's1', name: 'Troca de óleo' }, value: 120 }] });
    expect((await call('admin', 'delete', `${SV}/s1`)).status).toBe(200);
    expect(read('companies/c1/services/s1')).toBeUndefined();
    expect(fakeStorage.deletedPrefixes).toContain('tenants/c1/services/s1/');
    expect((read('companies/c1/orders/o1') as any).services[0].service.name).toBe('Troca de óleo');
    expect((await call('admin', 'delete', `${SV}/s1`)).status).toBe(404);
  });

  test('só admin', async () => {
    for (const role of ['manager', 'supervisor', 'consultant', 'technician'] as const) {
      expect((await call(role, 'delete', `${PR}/p1`)).status).toBe(403);
    }
  });
});

// ─── Extras de mesa ─────────────────────────────────────────────────────────
describe('POST /import', () => {
  const items = [{ name: 'Polimento', value: 200 }, { name: 'Cristalização' }];

  test('cria todos e repetir com o mesmo importId não duplica', async () => {
    const first = await call('admin', 'post', `${SV}/import`, { importId: 'imp-12345678', items });
    expect(first.body.data).toEqual({ created: 2, existing: 0 });
    expect(read('companies/c1/services/imp-12345678-0')).toMatchObject({ name: 'Polimento', value: 200, createdBy: { id: 'admin1' } });
    expect((read('companies/c1/services/imp-12345678-1') as any).value).toBeNull();
    const again = await call('admin', 'post', `${SV}/import`, { importId: 'imp-12345678', items });
    expect(again.body.data).toEqual({ created: 0, existing: 2 });
    expect(list('companies/c1/services')).toHaveLength(4);
  });

  test('preço na planilha exige editPrices; sem preço o admin importa mesmo com valores desligados', async () => {
    seedCompanies({ useFinancial: false });
    expect((await call('admin', 'post', `${PR}/import`, { importId: 'imp-22222222', items })).status).toBe(403);
    expect((await call('admin', 'post', `${PR}/import`, { importId: 'imp-22222222', items: [{ name: 'Sem preço' }] })).status).toBe(200);
  });

  test('linha inválida recusa tudo; acima de 500 também; só admin', async () => {
    expect((await call('admin', 'post', `${SV}/import`, { importId: 'imp-33333333', items: [{ name: 'Ok' }, { name: '' }] })).status).toBe(400);
    const many = Array.from({ length: 501 }, (_, i) => ({ name: `N${i}` }));
    expect((await call('admin', 'post', `${SV}/import`, { importId: 'imp-33333333', items: many })).status).toBe(400);
    expect(list('companies/c1/services')).toHaveLength(2);
    expect((await call('consultant', 'post', `${SV}/import`, { importId: 'imp-33333333', items: [{ name: 'X' }] })).status).toBe(403);
  });
});

describe('POST /prices (preços em lote)', () => {
  test('aplica o novo preço onde o atual é o que a pessoa viu', async () => {
    seed('companies/c1/services/s3', { name: 'Revisão', value: 300 });
    const res = await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 132 }, { id: 's3', from: 300, to: 330 }] });
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ updated: 2, unchanged: 0 });
    expect(read('companies/c1/services/s1')).toMatchObject({ value: 132, createdAt: T0, updatedBy: { id: 'admin1' } });
    expect((read('companies/c1/services/s3') as any).value).toBe(330);
  });

  test('repetir depois de a resposta se perder não aplica de novo (idempotente)', async () => {
    const changes = [{ id: 's1', from: 120, to: 132 }];
    await call('admin', 'post', `${SV}/prices`, { changes });
    const again = await call('admin', 'post', `${SV}/prices`, { changes });
    expect(again.status).toBe(200);
    expect(again.body.data).toEqual({ updated: 0, unchanged: 1 });
    expect((read('companies/c1/services/s1') as any).value).toBe(132);
  });

  test('alguém mudou um preço depois: 409 com os ids e nada gravado em nenhum', async () => {
    seed('companies/c1/services/s3', { name: 'Revisão', value: 310 });
    const res = await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 132 }, { id: 's3', from: 300, to: 330 }] });
    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({ code: 'CATALOG_ITEM_CHANGED', ids: ['s3'] });
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
  });

  test('item apagado entra no 409; compara em centavos (35.5 vale 35.50)', async () => {
    const gone = await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 'nope', from: 1, to: 2 }] });
    expect(gone.status).toBe(409);
    expect(gone.body.error.ids).toEqual(['nope']);
    const cents = await call('admin', 'post', `${PR}/prices`, { changes: [{ id: 'p1', from: 35.50000001, to: 39.05 }] });
    expect(cents.status).toBe(200);
    expect((read('companies/c1/products/p1') as any).value).toBe(39.05);
  });

  test('exige manage e editPrices; preço negativo, vazio ou mais de 500: 400', async () => {
    expect((await call('manager', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 1 }] })).status).toBe(403);
    expect((await call('supervisor', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 1 }] })).status).toBe(403);
    expect((await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: -1 }] })).status).toBe(400);
    expect((await call('admin', 'post', `${SV}/prices`, { changes: [] })).status).toBe(400);
    const many = Array.from({ length: 501 }, (_, i) => ({ id: `x${i}`, from: 1, to: 2 }));
    expect((await call('admin', 'post', `${SV}/prices`, { changes: many })).status).toBe(400);
    seedCompanies({ useFinancial: false });
    expect((await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 1 }] })).status).toBe(403);
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
  });
});

// ─── Revisão do PR #520 ─────────────────────────────────────────────────────
describe('revisão #520', () => {
  test('B1: /prices recusa o mesmo id duas vezes no lote', async () => {
    const res = await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 's1', from: 120, to: 132 }, { id: 's1', from: 120, to: 150 }] });
    expect(res.status).toBe(400);
    expect((read('companies/c1/services/s1') as any).value).toBe(120);
  });

  test('A1: o lote leva uma chave; repetir com a mesma chave não aplica de novo e a chave fica no item', async () => {
    const body = { batchId: 'lote-0000-1111', changes: [{ id: 's1', from: 120, to: 132 }] };
    expect((await call('admin', 'post', `${SV}/prices`, body)).body.data).toEqual({ updated: 1, unchanged: 0 });
    expect(read('companies/c1/services/s1')).toMatchObject({ value: 132, priceBatchId: 'lote-0000-1111' });
    expect((await call('admin', 'post', `${SV}/prices`, body)).body.data).toEqual({ updated: 0, unchanged: 1 });
    expect((read('companies/c1/services/s1') as any).value).toBe(132);
    expect((await call('admin', 'post', `${SV}/prices`, { batchId: 'x', changes: body.changes })).status).toBe(400);
  });

  test('B4: importId repetido com outro conteúdo dá 409 e nada é gravado; igual devolve existing', async () => {
    await call('admin', 'post', `${SV}/import`, { importId: 'imp-44444444', items: [{ name: 'Polimento', value: 200 }] });
    const other = await call('admin', 'post', `${SV}/import`, { importId: 'imp-44444444', items: [{ name: 'Polimento', value: 250 }, { name: 'Nova' }] });
    expect(other.status).toBe(409);
    expect(other.body.error.code).toBe('IMPORT_ID_CONFLICT');
    expect((read('companies/c1/services/imp-44444444-0') as any).value).toBe(200);
    expect(read('companies/c1/services/imp-44444444-1')).toBeUndefined();
    const same = await call('admin', 'post', `${SV}/import`, { importId: 'imp-44444444', items: [{ name: 'Polimento', value: 200 }] });
    expect(same.body.data).toEqual({ created: 0, existing: 1 });
  });

  test('M2: tirar a foto apaga só o arquivo do documento, não a pasta', async () => {
    const current = photoOf('tenants/c1/services/s1/photo.jpg');
    seed('companies/c1/services/s1', { name: 'Troca de óleo', value: 120, photo: current.url, updatedAt: '2026-10-02T09:00:00.000Z' });
    const res = await call('admin', 'patch', `${SV}/s1`, { photo: null, photoSeen: current.url, version: '2026-10-02T09:00:00.000Z' });
    expect(res.status).toBe(200);
    expect((read('companies/c1/services/s1') as any).photo).toBeNull();
    expect(fakeStorage.deleted).toEqual(['tenants/c1/services/s1/photo.jpg']);
    expect(fakeStorage.deletedPrefixes).toEqual([]);
  });

  test('M2: a foto mudou no app depois que a pessoa viu (sem mudar updatedAt): 409 e nada apagado', async () => {
    const fresh = photoOf('tenants/c1/services/s1/photo.jpg');
    seed('companies/c1/services/s1', { name: 'Troca de óleo', value: 120, photo: `${fresh.url}&v=2`, updatedAt: '2026-10-02T09:00:00.000Z' });
    const res = await call('admin', 'patch', `${SV}/s1`, { photo: null, photoSeen: fresh.url, version: '2026-10-02T09:00:00.000Z' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CATALOG_ITEM_CHANGED');
    expect((read('companies/c1/services/s1') as any).photo).toBe(`${fresh.url}&v=2`);
    expect(fakeStorage.deleted).toEqual([]);
  });

  test('M2: tirar a foto exige a foto vista e confere a versão', async () => {
    seed('companies/c1/services/s1', { name: 'Troca de óleo', value: 120, photo: 'https://x', updatedAt: '2026-10-02T09:00:00.000Z' });
    expect((await call('admin', 'patch', `${SV}/s1`, { photo: null })).status).toBe(400);
    const stale = await call('admin', 'patch', `${SV}/s1`, { photo: null, photoSeen: 'https://x', version: '2026-10-01T09:00:00.000Z' });
    expect(stale.status).toBe(409);
    expect((read('companies/c1/services/s1') as any).photo).toBe('https://x');
  });

  test('B5: id com barra (%2F) é recusado', async () => {
    expect((await call('admin', 'get', `${SV}/s1%2Fx%2Fy`)).status).toBe(400);
    expect((await call('admin', 'patch', `${SV}/a%2Fb`, { name: 'X' })).status).toBe(400);
    expect((await call('admin', 'post', `${SV}/prices`, { changes: [{ id: 'a/b', from: 1, to: 2 }] })).status).toBe(400);
  });
});
