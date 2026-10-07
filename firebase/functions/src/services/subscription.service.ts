/**
 * Subscription Service
 * Server-side subscription state: RevenueCat sync, usage counters, expiry.
 * Plan fields are written only here (Firestore rules block clients).
 */

import {
  db,
  getRootCollection,
  getDocument,
  updateDocument,
} from './firestore.service';
import { Subscription } from '../models/types';
import {
  PLAN_LIMITS,
  getNextMonthReset,
  getPlanLimits,
  isGraceActive,
  resolveSubscriptionState,
  type ResolvedSubscriptionState,
} from './subscription-plans';
import type { RcSubscriber } from './revenuecat.client';

export {
  PLAN_LIMITS,
  getPlanLimits,
  getNextMonthReset,
  resolveSubscriptionState,
  isGraceActive,
  buildGraceSubscription,
} from './subscription-plans';
export type { ResolvedSubscriptionState } from './subscription-plans';

// ============================================================================
// Subscription Operations
// ============================================================================

/**
 * Get subscription for a company
 */
export async function getCompanySubscription(companyId: string): Promise<Subscription | null> {
  const collection = getRootCollection('companies');
  const company = await getDocument<{ subscription?: Subscription }>(collection, companyId);
  return company?.subscription || null;
}

/**
 * Create default free subscription for new company
 */
export function createFreeSubscription(): Subscription {
  return {
    plan: 'free',
    status: 'active',
    limits: PLAN_LIMITS.free,
    usage: {
      photosThisMonth: 0,
      formTemplatesActive: 0,
      usersActive: 1,
      usageResetAt: getNextMonthReset(),
    },
  };
}

/**
 * Increment photo usage for company
 */
export async function incrementPhotoUsage(companyId: string): Promise<void> {
  const collection = getRootCollection('companies');
  const companyRef = collection.doc(companyId);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(companyRef);
    if (!doc.exists) return;

    const data = doc.data();
    const subscription = data?.subscription as Subscription | undefined;
    const currentCount = subscription?.usage?.photosThisMonth || 0;

    transaction.update(companyRef, {
      'subscription.usage.photosThisMonth': currentCount + 1,
      updatedAt: new Date().toISOString(),
    });
  });
}

/**
 * Update form template count for company
 */
export async function updateFormTemplateCount(companyId: string, count: number): Promise<void> {
  const collection = getRootCollection('companies');
  await updateDocument(collection, companyId, {
    'subscription.usage.formTemplatesActive': count,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Update user count for company
 */
export async function updateUserCount(companyId: string, count: number): Promise<void> {
  const collection = getRootCollection('companies');
  await updateDocument(collection, companyId, {
    'subscription.usage.usersActive': count,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Reset monthly usage counters for all companies
 * Called by scheduled Cloud Function
 */
export async function resetMonthlyUsage(): Promise<number> {
  const now = new Date();
  const nextReset = getNextMonthReset();
  let count = 0;

  // Query companies where usageResetAt is in the past
  const companiesRef = db.collection('companies');
  const snapshot = await companiesRef
    .where('subscription.usage.usageResetAt', '<=', now.toISOString())
    .get();

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, {
      'subscription.usage.photosThisMonth': 0,
      'subscription.usage.usageResetAt': nextReset,
      updatedAt: new Date().toISOString(),
    });
    count++;
  });

  if (count > 0) {
    await batch.commit();
    console.log(`[Subscription] Reset monthly usage for ${count} companies`);
  }

  return count;
}

// ============================================================================
// RevenueCat sync (authoritative state)
// ============================================================================

type FieldUpdates = FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData>;

export interface SyncDeps {
  /** Reads GET /v1/subscribers/{appUserId} (bound to the secret API key by the caller). */
  fetchSubscriber: (appUserId: string) => Promise<RcSubscriber>;
  now?: Date;
}

export type SyncResult = 'updated' | 'grace_kept' | 'company_not_found';

/** Dotted-path update with the plan fields only; never touches subscription.usage. */
function buildPlanUpdate(
  companyId: string,
  subscriber: RcSubscriber,
  state: ResolvedSubscriptionState,
  now: Date,
): FieldUpdates {
  const nowIso = now.toISOString();
  return {
    'subscription.plan': state.plan,
    'subscription.status': state.status,
    'subscription.limits': getPlanLimits(state.plan),
    'subscription.expiresAt': state.expiresAt,
    'subscription.store': state.store,
    'subscription.source': 'store',
    'subscription.rcSubscriberId': subscriber.original_app_user_id || companyId,
    'subscription.updatedAt': nowIso,
    updatedAt: nowIso,
  };
}

/**
 * Writes the company's current subscription as RevenueCat reports it
 * (app_user_id = companyId). Idempotent: safe for repeated and out-of-order
 * webhook events. A running launch grace period is kept while RevenueCat has
 * no active entitlement.
 */
export async function syncCompanySubscription(companyId: string, deps: SyncDeps): Promise<SyncResult> {
  const now = deps.now ?? new Date();
  const ref = getRootCollection('companies').doc(companyId);
  const snapshot = await ref.get();
  if (!snapshot.exists) return 'company_not_found';

  const subscriber = await deps.fetchSubscriber(companyId);
  const state = resolveSubscriptionState(subscriber, now);
  const current = snapshot.get('subscription') as Subscription | undefined;
  if (state.plan === 'free' && isGraceActive(current, now)) {
    console.log(`[Subscription] Grace period kept for company ${companyId}`);
    return 'grace_kept';
  }

  await ref.update(buildPlanUpdate(companyId, subscriber, state, now));
  console.log(`[Subscription] Company ${companyId} synced: ${state.plan} (${state.status})`);
  return 'updated';
}
