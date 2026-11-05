/**
 * Cloud KMS keys of the certificates: one key per emitter
 * (`nfse-certs/emitter-{emitterId}`), so one certificate is destroyed
 * (crypto-shredding) without touching the others. Spec §6 items 2, 3 and 7.
 *
 * Only the nfseApi service account has `cloudkms.cryptoKeyDecrypter` on these
 * keys. Creating the key ring and that account is a manual step (issue #561).
 */

import type { KeyManagementServiceClient } from '@google-cloud/kms';
import { NfseServiceError } from './errors';

export interface WrappedKey {
  wrappedDek: Buffer;
  /** Full resource name of the key version that wrapped the DEK. */
  keyVersion: string;
}

export interface KeyVault {
  /**
   * Makes the emitter's key ready to wrap a new certificate: creates it, or,
   * when it already exists (a replaced or deleted certificate), adds a new
   * primary version. Never reuses a version that may be scheduled for destruction.
   */
  prepareKey(emitterId: string): Promise<void>;
  wrap(emitterId: string, dek: Buffer, aad: Buffer): Promise<WrappedKey>;
  unwrap(emitterId: string, wrappedDek: Buffer, aad: Buffer): Promise<Buffer>;
  /** Schedules destruction of one version (24 h, then irreversible). */
  destroyVersion(keyVersion: string): Promise<void>;
}

export const NFSE_KEY_RING = 'nfse-certs';
/** Minimum KMS allows: a mistaken delete can still be undone for one day. */
export const DESTROY_SCHEDULED_SECONDS = 24 * 60 * 60;

export function emitterKeyId(emitterId: string): string {
  if (!/^[A-Za-z0-9_-]{1,56}$/.test(emitterId)) throw new Error('Invalid emitter id for a KMS key');
  return `emitter-${emitterId}`;
}

interface KmsConfig {
  projectId: string;
  location: string;
  keyRing: string;
}

const GRPC_ALREADY_EXISTS = 6;
const GRPC_NOT_FOUND = 5;
const GRPC_FAILED_PRECONDITION = 9;

function grpcCode(error: unknown): number | undefined {
  return (error as { code?: number })?.code;
}

/** KeyVault on Cloud KMS. The client is created on first use (tests never touch it). */
export class KmsKeyVault implements KeyVault {
  private clientPromise: Promise<KeyManagementServiceClient> | null = null;

  constructor(
    private readonly config: KmsConfig,
    private readonly makeClient: () => Promise<KeyManagementServiceClient> = async () => {
      const { KeyManagementServiceClient: Client } = await import('@google-cloud/kms');
      return new Client();
    },
  ) {}

  private client(): Promise<KeyManagementServiceClient> {
    if (!this.clientPromise) this.clientPromise = this.makeClient();
    return this.clientPromise;
  }

  private keyName(client: KeyManagementServiceClient, emitterId: string): string {
    const { projectId, location, keyRing } = this.config;
    return client.cryptoKeyPath(projectId, location, keyRing, emitterKeyId(emitterId));
  }

  async prepareKey(emitterId: string): Promise<void> {
    const client = await this.client();
    const { projectId, location, keyRing } = this.config;
    try {
      await client.createCryptoKey({
        parent: client.keyRingPath(projectId, location, keyRing),
        cryptoKeyId: emitterKeyId(emitterId),
        cryptoKey: {
          purpose: 'ENCRYPT_DECRYPT',
          versionTemplate: { algorithm: 'GOOGLE_SYMMETRIC_ENCRYPTION', protectionLevel: 'SOFTWARE' },
          destroyScheduledDuration: { seconds: DESTROY_SCHEDULED_SECONDS },
          labels: { app: 'praticos', use: 'nfse-certificate' },
        },
      });
      return;
    } catch (error) {
      if (grpcCode(error) !== GRPC_ALREADY_EXISTS) throw unavailable(error);
    }
    // Existing key: a fresh primary version for the new certificate.
    try {
      const name = this.keyName(client, emitterId);
      const [version] = await client.createCryptoKeyVersion({ parent: name, cryptoKeyVersion: {} });
      const versionId = String(version.name ?? '').split('/').pop();
      if (!versionId) throw new Error('KMS returned a version without a name');
      await client.updateCryptoKeyPrimaryVersion({ name, cryptoKeyVersionId: versionId });
    } catch (error) {
      throw unavailable(error);
    }
  }

  async wrap(emitterId: string, dek: Buffer, aad: Buffer): Promise<WrappedKey> {
    const client = await this.client();
    try {
      const [result] = await client.encrypt({
        name: this.keyName(client, emitterId),
        plaintext: dek,
        additionalAuthenticatedData: aad,
      });
      if (!result.ciphertext || !result.name) throw new Error('KMS encrypt returned no ciphertext');
      return { wrappedDek: Buffer.from(result.ciphertext as Uint8Array), keyVersion: result.name };
    } catch (error) {
      throw unavailable(error);
    }
  }

  async unwrap(emitterId: string, wrappedDek: Buffer, aad: Buffer): Promise<Buffer> {
    const client = await this.client();
    try {
      const [result] = await client.decrypt({
        name: this.keyName(client, emitterId),
        ciphertext: wrappedDek,
        additionalAuthenticatedData: aad,
      });
      if (!result.plaintext) throw new Error('KMS decrypt returned no plaintext');
      return Buffer.from(result.plaintext as Uint8Array);
    } catch (error) {
      // A destroyed version (deleted certificate) answers FAILED_PRECONDITION/NOT_FOUND.
      const code = grpcCode(error);
      if (code === GRPC_FAILED_PRECONDITION || code === GRPC_NOT_FOUND) {
        throw new NfseServiceError('CERT_NOT_FOUND', 'Certificate key is no longer available');
      }
      throw unavailable(error);
    }
  }

  async destroyVersion(keyVersion: string): Promise<void> {
    const client = await this.client();
    try {
      await client.destroyCryptoKeyVersion({ name: keyVersion });
    } catch (error) {
      // Already destroyed or scheduled: nothing left to do.
      if (grpcCode(error) === GRPC_FAILED_PRECONDITION || grpcCode(error) === GRPC_NOT_FOUND) return;
      throw unavailable(error);
    }
  }
}

function unavailable(error: unknown): NfseServiceError {
  if (error instanceof NfseServiceError) return error;
  // gRPC status only: messages may carry resource names, never secrets, but keep the log short.
  console.error('[nfse] KMS error', grpcCode(error) ?? (error as Error)?.name);
  return new NfseServiceError('KEY_VAULT_UNAVAILABLE', 'Key vault unavailable');
}

/** Production vault: project from the runtime, location and ring by env (defaults: São Paulo, nfse-certs). */
export function defaultKeyVault(): KeyVault {
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || '';
  return new KmsKeyVault({
    projectId,
    location: process.env.NFSE_KMS_LOCATION || 'southamerica-east1',
    keyRing: process.env.NFSE_KMS_KEY_RING || NFSE_KEY_RING,
  });
}
