/**
 * Opens and checks an A1 certificate (.pfx/.p12) in memory.
 *
 * Spec 2026-11-05-nfse-direta-design §6: the password and the .pfx are never
 * stored nor logged. Only the private key and the chain, already open (PEM),
 * leave this module, to be encrypted right away by the vault.
 *
 * node-forge opens the "legacy" PFX (RC2/3DES) common in ICP-Brasil A1s, which
 * Node/OpenSSL 3 refuses. The chain is checked with Node's X509Certificate
 * against the pinned ICP-Brasil roots (icp-brasil-roots.ts).
 */

import { X509Certificate } from 'node:crypto';
import forge from 'node-forge';
import { NfseServiceError } from './errors';
import { ICP_BRASIL_ROOTS } from './icp-brasil-roots';

/** ICP-Brasil OID of the CNPJ in the subjectAltName otherName of an e-CNPJ (DOC-ICP-04). */
const OID_ICP_CNPJ = '2.16.76.1.3.3';

/** The opened certificate. `keyPem` is a secret: keep it in memory only. */
export interface OpenedCertificate {
  keyPem: string;
  /** Holder's certificate followed by the intermediates, PEM (for mTLS). */
  chainPem: string;
  certPem: string;
  /** Holder name (CN without the ":CNPJ" suffix). */
  holderName: string;
  /** CNPJ (14) of an e-CNPJ, or CPF (11) of an e-CPF. */
  taxId: string;
  notBefore: Date;
  notAfter: Date;
  /** Serial number, hex (audit only). */
  serialNumber: string;
}

export interface OpenCertificateOptions {
  now?: Date;
  /** Trusted roots in PEM; defaults to ICP-Brasil. Tests pass their own. */
  trustedRoots?: readonly string[];
}

const MAX_PFX_BYTES = 64 * 1024;

function bagsOf(p12: forge.pkcs12.Pkcs12Pfx, type: string): forge.pkcs12.Bag[] {
  return p12.getBags({ bagType: type })[type] ?? [];
}

function decodePfx(pfx: Buffer, password: string): forge.pkcs12.Pkcs12Pfx {
  let asn1: forge.asn1.Asn1;
  try {
    asn1 = forge.asn1.fromDer(forge.util.createBuffer(pfx.toString('binary')));
  } catch {
    throw new NfseServiceError('CERT_INVALID_FILE', 'Not a PKCS#12 file');
  }
  try {
    return forge.pkcs12.pkcs12FromAsn1(asn1, false, password);
  } catch (error) {
    // forge says "Invalid password?" (MAC check) or fails to decrypt the bags.
    const message = (error as Error)?.message ?? '';
    if (/password|mac|decrypt|padding/i.test(message)) {
      throw new NfseServiceError('CERT_WRONG_PASSWORD', 'Wrong certificate password');
    }
    throw new NfseServiceError('CERT_INVALID_FILE', 'Could not read the PKCS#12 file');
  }
}

/** Value of the first primitive (string) node under [nodes], depth first. */
function firstPrimitive(nodes: forge.asn1.Asn1[]): string | null {
  for (const node of nodes) {
    if (typeof node?.value === 'string') return node.value;
    if (Array.isArray(node?.value)) {
      const inner = firstPrimitive(node.value as forge.asn1.Asn1[]);
      if (inner !== null) return inner;
    }
  }
  return null;
}

/** CNPJ/CPF of an ICP-Brasil certificate: SAN otherName first, then the "NAME:DOC" CN. */
export function taxIdOfCertificate(cert: forge.pki.Certificate): string | null {
  const san = cert.getExtension('subjectAltName') as { altNames?: Array<{ type: number; value: unknown }> } | null;
  for (const name of san?.altNames ?? []) {
    // forge leaves otherName (type 0) as raw ASN.1: [OID, [0] { value }].
    if (name.type !== 0 || !Array.isArray(name.value)) continue;
    const parts = name.value as forge.asn1.Asn1[];
    const oid = parts[0] && typeof parts[0].value === 'string' ? forge.asn1.derToOid(parts[0].value) : null;
    if (oid !== OID_ICP_CNPJ) continue;
    const digits = firstPrimitive(parts.slice(1))?.replace(/\D/g, '') ?? '';
    if (digits.length === 14) return digits;
  }
  const cn = String(cert.subject.getField('CN')?.value ?? '');
  const match = cn.match(/:(\d{14}|\d{11})$/);
  return match ? match[1] : null;
}

