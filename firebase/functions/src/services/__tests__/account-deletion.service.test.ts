import {
  AccountDeletionDeps,
  AccountDeletionError,
  COMPANY_HAS_MEMBERS_MESSAGE,
  OWNERSHIP_MISMATCH_MESSAGE,
  RECENT_LOGIN_MAX_AGE_SECONDS,
  assertRecentLogin,
  deleteAccount,
} from '../account-deletion.service';

interface FakeCompany {
  /** `owner` field of the company doc. */
  ownerId: string;
  /** memberships/* ids. */
  members: string[];
  /** private/membership.members; defaults to {} (app-created companies). */
  privateMap?: Record<string, string>;
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
    getOwnedCompanyIds: jest.fn(async (uid) =>
      [...companies.entries()].filter(([, c]) => c.ownerId === uid).map(([id]) => id),
    ),
    getCompany: jest.fn(async (id, uid) => {
      const c = companies.get(id);
      if (!c) {
        return {
          exists: false,
          ownerId: null,
          privateRole: null,
          otherOwnerInPrivateMap: false,
          hasOtherMembers: false,
          isMember: false,
        };
      }
      const map = c.privateMap ?? {};
      const others = new Set([...c.members, ...Object.keys(map)]);
      others.delete(uid);
      return {
        exists: true,
        ownerId: c.ownerId,
        privateRole: map[uid] ?? null,
        otherOwnerInPrivateMap: Object.entries(map).some(([m, role]) => m !== uid && role === 'owner'),
        hasOtherMembers: others.size > 0,
        isMember: c.members.includes(uid) || uid in map,
      };
    }),
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
    expect(w.calls).toEqual(['storage:tenants/c1/users/u2/', 'leave:c1', 'links:u2', 'user:u2', 'auth:u2']);
    expect(w.companies.get('c1')?.members).toEqual(['u1']);
    expect(w.deps.deleteCompanyTree).not.toHaveBeenCalled();
  });

  it('admin who rewrote the owner field: OWNERSHIP_MISMATCH and nothing deleted', async () => {
    const w = fakeWorld({
      users: { admin: ['solo', 'c1'] },
      companies: {
        solo: { ownerId: 'admin', members: ['admin'] },
        c1: { ownerId: 'admin', members: ['admin'], privateMap: { admin: 'admin' } },
      },
      authUsers: ['admin'],
    });

    const error = await deleteAccount('admin', w.deps).catch((e) => e);

    expect(error).toBeInstanceOf(AccountDeletionError);
    expect(error.code).toBe('OWNERSHIP_MISMATCH');
    expect(error.message).toBe(OWNERSHIP_MISMATCH_MESSAGE);
    expect(w.calls).toEqual([]);
  });

  it('owner field points elsewhere but the map says owner: OWNERSHIP_MISMATCH', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u9', members: ['u1'], privateMap: { u1: 'owner' } } },
      authUsers: ['u1'],
    });

    await expect(deleteAccount('u1', w.deps)).rejects.toMatchObject({ code: 'OWNERSHIP_MISMATCH' });
    expect(w.calls).toEqual([]);
  });

  it('another uid is owner in the map: OWNERSHIP_MISMATCH', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: [], privateMap: { u9: 'owner' } } },
    });

    await expect(deleteAccount('u1', w.deps)).rejects.toMatchObject({ code: 'OWNERSHIP_MISMATCH' });
  });

  it('owner confirmed by the map (bot-created company) is deleted', async () => {
    const w = fakeWorld({
      users: { u1: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1'], privateMap: { u1: 'owner' } } },
      authUsers: ['u1'],
    });

    await expect(deleteAccount('u1', w.deps)).resolves.toMatchObject({ deletedCompanies: 1 });
  });

  it('also deletes owned companies missing from users.companies', async () => {
    const w = fakeWorld({
      users: { u1: [] },
      companies: { hidden: { ownerId: 'u1', members: ['u1'] } },
      authUsers: ['u1'],
    });

    const result = await deleteAccount('u1', w.deps);

    expect(result.deletedCompanies).toBe(1);
    expect(w.deps.deleteCompanyTree).toHaveBeenCalledWith('hidden');
  });

  it('forged users.companies entry (not a member): ignored, nothing removed', async () => {
    const w = fakeWorld({
      users: { u2: ['c1'] },
      companies: { c1: { ownerId: 'u1', members: ['u1'] } },
      authUsers: ['u2'],
    });

    const result = await deleteAccount('u2', w.deps);

    expect(result.leftCompanies).toBe(0);
    expect(w.deps.leaveCompany).not.toHaveBeenCalled();
    expect(w.deps.deleteStoragePrefix).not.toHaveBeenCalled();
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
