const mockCompanyGet = jest.fn();
const mockPrivateGet = jest.fn();
const mockMembershipGet = jest.fn();

jest.mock('../firestore.service', () => ({
  db: {
    collection: (name: string) => {
      if (name !== 'companies') throw new Error(`unexpected collection ${name}`);
      return {
        doc: (companyId: string) => ({
          get: () => mockCompanyGet(companyId),
          collection: (sub: string) => ({
            doc: (docId: string) => ({
              get: () =>
                sub === 'private' && docId === 'membership'
                  ? mockPrivateGet(companyId)
                  : mockMembershipGet(companyId, docId),
            }),
          }),
        }),
      };
    },
  },
}));

import { buildRolesClaim, verifyMembership, verifyUserMemberships } from '../membership.service';

type Data = Record<string, unknown>;

function snap(data: Data | null) {
  return { exists: !!data, data: () => data ?? undefined };
}

/**
 * Configures server data: companies by id, server-only member maps by company
 * id, and display-only membership docs by `${cid}/${uid}`.
 */
function serverData(
  companies: Record<string, Data>,
  members: Record<string, Record<string, unknown>> = {},
  memberships: Record<string, Data> = {},
) {
  mockCompanyGet.mockImplementation(async (cid: string) => snap(companies[cid] ?? null));
  mockPrivateGet.mockImplementation(async (cid: string) =>
    snap(members[cid] ? { members: members[cid] } : null),
  );
  mockMembershipGet.mockImplementation(async (cid: string, uid: string) =>
    snap(memberships[`${cid}/${uid}`] ?? null),
  );
}

const entry = (companyId: string, role?: string) => ({ company: { id: companyId, name: 'X' }, role });

