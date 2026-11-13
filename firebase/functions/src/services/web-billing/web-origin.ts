/**
 * Hook of syncCompanySubscription (subscription.service.ts) for plans bought
 * on the web (docs/WEB_CHECKOUT.md):
 * - a promotional entitlement backed by the company's web record is written
 *   with store `web` (and status `cancelled` once it stops renewing);
 * - a store purchase (App Store / Google Play) in force while the web still
 *   renews stops the Asaas recurrence: the higher plan wins through the
 *   RevenueCat ranking and the customer is not charged twice.
 * Never throws: a failure here keeps the state RevenueCat reported.
 */

import { db } from '../firestore.service';
import type { RcSubscriber } from '../revenuecat.client';
import type { ResolvedSubscriptionState } from '../subscription-plans';
import { billingAsaasFromEnv, type BillingAsaas } from './billing-env';
import { applyWebOrigin, storeOverlapsWeb, type WebBillingRecord } from './web-billing-rules';

export const webBillingRef = (companyId: string) =>
  db.collection('companies').doc(companyId).collection('private').doc('webBilling');

export async function readWebBilling(companyId: string): Promise<WebBillingRecord | null> {
  const snapshot = await webBillingRef(companyId).get();
  return snapshot.exists ? (snapshot.data() as WebBillingRecord) : null;
}

/** Stops the Asaas recurrence (DELETE /subscriptions) and marks the record cancelled. */
export async function stopWebRecurrence(
  companyId: string,
  record: WebBillingRecord,
  reason: NonNullable<WebBillingRecord['cancelReason']>,
  now: Date,
  asaas: BillingAsaas | null,
): Promise<void> {
  if (!asaas) throw new Error('web billing: Asaas key not configured');
  await asaas.client.deleteSubscription(record.asaasSubscriptionId).catch((error: { status?: number }) => {
    // Already removed in Asaas: nothing left to stop.
    if (error?.status !== 404) throw error;
  });
  const nowIso = now.toISOString();
  await webBillingRef(companyId).update({
    status: 'cancelled',
    cancelledAt: nowIso,
    cancelReason: reason,
    updatedAt: nowIso,
  });
}

export async function webOriginFor(
  companyId: string,
  subscriber: RcSubscriber,
  state: ResolvedSubscriptionState,
  now: Date,
  asaas: () => BillingAsaas | null = billingAsaasFromEnv,
): Promise<ResolvedSubscriptionState> {
  try {
    const record = await readWebBilling(companyId);
    if (!record) return state;
    if (storeOverlapsWeb(state, record)) {
      try {
        await stopWebRecurrence(companyId, record, 'store', now, asaas());
        console.warn('[WebBilling] store purchase over a web subscription: Asaas recurrence stopped', { companyId });
        return state;
      } catch (error) {
        console.error('[WebBilling] could not stop the web recurrence after a store purchase', {
          companyId,
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
    return applyWebOrigin(state, subscriber, record);
  } catch (error) {
    console.error('[WebBilling] web origin check failed', {
      companyId,
      error: error instanceof Error ? error.message : 'unknown',
    });
    return state;
  }
}
