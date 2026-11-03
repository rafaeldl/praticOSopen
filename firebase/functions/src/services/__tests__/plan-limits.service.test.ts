/**
 * plan-limits.service usage counting and the routes that apply it, over the
 * in-memory Firestore and a fake Storage listing. The check itself is
 * covered by the shared cases (__tests__/plan-limits.cases.test.ts).
 */
import { Server } from 'http';
import express, { NextFunction, Request, Response } from 'express';
import request from 'supertest';

const mockFiles: Array<{ name: string; metadata: { timeCreated: string } }> = [];
const mockGetFiles = jest.fn(async (_options?: unknown) => [mockFiles]);

jest.mock('../firestore.service', () => ({
  ...jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock,
  storage: { bucket: () => ({ getFiles: (options: unknown) => mockGetFiles(options) }) },
}));

jest.mock('../invite.service', () => ({
  ...jest.requireActual('../invite.service'),
  createInvite: jest.fn(async () => ({ token: 'INV_X', expiresAt: new Date('2030-01-01T00:00:00Z') })),
}));

jest.mock('../photo-upload.service', () => ({
  uploadPhotoFromBase64: jest.fn(async () => ({ id: 'ph1', url: 'https://x/ph1.jpg', storagePath: 'p', createdAt: '' })),
  uploadPhotoFromUrl: jest.fn(),
}));

jest.mock('../order.service', () => ({
  ...jest.requireActual('../order.service'),
  getOrder: jest.fn(async (_c: string, id: string) => ({ id, createdBy: { id: 'someone', name: 'X' } })),
  addPhotoToOrder: jest.fn(async () => undefined),
}));

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import {
  checkCompanyPlanLimit,
  countCollaborators,
  countFormTemplates,
  countPhotosThisMonth,
  monthStart,
} from '../plan-limits.service';
import appInviteRoutes from '../../routes/v1/invite.routes';
import formTemplatesRoutes from '../../routes/v1/form-templates.routes';
import orderPhotosRoutes from '../../routes/v1/order-photos.routes';

const NOW = new Date('2026-11-20T15:00:00.000Z');
const FREE = { name: 'Clima', subscription: { plan: 'free', status: 'active', usage: { usersActive: 0, formTemplatesActive: 0, photosThisMonth: 0 } } };

beforeEach(() => {
  resetFakeDb();
  mockFiles.length = 0;
  mockGetFiles.mockClear();
});

describe('usage counted on the server', () => {
  it('collaborators: members plus pending invites still valid, of this company only', async () => {
    seed('companies/c1/memberships/owner1', { role: 'owner' });
    seed('companies/c1/memberships/tech1', { role: 'technician' });
    seed('links/invites/tokens/A', { company: { id: 'c1' }, status: 'pending', expiresAt: '2026-11-25T00:00:00.000Z' });
    seed('links/invites/tokens/B', { company: { id: 'c1' }, status: 'pending', expiresAt: '2026-11-01T00:00:00.000Z' });
    seed('links/invites/tokens/C', { company: { id: 'c1' }, status: 'accepted', expiresAt: '2026-11-25T00:00:00.000Z' });
    seed('links/invites/tokens/D', { company: { id: 'c2' }, status: 'pending', expiresAt: '2026-11-25T00:00:00.000Z' });
    expect(await countCollaborators('c1', NOW)).toBe(3);
  });

  it('form templates: active ones in forms/, a missing isActive counts as active', async () => {
    seed('companies/c1/forms/f1', { title: 'A', isActive: true });
    seed('companies/c1/forms/f2', { title: 'B' });
    seed('companies/c1/forms/f3', { title: 'C', isActive: false });
    // The app's counter reads formTemplates/, which is not where templates live.
    seed('companies/c1/formTemplates/x', { isActive: true });
    expect(await countFormTemplates('c1')).toBe(2);
  });

  it('photos: order photos created this month (Brasília calendar), not checklist photos nor documents', async () => {
    const at = (iso: string) => ({ timeCreated: iso });
    mockFiles.push(
      { name: 'tenants/c1/orders/o1/photos/1.jpg', metadata: at('2026-11-02T10:00:00.000Z') },
      { name: 'tenants/c1/orders/o2/photos/2.jpg', metadata: at('2026-11-01T03:00:00.000Z') },
      { name: 'tenants/c1/orders/o2/photos/3.jpg', metadata: at('2026-11-01T02:59:59.000Z') }, // 31/10 23:59 BRT
      { name: 'tenants/c1/orders/o1/forms/i1/items/x/4.jpg', metadata: at('2026-11-05T10:00:00.000Z') },
      { name: 'tenants/c1/orders/o1/documents/5.pdf', metadata: at('2026-11-05T10:00:00.000Z') },
    );
    expect(await countPhotosThisMonth('c1', NOW)).toBe(2);
    expect(mockGetFiles).toHaveBeenCalledWith({ prefix: 'tenants/c1/orders/' });
  });

  it('the month starts at midnight in Brasília', () => {
    expect(monthStart(new Date('2026-11-01T02:59:00.000Z')).toISOString()).toBe('2026-10-01T03:00:00.000Z');
    expect(monthStart(NOW).toISOString()).toBe('2026-11-01T03:00:00.000Z');
  });
});

