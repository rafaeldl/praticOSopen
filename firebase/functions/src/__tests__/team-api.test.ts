/**
 * /v1/app/team — role change and removal of a member (issue #457).
 *
 * Same harness as rbac-api.test.ts: the router is mounted behind the REAL
 * bearerAuth and resolveCompanyContext over the in-memory Firestore; only
 * verifyIdToken (token = uid) and setCustomUserClaims are faked.
 */

import request from 'supertest';
import express, { Express } from 'express';

const mockSetClaims = jest.fn(async (_uid: string, _claims: unknown) => undefined);

jest.mock('../services/firestore.service', () => ({
  ...jest.requireActual('./helpers/fake-firestore').firestoreServiceMock,
  auth: {
    verifyIdToken: async (token: string) => ({ uid: token }),
    setCustomUserClaims: (uid: string, claims: unknown) => mockSetClaims(uid, claims),
  },
}));

import { read, resetFakeDb, seed } from './helpers/fake-firestore';
import { bearerAuth } from '../middleware/auth.middleware';
import { resolveCompanyContext } from '../middleware/company.middleware';
import teamRoutes from '../routes/v1/team.routes';

const ROLES = ['owner', 'admin', 'supervisor', 'manager', 'consultant', 'technician'] as const;
type Role = (typeof ROLES)[number];
const UID: Record<Role, string> = {
  owner: 'owner1', admin: 'admin1', supervisor: 'sup1', manager: 'mgr1', consultant: 'cons1', technician: 'tech1',
};
/** The member every case acts on. */
const TARGET = 'target1';

function seedTenants() {
  resetFakeDb();
  const members: Record<string, string> = Object.fromEntries(
    ROLES.filter((r) => r !== 'owner').map((r) => [UID[r], r]),
  );
  members[TARGET] = 'technician';
  seed('companies/c1', {
    name: 'Company c1',
    owner: { id: UID.owner, name: 'Owner' },
    users: Object.entries(members).map(([id, role]) => ({ user: { id, name: id }, role })),
  });
  seed('companies/c1/private/membership', { members });
  for (const [id, role] of Object.entries(members)) {
    seed(`companies/c1/memberships/${id}`, { user: { id, name: id }, role });
  }
  // Another company: its admin must not reach c1's members.
  seed('companies/c2', { name: 'Company c2', owner: { id: 'owner2', name: 'Owner 2' } });
  seed('companies/c2/private/membership', { members: { admin2: 'admin' } });
  seed('users/admin2', { name: 'admin2', companies: [{ company: { id: 'c2', name: 'c2' }, role: 'admin' }] });

  for (const role of ROLES) {
    seed(`users/${UID[role]}`, { name: role, companies: [{ company: { id: 'c1', name: 'c1' }, role }] });
  }
  seed(`users/${TARGET}`, {
    name: 'Target',
    companies: [
      { company: { id: 'c1', name: 'c1' }, role: 'technician' },
      { company: { id: 'c2', name: 'c2' }, role: 'technician' },
    ],
  });
  seed('companies/c2/private/membership', { members: { admin2: 'admin', [TARGET]: 'technician' } });
}

function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use('/v1/app/team', bearerAuth, resolveCompanyContext, teamRoutes);
  return app;
}

const patch = (app: Express, as: string, target: string, role: string, company = 'c1') =>
  request(app).patch(`/v1/app/team/members/${target}`)
    .set('Authorization', `Bearer ${as}`).set('X-Company-ID', company).send({ role });
const del = (app: Express, as: string, target: string, company = 'c1') =>
  request(app).delete(`/v1/app/team/members/${target}`)
    .set('Authorization', `Bearer ${as}`).set('X-Company-ID', company);

const roleIn = (path: string, uid: string) =>
  ((read(path)?.members ?? {}) as Record<string, string>)[uid];
const userCompanies = (uid: string) =>
  read(`users/${uid}`)?.companies as Array<{ company: { id: string }; role: string }>;

let app: Express;
let logSpies: jest.SpyInstance[];

beforeAll(() => {
  app = buildApp();
  logSpies = (['log', 'warn', 'error'] as const).map((m) => jest.spyOn(console, m).mockImplementation(() => undefined));
});
afterAll(() => logSpies.forEach((s) => s.mockRestore()));
beforeEach(() => {
  seedTenants();
  mockSetClaims.mockClear();
});

