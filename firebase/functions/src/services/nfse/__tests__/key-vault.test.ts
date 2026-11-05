import type { KeyManagementServiceClient } from '@google-cloud/kms';
import { DESTROY_SCHEDULED_SECONDS, emitterKeyId, KmsKeyVault } from '../key-vault';

const config = { projectId: 'demo-praticos', location: 'southamerica-east1', keyRing: 'nfse-certs' };

function fakeClient(overrides: Record<string, jest.Mock> = {}) {
  const client = {
    keyRingPath: (p: string, l: string, r: string) => `projects/${p}/locations/${l}/keyRings/${r}`,
    cryptoKeyPath: (p: string, l: string, r: string, k: string) => `projects/${p}/locations/${l}/keyRings/${r}/cryptoKeys/${k}`,
    createCryptoKey: jest.fn(async () => [{}]),
    createCryptoKeyVersion: jest.fn(async () => [{ name: 'projects/x/cryptoKeys/emitter-e1/cryptoKeyVersions/2' }]),
    updateCryptoKeyPrimaryVersion: jest.fn(async () => [{}]),
    encrypt: jest.fn(async () => [{ name: 'k/cryptoKeyVersions/1', ciphertext: Buffer.from('wrapped') }]),
    decrypt: jest.fn(async () => [{ plaintext: Buffer.from('dek') }]),
    destroyCryptoKeyVersion: jest.fn(async () => [{}]),
    ...overrides,
  };
  const vault = new KmsKeyVault(config, async () => client as unknown as KeyManagementServiceClient);
  return { client, vault };
}

const KEY = 'projects/demo-praticos/locations/southamerica-east1/keyRings/nfse-certs/cryptoKeys/emitter-e1';

describe('KmsKeyVault', () => {
  it('creates one key per emitter, with destruction scheduled for 24 h', async () => {
    const { client, vault } = fakeClient();
    await vault.prepareKey('e1');
    expect(client.createCryptoKey).toHaveBeenCalledWith(
      expect.objectContaining({
        parent: 'projects/demo-praticos/locations/southamerica-east1/keyRings/nfse-certs',
        cryptoKeyId: 'emitter-e1',
        cryptoKey: expect.objectContaining({
          purpose: 'ENCRYPT_DECRYPT',
          destroyScheduledDuration: { seconds: DESTROY_SCHEDULED_SECONDS },
        }),
      }),
    );
    expect(DESTROY_SCHEDULED_SECONDS).toBe(86400);
    expect(client.createCryptoKeyVersion).not.toHaveBeenCalled();
  });

  it('an existing key gets a new primary version (renewal or a certificate sent again)', async () => {
    const { client, vault } = fakeClient({
      createCryptoKey: jest.fn(async () => {
        throw Object.assign(new Error('exists'), { code: 6 });
      }),
    });
    await vault.prepareKey('e1');
    expect(client.createCryptoKeyVersion).toHaveBeenCalledWith({ parent: KEY, cryptoKeyVersion: {} });
    expect(client.updateCryptoKeyPrimaryVersion).toHaveBeenCalledWith({ name: KEY, cryptoKeyVersionId: '2' });
  });

  it('wraps and unwraps with the additional data', async () => {
    const { client, vault } = fakeClient();
    const aad = Buffer.from('aad');
    expect(await vault.wrap('e1', Buffer.from('dek'), aad)).toEqual({
      wrappedDek: Buffer.from('wrapped'),
      keyVersion: 'k/cryptoKeyVersions/1',
    });
    expect(client.encrypt).toHaveBeenCalledWith({ name: KEY, plaintext: Buffer.from('dek'), additionalAuthenticatedData: aad });
    expect((await vault.unwrap('e1', Buffer.from('wrapped'), aad)).toString()).toBe('dek');
  });

  it('a destroyed version reads as "no certificate"', async () => {
    const { vault } = fakeClient({
      decrypt: jest.fn(async () => {
        throw Object.assign(new Error('destroyed'), { code: 9 });
      }),
    });
    await expect(vault.unwrap('e1', Buffer.from('x'), Buffer.from('a'))).rejects.toMatchObject({ code: 'CERT_NOT_FOUND' });
  });

  it('other KMS failures are KEY_VAULT_UNAVAILABLE', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    const { vault } = fakeClient({
      encrypt: jest.fn(async () => {
        throw Object.assign(new Error('denied'), { code: 7 });
      }),
    });
    await expect(vault.wrap('e1', Buffer.from('d'), Buffer.from('a'))).rejects.toMatchObject({ code: 'KEY_VAULT_UNAVAILABLE' });
  });

  it('destroying an already destroyed version is fine', async () => {
    const { client, vault } = fakeClient({
      destroyCryptoKeyVersion: jest.fn(async () => {
        throw Object.assign(new Error('already'), { code: 9 });
      }),
    });
    await expect(vault.destroyVersion('k/cryptoKeyVersions/1')).resolves.toBeUndefined();
    expect(client.destroyCryptoKeyVersion).toHaveBeenCalledWith({ name: 'k/cryptoKeyVersions/1' });
  });

  it('refuses emitter ids that would not be a valid key id', () => {
    expect(emitterKeyId('abcDEF_1-2')).toBe('emitter-abcDEF_1-2');
    expect(() => emitterKeyId('../x')).toThrow();
  });
});
