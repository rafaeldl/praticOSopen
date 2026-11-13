/** Production wiring of the web checkout: Rafsoft's Asaas + RevenueCat from the bound secrets. */

import { fetchSubscriber } from '../revenuecat.client';
import { syncCompanySubscription } from '../subscription.service';
import { billingAsaasFromEnv, revenueCatKeyFromEnv } from './billing-env';
import { grantPromotional, revokePromotionals } from './revenuecat-promotional';
import type { WebBillingDeps } from './web-billing.service';

/** Null when a secret is missing: the routes answer NOT_CONFIGURED and process nothing. */
export function defaultWebBillingDeps(env: NodeJS.ProcessEnv = process.env): WebBillingDeps | null {
  const asaas = billingAsaasFromEnv(env);
  const rcKey = revenueCatKeyFromEnv(env);
  if (!asaas || !rcKey) return null;
  return {
    asaas: asaas.client,
    environment: asaas.environment,
    grant: (companyId, plan, endTimeMs) => grantPromotional(companyId, plan, endTimeMs, rcKey),
    revoke: (companyId, plan) => revokePromotionals(companyId, plan, rcKey),
    sync: (companyId) =>
      syncCompanySubscription(companyId, { fetchSubscriber: (appUserId) => fetchSubscriber(appUserId, rcKey) }),
  };
}
