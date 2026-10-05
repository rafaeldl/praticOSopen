/**
 * Secret encryption for the Asaas integration.
 * AES-256-GCM with a 32-byte master key (secret ASAAS_CREDENTIALS_KEY, base64).
 */

import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { EncryptedSecret } from '../../models/asaas.types';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;

function parseMasterKey(masterKeyB64: string): Buffer {
  const key = Buffer.from(masterKeyB64 || '', 'base64');
  if (key.length !== 32) {
    throw new Error('ASAAS_CREDENTIALS_KEY must be 32 bytes encoded as base64');
  }
  return key;
}

export function encryptSecret(plain: string, masterKeyB64: string): EncryptedSecret {
  const key = parseMasterKey(masterKeyB64);
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  return {
    iv: iv.toString('base64'),
    tag: cipher.getAuthTag().toString('base64'),
    ciphertext: ciphertext.toString('base64'),
  };
}

/** Throws when the master key is wrong or any part was tampered with. */
export function decryptSecret(enc: EncryptedSecret, masterKeyB64: string): string {
  const key = parseMasterKey(masterKeyB64);
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(enc.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(enc.tag, 'base64'));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(enc.ciphertext, 'base64')),
    decipher.final(),
  ]);
  return plain.toString('utf8');
}

/** SHA-256 hex of a token (webhook auth token is stored only as this hash). */
export function hashToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

const SHA256_HEX = /^[0-9a-f]{64}$/i;

/**
 * Timing-safe comparison of two SHA-256 hex digests (case-insensitive).
 * False unless both are exactly 64 hex chars: Buffer.from(hex) silently stops
 * at the first invalid char, so a malformed value could otherwise match a prefix.
 */
export function safeEqualHex(a: string, b: string): boolean {
  if (typeof a !== 'string' || typeof b !== 'string' || !SHA256_HEX.test(a) || !SHA256_HEX.test(b)) {
    return false;
  }
  return timingSafeEqual(Buffer.from(a, 'hex'), Buffer.from(b, 'hex'));
}

/** Master key from the bound secret (process.env at runtime). */
export function readMasterKeyFromEnv(): string {
  const key = process.env.ASAAS_CREDENTIALS_KEY;
  if (!key) {
    throw new Error('ASAAS_CREDENTIALS_KEY is not configured');
  }
  return key;
}
