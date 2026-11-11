/**
 * GET and DELETE /v1/app/invites — the team screen of the web lists and
 * cancels the company's invites through the API (fatia 07). The name typed in
 * the invite comes back, so the row says who is waiting; only owner/admin list,
 * and only their company. An admin cancels an invite the owner sent.
 *
 * Same harness as team-api.test.ts: real bearerAuth and resolveCompanyContext
 * over the in-memory Firestore; verifyIdToken is faked (token = uid).
 */

import { readFileSync } from 'fs';
import { join } from 'path';
import request from 'supertest';
import express, { Express } from 'express';

jest.mock('../services/firestore.service', () => ({
  ...jest.requireActual('./helpers/fake-firestore').firestoreServiceMock,
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

import { FakeCollection, read, resetFakeDb, seed } from './helpers/fake-firestore';
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

  it('lists newest first without orderBy, so the deployed company.id + status index is enough', async () => {
    // Production has no company.id + status + createdAt index: the orderBy made
    // Firestore answer FAILED_PRECONDITION and the web team screen said "Não deu
    // certo". The in-memory Firestore never asks for an index, so guard both sides.
    seed('links/invites/tokens/INV_NEW', {
      token: 'INV_NEW', company: { id: 'c1', name: 'c1' }, role: 'technician', status: 'pending',
      createdAt: '2026-11-05T12:00:00.000Z', invitedBy: { id: 'owner1', name: 'Owner' }, channel: 'app',
    });
    const queryProto = Object.getPrototypeOf(FakeCollection.prototype) as { orderBy: (...args: unknown[]) => unknown };
    const orderBy = jest.spyOn(queryProto, 'orderBy');
    try {
      const res = await request(buildApp()).get('/v1/app/invites').set('Authorization', 'Bearer admin1').set('X-Company-ID', 'c1');
      expect(res.status).toBe(200);
      expect((res.body.data.invites as { token: string }[])[0].token).toBe('INV_NEW');
      expect(orderBy).not.toHaveBeenCalled();
    } finally {
      orderBy.mockRestore();
    }

    const indexes = JSON.parse(readFileSync(join(__dirname, '../../../firestore.indexes.json'), 'utf8')).indexes as {
      collectionGroup: string; queryScope: string; fields: { fieldPath: string }[];
    }[];
    const fields = (index: (typeof indexes)[number]) => index.fields.map((field) => field.fieldPath).filter((path) => path !== '__name__');
    expect(indexes.some((index) => index.collectionGroup === 'tokens' && index.queryScope === 'COLLECTION' && fields(index).join() === 'company.id,status')).toBe(true);
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

  it('an old invite saved without company is not found, never a 500', async () => {
    seed('links/invites/tokens/INV_NOCO', { token: 'INV_NOCO', role: 'technician', status: 'pending', invitedBy: { id: 'owner1', name: 'Owner' } });
    const res = await del('admin1', 'INV_NOCO');
    expect(res.status).toBe(404);
    expect(read('links/invites/tokens/INV_NOCO')?.status).toBe('pending');
  });

  it('an invite of another company is not found', async () => {
    const res = await del('admin1', 'INV_OTHER');
    expect(res.status).toBe(404);
    expect(read('links/invites/tokens/INV_OTHER')?.status).toBe('pending');
  });
});