describe('team API: role × action', () => {
  const allowed: Role[] = ['owner', 'admin'];

  describe.each(ROLES.map((r) => [r]))('%s', (role) => {
    it(`change role → ${allowed.includes(role) ? 'allowed' : 'denied'}`, async () => {
      const res = await patch(app, UID[role], TARGET, 'manager');
      if (allowed.includes(role)) {
        expect(res.status).toBe(200);
        expect(roleIn('companies/c1/private/membership', TARGET)).toBe('manager');
      } else {
        expect(res.status).toBe(403);
        expect(roleIn('companies/c1/private/membership', TARGET)).toBe('technician');
      }
    });

    it(`remove member → ${allowed.includes(role) ? 'allowed' : 'denied'}`, async () => {
      const res = await del(app, UID[role], TARGET);
      if (allowed.includes(role)) {
        expect(res.status).toBe(200);
        expect(roleIn('companies/c1/private/membership', TARGET)).toBeUndefined();
      } else {
        expect(res.status).toBe(403);
        expect(roleIn('companies/c1/private/membership', TARGET)).toBe('technician');
      }
    });
  });
});

describe('team API: what a role change writes', () => {
  it('updates every copy of the membership and the claim, only for this company', async () => {
    const res = await patch(app, UID.admin, TARGET, 'supervisor');
    expect(res.status).toBe(200);

    expect(roleIn('companies/c1/private/membership', TARGET)).toBe('supervisor');
    expect(read(`companies/c1/memberships/${TARGET}`)?.role).toBe('supervisor');
    const users = read('companies/c1')?.users as Array<{ user: { id: string }; role: string }>;
    expect(users.find((u) => u.user.id === TARGET)?.role).toBe('supervisor');
    expect(userCompanies(TARGET)).toEqual([
      { company: { id: 'c1', name: 'c1' }, role: 'supervisor' },
      { company: { id: 'c2', name: 'c2' }, role: 'technician' },
    ]);
    expect(mockSetClaims).toHaveBeenCalledWith(TARGET, { roles: { c1: 'supervisor', c2: 'technician' } });
  });

  it('rejects an unknown role and the owner role', async () => {
    expect((await patch(app, UID.admin, TARGET, 'owner')).status).toBe(400);
    expect((await patch(app, UID.admin, TARGET, 'god')).status).toBe(400);
    expect(roleIn('companies/c1/private/membership', TARGET)).toBe('technician');
  });
});

describe('team API: what a removal writes', () => {
  it('removes every copy of the membership and the company from the claim', async () => {
    const res = await del(app, UID.owner, TARGET);
    expect(res.status).toBe(200);

    expect(roleIn('companies/c1/private/membership', TARGET)).toBeUndefined();
    expect(read(`companies/c1/memberships/${TARGET}`)).toBeUndefined();
    const users = read('companies/c1')?.users as Array<{ user: { id: string } }>;
    expect(users.some((u) => u.user.id === TARGET)).toBe(false);
    expect(userCompanies(TARGET)).toEqual([{ company: { id: 'c2', name: 'c2' }, role: 'technician' }]);
    expect(mockSetClaims).toHaveBeenCalledWith(TARGET, { roles: { c2: 'technician' } });
  });

  it('removes the WhatsApp link to this company only', async () => {
    seed('links/whatsapp/numbers/+551100', { userId: TARGET, companyId: 'c1', role: 'technician' });
    seed('links/whatsapp/numbers/+551101', { userId: TARGET, companyId: 'c2', role: 'technician' });
    expect((await del(app, UID.admin, TARGET)).status).toBe(200);
    expect(read('links/whatsapp/numbers/+551100')).toBeUndefined();
    expect(read('links/whatsapp/numbers/+551101')).toBeDefined();
  });
});

describe('team API: the owner', () => {
  it('nobody changes the owner role', async () => {
    const res = await patch(app, UID.admin, UID.owner, 'technician');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('OWNER_PROTECTED');
    expect(mockSetClaims).not.toHaveBeenCalled();
  });

  it('nobody removes the owner, not even the owner', async () => {
    for (const as of [UID.admin, UID.owner]) {
      const res = await del(app, as, UID.owner);
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('OWNER_PROTECTED');
    }
    expect(userCompanies(UID.owner)).toHaveLength(1);
  });
});

