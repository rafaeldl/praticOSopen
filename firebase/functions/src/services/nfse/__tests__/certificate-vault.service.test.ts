jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { fakeDb, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import {
  deleteCertificate,
  deleteCompanyCertificates,
  loadCertificate,
  NFSE_CERTIFICATE_TERMS_VERSION,
  processPendingKeyDestructions,
  purgeExpiredCertificates,
  storeCertificate,
  type VaultDeps,
} from '../certificate-vault.service';
import { NfseServiceError } from '../errors';
import type { KeyVault } from '../key-vault';
import { testPki } from './test-certificates';

/** In-memory KMS: one key per emitter, versions with their own AES key, destroy = key gone. */
class FakeKeyVault implements KeyVault {
  keys = new Map<string, { versions: Array<{ name: string; key: Buffer | null }>; primary: number }>();
  calls: string[] = [];
  failDestroy = false;

  async prepareKey(emitterId: string) {
    this.calls.push(`prepare:${emitterId}`);
    const entry = this.keys.get(emitterId) ?? { versions: [], primary: -1 };
    entry.versions.push({ name: `kms/emitter-${emitterId}/v${entry.versions.length + 1}`, key: randomBytes(32) });
    entry.primary = entry.versions.length - 1;
    this.keys.set(emitterId, entry);
  }
  async wrap(emitterId: string, dek: Buffer, aad: Buffer) {
    const entry = this.keys.get(emitterId)!;
    const version = entry.versions[entry.primary];
    const iv = randomBytes(12);
    const c = createCipheriv('aes-256-gcm', version.key!, iv);
    c.setAAD(aad);
    const out = Buffer.concat([iv, c.update(dek), c.final(), c.getAuthTag()]);
    return { wrappedDek: Buffer.concat([Buffer.from([entry.primary]), out]), keyVersion: version.name };
  }
  async unwrap(emitterId: string, wrapped: Buffer, aad: Buffer) {
    const version = this.keys.get(emitterId)?.versions[wrapped[0]];
    if (!version?.key) throw new NfseServiceError('CERT_NOT_FOUND', 'destroyed');
    const body = wrapped.subarray(1);
    const d = createDecipheriv('aes-256-gcm', version.key, body.subarray(0, 12));
    d.setAAD(aad);
    d.setAuthTag(body.subarray(body.length - 16));
    return Buffer.concat([d.update(body.subarray(12, body.length - 16)), d.final()]);
  }
  async destroyVersion(name: string) {
    this.calls.push(`destroy:${name}`);
    if (this.failDestroy) throw new NfseServiceError('KEY_VAULT_UNAVAILABLE', 'down');
    for (const entry of this.keys.values()) for (const v of entry.versions) if (v.name === name) v.key = null;
  }
}

const pki = testPki();
const NOW = new Date('2026-11-05T12:00:00Z');
const actor = { user: { id: 'u1', name: 'Dono' }, device: 'iOS 1.104.0', ip: '203.0.113.1' };
let vault: FakeKeyVault;
let deps: Partial<VaultDeps>;

function input(overrides: Partial<Parameters<typeof storeCertificate>[0]> = {}) {
  return {
    companyId: 'c1',
    pfx: pki.pfx(),
    password: 'senha-teste',
    termsVersion: NFSE_CERTIFICATE_TERMS_VERSION,
    actor,
    ...overrides,
  };
}

function docsUnder(prefix: string) {
  return [...((fakeDb as unknown as { docs: Map<string, Record<string, unknown>> }).docs.entries())]
    .filter(([path]) => path.startsWith(prefix))
    .map(([, value]) => value);
}

async function codeOf(promise: Promise<unknown>) {
  try {
    await promise;
  } catch (error) {
    return (error as NfseServiceError).code;
  }
  return undefined;
}

beforeEach(() => {
  resetFakeDb();
  vault = new FakeKeyVault();
  deps = { vault, now: () => NOW, certificateOptions: { trustedRoots: [pki.rootPem] } };
});

describe('storeCertificate', () => {
  it('creates the emitter, stores only sealed material and audits the upload', async () => {
    const result = await storeCertificate(input(), deps);
    expect(result).toMatchObject({ created: true, taxId: '00000000000191', holderName: 'OFICINA EXEMPLO LTDA' });

    const emitter = read(`companies/c1/fiscalEmitters/${result.emitterId}`)!;
    expect(emitter).toMatchObject({
      taxId: '00000000000191',
      legalName: 'OFICINA EXEMPLO LTDA',
      certificate: { holderName: 'OFICINA EXEMPLO LTDA', notAfter: '2027-03-12T00:00:00.000Z', status: 'active' },
    });

    const stored = read(`nfseCertificates/${result.emitterId}`)!;
    expect(stored).toMatchObject({ companyId: 'c1', status: 'active', termsVersion: NFSE_CERTIFICATE_TERMS_VERSION });
    // Nothing readable: no PEM, no password, no PFX anywhere in Firestore.
    const everything = JSON.stringify([...(fakeDb as unknown as { docs: Map<string, unknown> }).docs.entries()]);
    expect(everything).not.toContain('PRIVATE KEY');
    expect(everything).not.toContain('senha-teste');
    expect(everything).not.toContain(pki.pfx().toString('base64').slice(0, 40));

    const audit = docsUnder('companies/c1/private/nfse/audit/');
    expect(audit).toEqual([
      expect.objectContaining({ action: 'upload', emitterId: result.emitterId, by: actor.user, device: 'iOS 1.104.0' }),
    ]);
  });

  it('opens back with the vault, bound to company and emitter', async () => {
    const { emitterId } = await storeCertificate(input(), deps);
    const cert = await loadCertificate('c1', emitterId, deps);
    expect(cert.keyPem).toContain('BEGIN RSA PRIVATE KEY');
    expect(cert.chainPem.match(/BEGIN CERTIFICATE/g)).toHaveLength(2);
    expect(await codeOf(loadCertificate('c2', emitterId, deps))).toBe('CERT_NOT_FOUND');

    // The sealed material copied to another emitter id does not open (AAD).
    seed('nfseCertificates/other', { ...read(`nfseCertificates/${emitterId}`)!, emitterId: 'other' });
    vault.keys.set('other', vault.keys.get(emitterId)!);
    await expect(loadCertificate('c1', 'other', deps)).rejects.toThrow();
  });

  it('refuses a CNPJ that is already an emitter of the company', async () => {
    await storeCertificate(input(), deps);
    expect(await codeOf(storeCertificate(input(), deps))).toBe('EMITTER_ALREADY_EXISTS');
  });

  it('refuses a certificate of another CNPJ for an existing emitter', async () => {
    seed('companies/c1/fiscalEmitters/e1', { taxId: '11222333000181' });
    expect(await codeOf(storeCertificate(input({ emitterId: 'e1' }), deps))).toBe('CERT_TAX_ID_MISMATCH');
    expect(await codeOf(storeCertificate(input({ emitterId: 'missing' }), deps))).toBe('EMITTER_NOT_FOUND');
  });

  it.each([
    ['senha errada', { password: 'errada' }, 'CERT_WRONG_PASSWORD'],
    ['vencido', { pfx: pki.pfx({ notAfter: new Date('2026-10-01T00:00:00Z') }) }, 'CERT_EXPIRED'],
    ['fora da ICP-Brasil', { pfx: pki.pfx({ selfSigned: true }) }, 'CERT_NOT_ICP_BRASIL'],
    ['sem aceitar o termo', { termsVersion: 'old' }, 'TERMS_NOT_ACCEPTED'],
  ])('%s: nothing is stored', async (_label, overrides, code) => {
    expect(await codeOf(storeCertificate(input(overrides), deps))).toBe(code);
    expect(docsUnder('nfseCertificates/')).toEqual([]);
    expect(docsUnder('companies/c1/fiscalEmitters/')).toEqual([]);
    expect(vault.calls).toEqual([]);
  });

  it('replacing makes a new key version and destroys the old one', async () => {
    const { emitterId } = await storeCertificate(input(), deps);
    const firstVersion = read(`nfseCertificates/${emitterId}`)!.kmsKeyVersion;
    const renewed = pki.pfx({ notAfter: new Date('2028-03-12T00:00:00Z') });
    const result = await storeCertificate(input({ emitterId, pfx: renewed }), deps);

    expect(result.created).toBe(false);
    const stored = read(`nfseCertificates/${emitterId}`)!;
    expect(stored.kmsKeyVersion).not.toBe(firstVersion);
    expect(vault.calls).toContain(`destroy:${firstVersion}`);
    expect((read(`companies/c1/fiscalEmitters/${emitterId}`)!.certificate as Record<string, unknown>).notAfter).toBe('2028-03-12T00:00:00.000Z');
    expect((await loadCertificate('c1', emitterId, deps)).notAfter).toBe('2028-03-12T00:00:00.000Z');
    expect(docsUnder('companies/c1/private/nfse/audit/').map((a) => a.action)).toEqual(['upload', 'replace']);
  });
});

describe('deleteCertificate (crypto-shredding)', () => {
  it('removes material and DEK, destroys the version and keeps the emitter and its notas', async () => {
    const { emitterId } = await storeCertificate(input(), deps);
    const version = read(`nfseCertificates/${emitterId}`)!.kmsKeyVersion;
    const backup = read(`nfseCertificates/${emitterId}`)!;
    seed('companies/c1/invoices/nf1', { emitter: { id: emitterId }, status: 'authorized' });

    expect(await deleteCertificate({ companyId: 'c1', emitterId, actor }, deps)).toBe(true);

    expect(read(`nfseCertificates/${emitterId}`)).toBeUndefined();
    expect(vault.calls).toContain(`destroy:${version}`);
    expect((read(`companies/c1/fiscalEmitters/${emitterId}`)!.certificate as Record<string, unknown>).status).toBe('deleted');
    expect(read('companies/c1/invoices/nf1')).toBeDefined();
    expect(docsUnder('companies/c1/private/nfse/audit/').map((a) => a.action)).toEqual(['upload', 'delete']);

    // A backup copy of the document is useless once the version is gone.
    seed(`nfseCertificates/${emitterId}`, backup);
    expect(await codeOf(loadCertificate('c1', emitterId, deps))).toBe('CERT_NOT_FOUND');
  });

  it('is idempotent and refuses another company', async () => {
    const { emitterId } = await storeCertificate(input(), deps);
    expect(await codeOf(deleteCertificate({ companyId: 'c2', emitterId, actor }, deps))).toBe('CERT_NOT_FOUND');
    expect(await deleteCertificate({ companyId: 'c1', emitterId, actor }, deps)).toBe(true);
    expect(await deleteCertificate({ companyId: 'c1', emitterId, actor }, deps)).toBe(false);
  });

  it('queues the destruction when KMS refuses and the daily retry finishes it', async () => {
    const { emitterId } = await storeCertificate(input(), deps);
    const version = read(`nfseCertificates/${emitterId}`)!.kmsKeyVersion;
    vault.failDestroy = true;
    await deleteCertificate({ companyId: 'c1', emitterId, actor }, deps);
    expect(read(`nfseCertificates/${emitterId}`)).toBeUndefined();
    expect(docsUnder('nfseKeyDestructions/')).toEqual([expect.objectContaining({ keyVersion: version, companyId: 'c1' })]);
    expect(docsUnder('companies/c1/private/nfse/audit/').map((a) => a.action)).toContain('destroy-failed');

    expect(await processPendingKeyDestructions(deps)).toBe(0);
    expect(docsUnder('nfseKeyDestructions/')[0].attempts).toBe(1);
    vault.failDestroy = false;
    expect(await processPendingKeyDestructions(deps)).toBe(1);
    expect(docsUnder('nfseKeyDestructions/')).toEqual([]);
  });
});

describe('purgeExpiredCertificates', () => {
  it('deletes only certificates expired for more than 90 days', async () => {
    const old = await storeCertificate(input(), { ...deps, now: () => new Date('2026-02-01T00:00:00Z') });
    const recent = await storeCertificate(input({ pfx: pki.pfx({ cnpj: '11222333000181' }) }), deps);
    // Expired in 2027-03-12; 90 days later is 2027-06-10.
    expect(await purgeExpiredCertificates({ ...deps, now: () => new Date('2027-06-01T00:00:00Z') })).toBe(0);
    seed(`nfseCertificates/${recent.emitterId}`, {
      ...read(`nfseCertificates/${recent.emitterId}`)!,
      notAfter: '2028-01-01T00:00:00.000Z',
    });
    expect(await purgeExpiredCertificates({ ...deps, now: () => new Date('2027-06-11T00:00:00Z') })).toBe(1);
    expect(read(`nfseCertificates/${old.emitterId}`)).toBeUndefined();
    expect(read(`nfseCertificates/${recent.emitterId}`)).toBeDefined();
    expect((read(`companies/c1/fiscalEmitters/${old.emitterId}`)!.certificate as Record<string, unknown>).status).toBe('expired');
  });
});

describe('deleteCompanyCertificates (account deletion)', () => {
  it('shreds every certificate of the company and nothing of others', async () => {
    const a = await storeCertificate(input(), deps);
    const b = await storeCertificate(input({ pfx: pki.pfx({ cnpj: '11222333000181' }) }), deps);
    const other = await storeCertificate(input({ companyId: 'c2' }), deps);
    expect(await deleteCompanyCertificates('c1', deps)).toBe(2);
    expect(read(`nfseCertificates/${a.emitterId}`)).toBeUndefined();
    expect(read(`nfseCertificates/${b.emitterId}`)).toBeUndefined();
    expect(read(`nfseCertificates/${other.emitterId}`)).toBeDefined();
    expect(vault.calls.filter((c) => c.startsWith('destroy:'))).toHaveLength(2);
  });
});
