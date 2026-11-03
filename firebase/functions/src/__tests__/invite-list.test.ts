/**
 * GET and DELETE /v1/app/invites — the team screen of the web lists and
 * cancels the company's invites through the API (fatia 07). The name typed in
 * the invite comes back, so the row says who is waiting; only owner/admin list,
 * and only their company. An admin cancels an invite the owner sent.
 *
 * Same harness as team-api.test.ts: real bearerAuth and resolveCompanyContext
 * over the in-memory Firestore; verifyIdToken is faked (token = uid).
 */

import request from 'supertest';
import express, { Express } from 'express';

jest.mock('../services/firestore.service', () => ({
  ...jest.requireActual('./helpers/fake-firestore').firestoreServiceMock,
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

import { read, resetFakeDb, seed } from './helpers/fake-firestore';
import { bearerAuth } from '../middleware/auth.middleware';
import { resolveCompanyContext } from '../middleware/company.middleware';
import inviteRoutes from '../routes/v1/invite.routes';

function seedTenant() {
  resetFakeDb();
  const members = { admin1: 'admin', tech1: 'technician' };
  seed('companies/c1', { name: 'c1', owner: { id: 'owner1', name: 'Owner' } });
  seed('companies/c1/private/membership', { members });
  for (const [id, role] of Object.entries(members)) {
    seed(`companies/c1/memberships/${id}`, { user: { id, name: id }, role });
    seed(`users/${id}`, { name: id, companies: [{ company: { id: 'c1', name: 'c1' }, role }] });
  }
  const invite = (token: string, company: string, extra: Record<string, unknown>) =>
    seed(`links/invites/tokens/${token}`, {
      token,
      company: { id: company, name: company },
      role: 'technician',
      status: 'pending',
      createdAt: '2026-11-01T12:00:00.000Z',
      expiresAt: '2026-11-08T12:00:00.000Z',
      invitedBy: { id: 'owner1', name: 'Owner' },
      channel: 'app',
      ...extra,
    });
  invite('INV_A', 'c1', { name: 'Paula', email: 'paula@x.test' });
  invite('INV_B', 'c1', { phone: '11999990000' });
  invite('INV_OTHER', 'c2', { name: 'Other company' });
}

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use('/v1/app/invites', bearerAuth, resolveCompanyContext, inviteRoutes);
  return app;
}

describe('GET /v1/app/invites', () => {
  beforeEach(seedTenant);

  it('lists the company invites with the typed name, and nothing of another company', async () => {
    const res = await request(buildApp()).get('/v1/app/invites').set('Authorization', 'Bearer admin1').set('X-Company-ID', 'c1');
    expect(res.status).toBe(200);
    const invites = res.body.data.invites as { token: string; name?: string; email?: string; phone?: string }[];
    expect(invites.map((invite) => invite.token).sort()).toEqual(['INV_A', 'INV_B']);
    expect(invites.find((invite) => invite.token === 'INV_A')).toMatchObject({ name: 'Paula', email: 'paula@x.test' });
    expect(invites.find((invite) => invite.token === 'INV_B')?.name).toBeUndefined();
  });

  it('refuses a technician', async () => {
    const res = await request(buildApp()).get('/v1/app/invites').set('Authorization', 'Bearer tech1').set('X-Company-ID', 'c1');
    expect(res.status).toBe(403);
  });
});

describe('DELETE /v1/app/invites/:token', () => {
  beforeEach(seedTenant);
  const del = (as: string, token: string) =>
    request(buildApp()).delete(`/v1/app/invites/${token}`).set('Authorization', `Bearer ${as}`).set('X-Company-ID', 'c1');

  it('an admin cancels an invite the owner sent', async () => {
    const res = await del('admin1', 'INV_A');
    expect(res.status).toBe(200);
    expect(read('links/invites/tokens/INV_A')?.status).toBe('cancelled');
  });

  it('a technician who did not send it cannot', async () => {
    const res = await del('tech1', 'INV_A');
    expect(res.status).toBe(403);
    expect(read('links/invites/tokens/INV_A')?.status).toBe('pending');
  });

  it('an invite of another company is not found', async () => {
    const res = await del('admin1', 'INV_OTHER');
    expect(res.status).toBe(404);
    expect(read('links/invites/tokens/INV_OTHER')?.status).toBe('pending');
  });
});
