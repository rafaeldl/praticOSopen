const mockInviteGet = jest.fn();
const mockInviteUpdate = jest.fn();
const mockUserGet = jest.fn();
const mockUserUpdate = jest.fn();

jest.mock('../firestore.service', () => ({
  db: {
    collection: (name: string) => {
      if (name === 'links') {
        return {
          doc: () => ({
            collection: () => ({
              doc: () => ({ get: mockInviteGet, update: mockInviteUpdate }),
            }),
          }),
        };
      }
      if (name === 'users') {
        return { doc: () => ({ get: mockUserGet, update: mockUserUpdate }) };
      }
      throw new Error(`unexpected collection ${name}`);
    },
  },
}));

jest.mock('../company.service', () => ({
  addMemberToCompany: jest.fn(),
  getCompany: jest.fn(),
}));

jest.mock('../channel-link.service', () => ({}));

import { acceptInvite } from '../invite.service';
import * as companyService from '../company.service';

const mockAddMember = companyService.addMemberToCompany as jest.MockedFunction<
  typeof companyService.addMemberToCompany
>;

function inviteSnap(data: Record<string, unknown> | null) {
  return {
    exists: !!data,
    data: () => data,
    ref: { update: mockInviteUpdate },
  };
}

const future = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

const baseInvite = {
  token: 'INV_ABC',
  company: { id: 'c1', name: 'Company 1' },
  role: 'technician',
  invitedBy: { id: 'admin1', name: 'Admin' },
  status: 'pending',
  createdAt: new Date().toISOString(),
  expiresAt: future,
  channel: 'app',
};

describe('invite.service acceptInvite', () => {
  afterEach(() => warnSpy.mockRestore());

  let warnSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    mockUserGet.mockResolvedValue({ exists: true, data: () => ({ companies: [] }) });
  });

  it('accepts when the caller email differs and logs only identifiers', async () => {
    mockInviteGet.mockResolvedValue(inviteSnap({ ...baseInvite, email: 'invited@example.com' }));

    const result = await acceptInvite('INV_ABC', 'user123456789', 'User', 'relay@privaterelay.example');

    expect(result).toMatchObject({ success: true, companyId: 'c1' });
    expect(mockAddMember).toHaveBeenCalled();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    const message = String(warnSpy.mock.calls[0][0]);
    expect(message).toContain('INV_ABC');
    expect(message).toContain('user12');
    expect(message).not.toContain('user123456789');
    expect(message).not.toContain('@');
  });

  it('accepts when the invite has an email and the caller has none', async () => {
    mockInviteGet.mockResolvedValue(inviteSnap({ ...baseInvite, email: 'invited@example.com' }));

    const result = await acceptInvite('INV_ABC', 'u1', 'User', undefined);

    expect(result).toMatchObject({ success: true });
    expect(warnSpy).toHaveBeenCalledTimes(1);
  });

  it('accepts when the email matches ignoring case and surrounding spaces', async () => {
    mockInviteGet.mockResolvedValue(inviteSnap({ ...baseInvite, email: ' Invited@Example.com' }));

    const result = await acceptInvite('INV_ABC', 'u1', 'User', 'invited@EXAMPLE.com');

    expect(result).toEqual({
      success: true,
      companyId: 'c1',
      companyName: 'Company 1',
      role: 'technician',
    });
    expect(mockAddMember).toHaveBeenCalledWith('c1', { id: 'u1', name: 'User' }, 'technician');
    expect(warnSpy).not.toHaveBeenCalled();
    expect(mockUserUpdate).toHaveBeenCalledWith({
      companies: [{ company: { id: 'c1', name: 'Company 1' }, role: 'technician' }],
    });
    expect(mockInviteUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'accepted', acceptedByUserId: 'u1' }),
    );
  });

  it('accepts invites without email (phone invites) regardless of the caller email', async () => {
    mockInviteGet.mockResolvedValue(inviteSnap({ ...baseInvite, phone: '+5548999999999' }));

    const result = await acceptInvite('INV_ABC', 'u1', 'User', undefined);

    expect(result).toMatchObject({ success: true, companyId: 'c1' });
    expect(mockAddMember).toHaveBeenCalled();
  });

  it('keeps rejecting invites that were already used', async () => {
    mockInviteGet.mockResolvedValue(
      inviteSnap({ ...baseInvite, email: 'invited@example.com', status: 'accepted' }),
    );

    const result = await acceptInvite('INV_ABC', 'u1', 'User', 'invited@example.com');

    expect(result).toEqual({ success: false, error: 'Invite has already been used' });
    expect(mockAddMember).not.toHaveBeenCalled();
  });
});
