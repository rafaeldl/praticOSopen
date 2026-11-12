/**
 * plan-limits.service usage counting and the routes that apply it, over the
 * in-memory Firestore. Storage must never be listed (M2 of the #526 review):
 * the fake listing fails the test if anything calls it. The check itself is
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

import { resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import {
  checkCompanyPlanLimit,
  countCollaborators,
  countFormTemplates,
  countPhotosThisMonth,
  monthStart,
  orderMonthKey,
  ordersUsage,
  previousMonthKey,
  resetPaidPlansCache,
} from '../plan-limits.service';
import appInviteRoutes from '../../routes/v1/invite.routes';

const NOW = new Date('2026-11-20T15:00:00.000Z');
const FREE = { name: 'Clima', subscription: { plan: 'free', status: 'active', usage: { usersActive: 0, formTemplatesActive: 0, photosThisMonth: 0 } } };

beforeEach(() => {
  resetFakeDb();
  resetPaidPlansCache();
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

  it('form templates: own active ones in forms/, a missing isActive counts as active', async () => {
    seed('companies/c1/forms/f1', { title: 'A', isActive: true });
    seed('companies/c1/forms/f2', { title: 'B' });
    seed('companies/c1/forms/f3', { title: 'C', isActive: false });
    // The old app counter read formTemplates/, which is not where templates live.
    seed('companies/c1/formTemplates/x', { isActive: true });
    expect(await countFormTemplates('c1')).toBe(2);
  });

  it('form templates: copies of the segment ready-made ones do not count', async () => {
    seed('companies/c1', { segment: { id: 'hvac' } });
    seed('segments/hvac/forms/ready1', { title: 'Vistoria' });
    seed('companies/c1/forms/ready1', { title: 'Vistoria' }); // first access: same id
    seed('companies/c1/forms/r2', { title: 'Entrega', sourceTemplateId: 'ready2' }); // "Usar"
    seed('companies/c1/forms/own', { title: 'Meu checklist' });
    expect(await countFormTemplates('c1')).toBe(1);
  });

  it('orders: the month turns by itself; São Paulo calendar', () => {
    expect(orderMonthKey(new Date('2026-12-01T02:59:00.000Z'))).toBe('2026-11');
    expect(orderMonthKey(new Date('2026-12-01T03:00:00.000Z'))).toBe('2026-12');
    expect(previousMonthKey('2027-01')).toBe('2026-12');
    const usage = { ordersMonth: '2026-11', ordersThisMonth: 12, ordersLastMonth: 4 };
    expect(ordersUsage(usage, NOW)).toEqual({ thisMonth: 12, lastMonth: 4 });
    expect(ordersUsage(usage, new Date('2026-12-05T12:00:00Z'))).toEqual({ thisMonth: 0, lastMonth: 12 });
    expect(ordersUsage(usage, new Date('2027-01-05T12:00:00Z'))).toEqual({ thisMonth: 0, lastMonth: 0 });
    expect(ordersUsage(undefined, NOW)).toEqual({ thisMonth: 0, lastMonth: 0 });
  });

  it('photos: subscription.usage.photosThisMonth kept by the order triggers; Storage is never listed', async () => {
    seed('companies/c1', { subscription: { plan: 'free', usage: { photosThisMonth: 12 } } });
    mockFiles.push({ name: 'tenants/c1/orders/o1/photos/1.jpg', metadata: { timeCreated: '2026-11-02T10:00:00.000Z' } });
    expect(await countPhotosThisMonth('c1')).toBe(12);
    expect(mockGetFiles).not.toHaveBeenCalled();
  });

  it('photos: no counter yet counts as none', async () => {
    seed('companies/c1', { subscription: { plan: 'free' } });
    expect(await countPhotosThisMonth('c1')).toBe(0);
    seed('companies/c2', { name: 'Sem plano' });
    expect(await countPhotosThisMonth('c2')).toBe(0);
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

  it('on, photos: no limit on any plan, without listing Storage', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', { subscription: { plan: 'free', usage: { photosThisMonth: 3000 } } });
    expect(await checkCompanyPlanLimit('c1', 'photo', 1, NOW)).toMatchObject({ allowed: true, limit: -1 });
    expect(mockGetFiles).not.toHaveBeenCalled();
  });

  it('on, orders: Free at 10 the first month over gets the month of grace, the next one is refused', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', { subscription: { plan: 'free', usage: { ordersMonth: '2026-11', ordersThisMonth: 10, ordersLastMonth: 3 } } });
    expect(await checkCompanyPlanLimit('c1', 'order', 1, NOW)).toMatchObject({ allowed: true, grace: true, limit: 10, usage: 10, level: 'over' });
    seed('companies/c1', { subscription: { plan: 'free', usage: { ordersMonth: '2026-11', ordersThisMonth: 10, ordersLastMonth: 14 } } });
    expect(await checkCompanyPlanLimit('c1', 'order', 1, NOW)).toMatchObject({ allowed: false, grace: false, limit: 10 });
  });

  it('on, orders: Business past 500 is not blocked, it says to talk to us', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', { subscription: { plan: 'business', tableVersion: '2', usage: { ordersMonth: '2026-11', ordersThisMonth: 600, ordersLastMonth: 700 } } });
    expect(await checkCompanyPlanLimit('c1', 'order', 1, NOW)).toMatchObject({ allowed: true, contactUs: true, limit: 500 });
  });

  it('on, unlimited plan: allowed without counting', async () => {
    seed('config/paidPlans', { enabled: true });
    seed('companies/c1', { subscription: { plan: 'business' } });
    expect(await checkCompanyPlanLimit('c1', 'formTemplate', 3, NOW)).toMatchObject({ allowed: true, limit: -1, adding: 3 });
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
    const res = await request(server).post('/invites').send({ email: 'x@example.com', role: 'admin' });
    expect(res.status).toBe(201);
  });

  it('invite with room but a Pro role on Starter: 402 PLAN_FEATURE (#724)', async () => {
    seed('companies/c1', { subscription: { plan: 'starter' } });
    const res = await request(server).post('/invites').send({ email: 'x@example.com', role: 'technician' });
    expect(res.status).toBe(402);
    expect(res.body.error).toMatchObject({ code: 'PLAN_FEATURE', feature: 'teamRoles', requiredPlan: 'pro' });
  });

  it('switch off (config/paidPlans): at the limit still goes through', async () => {
    seed('config/paidPlans', { enabled: false });
    resetPaidPlansCache();
    const res = await request(server).post('/invites').send({ email: 'x@example.com', role: 'technician' });
    expect(res.status).toBe(201);
  });
});
