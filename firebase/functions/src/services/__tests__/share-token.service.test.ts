jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { generateShareToken, validateShareToken } from '../share-token.service';

const TOKENS = 'links/share/tokens';
const customer = { id: 'cu1', name: 'Cliente' };
const by = { id: 'u1', name: 'Usuário' };
const future = '2099-01-01T00:00:00.000Z';

describe('share-token.service: trocar o link desativa o anterior', () => {
  beforeEach(() => {
    resetFakeDb();
    seed(`${TOKENS}/ST_old`, {
      token: 'ST_old', orderId: 'o1', companyId: 'c1', permissions: ['view', 'approve'],
      customer, createdBy: by, createdAt: '2026-11-01T10:00:00.000Z', expiresAt: future, viewCount: 0,
    });
    seed(`${TOKENS}/ST_otherOrder`, {
      token: 'ST_otherOrder', orderId: 'o2', companyId: 'c1', permissions: ['view'],
      customer, createdBy: by, createdAt: '2026-11-01T10:00:00.000Z', expiresAt: future, viewCount: 0,
    });
    seed(`${TOKENS}/ST_otherCompany`, {
      token: 'ST_otherCompany', orderId: 'o1', companyId: 'c2', permissions: ['view'],
      customer, createdBy: by, createdAt: '2026-11-01T10:00:00.000Z', expiresAt: future, viewCount: 0,
    });
  });

  it('o link anterior da mesma OS para de valer, e o novo vale', async () => {
    expect(await validateShareToken('ST_old')).not.toBeNull();

    const fresh = await generateShareToken('o1', 'c1', customer, ['view'], by, 7);

    expect(await validateShareToken(fresh.token)).not.toBeNull();
    expect(await validateShareToken('ST_old')).toBeNull();
    // Kept with the date, not deleted: approval history stays on the token.
    expect(read(`${TOKENS}/ST_old`)?.revokedAt).toEqual(expect.any(String));
  });

  it('links de outra OS e de outra empresa continuam valendo', async () => {
    await generateShareToken('o1', 'c1', customer, ['view'], by, 7);

    expect(await validateShareToken('ST_otherOrder')).not.toBeNull();
    expect(await validateShareToken('ST_otherCompany')).not.toBeNull();
  });

  it('não desativa link mais novo que o recém-criado (dois pedidos ao mesmo tempo)', async () => {
    seed(`${TOKENS}/ST_newer`, {
      token: 'ST_newer', orderId: 'o1', companyId: 'c1', permissions: ['view'],
      customer, createdBy: by, createdAt: '2099-01-01T00:00:00.000Z', expiresAt: future, viewCount: 0,
    });

    await generateShareToken('o1', 'c1', customer, ['view'], by, 7);

    expect(await validateShareToken('ST_newer')).not.toBeNull();
  });
});