describe('membership.service', () => {
  let warnSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => warnSpy.mockRestore());

  describe('verifyUserMemberships', () => {
    it('accepts the company owner (owner aggregate) with the admin role by default', async () => {
      serverData({ c1: { owner: { id: 'u1', name: 'U' } } });

      const result = await verifyUserMemberships('u1', [entry('c1', 'technician')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'admin' }]);
      expect(mockPrivateGet).not.toHaveBeenCalled();
    });

    it('keeps the owner role when the entry says owner or admin', async () => {
      serverData({ c1: { owner: { id: 'u1' } }, c2: { owner: { id: 'u1' } } });

      const result = await verifyUserMemberships('u1', [entry('c1', 'OWNER'), entry('c2', 'admin')]);

      expect(result).toEqual([
        { companyId: 'c1', role: 'owner' },
        { companyId: 'c2', role: 'admin' },
      ]);
    });

    it('accepts the legacy string owner field', async () => {
      serverData({ c1: { owner: 'u1' } });

      expect(await verifyUserMemberships('u1', [entry('c1')])).toEqual([{ companyId: 'c1', role: 'admin' }]);
    });

    it('takes the role from the server-only member map, not from the entry', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { other: 'admin', u1: 'Supervisor' } });

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'supervisor' }]);
    });

    it('maps an owner role in the member map to admin for non-owners', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { u1: 'owner' } });

      expect(await verifyUserMemberships('u1', [entry('c1', 'owner')])).toEqual([
        { companyId: 'c1', role: 'admin' },
      ]);
    });

    it('treats the company users array as display data only', async () => {
      serverData({ c1: { owner: { id: 'x' }, users: [{ user: { id: 'u1' }, role: 'admin' }] } });

      expect(await verifyUserMemberships('u1', [entry('c1', 'admin')])).toEqual([]);
    });

    it('treats membership documents as display data only', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, {}, { 'c1/u1': { role: 'admin' } });

      expect(await verifyUserMemberships('u1', [entry('c1', 'admin')])).toEqual([]);
      expect(mockMembershipGet).not.toHaveBeenCalled();
    });

    it('uses the member map role even when the users array disagrees', async () => {
      serverData(
        { c1: { owner: { id: 'x' }, users: [{ user: { id: 'u1' }, role: 'admin' }] } },
        { c1: { u1: 'technician' } },
      );

      expect(await verifyUserMemberships('u1', [entry('c1', 'admin')])).toEqual([
        { companyId: 'c1', role: 'technician' },
      ]);
    });

    it('drops entries without server-side backing and logs only identifiers', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { other: 'admin' } });

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([]);
      expect(warnSpy).toHaveBeenCalledTimes(1);
      const message = String(warnSpy.mock.calls[0][0]);
      expect(message).toContain('u1');
      expect(message).toContain('c1');
    });

    it('drops entries whose company does not exist', async () => {
      serverData({});

      expect(await verifyUserMemberships('u1', [entry('missing', 'admin')])).toEqual([]);
      expect(mockPrivateGet).not.toHaveBeenCalled();
    });

    it('drops a member map entry without a usable role', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { u1: '' } });

      expect(await verifyUserMemberships('u1', [entry('c1', 'admin')])).toEqual([]);
    });

    it('keeps the user order and ignores duplicates', async () => {
      serverData({ c1: { owner: { id: 'u1' } }, c2: { owner: { id: 'x' } } }, { c2: { u1: 'consultant' } });

      const result = await verifyUserMemberships('u1', [
        entry('c2', 'admin'),
        entry('c1', 'admin'),
        entry('c2', 'owner'),
      ]);

      expect(result).toEqual([
        { companyId: 'c2', role: 'consultant' },
        { companyId: 'c1', role: 'admin' },
      ]);
      expect(mockCompanyGet).toHaveBeenCalledTimes(2);
    });

    it('ignores malformed entries', async () => {
      serverData({ c1: { owner: { id: 'u1' } } });

      const result = await verifyUserMemberships('u1', [
        null,
        'c1',
        {},
        { company: {} },
        { company: { id: 42 } },
        { company: { id: '' } },
        entry('c1', 'admin'),
      ]);

      expect(result).toEqual([{ companyId: 'c1', role: 'admin' }]);
    });

    it('returns an empty list for a non-array input', async () => {
      expect(await verifyUserMemberships('u1', undefined as unknown as unknown[])).toEqual([]);
      expect(mockCompanyGet).not.toHaveBeenCalled();
    });
  });

  describe('verifyMembership', () => {
    it('returns the verified membership', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { u1: 'manager' } });

      expect(await verifyMembership('u1', 'c1')).toEqual({ companyId: 'c1', role: 'manager' });
    });

    it('returns admin for the owner when no entry role is given', async () => {
      serverData({ c1: { owner: { id: 'u1' } } });

      expect(await verifyMembership('u1', 'c1')).toEqual({ companyId: 'c1', role: 'admin' });
    });

    it('keeps the owner role when the entry role is owner', async () => {
      serverData({ c1: { owner: { id: 'u1' } } });

      expect(await verifyMembership('u1', 'c1', 'owner')).toEqual({ companyId: 'c1', role: 'owner' });
    });

    it('ignores the entry role for non-owners', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { c1: { u1: 'technician' } });

      expect(await verifyMembership('u1', 'c1', 'admin')).toEqual({ companyId: 'c1', role: 'technician' });
    });

    it('returns null without a server-only member map', async () => {
      serverData({ c1: { owner: { id: 'x' } } });

      expect(await verifyMembership('u1', 'c1')).toBeNull();
    });

    it('returns null when the company does not exist', async () => {
      serverData({});

      expect(await verifyMembership('u1', 'c1')).toBeNull();
    });
  });

  describe('buildRolesClaim', () => {
    it('maps only verified memberships to the roles claim', async () => {
      serverData(
        { c1: { owner: { id: 'u1' } }, c2: { owner: { id: 'x' } }, c3: { owner: { id: 'x' } } },
        { c2: { u1: 'Technician' } },
        { 'c3/u1': { role: 'admin' } },
      );

      const roles = await buildRolesClaim('u1', [
        entry('c1', 'admin'),
        entry('c2', 'admin'),
        entry('c3', 'admin'),
      ]);

      expect(roles).toEqual({ c1: 'admin', c2: 'technician' });
    });

    it('returns an empty map without entries', async () => {
      expect(await buildRolesClaim('u1', [])).toEqual({});
    });
  });
});
