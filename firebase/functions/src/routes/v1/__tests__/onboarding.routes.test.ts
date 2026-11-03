/**
 * /v1/app/onboarding as the web's first access uses it (docs/WEB_API.md,
 * "Primeiro acesso"): the browser creates the company like the app, then the
 * server copies the segment's checklists and, on "Criar meu PraticOS", its
 * samples. Real bearerAuth + resolveCompanyContext over the in-memory Firestore
 * (token = uid).
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
import onboardingRoutes from '../onboarding.routes';
import { sampleOrderDueDate } from '../../../services/bootstrap-server.service';
import { seedSubspecialties } from '../../../services/onboarding-seed.service';

const PATH = '/v1/app/onboarding/seed';

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use('/v1/app/onboarding', bearerAuth, resolveCompanyContext, onboardingRoutes);
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

const q = (id: string, label: string, labelI18n?: Record<string, string>) => ({ id, label, type: 'boolean', labelI18n: labelI18n ?? null });

/** A company just created by the first access: the owner, no member map, no data. */
function seedWorld(company: Record<string, unknown> = {}) {
  resetFakeDb();
  seed('companies/new1', {
    id: 'new1', name: 'Oficina Nova', country: 'BR', segment: 'automotive', subspecialties: null,
    owner: { id: 'founder', name: 'Fábio' }, createdAt: new Date(Date.now() - 60_000).toISOString(), ...company,
  });
  seed('users/founder', { id: 'founder', name: 'Fábio', companies: [{ company: { id: 'new1', name: 'Oficina Nova' }, role: 'admin' }] });
  seed('companies/new1/private/membership', { members: { tech1: 'technician', mgr1: 'manager' } });
  seed('users/tech1', { name: 'Téc', companies: [{ company: { id: 'new1' }, role: 'technician' }] });
  seed('users/mgr1', { name: 'Ger', companies: [{ company: { id: 'new1' }, role: 'manager' }] });
  seed('segments/automotive', {
    name: 'Mecânica', active: true,
    subspecialties: [{ id: 'mechanical', name: { 'pt-BR': 'Mecânica geral' } }, { id: 'bodywork', name: { 'pt-BR': 'Funilaria' } }],
  });
  seed('segments/automotive/forms/entrada', {
    title: 'Vistoria', titleI18n: { pt: 'Vistoria de entrada', en: 'Check-in', es: 'Inspección' },
    isActive: true, subspecialties: [], items: [q('pneus', 'Pneus?', { pt: 'Pneus ok?', en: 'Tires ok?', es: '¿Neumáticos?' })],
  });
  seed('segments/automotive/forms/funilaria', { title: 'Funilaria', isActive: true, subspecialties: ['bodywork'], items: [q('a', 'Amassado?')] });
  seed('segments/automotive/forms/velho', { title: 'Desligado', isActive: false, items: [] });
  seed('segments/automotive/bootstrap/mechanical', {
    services: [{ name: { 'pt-BR': 'Troca de óleo', 'en-US': 'Oil change', 'es-ES': 'Cambio de aceite' }, value: 120 }],
    products: [{ name: { 'pt-BR': 'Filtro de óleo', 'en-US': 'Oil filter' }, value: 40 }],
    devices: [{ name: 'Gol', manufacturer: 'VW', category: { 'pt-BR': 'Carro', 'en-US': 'Car' } }],
    customer: { name: { 'pt-BR': 'Cliente (Exemplo)', 'en-US': 'Customer (Example)' }, phone: '+5511900000000' },
  });
  seed('segments/automotive/bootstrap/bodywork', {
    services: [{ name: { 'pt-BR': 'Troca de óleo' }, value: 120 }, { name: { 'pt-BR': 'Pintura' }, value: 900 }],
  });
}

function post(uid: string, body: unknown) {
  return request(server).post(PATH).set('Authorization', `Bearer ${uid}`).set('X-Company-ID', 'new1').send(body as object);
}

