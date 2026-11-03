/**
 * /v1/app/invites for an account that has no company yet (onboarding).
 *
 * The app lists the invites addressed to the user and accepts one with
 * POST /v1/app/invites/:token/accept before the user has any company.
 * Real bearerAuth over the in-memory Firestore; only verifyIdToken is faked
 * (the token is a key into DECODED).
 */

import request from 'supertest';
import express, { Express } from 'express';

const DECODED: Record<string, Record<string, unknown>> = {
  newbie: { uid: 'newbie', email: 'Newbie@Example.com', email_verified: true },
  phoneuser: { uid: 'phoneuser', phone_number: '+5548999990000' },
  unverified: { uid: 'unverified', email: 'newbie@example.com', email_verified: false },
  stranger: { uid: 'stranger', email: 'stranger@example.com', email_verified: true },
  admin1: { uid: 'admin1', email: 'admin@example.com', email_verified: true },
  member2: { uid: 'member2', email: 'member2@example.com', email_verified: true },
};

jest.mock('../services/firestore.service', () => ({
  ...jest.requireActual('./helpers/fake-firestore').firestoreServiceMock,
  auth: {
    verifyIdToken: async (token: string) => {
      if (!DECODED[token]) throw new Error('bad token');
      return DECODED[token];
    },
  },
}));

import { read, resetFakeDb, seed } from './helpers/fake-firestore';
import { mountAppInviteRoutes } from '../routes/v1/app-invites.mount';

const FUTURE = new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString();

function invite(token: string, extra: Record<string, unknown>) {
  seed(`links/invites/tokens/${token}`, {
    token,
    company: { id: 'c1', name: 'Oficina' },
    role: 'technician',
    invitedBy: { id: 'admin1', name: 'Admin' },
    channel: 'app',
    status: 'pending',
    createdAt: new Date().toISOString(),
    expiresAt: FUTURE,
    ...extra,
  });
}

function seedAll() {
  resetFakeDb();
  seed('companies/c1', { name: 'Oficina', owner: { id: 'owner1', name: 'Owner' }, users: [] });
  seed('companies/c1/private/membership', { members: { admin1: 'admin' } });
  seed('companies/c1/memberships/admin1', { user: { id: 'admin1', name: 'Admin' }, role: 'admin' });
  seed('users/admin1', { name: 'Admin', companies: [{ company: { id: 'c1', name: 'Oficina' }, role: 'admin' }] });
  for (const uid of ['newbie', 'phoneuser', 'unverified', 'stranger']) {
    seed(`users/${uid}`, { name: uid, companies: [] });
  }
  invite('INV_EMAIL', { email: 'newbie@example.com' });
  invite('INV_PHONE', { phone: '5548999990000' });
  invite('INV_LOCAL', { phone: '(48) 99999-0000', createdAt: '2020-01-01T00:00:00.000Z' });
  invite('INV_OTHER', { email: 'someone-else@example.com' });
  invite('INV_ADMIN', { email: 'newbie@example.com', role: 'admin' });
  invite('INV_OLD', { email: 'someone-else@example.com', expiresAt: undefined, createdAt: daysAgo(8) });
  invite('INV_RECENT', { email: 'someone-else@example.com', expiresAt: undefined, createdAt: daysAgo(1) });
  // A member of another company.
  seed('companies/c2', { name: 'Outra', owner: { id: 'member2', name: 'M' }, users: [] });
  seed('companies/c2/private/membership', { members: {} });
  seed('users/member2', { name: 'M', companies: [{ company: { id: 'c2', name: 'Outra' }, role: 'owner' }] });
}

function daysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 3600 * 1000).toISOString();
}

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  mountAppInviteRoutes(app);
  return app;
}

