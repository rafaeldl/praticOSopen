/**
 * Secrets of the web checkout (docs/WEB_CHECKOUT.md), bound to the `api`
 * function in index.ts:
 * - ASAAS_BILLING_API_KEY: API key of Rafsoft's Asaas account ($aact_hmlg_...
 *   sandbox, $aact_prod_... production; the prefix picks the environment);
 * - ASAAS_BILLING_WEBHOOK_TOKEN: token set on that account's webhook
 *   (header asaas-access-token);
 * - REVENUECAT_SECRET_API_KEY: already used by the RevenueCat webhook.
 * Nothing here is ever logged.
 */

import { AsaasClient, environmentFromApiKey } from '../asaas/asaas-client';

export interface BillingAsaas {
  client: AsaasClient;
  environment: 'sandbox' | 'production';
}

/** Client for Rafsoft's Asaas account, or null when the key is missing or not an Asaas key. */
export function billingAsaasFromEnv(env: NodeJS.ProcessEnv = process.env): BillingAsaas | null {
  const apiKey = env.ASAAS_BILLING_API_KEY?.trim();
  if (!apiKey) return null;
  const environment = environmentFromApiKey(apiKey);
  if (!environment) return null;
  return { client: new AsaasClient({ apiKey, environment }), environment };
}

export function revenueCatKeyFromEnv(env: NodeJS.ProcessEnv = process.env): string | null {
  return env.REVENUECAT_SECRET_API_KEY?.trim() || null;
}
