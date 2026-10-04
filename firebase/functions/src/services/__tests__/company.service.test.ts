jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../firestore.service';
import { FakeFirestore, SERVER_TIMESTAMP } from '../../__tests__/helpers/fake-firestore';
import { addMemberToCompany, removeMember, updateMemberRole } from '../company.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;
const admin = { id: 'admin1', name: 'Admin' };

describe('company.service membership consistency', () => {
  beforeEach(() => {
    fake.docs.clear();
    fake.seed('companies/c1', { id: 'c1', name: 'C1', owner: admin, users: [] });
    fake.seed('users/u1', { id: 'u1', companies: [{ company: { id: 'c1', name: 'C1' }, role: 'technician' }] });
  });

  it('addMemberToCompany writes the server-only member map, users array and membership doc', async () => {
    await addMemberToCompany('c1', { id: 'u1', name: 'User' }, 'technician');

    expect(fake.read('companies/c1/private/membership')).toEqual({
      members: { u1: 'technician' },
      updatedAt: SERVER_TIMESTAMP,
    });
    expect(fake.read('companies/c1')?.users).toEqual([{ user: { id: 'u1', name: 'User' }, role: 'technician' }]);
    expect(fake.read('companies/c1/memberships/u1')).toEqual({
      user: { id: 'u1', name: 'User' },
      role: 'technician',
      joinedAt: SERVER_TIMESTAMP,
    });
  });

  it('addMemberToCompany keeps other members in the member map', async () => {
    fake.seed('companies/c1/private/membership', { members: { other: 'admin' } });

    await addMemberToCompany('c1', { id: 'u1', name: 'User' }, 'technician');

    expect(fake.read('companies/c1/private/membership')?.members).toEqual({ other: 'admin', u1: 'technician' });
  });

  it('updateMemberRole updates the member map, users array and an existing membership doc', async () => {
    fake.seed('companies/c1', {
      id: 'c1',
      owner: admin,
      users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }],
    });
    fake.seed('companies/c1/private/membership', { members: { u1: 'technician' } });
    fake.seed('companies/c1/memberships/u1', { role: 'technician' });

    expect(await updateMemberRole('c1', 'u1', 'manager', admin)).toBe(true);

    expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'manager' });
    expect(fake.read('companies/c1')?.users).toEqual([{ user: { id: 'u1', name: 'User' }, role: 'manager' }]);
    expect(fake.read('companies/c1/memberships/u1')?.role).toBe('manager');
    expect(fake.read('users/u1')?.companies).toEqual([{ company: { id: 'c1', name: 'C1' }, role: 'manager' }]);
  });

  it('updateMemberRole recognizes members present only in the member map', async () => {
    fake.seed('companies/c1/private/membership', { members: { u1: 'technician' } });

    expect(await updateMemberRole('c1', 'u1', 'supervisor', admin)).toBe(true);

    expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'supervisor' });
    expect(fake.read('companies/c1/memberships/u1')).toBeUndefined();
  });

  it('updateMemberRole returns false for non-members', async () => {
    expect(await updateMemberRole('c1', 'u1', 'manager', admin)).toBe(false);
    expect(fake.read('companies/c1/private/membership')).toBeUndefined();
  });

  it('removeMember removes the member from the member map, users array and membership doc', async () => {
    fake.seed('companies/c1', {
      id: 'c1',
      owner: admin,
      users: [{ user: { id: 'u1', name: 'User' }, role: 'technician' }],
    });
    fake.seed('companies/c1/private/membership', { members: { u1: 'technician', other: 'admin' } });
    fake.seed('companies/c1/memberships/u1', { role: 'technician' });

    expect(await removeMember('c1', 'u1', admin)).toBe(true);

    expect(fake.read('companies/c1/private/membership')?.members).toEqual({ other: 'admin' });
    expect(fake.read('companies/c1')?.users).toEqual([]);
    expect(fake.read('companies/c1/memberships/u1')).toBeUndefined();
    expect(fake.read('users/u1')?.companies).toEqual([]);
  });
});