describe('checkCompanyPlanLimit', () => {
  it('off by default: everything passes and nothing is counted', async () => {
    seed('companies/c1', FREE);
    const check = await checkCompanyPlanLimit('c1', 'photo', 1, NOW);
    expect(check).toMatchObject({ allowed: true, limit: -1 });
    expect(mockGetFiles).not.toHaveBeenCalled();
  });

  it('on: ignores the counter the app wrote and counts', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', FREE); // stored usersActive: 0
    seed('companies/c1/memberships/owner1', { role: 'owner' });
    const check = await checkCompanyPlanLimit('c1', 'collaborator', 1, NOW);
    expect(check).toMatchObject({ allowed: false, limit: 1, usage: 1, plan: 'free' });
  });

  it('on, unlimited plan: allowed without counting', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', { subscription: { plan: 'business' } });
    expect(await checkCompanyPlanLimit('c1', 'photo', 3, NOW)).toMatchObject({ allowed: true, limit: -1, adding: 3 });
    expect(mockGetFiles).not.toHaveBeenCalled();
  });
});

describe('routes return PLAN_LIMIT', () => {
  let server: Server;
  beforeAll((done) => {
    const app = express();
    app.use(express.json());
    app.use((req: Request, _res: Response, next: NextFunction) => {
      const role = req.header('x-test-role') ?? 'admin';
      Object.assign(req, {
        auth: { companyId: 'c1', userId: 'admin1', permissions: ['manage:members'] },
        userContext: { companyId: 'c1', userId: 'admin1', userName: 'Admin', role, permissions: ['manage:members'] },
      });
      next();
    });
    app.use('/invites', appInviteRoutes);
    app.use('/forms', formTemplatesRoutes);
    app.use('/orders', orderPhotosRoutes);
    server = app.listen(0, '127.0.0.1', done);
  });
  afterAll((done) => {
    server.close(done);
  });

  beforeEach(() => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', FREE);
    seed('companies/c1/memberships/owner1', { role: 'owner' });
  });

  it('invite at the limit: 402 with resource, limit and usage', async () => {
    const res = await request(server).post('/invites').send({ email: 'x@example.com', role: 'technician' });
    expect(res.status).toBe(402);
    expect(res.body.error).toMatchObject({ code: 'PLAN_LIMIT', resource: 'collaborator', limit: 1, usage: 1, plan: 'free' });
  });

  it('invite with room in the plan goes through', async () => {
    seed('companies/c1', { subscription: { plan: 'starter' } });
    const res = await request(server).post('/invites').send({ email: 'x@example.com', role: 'technician' });
    expect(res.status).toBe(201);
  });

  it('form template: the second one is refused, even saved inactive (like the app)', async () => {
    seed('companies/c1/forms/f1', { title: 'A', isActive: true });
    const res = await request(server).post('/forms').send({ title: 'B', isActive: false });
    expect(res.status).toBe(402);
    expect(res.body.error).toMatchObject({ resource: 'formTemplate', limit: 1, usage: 1 });
  });

  it('form template: turning one on at the limit is refused, editing its title is not', async () => {
    seed('companies/c1/forms/f1', { title: 'A', isActive: true });
    seed('companies/c1/forms/f2', { title: 'B', isActive: false });
    expect((await request(server).patch('/forms/f2').send({ isActive: true })).status).toBe(402);
    expect((await request(server).patch('/forms/f2').send({ title: 'B2' })).status).toBe(200);
    expect((read('companies/c1/forms/f2') as any).title).toBe('B2');
  });

  it('photo at the monthly limit: 402', async () => {
    for (let i = 0; i < 30; i++) {
      mockFiles.push({ name: `tenants/c1/orders/o1/photos/${i}.jpg`, metadata: { timeCreated: new Date().toISOString() } });
    }
    const res = await request(server).post('/orders/o1/photos').send({ base64: 'aGk=' });
    expect(res.status).toBe(402);
    expect(res.body.error).toMatchObject({ resource: 'photo', limit: 30, usage: 30 });
  });

  it('photo under the limit is stored', async () => {
    const res = await request(server).post('/orders/o1/photos').send({ base64: 'aGk=' });
    expect(res.status).toBe(201);
    expect(res.body.data.photo.id).toBe('ph1');
  });
});
