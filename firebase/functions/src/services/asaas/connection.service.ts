/**
 * Connects / disconnects a company's Asaas account (API key mode).
 * The key is validated against Asaas, encrypted (AES-256-GCM) and stored in
 * companies/{cid}/private/asaas; a webhook is registered with a random token
 * stored only as SHA-256.
 */

import { randomBytes } from 'node:crypto';
import { db } from '../firestore.service';
import { UserAggr } from '../../models/types';
import {
  AsaasConnectionDoc,
  AsaasCreateWebhookInput,
  PaymentSettingsDoc,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient, environmentFromApiKey } from './asaas-client';
import { encryptSecret, hashToken, readMasterKeyFromEnv } from './crypto';
import { asaasConnectionRef, clientFromConnection } from './credential-provider';
import { AsaasServiceError } from './errors';

const DEFAULT_WEBHOOK_BASE_URL = 'https://southamerica-east1-praticos.cloudfunctions.net/api';

export const ASAAS_WEBHOOK_EVENTS: AsaasCreateWebhookInput['events'] = [
  'PAYMENT_RECEIVED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_OVERDUE',
  'PAYMENT_REFUNDED',
  'PAYMENT_DELETED',
];

export function paymentSettingsRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection('settings').doc('payments');
}

export function webhookUrl(companyId: string): string {
  const base = (process.env.ASAAS_WEBHOOK_BASE_URL || DEFAULT_WEBHOOK_BASE_URL).replace(/\/+$/, '');
  return `${base}/webhooks/asaas/${companyId}`;
}

export async function getPaymentSettings(companyId: string): Promise<PaymentSettingsDoc> {
  const snapshot = await paymentSettingsRef(companyId).get();
  const data = (snapshot.data() || {}) as Partial<PaymentSettingsDoc>;
  const settings: PaymentSettingsDoc = {
    asaasEnabled: data.asaasEnabled === true,
    asaasConnected: data.asaasConnected === true,
  };
  if (data.asaasAccountName) settings.asaasAccountName = data.asaasAccountName;
  if (data.asaasEnvironment) settings.asaasEnvironment = data.asaasEnvironment;
  return settings;
}

async function resolveWebhookEmail(
  user: UserAggr & { email?: string },
  accountEmail: string | undefined,
): Promise<string> {
  if (user.email) return user.email;
  const userDoc = await db.collection('users').doc(user.id).get();
  const email = userDoc.data()?.email as string | undefined;
  if (email) return email;
  if (accountEmail) return accountEmail;
  throw new AsaasServiceError('ASAAS_VALIDATION_ERROR', 'An email is required to register the Asaas webhook');
}

/**
 * Runs an Asaas API call. Network failures (raw TimeoutError/TypeError from
 * fetch) become ASAAS_UNAVAILABLE; AsaasApiError and business errors pass through.
 */
async function callAsaas<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    if (error instanceof AsaasApiError || error instanceof AsaasServiceError) throw error;
    throw new AsaasServiceError('ASAAS_UNAVAILABLE', 'Asaas is unavailable');
  }
}

/** Best effort: removes the webhook of a stored connection. Never throws. */
async function deleteStoredWebhook(companyId: string, connection: AsaasConnectionDoc): Promise<void> {
  if (!connection.webhookId) return;
  try {
    const client = clientFromConnection(connection, readMasterKeyFromEnv());
    await client.deleteWebhook(connection.webhookId);
  } catch (error) {
    const status = error instanceof AsaasApiError ? error.status : 'unknown';
    console.warn(`[Asaas] Could not delete webhook of company ${companyId} (status ${status})`);
  }
}

export async function connectAsaas(
  companyId: string,
  apiKey: string,
  user: UserAggr & { email?: string },
): Promise<PaymentSettingsDoc> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasEnabled) {
    throw new AsaasServiceError('ASAAS_NOT_ENABLED', 'Asaas is not enabled for this company');
  }

  const key = (apiKey || '').trim();
  const environment = environmentFromApiKey(key);
  if (!environment) {
    throw new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key');
  }

  const client = new AsaasClient({ apiKey: key, environment });

  let account;
  try {
    account = await callAsaas(() => client.getMyAccount());
  } catch (error) {
    if (error instanceof AsaasApiError && (error.status === 401 || error.status === 403)) {
      throw new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key');
    }
    throw error;
  }

  const wallets = await callAsaas(() => client.getWallets());
  const accountName = account.tradingName || account.companyName || account.name || '';
  const email = await resolveWebhookEmail(user, account.email);
  const masterKey = readMasterKeyFromEnv();

  const connectionRef = asaasConnectionRef(companyId);
  const existing = await connectionRef.get();
  if (existing.exists) {
    await deleteStoredWebhook(companyId, existing.data() as AsaasConnectionDoc);
  }

  const authToken = randomBytes(48).toString('base64url');
  const webhook = await callAsaas(() => client.createWebhook({
    name: 'PraticOS',
    url: webhookUrl(companyId),
    email,
    enabled: true,
    interrupted: false,
    apiVersion: 3,
    sendType: 'SEQUENTIALLY',
    authToken,
    events: ASAAS_WEBHOOK_EVENTS,
  }));

  const connection: AsaasConnectionDoc = {
    mode: 'apiKey',
    environment,
    encryptedApiKey: encryptSecret(key, masterKey),
    accountName,
    webhookId: webhook.id,
    webhookTokenHash: hashToken(authToken),
    status: 'active',
    connectedBy: { id: user.id, name: user.name },
    connectedAt: new Date().toISOString(),
  };
  if (wallets[0]?.id) connection.walletId = wallets[0].id;

  const newSettings: PaymentSettingsDoc = {
    asaasEnabled: true,
    asaasConnected: true,
    asaasAccountName: accountName,
    asaasEnvironment: environment,
  };

  try {
    const batch = db.batch();
    batch.set(connectionRef, connection);
    batch.set(paymentSettingsRef(companyId), newSettings);
    await batch.commit();
  } catch (error) {
    await client.deleteWebhook(webhook.id).catch(() => undefined);
    throw error;
  }

  console.log(`[Asaas] Company ${companyId} connected (${environment})`);
  return newSettings;
}

export async function disconnectAsaas(companyId: string): Promise<void> {
  const connectionRef = asaasConnectionRef(companyId);
  const snapshot = await connectionRef.get();
  if (snapshot.exists) {
    await deleteStoredWebhook(companyId, snapshot.data() as AsaasConnectionDoc);
  }

  // Removes the credential and the server-only subcollections (customers map, events).
  await db.recursiveDelete(connectionRef);

  const settings = await getPaymentSettings(companyId);
  await paymentSettingsRef(companyId).set({
    asaasEnabled: settings.asaasEnabled,
    asaasConnected: false,
  });

  console.log(`[Asaas] Company ${companyId} disconnected`);
}
