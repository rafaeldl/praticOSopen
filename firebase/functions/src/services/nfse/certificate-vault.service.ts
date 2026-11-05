/**
 * Vault of the A1 certificates of the NFS-e direct engine (issue #561, spec §6).
 *
 * - The .pfx and its password live only in the memory of `storeCertificate`.
 * - What is stored is the private key + chain (PEM), sealed with a fresh DEK
 *   (AES-256-GCM); the DEK is wrapped by the emitter's own KMS key.
 * - The sealed material sits in /nfseCertificates/{emitterId}, closed in the
 *   rules; the emitter document shows only holder, validity and who sent it.
 * - Replacing creates a new key version and destroys the old one; deleting
 *   removes material and DEK and schedules the version's destruction (24 h),
 *   after which every backup copy is unreadable (crypto-shredding).
 * - Every action goes to companies/{cid}/private/nfse/audit.
 *
 * When KMS cannot destroy a version right away, the version goes to
 * /nfseKeyDestructions (closed) and `processPendingKeyDestructions` retries it.
 */

import { db } from '../firestore.service';
import type { UserAggr } from '../../models/types';
import type {
  FiscalCertificateStatus,
  FiscalEmitter,
  FiscalEmitterCertificate,
} from '../../models/nfse-direct.types';
import { openCertificate, type OpenCertificateOptions } from './certificate';
import { certificateAad, newDataKey, open, seal } from './envelope';
import { NfseServiceError } from './errors';
import { defaultKeyVault, type KeyVault } from './key-vault';

/** Version of the certificate terms the app shows; bump when the text changes. */
export const NFSE_CERTIFICATE_TERMS_VERSION = '2026-11-05';

/** A certificate expired for longer than this is deleted (spec §6 item 7). */
export const EXPIRED_RETENTION_DAYS = 90;

export const CERTIFICATES = 'nfseCertificates';
export const KEY_DESTRUCTIONS = 'nfseKeyDestructions';

/** /nfseCertificates/{emitterId}. Binary fields in base64. */
export interface StoredCertificateDoc {
  companyId: string;
  emitterId: string;
  ciphertext: string;
  iv: string;
  tag: string;
  wrappedDek: string;
  kmsKeyVersion: string;
  taxId: string;
  /** ISO 8601: drives the 90-day purge. */
  notAfter: string;
  status: 'active' | 'pending';
  termsVersion: string;
  createdAt: string;
  createdBy: UserAggr;
}

export type CertificateAuditAction = 'upload' | 'replace' | 'delete' | 'purge-expired' | 'delete-account' | 'destroy-failed';

/** Who did it, from which device: written to the audit log (no secrets). */
export interface CertificateActor {
  user: UserAggr;
  /** App platform and version or the web user agent, trimmed. */
  device?: string | null;
  ip?: string | null;
}

export interface VaultDeps {
  vault: KeyVault;
  now: () => Date;
  certificateOptions?: OpenCertificateOptions;
}

let defaultDeps: VaultDeps | null = null;
function deps(override?: Partial<VaultDeps>): VaultDeps {
  if (!defaultDeps) defaultDeps = { vault: defaultKeyVault(), now: () => new Date() };
  return { ...defaultDeps, ...override };
}

const emittersOf = (companyId: string) => db.collection('companies').doc(companyId).collection('fiscalEmitters');
const auditOf = (companyId: string) =>
  db.collection('companies').doc(companyId).collection('private').doc('nfse').collection('audit');

function auditEntry(action: CertificateAuditAction, emitterId: string, actor: CertificateActor | null, now: Date, extra: Record<string, unknown> = {}) {
  return {
    action,
    emitterId,
    at: now.toISOString(),
    by: actor?.user ?? null,
    device: actor?.device ? String(actor.device).slice(0, 200) : null,
    ip: actor?.ip ?? null,
    ...extra,
  };
}

/** The certificate fields the emitter shows (never the material). */
function publicCertificate(holderName: string, notAfter: Date, now: Date, by: UserAggr, status: FiscalCertificateStatus): FiscalEmitterCertificate {
  return { holderName, notAfter: notAfter.toISOString(), uploadedAt: now.toISOString(), uploadedBy: by, status };
}

export interface StoreCertificateInput {
  companyId: string;
  /** Replace the certificate of this emitter; absent = add a new CNPJ. */
  emitterId?: string | null;
  pfx: Buffer;
  password: string;
  /** Version of the terms the person accepted; must be the current one. */
  termsVersion: string;
  actor: CertificateActor;
}

export interface StoreCertificateResult {
  emitterId: string;
  created: boolean;
  taxId: string;
  holderName: string;
  notAfter: string;
}

/**
 * Opens and checks the certificate, then seals and stores it for the emitter
 * (new one when [emitterId] is absent). The password is not kept anywhere.
 */
