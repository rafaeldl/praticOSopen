/**
 * Envelope encryption of a certificate: a fresh 256-bit data key (DEK) per
 * certificate, AES-256-GCM, with additional data binding the ciphertext to
 * its company and emitter (a copy moved to another document fails to open).
 * The DEK itself is encrypted by the emitter's KMS key (key-vault.ts).
 */

import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;

export interface SealedData {
  ciphertext: Buffer;
  iv: Buffer;
  tag: Buffer;
}

/** Additional authenticated data of an emitter's certificate (AES-GCM and KMS). */
export function certificateAad(companyId: string, emitterId: string): Buffer {
  return Buffer.from(`praticos/nfse-cert/v1/${companyId}/${emitterId}`, 'utf8');
}

export function newDataKey(): Buffer {
  return randomBytes(32);
}

export function seal(plain: Buffer, dek: Buffer, aad: Buffer): SealedData {
  if (dek.length !== 32) throw new Error('DEK must be 32 bytes');
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, dek, iv);
  cipher.setAAD(aad);
  const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
  return { ciphertext, iv, tag: cipher.getAuthTag() };
}

/** Throws when the key, the additional data or any part was changed. */
export function open(sealed: SealedData, dek: Buffer, aad: Buffer): Buffer {
  const decipher = createDecipheriv(ALGORITHM, dek, sealed.iv);
  decipher.setAAD(aad);
  decipher.setAuthTag(sealed.tag);
  return Buffer.concat([decipher.update(sealed.ciphertext), decipher.final()]);
}
