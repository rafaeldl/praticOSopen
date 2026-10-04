const mockCompanyGet = jest.fn();
const mockMembershipGet = jest.fn();

jest.mock('../firestore.service', () => ({
  db: {
    collection: (name: string) => {
      if (name !== 'companies') throw new Error(`unexpected collection ${name}`);
      return {
        doc: (companyId: string) => ({
          get: () => mockCompanyGet(companyId),
          collection: (sub: string) => {
            if (sub !== 'memberships') throw new Error(`unexpected subcollection ${sub}`);
            return {
              doc: (memberId: string) => ({
                get: () => mockMembershipGet(companyId, memberId),
              }),
            };
          },
        }),
      };
    },
  },
}));

import { verifyMembership, verifyUserMemberships } from '../membership.service';

type Data = Record<string, unknown>;

function snap(data: Data | null) {
  return { exists: !!data, data: () => data ?? undefined };
}

/** Configures server data: companies by id and memberships by `${cid}/${uid}`. */
function serverData(companies: Record<string, Data>, memberships: Record<string, Data> = {}) {
  mockCompanyGet.mockImplementation(async (cid: string) => snap(companies[cid] ?? null));
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

      const result = await verifyUserMemberships('u1', [entry('c1')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'admin' }]);
    });

    it('takes the role from the company users array, not from the entry', async () => {
      serverData({
        c1: {
          owner: { id: 'someone-else' },
          users: [
            { user: { id: 'other' }, role: 'admin' },
            { user: { id: 'u1' }, role: 'Supervisor' },
          ],
        },
      });

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'supervisor' }]);
    });

    it('takes the role from the membership document when not in the users array', async () => {
      serverData(
        { c1: { owner: { id: 'someone-else' }, users: [] } },
        { 'c1/u1': { role: 'manager' } },
      );

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'manager' }]);
    });

    it('prefers the users array over the membership document', async () => {
      serverData(
        { c1: { owner: { id: 'x' }, users: [{ user: { id: 'u1' }, role: 'technician' }] } },
        { 'c1/u1': { role: 'admin' } },
      );

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([{ companyId: 'c1', role: 'technician' }]);
      expect(mockMembershipGet).not.toHaveBeenCalled();
    });

    it('drops entries without server-side backing and logs only identifiers', async () => {
      serverData({ c1: { owner: { id: 'x' }, users: [] } });

      const result = await verifyUserMemberships('u1', [entry('c1', 'admin')]);

      expect(result).toEqual([]);
      expect(warnSpy).toHaveBeenCalledTimes(1);
      const message = String(warnSpy.mock.calls[0][0]);
      expect(message).toContain('u1');
      expect(message).toContain('c1');
    });

    it('drops entries whose company does not exist', async () => {
      serverData({});

      const result = await verifyUserMemberships('u1', [entry('missing', 'admin')]);

      expect(result).toEqual([]);
      expect(mockMembershipGet).not.toHaveBeenCalled();
    });

    it('drops a membership document without a role', async () => {
      serverData({ c1: { owner: { id: 'x' } } }, { 'c1/u1': { user: { id: 'u1' } } });

      expect(await verifyUserMemberships('u1', [entry('c1', 'admin')])).toEqual([]);
    });

    it('keeps the user order and ignores duplicates', async () => {
      serverData({
        c1: { owner: { id: 'u1' } },
        c2: { owner: { id: 'x' }, users: [{ user: { id: 'u1' }, role: 'consultant' }] },
      });

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
      serverData({ c1: { owner: { id: 'x' }, users: [{ user: { id: 'u1' }, role: 'manager' }] } });

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
      serverData({ c1: { owner: { id: 'x' } } }, { 'c1/u1': { role: 'technician' } });

      expect(await verifyMembership('u1', 'c1', 'admin')).toEqual({ companyId: 'c1', role: 'technician' });
    });

    it('returns null when not a member', async () => {
      serverData({ c1: { owner: { id: 'x' } } });

      expect(await verifyMembership('u1', 'c1')).toBeNull();
    });

    it('returns null when the company does not exist', async () => {
      serverData({});

      expect(await verifyMembership('u1', 'c1')).toBeNull();
    });
  });
});