function holderNameOf(cert: forge.pki.Certificate): string {
  const cn = String(cert.subject.getField('CN')?.value ?? '');
  return cn.replace(/:(\d{14}|\d{11})$/, '').trim();
}

function utf8Safe(text: string): string {
  try {
    return forge.util.decodeUtf8(text);
  } catch {
    return text;
  }
}

/** True when [chain] (leaf first) ends in one of [roots]: each certificate signed by the next. */
export function chainsToTrustedRoot(chainPem: string[], roots: readonly string[], now: Date): boolean {
  const certs = chainPem.map((pem) => new X509Certificate(pem));
  const trusted = roots.map((pem) => new X509Certificate(pem));
  const pool = [...certs.slice(1)];
  let current = certs[0];
  for (let depth = 0; depth < 8; depth++) {
    const root = trusted.find((r) => current.checkIssued(r) && current.verify(r.publicKey));
    if (root) return now >= new Date(root.validFrom) && now <= new Date(root.validTo);
    const next = pool.find((c) => current.checkIssued(c) && current.verify(c.publicKey));
    if (!next) return false;
    if (now < new Date(next.validFrom) || now > new Date(next.validTo)) return false;
    pool.splice(pool.indexOf(next), 1);
    current = next;
  }
  return false;
}

/**
 * Opens [pfx] with [password] and checks it: holder's key and certificate,
 * validity, ICP-Brasil chain and the CNPJ. Throws NfseServiceError with the
 * reason the app shows (CERT_*). The password is used only here.
 */
export function openCertificate(pfx: Buffer, password: string, options: OpenCertificateOptions = {}): OpenedCertificate {
  if (pfx.length === 0 || pfx.length > MAX_PFX_BYTES) {
    throw new NfseServiceError('CERT_INVALID_FILE', 'Certificate file is empty or too large');
  }
  const now = options.now ?? new Date();
  const p12 = decodePfx(pfx, password);

  const keyBag = bagsOf(p12, forge.pki.oids.pkcs8ShroudedKeyBag)[0] ?? bagsOf(p12, forge.pki.oids.keyBag)[0];
  const certs = bagsOf(p12, forge.pki.oids.certBag)
    .map((bag) => bag.cert)
    .filter((cert): cert is forge.pki.Certificate => !!cert);
  const key = keyBag?.key as forge.pki.rsa.PrivateKey | undefined;
  if (!key || certs.length === 0) {
    throw new NfseServiceError('CERT_INVALID_FILE', 'PKCS#12 without a private key or a certificate');
  }

  // The holder's certificate is the one whose public key matches the private key.
  const leaf = certs.find((cert) => (cert.publicKey as forge.pki.rsa.PublicKey).n?.equals(key.n));
  if (!leaf) {
    throw new NfseServiceError('CERT_INVALID_FILE', 'No certificate matches the private key');
  }

  if (now < leaf.validity.notBefore) throw new NfseServiceError('CERT_NOT_YET_VALID', 'Certificate not yet valid');
  if (now > leaf.validity.notAfter) throw new NfseServiceError('CERT_EXPIRED', 'Certificate expired');

  const chain = [leaf, ...certs.filter((cert) => cert !== leaf)].map((cert) => forge.pki.certificateToPem(cert));
  if (!chainsToTrustedRoot(chain, options.trustedRoots ?? ICP_BRASIL_ROOTS, now)) {
    throw new NfseServiceError('CERT_NOT_ICP_BRASIL', 'Certificate does not chain to an ICP-Brasil root');
  }

  const taxId = taxIdOfCertificate(leaf);
  if (!taxId) throw new NfseServiceError('CERT_NO_TAX_ID', 'Certificate has no CNPJ/CPF');

  return {
    keyPem: forge.pki.privateKeyToPem(key),
    chainPem: chain.join(''),
    certPem: chain[0],
    holderName: utf8Safe(holderNameOf(leaf)),
    taxId,
    notBefore: leaf.validity.notBefore,
    notAfter: leaf.validity.notAfter,
    serialNumber: leaf.serialNumber,
  };
}
