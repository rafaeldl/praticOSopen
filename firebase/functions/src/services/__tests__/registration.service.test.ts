jest.mock('../firestore.service', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const mod = require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule();
  return {
    ...mod,
    auth: {
      getUserByPhoneNumber: jest.fn(async () => {
        throw { code: 'auth/user-not-found' };
      }),
      createUser: jest.fn(async () => ({ uid: 'newowner1' })),
    },
  };
});
jest.mock('../channel-link.service', () => ({ linkWhatsApp: jest.fn() }));
jest.mock('../bootstrap-server.service', () => ({ executeServerBootstrap: jest.fn() }));

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { completeRegistration } from '../registration.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

describe('registration.service completeRegistration', () => {
  beforeEach(() => {
    fake.docs.clear();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    fake.seed('links/registrations/tokens/RG_1', {
      token: 'RG_1',
      whatsappNumber: '+5548999990000',
      state: 'awaiting_confirm',
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
      data: { companyName: 'Oficina', segmentId: 'other', locale: 'pt-BR' },
    });
  });
  afterEach(() => jest.restoreAllMocks());

  it('registers the owner in the server-only member map of the new company', async () => {
    const result = await completeRegistration('RG_1');

    expect(result).toMatchObject({ success: true, userId: 'newowner1' });
    const companyId = (result as { companyId: string }).companyId;
    expect(fake.read(`companies/${companyId}`)?.owner).toEqual({ id: 'newowner1', name: 'Oficina' });
    expect(fake.read(`companies/${companyId}/private/membership`)?.members).toEqual({ newowner1: 'owner' });
  });
});
