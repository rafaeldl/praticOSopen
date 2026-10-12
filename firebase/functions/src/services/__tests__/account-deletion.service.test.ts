import {
  AccountDeletionDeps,
  AccountDeletionError,
  COMPANY_HAS_MEMBERS_MESSAGE,
  RECENT_LOGIN_MAX_AGE_SECONDS,
  assertRecentLogin,
  deleteAccount,
} from '../account-deletion.service';

interface FakeCompany {
  ownerId: string;
  members: string[];
}

/** In-memory world: users, companies, storage prefixes and auth users. */
function fakeWorld(init: {
  users?: Record<string, string[]>;
  companies?: Record<string, FakeCompany>;
  authUsers?: string[];
}) {
  const users = new Map(Object.entries(init.users ?? {}));
  const companies = new Map(Object.entries(init.companies ?? {}));
  const authUsers = new Set(init.authUsers ?? []);
  const calls: string[] = [];

  const deps: AccountDeletionDeps = {
    getUserCompanyIds: jest.fn(async (uid) => users.get(uid) ?? null),
    getCompany: jest.fn(async (id) => {
      const c = companies.get(id);
      return { exists: !!c, ownerId: c?.ownerId ?? null };
    }),
    hasOtherMembers: jest.fn(async (id, uid) => (companies.get(id)?.members ?? []).some((m) => m !== uid)),
    deleteStoragePrefix: jest.fn(async (prefix) => {
      calls.push(`storage:${prefix}`);
    }),
    deleteCompanyTree: jest.fn(async (id) => {
      calls.push(`company:${id}`);
      companies.delete(id);
    }),
    leaveCompany: jest.fn(async (id, uid) => {
      calls.push(`leave:${id}`);
      const c = companies.get(id);
      if (c) c.members = c.members.filter((m) => m !== uid);
    }),
    deleteUserChannelLinks: jest.fn(async (uid) => {
      calls.push(`links:${uid}`);
    }),
    deleteUserTree: jest.fn(async (uid) => {
      calls.push(`user:${uid}`);
      users.delete(uid);
    }),
    deleteAuthUser: jest.fn(async (uid) => {
      calls.push(`auth:${uid}`);
      return authUsers.delete(uid);
    }),
  };
  return { deps, users, companies, authUsers, calls };
}

beforeEach(() => {
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

describe('deleteAccount', () => {
  it('sole owner: deletes Storage (both prefixes), the company tree, user doc and auth user', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1'] } },
      authUsers: ['u1'],
    });

    const result = await deleteAccount('u1', w.deps);

    expect(result).toEqual({ deletedCompanies: 1, leftCompanies: 0, authUserDeleted: true });
    expect(w.calls).toEqual([
      'storage:tenants/c1/',
      'storage:companies/c1/',
      'company:c1',
      'links:u1',
      'user:u1',
      'auth:u1',
    ]);
    expect(w.companies.has('c1')).toBe(false);
    expect(w.users.has('u1')).toBe(false);
  });

  it('owner with other members anywhere: blocks with COMPANY_HAS_MEMBERS and deletes nothing', async () => {
    const w = fakeWorld({
      users: { u1: ['solo', 'team'] },
      companies: {
        solo: { ownerId: 'u1', members: ['u1'] },
        team: { ownerId: 'u1', members: ['u1', 'u2'] },
      },
      authUsers: ['u1'],
    });

    const error = await deleteAccount('u1', w.deps).catch((e) => e);

    expect(error).toBeInstanceOf(AccountDeletionError);
    expect(error.code).toBe('COMPANY_HAS_MEMBERS');
    expect(error.message).toBe(COMPANY_HAS_MEMBERS_MESSAGE);
    expect(w.calls).toEqual([]); // the solo company listed first was not touched either
    expect(w.companies.size).toBe(2);
    expect(w.authUsers.has('u1')).toBe(true);
  });

  it('member of a company owned by someone else: only leaves it', async () => {
    const w = fakeWorld({
      users: { u2: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1', 'u2'] } },
      authUsers: ['u2'],
    });

    const result = await deleteAccount('u2', w.deps);

    expect(result).toEqual({ deletedCompanies: 0, leftCompanies: 1, authUserDeleted: true });
    expect(w.calls).toEqual(['leave:c1', 'links:u2', 'user:u2', 'auth:u2']);
    expect(w.companies.get('c1')?.members).toEqual(['u1']);
    expect(w.deps.deleteStoragePrefix).not.toHaveBeenCalled();
    expect(w.deps.deleteCompanyTree).not.toHaveBeenCalled();
  });

  it('is idempotent: a second run (no user doc, no auth user) succeeds', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1'] } },
      authUsers: ['u1'],
    });

    await deleteAccount('u1', w.deps);
    const second = await deleteAccount('u1', w.deps);

    expect(second).toEqual({ deletedCompanies: 0, leftCompanies: 0, authUserDeleted: false });
  });

  it('resumes a partial run: skips companies that are already gone', async () => {
    const w = fakeWorld({
      users: { u1: ['gone', 'c2', 'c2'] },
      companies: { c2: { ownerId: 'u1', members: [] } },
      authUsers: ['u1'],
    });

    const result = await deleteAccount('u1', w.deps);

    expect(result.deletedCompanies).toBe(1);
    expect(w.deps.deleteCompanyTree).toHaveBeenCalledTimes(1);
    expect(w.deps.deleteCompanyTree).toHaveBeenCalledWith('c2');
  });

  it('a Storage failure stops before Firestore is touched', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1'] } },
      authUsers: ['u1'],
    });
    (w.deps.deleteStoragePrefix as jest.Mock).mockRejectedValueOnce(new Error('boom'));

    await expect(deleteAccount('u1', w.deps)).rejects.toThrow('boom');
    expect(w.deps.deleteCompanyTree).not.toHaveBeenCalled();
    expect(w.deps.deleteUserTree).not.toHaveBeenCalled();
    expect(w.deps.deleteAuthUser).not.toHaveBeenCalled();
  });
});

describe('assertRecentLogin', () => {
  const now = Date.UTC(2026, 9, 11, 12, 0, 0);
  const nowSec = now / 1000;

  it('accepts a sign-in within 5 minutes', () => {
    expect(() => assertRecentLogin(nowSec - RECENT_LOGIN_MAX_AGE_SECONDS, now)).not.toThrow();
    expect(() => assertRecentLogin(nowSec - 10, now)).not.toThrow();
  });

  it('rejects an older sign-in or a missing auth_time with REQUIRES_RECENT_LOGIN', () => {
    for (const authTime of [nowSec - RECENT_LOGIN_MAX_AGE_SECONDS - 1, undefined, 'x']) {
      try {
        assertRecentLogin(authTime, now);
        fail('expected to throw');
      } catch (e) {
        expect((e as AccountDeletionError).code).toBe('REQUIRES_RECENT_LOGIN');
      }
    }
  });
});
