/**
 * Synthetic certificates for the tests: a fake root, an intermediate and an
 * e-CNPJ-like holder certificate, packed in a legacy (3DES) PFX like the
 * ICP-Brasil A1s. Never a real certificate (the repository is public).
 */

import { generateKeyPairSync } from 'node:crypto';
import forge from 'node-forge';

const OID_ICP_CNPJ = '2.16.76.1.3.3';

function rsaKeys() {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  return {
    privateKey: forge.pki.privateKeyFromPem(privateKey.export({ type: 'pkcs1', format: 'pem' }).toString()),
    publicKey: forge.pki.publicKeyFromPem(publicKey.export({ type: 'spki', format: 'pem' }).toString()),
  };
}

type Attrs = forge.pki.CertificateField[];

function makeCert(opts: {
  subject: Attrs;
  issuer: Attrs;
  publicKey: forge.pki.PublicKey;
  signer: forge.pki.PrivateKey;
  ca: boolean;
  notBefore: Date;
  notAfter: Date;
  serial: string;
  extra?: object[];
}) {
  const cert = forge.pki.createCertificate();
  cert.publicKey = opts.publicKey;
  cert.serialNumber = opts.serial;
  cert.validity.notBefore = opts.notBefore;
  cert.validity.notAfter = opts.notAfter;
  cert.setSubject(opts.subject);
  cert.setIssuer(opts.issuer);
  cert.setExtensions([
    { name: 'basicConstraints', cA: opts.ca },
    { name: 'keyUsage', keyCertSign: opts.ca, digitalSignature: true, keyEncipherment: !opts.ca },
    ...(opts.extra ?? []),
  ]);
  cert.sign(opts.signer as forge.pki.rsa.PrivateKey, forge.md.sha256.create());
  return cert;
}

/** subjectAltName with the ICP-Brasil otherName of the CNPJ (DOC-ICP-04). */
function icpSan(cnpj: string) {
  const { asn1 } = forge;
  const otherName = asn1.create(asn1.Class.CONTEXT_SPECIFIC, 0, true, [
    asn1.create(asn1.Class.UNIVERSAL, asn1.Type.OID, false, asn1.oidToDer(OID_ICP_CNPJ).getBytes()),
    asn1.create(asn1.Class.CONTEXT_SPECIFIC, 0, true, [
      asn1.create(asn1.Class.UNIVERSAL, asn1.Type.OCTETSTRING, false, cnpj),
    ]),
  ]);
  const generalNames = asn1.create(asn1.Class.UNIVERSAL, asn1.Type.SEQUENCE, true, [otherName]);
  return { id: '2.5.29.17', name: 'subjectAltName', critical: false, value: asn1.toDer(generalNames).getBytes() };
}

export interface TestPki {
  rootPem: string;
  intermediatePem: string;
  /** A legacy PFX of the holder (key + holder + intermediate). */
  pfx(options?: {
    cnpj?: string;
    holderName?: string;
    password?: string;
    notBefore?: Date;
    notAfter?: Date;
    withSan?: boolean;
    withCnSuffix?: boolean;
    withIntermediate?: boolean;
    selfSigned?: boolean;
  }): Buffer;
}

const name = (cn: string): Attrs => [
  { name: 'countryName', value: 'BR' },
  { name: 'organizationName', value: 'Teste PraticOS' },
  { name: 'commonName', value: cn },
];

let cached: TestPki | null = null;

export function testPki(): TestPki {
  if (cached) return cached;
  const longAgo = new Date('2020-01-01T00:00:00Z');
  const farAway = new Date('2040-01-01T00:00:00Z');
  const rootKeys = rsaKeys();
  const root = makeCert({
    subject: name('Raiz de Teste'), issuer: name('Raiz de Teste'), publicKey: rootKeys.publicKey,
    signer: rootKeys.privateKey, ca: true, notBefore: longAgo, notAfter: farAway, serial: '01',
  });
  const interKeys = rsaKeys();
  const inter = makeCert({
    subject: name('AC Intermediaria de Teste'), issuer: name('Raiz de Teste'), publicKey: interKeys.publicKey,
    signer: rootKeys.privateKey, ca: true, notBefore: longAgo, notAfter: farAway, serial: '02',
  });
  const holderKeys = rsaKeys();
  let serial = 10;

  cached = {
    rootPem: forge.pki.certificateToPem(root),
    intermediatePem: forge.pki.certificateToPem(inter),
    pfx(options = {}) {
      const cnpj = options.cnpj ?? '00000000000191';
      const holderName = options.holderName ?? 'OFICINA EXEMPLO LTDA';
      const cn = options.withCnSuffix === false ? holderName : `${holderName}:${cnpj}`;
      const selfSigned = options.selfSigned === true;
      const leaf = makeCert({
        subject: name(cn),
        issuer: selfSigned ? name(cn) : name('AC Intermediaria de Teste'),
        publicKey: holderKeys.publicKey,
        signer: selfSigned ? holderKeys.privateKey : interKeys.privateKey,
        ca: false,
        notBefore: options.notBefore ?? new Date('2026-01-01T00:00:00Z'),
        notAfter: options.notAfter ?? new Date('2027-03-12T00:00:00Z'),
        serial: (serial++).toString(16).padStart(2, '0'),
        extra: options.withSan === false ? [] : [icpSan(cnpj)],
      });
      const chain = options.withIntermediate === false || selfSigned ? [leaf] : [leaf, inter];
      const p12 = forge.pkcs12.toPkcs12Asn1(holderKeys.privateKey, chain, options.password ?? 'senha-teste', {
        algorithm: '3des',
      });
      return Buffer.from(forge.asn1.toDer(p12).getBytes(), 'binary');
    },
  };
  return cached;
}