export async function storeCertificate(input: StoreCertificateInput, override?: Partial<VaultDeps>): Promise<StoreCertificateResult> {
  const d = deps(override);
  if (input.termsVersion !== NFSE_CERTIFICATE_TERMS_VERSION) {
    throw new NfseServiceError('TERMS_NOT_ACCEPTED', 'Certificate terms must be accepted');
  }
  const now = d.now();
  const cert = openCertificate(input.pfx, input.password, { ...d.certificateOptions, now });

  const emitters = emittersOf(input.companyId);
  let emitterId = input.emitterId ?? null;
  let created = false;
  if (emitterId) {
    const snap = await emitters.doc(emitterId).get();
    if (!snap.exists) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    const emitter = snap.data() as Partial<FiscalEmitter>;
    if (emitter.taxId !== cert.taxId) {
      throw new NfseServiceError('CERT_TAX_ID_MISMATCH', 'Certificate belongs to another CNPJ');
    }
  } else {
    const same = await emitters.where('taxId', '==', cert.taxId).limit(1).get();
    if (!same.empty) throw new NfseServiceError('EMITTER_ALREADY_EXISTS', 'This CNPJ is already an emitter');
    emitterId = emitters.doc().id;
    created = true;
  }

  const certRef = db.collection(CERTIFICATES).doc(emitterId);
  const previous = (await certRef.get()).data() as StoredCertificateDoc | undefined;
  if (previous && previous.companyId !== input.companyId) {
    // Ids are random per emitter; a clash means something is very wrong.
    throw new NfseServiceError('FORBIDDEN', 'Certificate slot belongs to another company');
  }

  const aad = certificateAad(input.companyId, emitterId);
  const dek = newDataKey();
  const plain = Buffer.from(JSON.stringify({ keyPem: cert.keyPem, chainPem: cert.chainPem }), 'utf8');
  const sealed = seal(plain, dek, aad);
  plain.fill(0);
  await d.vault.prepareKey(emitterId);
  const { wrappedDek, keyVersion } = await d.vault.wrap(emitterId, dek, aad);
  dek.fill(0);

  const doc: StoredCertificateDoc = {
    companyId: input.companyId,
    emitterId,
    ciphertext: sealed.ciphertext.toString('base64'),
    iv: sealed.iv.toString('base64'),
    tag: sealed.tag.toString('base64'),
    wrappedDek: wrappedDek.toString('base64'),
    kmsKeyVersion: keyVersion,
    taxId: cert.taxId,
    notAfter: cert.notAfter.toISOString(),
    status: 'active',
    termsVersion: input.termsVersion,
    createdAt: now.toISOString(),
    createdBy: input.actor.user,
  };

  const certificate = publicCertificate(cert.holderName, cert.notAfter, now, input.actor.user, 'active');
  const batch = db.batch();
  batch.set(certRef, doc);
  if (created) {
    // The rest (regime, city, service, series) comes from the registry lookups and the import.
    batch.set(emitters.doc(emitterId), {
      id: emitterId,
      taxId: cert.taxId,
      legalName: cert.holderName,
      enabledInCity: false,
      certificate,
      createdAt: now.toISOString(),
    });
  } else {
    batch.set(emitters.doc(emitterId), { certificate, updatedAt: now.toISOString() }, { merge: true });
  }
  batch.set(
    auditOf(input.companyId).doc(),
    auditEntry(previous ? 'replace' : 'upload', emitterId, input.actor, now, {
      termsVersion: input.termsVersion,
      notAfter: doc.notAfter,
      serialNumber: cert.serialNumber,
    }),
  );
  await batch.commit();

  if (previous && previous.kmsKeyVersion !== keyVersion) {
    await destroyOrQueue(d, input.companyId, emitterId, previous.kmsKeyVersion, input.actor);
  }

  return { emitterId, created, taxId: cert.taxId, holderName: cert.holderName, notAfter: doc.notAfter };
}

/** Key and chain of an emitter, in memory, for one call. Never cache the result. */
export interface UsableCertificate {
  keyPem: string;
  chainPem: string;
  taxId: string;
  notAfter: string;
}

/** Opens the emitter's certificate for one operation (issue, cancel, read). */
export async function loadCertificate(companyId: string, emitterId: string, override?: Partial<VaultDeps>): Promise<UsableCertificate> {
  const d = deps(override);
  const snap = await db.collection(CERTIFICATES).doc(emitterId).get();
  const doc = snap.data() as StoredCertificateDoc | undefined;
  if (!snap.exists || !doc || doc.companyId !== companyId) {
    throw new NfseServiceError('CERT_NOT_FOUND', 'Emitter has no certificate');
  }
  if (doc.status !== 'active') throw new NfseServiceError('CERT_NOT_FOUND', 'Certificate waiting for confirmation');
  if (d.now() > new Date(doc.notAfter)) throw new NfseServiceError('CERT_EXPIRED', 'Certificate expired');

  const aad = certificateAad(companyId, emitterId);
  const dek = await d.vault.unwrap(emitterId, Buffer.from(doc.wrappedDek, 'base64'), aad);
  try {
    const plain = open(
      { ciphertext: Buffer.from(doc.ciphertext, 'base64'), iv: Buffer.from(doc.iv, 'base64'), tag: Buffer.from(doc.tag, 'base64') },
      dek,
      aad,
    );
    const { keyPem, chainPem } = JSON.parse(plain.toString('utf8')) as { keyPem: string; chainPem: string };
    plain.fill(0);
    return { keyPem, chainPem, taxId: doc.taxId, notAfter: doc.notAfter };
  } finally {
    dek.fill(0);
  }
}