const as = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('invites for an account without a company', () => {
  let app: Express;
  beforeEach(() => {
    seedAll();
    app = buildApp();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('lists the invites addressed to the verified email', async () => {
    const res = await request(app).get('/v1/app/invites/pending').set(as('newbie'));

    expect(res.status).toBe(200);
    expect(res.body.data.invites.map((i: { token: string }) => i.token).sort()).toEqual(['INV_ADMIN', 'INV_EMAIL']);
  });

  it('lists the invites addressed to the verified phone', async () => {
    const res = await request(app).get('/v1/app/invites/pending').set(as('phoneuser'));

    expect(res.status).toBe(200);
    expect(res.body.data.invites.map((i: { token: string }) => i.token)).toEqual(['INV_PHONE']);
  });

  it('accepts an invite whose phone was typed without the country code', async () => {
    const res = await request(app).post('/v1/app/invites/INV_LOCAL/accept').set(as('phoneuser'));

    expect(res.status).toBe(200);
  });

  it('does not match an unverified email', async () => {
    const res = await request(app).get('/v1/app/invites/pending').set(as('unverified'));

    expect(res.status).toBe(200);
    expect(res.body.data.invites).toEqual([]);
  });

  it('accepts an invite addressed to the email and joins the company', async () => {
    const res = await request(app).post('/v1/app/invites/INV_EMAIL/accept').set(as('newbie'));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ companyId: 'c1', role: 'technician' });
    expect(read('companies/c1/private/membership')?.members).toMatchObject({ newbie: 'technician' });
    expect(read('users/newbie')?.companies).toEqual([
      { company: { id: 'c1', name: 'Oficina' }, role: 'technician' },
    ]);
    expect(read('links/invites/tokens/INV_EMAIL')?.status).toBe('accepted');
  });

  it('accepts an invite addressed to the phone', async () => {
    const res = await request(app).post('/v1/app/invites/INV_PHONE/accept').set(as('phoneuser'));

    expect(res.status).toBe(200);
    expect(read('companies/c1/private/membership')?.members).toMatchObject({ phoneuser: 'technician' });
  });

  it('looks up an invite by code', async () => {
    const res = await request(app).get('/v1/app/invites/INV_OTHER').set(as('stranger'));

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ token: 'INV_OTHER', company: { id: 'c1', name: 'Oficina' }, role: 'technician' });
    expect(res.body.data).not.toHaveProperty('email');
  });

  it('accepts by code an invite sent to another email or phone', async () => {
    const res = await request(app).post('/v1/app/invites/INV_OTHER/accept').set(as('stranger'));

    expect(res.status).toBe(200);
    expect(read('companies/c1/private/membership')?.members).toMatchObject({ stranger: 'technician' });
  });

  describe('admin invite', () => {
    it.each(['stranger', 'unverified', 'member2'])('%s, who is not the recipient, cannot accept it', async (who) => {
      const res = await request(app).post('/v1/app/invites/INV_ADMIN/accept').set(as(who));

      expect(res.status).toBe(403);
      expect(read('links/invites/tokens/INV_ADMIN')?.status).toBe('pending');
      expect(read('companies/c1/private/membership')?.members).not.toHaveProperty(who);
    });

    it('the recipient accepts it', async () => {
      const res = await request(app).post('/v1/app/invites/INV_ADMIN/accept').set(as('newbie'));

      expect(res.status).toBe(200);
      expect(read('companies/c1/private/membership')?.members).toMatchObject({ newbie: 'admin' });
    });
  });

  describe('wrong codes', () => {
    it('after 10 wrong codes in an hour the user gets 429, also for a right code', async () => {
      for (let i = 0; i < 5; i++) {
        expect((await request(app).get(`/v1/app/invites/INV_NOPE${i}`).set(as('stranger'))).status).toBe(404);
      }
      for (let i = 5; i < 10; i++) {
        expect((await request(app).post(`/v1/app/invites/INV_NOPE${i}/accept`).set(as('stranger'))).status).toBe(400);
      }
      expect((await request(app).get('/v1/app/invites/INV_NOPE10').set(as('stranger'))).status).toBe(429);
      expect((await request(app).get('/v1/app/invites/INV_OTHER').set(as('stranger'))).status).toBe(429);
      const accept = await request(app).post('/v1/app/invites/INV_OTHER/accept').set(as('stranger'));
      expect(accept.status).toBe(429);
      expect(read('links/invites/tokens/INV_OTHER')?.status).toBe('pending');
    });

    it('counts per user', async () => {
      for (let i = 0; i < 10; i++) await request(app).get(`/v1/app/invites/INV_NOPE${i}`).set(as('stranger'));
      expect((await request(app).get('/v1/app/invites/INV_OTHER').set(as('newbie'))).status).toBe(200);
    });

    it('the window of an hour starts over', async () => {
      seed('inviteCodeAttempts/stranger', { windowStart: daysAgo(1), failures: 50 });
      expect((await request(app).get('/v1/app/invites/INV_OTHER').set(as('stranger'))).status).toBe(200);
    });
  });

  describe('invite without expiresAt', () => {
    it('older than 7 days is expired', async () => {
      const get = await request(app).get('/v1/app/invites/INV_OLD').set(as('stranger'));
      expect(get.status).toBe(400);
      expect(get.body.error.code).toBe('EXPIRED');
      expect((await request(app).post('/v1/app/invites/INV_OLD/accept').set(as('stranger'))).status).toBe(400);
      expect(read('links/invites/tokens/INV_OLD')?.status).toBe('pending');
    });

    it('within 7 days of createdAt still works', async () => {
      expect((await request(app).get('/v1/app/invites/INV_RECENT').set(as('stranger'))).status).toBe(200);
      expect((await request(app).post('/v1/app/invites/INV_RECENT/accept').set(as('stranger'))).status).toBe(200);
    });
  });

  it('keeps every other invite route closed without a company', async () => {
    const results = await Promise.all([
      request(app).get('/v1/app/invites').set(as('newbie')),
      request(app).post('/v1/app/invites').set(as('newbie')).send({ email: 'x@example.com', role: 'technician' }),
      request(app).delete('/v1/app/invites/INV_OTHER').set(as('newbie')),
    ]);

    for (const res of results) expect(res.status).toBe(403);
    expect(read('links/invites/tokens/INV_OTHER')?.status).toBe('pending');
  });

  it('still requires a valid token', async () => {
    const res = await request(app).get('/v1/app/invites/pending');
    expect(res.status).toBe(401);
  });

  it('keeps the company routes working for a member', async () => {
    const list = await request(app).get('/v1/app/invites').set(as('admin1'));
    expect(list.status).toBe(200);
  });
});
