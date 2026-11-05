import forge from 'node-forge';
import { MAX_PFX_ITERATIONS, openCertificate, taxIdOfCertificate } from '../certificate';
import { NfseServiceError } from '../errors';
import { ICP_BRASIL_ROOTS } from '../icp-brasil-roots';
import { testPki } from './test-certificates';

const now = new Date('2026-11-05T12:00:00Z');

function codeOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (error) {
    return (error as NfseServiceError).code;
  }
  return undefined;
}

describe('openCertificate', () => {
  const pki = testPki();
  const roots = [pki.rootPem];

  it('opens a legacy (3DES) PFX and reads holder, CNPJ and validity', () => {
    const cert = openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: roots });
    expect(cert.taxId).toBe('00000000000191');
    expect(cert.holderName).toBe('OFICINA EXEMPLO LTDA');
    expect(cert.notAfter.toISOString()).toBe('2027-03-12T00:00:00.000Z');
    expect(cert.keyPem).toContain('BEGIN RSA PRIVATE KEY');
    // Holder first, then the intermediate (for mTLS).
    expect(cert.chainPem.match(/BEGIN CERTIFICATE/g)).toHaveLength(2);
    expect(cert.chainPem.startsWith(cert.certPem)).toBe(true);
  });

  it('reads the CNPJ from the ICP-Brasil otherName even without the CN suffix', () => {
    const cert = openCertificate(pki.pfx({ cnpj: '11222333000181', withCnSuffix: false }), 'senha-teste', {
      now,
      trustedRoots: roots,
    });
    expect(cert.taxId).toBe('11222333000181');
  });

  it('falls back to the "NAME:CNPJ" CN when there is no otherName', () => {
    const cert = openCertificate(pki.pfx({ withSan: false }), 'senha-teste', { now, trustedRoots: roots });
    expect(cert.taxId).toBe('00000000000191');
  });

  it('wrong password', () => {
    expect(codeOf(() => openCertificate(pki.pfx(), 'errada', { now, trustedRoots: roots }))).toBe('CERT_WRONG_PASSWORD');
  });

  it('not a PFX', () => {
    expect(codeOf(() => openCertificate(Buffer.from('not a certificate'), 'x', { now, trustedRoots: roots }))).toBe(
      'CERT_INVALID_FILE',
    );
    expect(codeOf(() => openCertificate(Buffer.alloc(0), 'x', { now, trustedRoots: roots }))).toBe('CERT_INVALID_FILE');
  });

  it('expired and not yet valid', () => {
    const expired = pki.pfx({ notAfter: new Date('2026-10-01T00:00:00Z') });
    expect(codeOf(() => openCertificate(expired, 'senha-teste', { now, trustedRoots: roots }))).toBe('CERT_EXPIRED');
    const future = pki.pfx({ notBefore: new Date('2026-12-01T00:00:00Z') });
    expect(codeOf(() => openCertificate(future, 'senha-teste', { now, trustedRoots: roots }))).toBe('CERT_NOT_YET_VALID');
  });

  it('refuses a chain that does not reach a trusted root', () => {
    // The real ICP-Brasil roots do not trust the test root.
    expect(codeOf(() => openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: ICP_BRASIL_ROOTS }))).toBe(
      'CERT_NOT_ICP_BRASIL',
    );
    // A self-signed certificate with an e-CNPJ-looking name.
    expect(codeOf(() => openCertificate(pki.pfx({ selfSigned: true }), 'senha-teste', { now, trustedRoots: roots }))).toBe(
      'CERT_NOT_ICP_BRASIL',
    );
    // The PFX without the intermediate cannot be chained.
    expect(
      codeOf(() => openCertificate(pki.pfx({ withIntermediate: false }), 'senha-teste', { now, trustedRoots: roots })),
    ).toBe('CERT_NOT_ICP_BRASIL');
  });

  it('refuses a certificate without CNPJ/CPF', () => {
    const pfx = pki.pfx({ withSan: false, withCnSuffix: false });
    expect(codeOf(() => openCertificate(pfx, 'senha-teste', { now, trustedRoots: roots }))).toBe('CERT_NO_TAX_ID');
  });

  it('pins the four ICP-Brasil roots', () => {
    expect(ICP_BRASIL_ROOTS).toHaveLength(4);
    for (const pem of ICP_BRASIL_ROOTS) {
      expect(forge.pki.certificateFromPem(pem).subject.getField('O')?.value).toBe('ICP-Brasil');
    }
  });
});

describe('taxIdOfCertificate', () => {
  it('reads an e-CPF suffix from the CN', () => {
    const cert = forge.pki.createCertificate();
    cert.setSubject([{ name: 'commonName', value: 'FULANO DE TAL:12345678909' }]);
    expect(taxIdOfCertificate(cert)).toBe('12345678909');
  });
});


/**
 * Rewrites every INTEGER equal to [from] (the iteration counts forge wrote) to
 * [to], also inside OCTET STRINGs that hold DER (the PKCS#12 safes).
 */
function withIterations(pfx: Buffer, from: number, to: number): Buffer {
  const { asn1 } = forge;
  const fromBytes = asn1.integerToDer(from).getBytes();
  const toBytes = asn1.integerToDer(to).getBytes();
  const walk = (node: forge.asn1.Asn1): boolean => {
    if (node.tagClass === asn1.Class.UNIVERSAL && node.type === asn1.Type.INTEGER && node.value === fromBytes) {
      node.value = toBytes;
      return true;
    }
    if (Array.isArray(node.value)) return node.value.map(walk).some(Boolean);
    if (node.tagClass === asn1.Class.UNIVERSAL && node.type === asn1.Type.OCTETSTRING && typeof node.value === 'string' && node.value.length > 8) {
      try {
        const inner = asn1.fromDer(forge.util.createBuffer(node.value));
        if (walk(inner)) {
          node.value = asn1.toDer(inner).getBytes();
          return true;
        }
      } catch {
        // Not DER (salt, digest, ciphertext).
      }
    }
    return false;
  };
  const root = asn1.fromDer(forge.util.createBuffer(pfx.toString('binary')));
  walk(root);
  return Buffer.from(asn1.toDer(root).getBytes(), 'binary');
}

describe('PFX with too many iterations (issue #560)', () => {
  const pki = testPki();
  const roots = [pki.rootPem];

  it('refuses a MAC with millions of iterations before deriving anything', () => {
    const evil = withIterations(pki.pfx(), 2048, 50_000_000);
    const start = Date.now();
    expect(codeOf(() => openCertificate(evil, 'senha-teste', { now, trustedRoots: roots }))).toBe('CERT_INVALID_FILE');
    expect(Date.now() - start).toBeLessThan(3000);
  });

  it('refuses an encrypted bag with too many iterations (file without MAC)', () => {
    const key = forge.pki.privateKeyFromPem(openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: roots }).keyPem);
    const cert = forge.pki.certificateFromPem(openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: roots }).certPem);
    const p12 = forge.pkcs12.toPkcs12Asn1(key, [cert], 'senha-teste', { algorithm: '3des', useMac: false });
    const plain = Buffer.from(forge.asn1.toDer(p12).getBytes(), 'binary');
    const evil = withIterations(plain, 2048, MAX_PFX_ITERATIONS + 1);
    expect(evil.equals(plain)).toBe(false);
    expect(codeOf(() => openCertificate(evil, 'senha-teste', { now, trustedRoots: roots }))).toBe('CERT_INVALID_FILE');
  });

  it('a normal file still opens after a refused one', () => {
    expect(openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: roots }).taxId).toBe('00000000000191');
  });
});
