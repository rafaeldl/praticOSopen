/**
 * Opens and checks an A1 certificate (.pfx/.p12) in memory.
 *
 * Spec 2026-11-05-nfse-direta-design §6: the password and the .pfx are never
 * stored nor logged. Only the private key and the chain, already open (PEM),
 * leave this module, to be encrypted right away by the vault.
 *
 * node-forge opens the "legacy" PFX (RC2/3DES) common in ICP-Brasil A1s, which
 * Node/OpenSSL 3 refuses. The chain is checked with Node's X509Certificate
 * against the pinned ICP-Brasil roots (icp-brasil-roots.ts). Many A1s bring
 * only the holder's certificate, so the pinned intermediate ACs
 * (icp-brasil-intermediates.ts) fill the gaps; nothing is fetched online.
 */

import { X509Certificate } from 'node:crypto';
import forge from 'node-forge';
import { NfseServiceError } from './errors';
import { ICP_BRASIL_INTERMEDIATES } from './icp-brasil-intermediates';
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
  /** Known intermediate ACs in PEM, used when the .pfx lacks them; defaults to ICP-Brasil. */
  intermediates?: readonly string[];
}

const MAX_PFX_BYTES = 64 * 1024;

/**
 * Highest PBE/MAC iteration count accepted for one key derivation. Real A1s
 * use 2 000 to 10 000 (OpenSSL, Windows, the ACs); node-forge has no ceiling
 * and derives in pure JS, so a crafted file with millions of iterations would
 * hold the instance for minutes. Spec §6, issue #560.
 */
export const MAX_PFX_ITERATIONS = 100_000;
/** All the derivations of one file together (MAC + every encrypted bag). */
export const MAX_PFX_TOTAL_ITERATIONS = 400_000;

/**
 * Budget of the file being opened now (openCertificate is synchronous, so one
 * file at a time per process). Null outside openCertificate.
 */
let iterationBudget: { left: number } | null = null;

function spendIterations(count: unknown): void {
  const n = Number(count);
  if (!Number.isFinite(n) || n > MAX_PFX_ITERATIONS) {
    throw new NfseServiceError('CERT_INVALID_FILE', 'Certificate file uses too many iterations');
  }
  if (iterationBudget) {
    iterationBudget.left -= Math.max(1, n);
    if (iterationBudget.left < 0) throw new NfseServiceError('CERT_INVALID_FILE', 'Certificate file uses too many iterations');
  }
}

type AnyFn = (...args: never[]) => unknown;
const GUARDED = Symbol.for('praticos.nfse.iterationGuard');

/** Wraps a forge key derivation so the iteration count (argument [index]) is checked before any work. */
function guard(owner: Record<string, unknown>, name: string, index: number): void {
  const original = owner?.[name] as (AnyFn & { [GUARDED]?: true }) | undefined;
  if (typeof original !== 'function' || original[GUARDED]) return;
  const wrapped = function (this: unknown, ...args: unknown[]) {
    spendIterations(args[index]);
    return (original as unknown as (...a: unknown[]) => unknown).apply(this, args);
  } as AnyFn & { [GUARDED]?: true };
  wrapped[GUARDED] = true;
  owner[name] = wrapped;
}

/*
 * node-forge looks these up on its module objects at call time (pkcs12.js MAC,
 * pbe.js PKCS#12 PBE and PBES2), so wrapping them here covers the MAC and the
 * bags nested inside encrypted safes, which a scan before decrypting cannot see.
 * Only this module uses forge's password-based crypto.
 */
const forgeAny = forge as unknown as Record<string, Record<string, unknown>>;
guard(forgeAny.pkcs12, 'generateKey', 3);
guard((forgeAny.pki as unknown as Record<string, Record<string, unknown>>).pbe, 'generatePkcs12Key', 3);
if (forgeAny.pbe && forgeAny.pbe !== (forgeAny.pki as unknown as Record<string, unknown>).pbe) guard(forgeAny.pbe, 'generatePkcs12Key', 3);
guard(forgeAny.pkcs5, 'pbkdf2', 2);

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
  iterationBudget = { left: MAX_PFX_TOTAL_ITERATIONS };
  try {
    return forge.pkcs12.pkcs12FromAsn1(asn1, false, password);
  } catch (error) {
    if (error instanceof NfseServiceError) throw error;
    // forge says "Invalid password?" (MAC check) or fails to decrypt the bags.
    const message = (error as Error)?.message ?? '';
    if (/password|mac|decrypt|padding/i.test(message)) {
      throw new NfseServiceError('CERT_WRONG_PASSWORD', 'Wrong certificate password');
    }
    throw new NfseServiceError('CERT_INVALID_FILE', 'Could not read the PKCS#12 file');
  } finally {
    iterationBudget = null;
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

let pinnedCache: { source: readonly string[]; certs: X509Certificate[] } | null = null;

function parsePinned(pems: readonly string[]): X509Certificate[] {
  if (pinnedCache?.source === pems) return pinnedCache.certs;
  const certs = pems.map((pem) => new X509Certificate(pem));
  pinnedCache = { source: pems, certs };
  return certs;
}

const validAt = (cert: X509Certificate, now: Date) => now >= new Date(cert.validFrom) && now <= new Date(cert.validTo);

/**
 * Path from the holder's certificate (first of [chainPem]) to one of [roots],
 * as PEM: holder followed by the intermediates, root left out. Each link must
 * be signed by the next, be a CA and be valid at [now]. Intermediates come
 * from the .pfx itself and, when it lacks them, from [intermediates] (pinned,
 * never from the internet). Null when no such path exists.
 */
export function buildTrustedChain(
  chainPem: string[],
  roots: readonly string[],
  now: Date,
  intermediates: readonly string[] = [],
): string[] | null {
  const certs = chainPem.map((pem) => new X509Certificate(pem));
  const trusted = roots.map((pem) => new X509Certificate(pem));
  const pool = [...certs.slice(1), ...parsePinned(intermediates)];
  const issues = (child: X509Certificate, issuer: X509Certificate) =>
    issuer.ca && child.checkIssued(issuer) && child.verify(issuer.publicKey);
  const path = [certs[0]];
  let current = certs[0];
  for (let depth = 0; depth < 8; depth++) {
    const root = trusted.find((r) => issues(current, r) && validAt(r, now));
    if (root) return path.map((cert) => cert.toString());
    // Several certificates may share the issuer name (AC renewals): try them all.
    const next = pool.find((c) => !path.includes(c) && issues(current, c) && validAt(c, now));
    if (!next) return null;
    path.push(next);
    current = next;
  }
  return null;
}

/** True when [chain] (leaf first) ends in one of [roots]: each certificate signed by the next. */
export function chainsToTrustedRoot(
  chainPem: string[],
  roots: readonly string[],
  now: Date,
  intermediates: readonly string[] = [],
): boolean {
  return buildTrustedChain(chainPem, roots, now, intermediates) !== null;
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

  const fromFile = [leaf, ...certs.filter((cert) => cert !== leaf)].map((cert) => forge.pki.certificateToPem(cert));
  const chain = buildTrustedChain(
    fromFile,
    options.trustedRoots ?? ICP_BRASIL_ROOTS,
    now,
    options.intermediates ?? ICP_BRASIL_INTERMEDIATES,
  );
  if (!chain) {
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
