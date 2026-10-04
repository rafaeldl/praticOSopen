jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

jest.mock('../channel-link.service', () => ({
  getWhatsAppLink: jest.fn(async () => null),
  getUserByPhone: jest.fn(async () => null),
  createUserFromWhatsApp: jest.fn(async () => 'wa_user_1'),
  linkWhatsApp: jest.fn(async () => undefined),
}));

import * as firestoreService from '../firestore.service';
import * as channelLinkService from '../channel-link.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { acceptInvite, acceptInviteViaWhatsApp, generateToken, normalizeInviteCode } from '../invite.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;
const mockChannel = channelLinkService as jest.Mocked<typeof channelLinkService>;

const future = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const INVITE_PATH = 'links/invites/tokens/INV_ABC';

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

function seedInvite(overrides: Record<string, unknown> = {}) {
  fake.seed(INVITE_PATH, { ...baseInvite, ...overrides });
}

describe('invite.service', () => {
  let warnSpy: jest.SpyInstance;

  beforeEach(() => {
    fake.docs.clear();
    jest.clearAllMocks();
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    fake.seed('companies/c1', { id: 'c1', name: 'Company 1', owner: { id: 'admin1' }, users: [] });
    fake.seed('users/u1', { id: 'u1', companies: [] });
  });
  afterEach(() => warnSpy.mockRestore());

  describe('acceptInvite', () => {
    it('registers the member, updates the user and marks the invite accepted', async () => {
      seedInvite({ email: 'invited@example.com' });

      const result = await acceptInvite('INV_ABC', 'u1', 'User', 'invited@EXAMPLE.com');

      expect(result).toEqual({ success: true, companyId: 'c1', companyName: 'Company 1', role: 'technician' });
      expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'technician' });
      expect(fake.read('companies/c1/memberships/u1')?.role).toBe('technician');
      expect(fake.read('users/u1')?.companies).toEqual([
        { company: { id: 'c1', name: 'Company 1' }, role: 'technician' },
      ]);
      expect(fake.read(INVITE_PATH)).toMatchObject({ status: 'accepted', acceptedByUserId: 'u1' });
      expect(warnSpy).not.toHaveBeenCalled();
    });

    it('rejects an existing member with ALREADY_MEMBER and keeps the current role', async () => {
      seedInvite({ role: 'admin' });
      fake.seed('companies/c1/private/membership', { members: { u1: 'technician' } });

      const result = await acceptInvite('INV_ABC', 'u1', 'User', undefined);

      expect(result).toEqual({
        success: false,
        code: 'ALREADY_MEMBER',
        error: 'User is already a member of this company',
      });
      expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'technician' });
      expect(fake.read(INVITE_PATH)?.status).toBe('pending');
    });

    it('rejects the company owner with ALREADY_MEMBER', async () => {
      seedInvite();

      const result = await acceptInvite('INV_ABC', 'admin1', 'Admin', undefined);

      expect(result).toMatchObject({ success: false, code: 'ALREADY_MEMBER' });
      expect(fake.read('companies/c1/private/membership')).toBeUndefined();
    });

    it('only accepts pending invites', async () => {
      seedInvite({ status: 'accepted' });
      expect(await acceptInvite('INV_ABC', 'u1', 'User')).toEqual({
        success: false,
        error: 'Invite has already been used',
      });

      seedInvite({ status: undefined });
      expect(await acceptInvite('INV_ABC', 'u1', 'User')).toMatchObject({ success: false });
      expect(fake.read('companies/c1/private/membership')).toBeUndefined();
    });

    it('can be accepted only once', async () => {
      seedInvite();
      fake.seed('users/u2', { id: 'u2', companies: [] });

      const first = await acceptInvite('INV_ABC', 'u1', 'User');
      const second = await acceptInvite('INV_ABC', 'u2', 'Other');

      expect(first).toMatchObject({ success: true });
      expect(second).toEqual({ success: false, error: 'Invite has already been used' });
      expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'technician' });
    });

    it('rejects expired invites', async () => {
      seedInvite({ expiresAt: new Date(Date.now() - 1000).toISOString() });

      expect(await acceptInvite('INV_ABC', 'u1', 'User')).toEqual({ success: false, error: 'Invite has expired' });
    });

    it('accepts with a different login email and logs only masked identifiers', async () => {
      seedInvite({ email: 'invited@example.com' });

      const result = await acceptInvite('INV_ABC', 'user123456789', 'User', 'relay@privaterelay.example');

      expect(result).toMatchObject({ success: true, companyId: 'c1' });
      expect(warnSpy).toHaveBeenCalledTimes(1);
      const message = String(warnSpy.mock.calls[0][0]);
      expect(message).toContain('INV_***');
      expect(message).not.toContain('INV_ABC');
      expect(message).toContain('user12');
      expect(message).not.toContain('user123456789');
      expect(message).not.toContain('@');
    });

    it('accepts phone invites without comparing emails', async () => {
      seedInvite({ phone: '+5548999999999' });

      expect(await acceptInvite('INV_ABC', 'u1', 'User', undefined)).toMatchObject({ success: true });
      expect(warnSpy).not.toHaveBeenCalled();
    });
  });

  describe('acceptInviteViaWhatsApp', () => {
    it('registers a new member atomically and links WhatsApp', async () => {
      seedInvite({ channel: 'whatsapp', phone: '+5548999999999' });
      fake.seed('users/wa_user_1', { id: 'wa_user_1', companies: [] });

      const result = await acceptInviteViaWhatsApp('INV_ABC', '+5548999999999', 'Tech');

      expect(result).toMatchObject({ success: true, userId: 'wa_user_1', companyId: 'c1', role: 'technician' });
      expect(fake.read('companies/c1/private/membership')?.members).toEqual({ wa_user_1: 'technician' });
      expect(fake.read(INVITE_PATH)?.status).toBe('accepted');
      expect(mockChannel.linkWhatsApp).toHaveBeenCalled();
    });

    it('rejects an existing member with ALREADY_MEMBER without linking or changing the role', async () => {
      seedInvite({ channel: 'whatsapp', role: 'admin' });
      mockChannel.getUserByPhone.mockResolvedValueOnce({ id: 'u1', name: 'User' } as never);
      fake.seed('companies/c1/private/membership', { members: { u1: 'technician' } });

      const result = await acceptInviteViaWhatsApp('INV_ABC', '+5548999999999');

      expect(result).toMatchObject({ success: false, code: 'ALREADY_MEMBER' });
      expect(fake.read('companies/c1/private/membership')?.members).toEqual({ u1: 'technician' });
      expect(fake.read(INVITE_PATH)?.status).toBe('pending');
      expect(mockChannel.linkWhatsApp).not.toHaveBeenCalled();
    });

    it('rejects invites that are not pending', async () => {
      seedInvite({ status: 'rejected' });

      expect(await acceptInviteViaWhatsApp('INV_ABC', '+5548999999999')).toMatchObject({ success: false });
      expect(mockChannel.createUserFromWhatsApp).not.toHaveBeenCalled();
    });
  });

  describe('tokens', () => {
    it('generates INV_ tokens with at least 16 uppercase alphanumeric characters', () => {
      const tokens = new Set(Array.from({ length: 200 }, () => generateToken()));
      expect(tokens.size).toBe(200);
      for (const token of tokens) {
        expect(token).toMatch(/^INV_[A-Z0-9]{16,}$/);
        expect(normalizeInviteCode(token.toLowerCase())).toBe(token);
      }
    });

    it('keeps accepting existing short tokens', async () => {
      fake.seed('links/invites/tokens/INV_AB12CD34', { ...baseInvite, token: 'INV_AB12CD34' });

      expect(await acceptInvite(normalizeInviteCode('ab12cd34'), 'u1', 'User')).toMatchObject({ success: true });
    });
  });
});