describe('team API: the last admin', () => {
  /** A company with no owner record and a single admin (legacy data). */
  function seedSingleAdmin() {
    seed('companies/c3', { name: 'c3', users: [{ user: { id: 'solo', name: 'solo' }, role: 'admin' }] });
    seed('companies/c3/private/membership', { members: { solo: 'admin', [TARGET]: 'technician' } });
    seed('users/solo', { name: 'solo', companies: [{ company: { id: 'c3', name: 'c3' }, role: 'admin' }] });
  }

  it('the last admin cannot demote themselves', async () => {
    seedSingleAdmin();
    const res = await patch(app, 'solo', 'solo', 'manager', 'c3');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('LAST_ADMIN');
    expect(roleIn('companies/c3/private/membership', 'solo')).toBe('admin');
    expect(userCompanies('solo')[0].role).toBe('admin');
  });

  it('the last admin cannot remove themselves', async () => {
    seedSingleAdmin();
    const res = await del(app, 'solo', 'solo', 'c3');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('LAST_ADMIN');
    expect(roleIn('companies/c3/private/membership', 'solo')).toBe('admin');
  });

  it('an admin can step down while the owner remains', async () => {
    const res = await patch(app, UID.admin, UID.admin, 'manager');
    expect(res.status).toBe(200);
    expect(roleIn('companies/c1/private/membership', UID.admin)).toBe('manager');
  });
});

describe('team API: other companies', () => {
  it("an admin of another company is barred from c1", async () => {
    expect((await patch(app, 'admin2', TARGET, 'manager')).status).toBe(403);
    expect((await del(app, 'admin2', TARGET)).status).toBe(403);
    expect(roleIn('companies/c1/private/membership', TARGET)).toBe('technician');
  });

  it("an admin of another company cannot touch that company's member through c1", async () => {
    // Acting in c2 (where admin2 is admin) on someone who is only in c1.
    const res = await patch(app, 'admin2', UID.supervisor, 'admin', 'c2');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('MEMBER_NOT_FOUND');
    expect(roleIn('companies/c1/private/membership', UID.supervisor)).toBe('supervisor');
  });

  it('a change in c2 leaves the c1 role and claim entry intact', async () => {
    expect((await patch(app, 'admin2', TARGET, 'manager', 'c2')).status).toBe(200);
    expect(roleIn('companies/c1/private/membership', TARGET)).toBe('technician');
    expect(mockSetClaims).toHaveBeenCalledWith(TARGET, { roles: { c1: 'technician', c2: 'manager' } });
  });

  it('unknown member → 404', async () => {
    const res = await del(app, UID.admin, 'nobody');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('MEMBER_NOT_FOUND');
  });
});

describe('team API: failures after the commit', () => {
  it('a claim failure after a role change is logged, not a 500', async () => {
    mockSetClaims.mockRejectedValueOnce(new Error('auth down'));
    const res = await patch(app, UID.admin, TARGET, 'supervisor');
    expect(res.status).toBe(200);
    expect(roleIn('companies/c1/private/membership', TARGET)).toBe('supervisor');
    expect(console.error).toHaveBeenCalledWith(
      '[team] changeMemberRole post-commit step failed', expect.objectContaining({ companyId: 'c1', userId: TARGET }),
    );
  });

  it('a claim failure after a removal is logged, not a 500, and the WhatsApp link still goes', async () => {
    seed('links/whatsapp/numbers/+551100', { userId: TARGET, companyId: 'c1', role: 'technician' });
    mockSetClaims.mockRejectedValueOnce(new Error('auth down'));
    const res = await del(app, UID.admin, TARGET);
    expect(res.status).toBe(200);
    expect(roleIn('companies/c1/private/membership', TARGET)).toBeUndefined();
    expect(read('links/whatsapp/numbers/+551100')).toBeUndefined();
    expect(console.error).toHaveBeenCalledWith(
      '[team] removeTeamMember post-commit step failed', expect.objectContaining({ companyId: 'c1', userId: TARGET }),
    );
  });
});