const names = (collection: string) => list(`companies/new1/${collection}`).map((doc) => doc.data.name).sort();

describe('POST /v1/app/onboarding/seed', () => {
  beforeEach(() => seedWorld());

  it('without samples copies only the segment checklists, translated and with the segment id', async () => {
    const res = await post('founder', { withSamples: false, locale: 'pt-BR' });
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ services: 0, products: 0, devices: 0, customers: 0, orders: 0 });
    const forms = list('companies/new1/forms');
    // No specialty picked: all of them count, so the bodywork checklist comes too.
    expect(forms.map((form) => form.id).sort()).toEqual(['entrada', 'funilaria']);
    const entrada = read('companies/new1/forms/entrada') as Record<string, any>;
    expect(entrada.title).toBe('Vistoria de entrada');
    expect(entrada.titleI18n).toBeUndefined();
    expect(entrada.items[0].label).toBe('Pneus ok?');
    expect(entrada.createdBy).toEqual({ id: 'founder', name: 'Fábio' });
    expect(names('services')).toEqual([]);
    expect(list('companies/new1/orders')).toEqual([]);
  });

  it('follows the language asked for', async () => {
    await post('founder', { withSamples: true, locale: 'en-US' });
    expect((read('companies/new1/forms/entrada') as any).title).toBe('Check-in');
    expect(names('services')).toEqual(['Oil change', 'Pintura']);
    expect(names('customers')).toEqual(['Customer (Example)']);
  });

  it('only the picked specialties', async () => {
    seedWorld({ subspecialties: ['mechanical'] });
    await post('founder', { withSamples: true, locale: 'pt-BR' });
    expect(list('companies/new1/forms').map((form) => form.id)).toEqual(['entrada']);
    expect(names('services')).toEqual(['Troca de óleo']);
  });

  it('with samples: catalog, devices, the sample customer and four orders in the coming days', async () => {
    const res = await post('founder', { withSamples: true, locale: 'pt-BR' });
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ services: 2, products: 1, devices: 1, customers: 1, orders: 4 });
    expect(names('services')).toEqual(['Pintura', 'Troca de óleo']);
    expect(names('products')).toEqual(['Filtro de óleo']);
    expect(names('devices')).toEqual(['Gol']);
    const orders = list('companies/new1/orders').map((doc) => doc.data as Record<string, any>).sort((a, b) => a.number - b.number);
    expect(orders.map((order) => order.status)).toEqual(['quote', 'approved', 'progress', 'done']);
    expect(orders.map((order) => order.number)).toEqual([1, 2, 3, 4]);
    for (const order of orders) {
      expect(order.customer.name).toBe('Cliente (Exemplo)');
      expect(order.devices[0].name).toBe('Gol');
      expect(order.dueDate).toMatch(/^\d{4}-\d{2}-\d{2}T09:00:00\.000$/);
      expect(order.company).toEqual({ id: 'new1', name: 'Oficina Nova', country: 'BR' });
      expect(order.createdBy).toEqual({ id: 'founder', name: 'Fábio' });
    }
    expect(orders[3].scheduledDate).toBeNull();
    expect(orders[0].scheduledDate).toBe(orders[0].dueDate);
    // The first one carries the first active checklist, as the app does.
    const first = list('companies/new1/orders').find((doc) => (doc.data as any).status === 'quote')!;
    expect(list(`companies/new1/orders/${first.id}/forms`).map((form) => form.data.formDefinitionId)).toEqual(['funilaria']);
  });

  it('a second call (retry or two tabs) is refused with 409 and changes nothing', async () => {
    await post('founder', { withSamples: true, locale: 'pt-BR' });
    const company = read('companies/new1') as Record<string, unknown>;
    expect(typeof company.onboardingSeededAt).toBe('string');
    const before = JSON.stringify([list('companies/new1/forms'), list('companies/new1/services'), list('companies/new1/orders'), company]);
    const res = await post('founder', { withSamples: true, locale: 'en-US' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ONBOARDING_ALREADY_SEEDED');
    expect(JSON.stringify([list('companies/new1/forms'), list('companies/new1/services'), list('companies/new1/orders'), read('companies/new1')])).toBe(before);
  });

  it('two calls at the same time: only one seeds', async () => {
    const [a, b] = await Promise.all([
      post('founder', { withSamples: true, locale: 'pt-BR' }),
      post('founder', { withSamples: true, locale: 'pt-BR' }),
    ]);
    expect([a.status, b.status].sort()).toEqual([200, 409]);
    expect(list('companies/new1/orders')).toHaveLength(4);
    expect(names('services')).toEqual(['Pintura', 'Troca de óleo']);
  });

  it('an existing company (older than a day, or without createdAt) is refused and untouched', async () => {
    for (const createdAt of ['2025-01-10T12:00:00.000', undefined]) {
      seedWorld({ createdAt });
      const res = await post('founder', { withSamples: true, locale: 'pt-BR' });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ONBOARDING_NOT_NEW');
      expect(list('companies/new1/forms')).toEqual([]);
      expect(names('services')).toEqual([]);
      expect((read('companies/new1') as Record<string, unknown>).onboardingSeededAt).toBeUndefined();
    }
  });

  it('a checklist already in the company is never written over; only the missing ones are created', async () => {
    seed('companies/new1/forms/entrada', { title: 'Minha vistoria', isActive: true, items: [] });
    await post('founder', { withSamples: false, locale: 'pt-BR' });
    expect(read('companies/new1/forms/entrada')).toEqual({ title: 'Minha vistoria', isActive: true, items: [] });
    expect(list('companies/new1/forms').map((form) => form.id).sort()).toEqual(['entrada', 'funilaria']);
  });

  it('sample orders keep the payment empty, as the app writes them', async () => {
    await post('founder', { withSamples: true, locale: 'pt-BR' });
    const orders = list('companies/new1/orders').map((doc) => doc.data as Record<string, unknown>);
    expect(orders.map((order) => order.payment)).toEqual([null, null, null, null]);
    expect(list('companies/new1/orders').map((doc) => doc.id).sort()).toEqual(['sample-order-1', 'sample-order-2', 'sample-order-3', 'sample-order-4']);
  });

  it('only who manages the company', async () => {
    expect((await post('tech1', { withSamples: true, locale: 'pt-BR' })).status).toBe(403);
    expect((await post('mgr1', { withSamples: true, locale: 'pt-BR' })).status).toBe(403);
    expect(names('services')).toEqual([]);
    expect(list('companies/new1/forms')).toEqual([]);
  });

  it('refuses a body it does not know and a company without a segment', async () => {
    expect((await post('founder', { withSamples: 'yes', locale: 'pt-BR' })).status).toBe(400);
    expect((await post('founder', { withSamples: true, locale: 'fr-FR' })).status).toBe(400);
    seedWorld({ segment: null });
    const res = await post('founder', { withSamples: true, locale: 'pt-BR' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('NO_SEGMENT');
  });
});

describe('first access rules', () => {
  it('specialties: the picked ones, else every one of the segment', () => {
    expect(seedSubspecialties(['a'], [{ id: 'a' }, { id: 'b' }])).toEqual(['a']);
    expect(seedSubspecialties(null, [{ id: 'a' }, { id: 'b' }])).toEqual(['a', 'b']);
    expect(seedSubspecialties([], undefined)).toEqual([]);
  });

  it('sample due dates: tomorrow, then every other day, at 09:00 of the company zone', () => {
    // 02:30 UTC on the 3rd is still the 2nd in São Paulo.
    const now = new Date('2026-11-03T02:30:00Z');
    expect(sampleOrderDueDate(0, now, 'BR')).toBe('2026-11-03T09:00:00.000');
    expect(sampleOrderDueDate(1, now, 'BR')).toBe('2026-11-05T09:00:00.000');
    expect(sampleOrderDueDate(3, now, 'PT')).toBe('2026-11-10T09:00:00.000');
  });
});
