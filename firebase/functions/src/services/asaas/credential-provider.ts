/**
 * Resolves an authenticated AsaasClient for a company.
 * Stage 1: API key pasted by the owner/admin (mode 'apiKey').
 * Stage 3 (Flapp Store) adds another provider behind the same interface.
 */

import { db } from '../firestore.service';
import { AsaasConnectionDoc } from '../../models/asaas.types';
import { AsaasClient } from './asaas-client';
import { decryptSecret, readMasterKeyFromEnv } from './crypto';
import { AsaasServiceError } from './errors';

export interface AsaasCredentialProvider {
  getClient(companyId: string): Promise<AsaasClient>;
}

export function asaasConnectionRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection('private').doc('asaas');
}

/** Builds a client from a stored connection doc (also used by disconnect). */
export function clientFromConnection(
  connection: AsaasConnectionDoc,
  masterKey: string,
  fetchImpl?: typeof fetch,
): AsaasClient {
  const apiKey = decryptSecret(connection.encryptedApiKey, masterKey);
  return new AsaasClient({ apiKey, environment: connection.environment, fetchImpl });
}

export class ApiKeyCredentialProvider implements AsaasCredentialProvider {
  constructor(
    private readonly masterKey: () => string = readMasterKeyFromEnv,
    private readonly fetchImpl?: typeof fetch,
  ) {}

  async getClient(companyId: string): Promise<AsaasClient> {
    const snapshot = await asaasConnectionRef(companyId).get();
    const connection = snapshot.data() as AsaasConnectionDoc | undefined;
    if (!snapshot.exists || !connection || connection.status !== 'active') {
      throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
    }
    return clientFromConnection(connection, this.masterKey(), this.fetchImpl);
  }
}

let provider: AsaasCredentialProvider | null = null;

export function getAsaasCredentialProvider(): AsaasCredentialProvider {
  if (!provider) provider = new ApiKeyCredentialProvider();
  return provider;
}

/** Test hook: replace the singleton (pass null to restore the default). */
export function setAsaasCredentialProvider(p: AsaasCredentialProvider | null): void {
  provider = p;
}