export interface DeleteCertificateInput {
  companyId: string;
  emitterId: string;
  actor: CertificateActor | null;
  action?: Extract<CertificateAuditAction, 'delete' | 'purge-expired' | 'delete-account'>;
}

/**
 * Deletes material and DEK and schedules the destruction of the key version
 * (crypto-shredding). The emitter stays, marked without a certificate; its
 * notas are kept. Idempotent: nothing stored = nothing to do.
 */
export async function deleteCertificate(input: DeleteCertificateInput, override?: Partial<VaultDeps>): Promise<boolean> {
  const d = deps(override);
  const now = d.now();
  const certRef = db.collection(CERTIFICATES).doc(input.emitterId);
  const doc = (await certRef.get()).data() as StoredCertificateDoc | undefined;
  if (!doc) return false;
  if (doc.companyId !== input.companyId) throw new NfseServiceError('CERT_NOT_FOUND', 'Emitter has no certificate');

  const action = input.action ?? 'delete';
  const batch = db.batch();
  batch.delete(certRef);
  if (action !== 'delete-account') {
    const emitterRef = emittersOf(input.companyId).doc(input.emitterId);
    if ((await emitterRef.get()).exists) {
      batch.set(
        emitterRef,
        { certificate: { status: action === 'purge-expired' ? 'expired' : 'deleted' }, updatedAt: now.toISOString() },
        { merge: true },
      );
    }
    batch.set(auditOf(input.companyId).doc(), auditEntry(action, input.emitterId, input.actor, now));
  }
  await batch.commit();
  await destroyOrQueue(d, input.companyId, input.emitterId, doc.kmsKeyVersion, input.actor);
  return true;
}

/** Schedules the version's destruction; on failure keeps it for the daily retry (and audits it). */
async function destroyOrQueue(d: VaultDeps, companyId: string, emitterId: string, keyVersion: string, actor: CertificateActor | null) {
  try {
    await d.vault.destroyVersion(keyVersion);
  } catch (error) {
    console.error('[nfse] key destruction deferred', (error as NfseServiceError)?.code ?? (error as Error)?.name);
    const now = d.now().toISOString();
    await db.collection(KEY_DESTRUCTIONS).doc().set({ companyId, emitterId, keyVersion, queuedAt: now, attempts: 0 });
    await auditOf(companyId).doc().set(auditEntry('destroy-failed', emitterId, actor, d.now()));
  }
}

/** Retries the destructions KMS refused before (daily routine of the nfseApi). */
export async function processPendingKeyDestructions(override?: Partial<VaultDeps>): Promise<number> {
  const d = deps(override);
  const pending = await db.collection(KEY_DESTRUCTIONS).limit(100).get();
  let done = 0;
  for (const snap of pending.docs) {
    const item = snap.data() as { keyVersion: string; attempts?: number };
    try {
      await d.vault.destroyVersion(item.keyVersion);
      await snap.ref.delete();
      done++;
    } catch {
      await snap.ref.set({ attempts: (item.attempts ?? 0) + 1, lastAttemptAt: d.now().toISOString() }, { merge: true });
    }
  }
  return done;
}

/** Deletes certificates expired for more than 90 days (daily routine). */
export async function purgeExpiredCertificates(override?: Partial<VaultDeps>): Promise<number> {
  const d = deps(override);
  const limit = new Date(d.now().getTime() - EXPIRED_RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const expired = await db.collection(CERTIFICATES).where('notAfter', '<', limit).limit(100).get();
  let count = 0;
  for (const snap of expired.docs) {
    const doc = snap.data() as StoredCertificateDoc;
    if (await deleteCertificate({ companyId: doc.companyId, emitterId: snap.id, actor: null, action: 'purge-expired' }, d)) {
      count++;
    }
  }
  return count;
}

/** Account deletion: every certificate of the company (before its tree is deleted). */
export async function deleteCompanyCertificates(companyId: string, override?: Partial<VaultDeps>): Promise<number> {
  const d = deps(override);
  const snap = await db.collection(CERTIFICATES).where('companyId', '==', companyId).get();
  let count = 0;
  for (const doc of snap.docs) {
    if (await deleteCertificate({ companyId, emitterId: doc.id, actor: null, action: 'delete-account' }, d)) count++;
  }
  return count;
}
