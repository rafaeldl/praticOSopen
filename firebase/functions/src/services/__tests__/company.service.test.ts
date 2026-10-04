const mockGetDocument = jest.fn();
const mockUpdateDocument = jest.fn();
const mockMembershipSet = jest.fn();
const mockMembershipUpdate = jest.fn();
const mockMembershipDelete = jest.fn();
const mockMembershipGet = jest.fn();
const mockUserGet = jest.fn();
const mockUserUpdate = jest.fn();
const membershipPaths: string[] = [];

jest.mock('../firestore.service', () => ({
  getRootCollection: (name: string) => ({ name }),
  getDocument: (...args: unknown[]) => mockGetDocument(...args),
  updateDocument: (...args: unknown[]) => mockUpdateDocument(...args),
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  db: {
    batch: () => ({ update: jest.fn(), delete: jest.fn(), commit: async () => undefined }),
    collection: (name: string) => {
      if (name === 'companies') {
        return {
          doc: (cid: string) => ({
            collection: () => ({
              doc: (uid: string) => {
                membershipPaths.push(`${cid}/${uid}`);
                return {
                  get: mockMembershipGet,
                  set: mockMembershipSet,
                  update: mockMembershipUpdate,
                  delete: mockMembershipDelete,
                };
              },
            }),
          }),
        };
      }
      if (name === 'users') {
        return { doc: () => ({ get: mockUserGet, update: mockUserUpdate }) };
      }
      if (name === 'links') {
        const empty = { empty: true, docs: [] };
        const query = { where: () => query, limit: () => query, get: async () => empty };
        return { doc: () => ({ collection: () => query }) };
      }
      throw new Error(`unexpected collection ${name}`);
    },
  },
}));

import { addMemberToCompany, removeMember, updateMemberRole } from '../company.service';

const admin = { id: 'admin1', name: 'Admin' };

describe('company.service membership consistency', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    membershipPaths.length = 0;
    mockUserGet.mockResolvedValue({ exists: true, data: () => ({ companies: [] }) });
  });

  it('addMemberToCompany also writes the membership document', async () => {
    mockGetDocument.mockResolvedValue({ id: 'c1', owner: admin, users: [] });

    await addMemberToCompany('c1', { id: 'u1', name: 'User' }, 'technician');

    expect(mockUpdateDocument).toHaveBeenCalledWith(
      { name: 'companies' },
      'c1',
      expect.objectContaining({ users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }] }),
    );
    expect(membershipPaths).toEqual(['c1/u1']);
    expect(mockMembershipSet).toHaveBeenCalledWith(
      { user: { id: 'u1', name: 'User' }, role: 'technician', joinedAt: 'SERVER_TIMESTAMP' },
      { merge: true },
    );
  });

  it('updateMemberRole also updates an existing membership document', async () => {
    mockGetDocument.mockResolvedValue({
      id: 'c1',
      owner: admin,
      users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }],
    });
    mockMembershipGet.mockResolvedValue({ exists: true });

    const ok = await updateMemberRole('c1', 'u1', 'manager', admin);

    expect(ok).toBe(true);
    expect(membershipPaths).toContain('c1/u1');
    expect(mockMembershipUpdate).toHaveBeenCalledWith({ role: 'manager' });
  });

  it('updateMemberRole does not create a missing membership document', async () => {
    mockGetDocument.mockResolvedValue({
      id: 'c1',
      owner: admin,
      users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }],
    });
    mockMembershipGet.mockResolvedValue({ exists: false });

    await updateMemberRole('c1', 'u1', 'manager', admin);

    expect(mockMembershipUpdate).not.toHaveBeenCalled();
    expect(mockMembershipSet).not.toHaveBeenCalled();
  });

  it('removeMember also deletes the membership document', async () => {
    mockGetDocument.mockResolvedValue({
      id: 'c1',
      owner: admin,
      users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }],
    });

    const ok = await removeMember('c1', 'u1', admin);

    expect(ok).toBe(true);
    expect(membershipPaths).toContain('c1/u1');
    expect(mockMembershipDelete).toHaveBeenCalled();
  });
});
