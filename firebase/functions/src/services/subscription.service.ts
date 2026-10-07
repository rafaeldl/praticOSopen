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
import { Subscription, SubscriptionPlan } from '../models/types';
import {
  PAID_PLANS_BY_RANK,
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

const ALL_PLANS: SubscriptionPlan[] = ['free', 'starter', 'pro', 'business'];
const BATCH_LIMIT = 400;

/**
 * Resets the monthly counters (photosThisMonth) of every company that has a
 * subscription. Firestore cannot query "field exists", so the query matches
 * every plan value (`in` on one field: automatic single-field index, no
 * composite index); companies without `subscription` have no counter.
 * Called by scheduledResetMonthlyUsage on the 1st of each month.
 */
export async function resetMonthlyUsage(now: Date = new Date()): Promise<number> {
  const nowIso = now.toISOString();
  const nextReset = getNextMonthReset(now);
  const snapshot = await getRootCollection('companies')
    .where('subscription.plan', 'in', ALL_PLANS)
    .get();

  let batch = db.batch();
  let pending = 0;
  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      'subscription.usage.photosThisMonth': 0,
      'subscription.usage.usageResetAt': nextReset,
      updatedAt: nowIso,
    });
    pending++;
    if (pending === BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  console.log(`[Subscription] Reset monthly usage for ${snapshot.size} companies`);
  return snapshot.size;
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
export function buildPlanUpdate(
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

export interface ExpireDeps {
  fetchSubscriber: (appUserId: string) => Promise<RcSubscriber>;
}

/**
 * Daily backstop: companies on a paid plan whose expiresAt has passed (end of
 * the launch grace period, missed webhooks) are re-synced from RevenueCat.
 * Without an active entitlement they drop to Free/expired; renewed ones get
 * the new expiresAt. A failure on one company is logged and skipped.
 */
export async function expireSubscriptions(now: Date, deps: ExpireDeps): Promise<{ expired: number }> {
  const snapshot = await getRootCollection('companies')
    .where('subscription.plan', 'in', PAID_PLANS_BY_RANK)
    .get();

  let expired = 0;
  for (const doc of snapshot.docs) {
    const current = doc.get('subscription') as Subscription | undefined;
    const expiresAt = current?.expiresAt;
    if (typeof expiresAt !== 'string' || Date.parse(expiresAt) > now.getTime()) continue;

    try {
      const subscriber = await deps.fetchSubscriber(doc.id);
      const state = resolveSubscriptionState(subscriber, now);
      await doc.ref.update(buildPlanUpdate(doc.id, subscriber, state, now));
      if (state.plan === 'free') expired++;
    } catch (error) {
      console.error('[Subscription] Expiry check failed', {
        companyId: doc.id,
        error: error instanceof Error ? error.message : 'unknown',
      });
    }
  }

  console.log(`[Subscription] Expiry check: ${expired} companies moved to Free`);
  return { expired };
}
