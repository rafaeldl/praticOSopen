const mockDeleteUser = jest.fn();
const mockDeleteFiles = jest.fn();

jest.mock('../firestore.service', () => ({
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  ...require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
  auth: { deleteUser: (...args: unknown[]) => mockDeleteUser(...args) },
  storage: { bucket: () => ({ deleteFiles: (...args: unknown[]) => mockDeleteFiles(...args) }) },
}));

import * as firestoreService from '../firestore.service';
import type { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { companyIdsFromEntries, defaultAccountDeletionDeps, readCompanyInfo } from '../account-deletion.deps';
import { deleteAccount } from '../account-deletion.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

beforeEach(() => {
  fake.reset();
  mockDeleteUser.mockReset().mockResolvedValue(undefined);
  mockDeleteFiles.mockReset().mockResolvedValue(undefined);
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

describe('companyIdsFromEntries', () => {
  it('keeps only entries with a string company id', () => {
    expect(
      companyIdsFromEntries([
        { company: { id: 'c1' }, role: 'owner' },
        null,
        'c2',
        { company: null },
        { company: { id: 42 } },
        { company: { id: '' } },
        {},
        { company: { id: 'c3' } },
      ]),
    ).toEqual(['c1', 'c3']);
  });

  it('non-array → []', () => {
    expect(companyIdsFromEntries(undefined)).toEqual([]);
    expect(companyIdsFromEntries({ c1: true })).toEqual([]);
  });
});

describe('readCompanyInfo', () => {
  it('missing company → exists false', async () => {
    expect((await readCompanyInfo('nope', 'u1')).exists).toBe(false);
  });

  it('app-created company with only the owner → no other members, no map role', async () => {
    fake.seed('companies/c1', { owner: { id: 'u1', name: 'A' }, users: [{ user: { id: 'u1' }, role: 'owner' }] });
    fake.seed('companies/c1/memberships/u1', { role: 'owner' });

    expect(await readCompanyInfo('c1', 'u1')).toEqual({
      exists: true,
      ownerId: 'u1',
      privateRole: null,
      otherOwnerInPrivateMap: false,
      hasOtherMembers: false,
      isMember: true,
    });
  });

  it('other member only in the private map → hasOtherMembers', async () => {
    fake.seed('companies/c1', { owner: { id: 'u1' } });
    fake.seed('companies/c1/private/membership', { members: { u2: 'technician' } });

    expect((await readCompanyInfo('c1', 'u1')).hasOtherMembers).toBe(true);
  });

  it('other member only in company.users (old companies) → hasOtherMembers', async () => {
    fake.seed('companies/c1', { owner: { id: 'u1' }, users: [{ user: { id: 'u1' } }, { user: { id: 'u2' } }, null] });

    expect((await readCompanyInfo('c1', 'u1')).hasOtherMembers).toBe(true);
  });

  it('reads the uid role and other owners from the private map', async () => {
    fake.seed('companies/c1', { owner: { id: 'u1' } });
    fake.seed('companies/c1/private/membership', { members: { u1: 'Admin', u9: 'owner' } });

    const info = await readCompanyInfo('c1', 'u1');
    expect(info.privateRole).toBe('admin');
    expect(info.otherOwnerInPrivateMap).toBe(true);
    expect(info.isMember).toBe(true);
  });

  it('not in memberships nor in the map → isMember false', async () => {
    fake.seed('companies/c1', { owner: { id: 'u1' }, users: [{ user: { id: 'u2' } }] });
    expect((await readCompanyInfo('c1', 'u2')).isMember).toBe(false);
  });
});

describe('defaultAccountDeletionDeps', () => {
  it('getUserCompanyIds: null when the user doc is gone, ignores malformed entries', async () => {
    const deps = defaultAccountDeletionDeps();
    expect(await deps.getUserCompanyIds('u1')).toBeNull();
    fake.seed('users/u1', { companies: [{ company: { id: 'c1' } }, { bad: true }] });
    expect(await deps.getUserCompanyIds('u1')).toEqual(['c1']);
  });

  it('getOwnedCompanyIds: owner as map or legacy string', async () => {
    fake.seed('companies/a', { owner: { id: 'u1' } });
    fake.seed('companies/b', { owner: 'u1' });
    fake.seed('companies/c', { owner: { id: 'u2' } });
    expect((await defaultAccountDeletionDeps().getOwnedCompanyIds('u1')).sort()).toEqual(['a', 'b']);
  });

  it('deleteAuthUser: user-not-found → false, other errors rethrow', async () => {
    const deps = defaultAccountDeletionDeps();
    mockDeleteUser.mockRejectedValueOnce(Object.assign(new Error('x'), { code: 'auth/user-not-found' }));
    expect(await deps.deleteAuthUser('u1')).toBe(false);
    mockDeleteUser.mockRejectedValueOnce(Object.assign(new Error('x'), { code: 'auth/internal-error' }));
    await expect(deps.deleteAuthUser('u1')).rejects.toThrow('x');
  });

  it('end to end (fake Firestore): member leaves, photo removed, user doc and links deleted', async () => {
    fake.seed('users/u2', { companies: [{ company: { id: 'c1' } }] });
    fake.seed('companies/c1', { owner: { id: 'u1' }, users: [{ user: { id: 'u1' } }, { user: { id: 'u2' } }] });
    fake.seed('companies/c1/memberships/u1', { role: 'owner' });
    fake.seed('companies/c1/memberships/u2', { role: 'technician' });
    fake.seed('companies/c1/private/membership', { members: { u2: 'technician' } });
    fake.seed('links/whatsapp/numbers/+55', { userId: 'u2', companyId: 'c1' });

    const result = await deleteAccount('u2', defaultAccountDeletionDeps());

    expect(result).toEqual({ deletedCompanies: 0, leftCompanies: 1, authUserDeleted: true });
    expect(mockDeleteFiles).toHaveBeenCalledWith({ prefix: 'tenants/c1/users/u2/' });
    expect(fake.read('companies/c1/memberships/u2')).toBeUndefined();
    expect(fake.read('companies/c1/private/membership')?.members).toEqual({});
    expect(fake.read('companies/c1')?.users).toEqual([{ user: { id: 'u1' } }]);
    expect(fake.read('links/whatsapp/numbers/+55')).toBeUndefined();
    expect(fake.read('users/u2')).toBeUndefined();
    expect(mockDeleteUser).toHaveBeenCalledWith('u2');
  });

  it('end to end: sole owner company tree and storage deleted', async () => {
    fake.seed('users/u1', { companies: [{ company: { id: 'c1' } }] });
    fake.seed('companies/c1', { owner: { id: 'u1' } });
    fake.seed('companies/c1/memberships/u1', { role: 'owner' });
    fake.seed('companies/c1/settings/ai', { enabled: true });
    fake.seed('companies/c1/orders/o1', { number: 1 });

    await deleteAccount('u1', defaultAccountDeletionDeps());

    expect(fake.docs.size).toBe(0);
    expect(mockDeleteFiles).toHaveBeenCalledWith({ prefix: 'tenants/c1/' });
    expect(mockDeleteFiles).toHaveBeenCalledWith({ prefix: 'companies/c1/' });
  });
});
