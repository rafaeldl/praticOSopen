/**
 * Subscription Service
 * Handles RevenueCat webhooks and subscription management
 */

import {
  db,
  getRootCollection,
  getDocument,
  updateDocument,
} from './firestore.service';
import {
  Subscription,
  SubscriptionStatus,
} from '../models/types';
import {
  PLAN_LIMITS,
  PRODUCT_TO_PLAN,
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
 * Update subscription from RevenueCat webhook
 */
export async function updateSubscriptionFromWebhook(
  companyId: string,
  productId: string,
  status: SubscriptionStatus,
  expiresAt?: string,
  subscriberId?: string
): Promise<boolean> {
  const plan = PRODUCT_TO_PLAN[productId] || 'free';
  const limits = PLAN_LIMITS[plan];

  const collection = getRootCollection('companies');
  const company = await getDocument<{ subscription?: Subscription }>(collection, companyId);
  if (!company) return false;

  // Preserve existing usage data
  const currentUsage = company.subscription?.usage || {
    photosThisMonth: 0,
    formTemplatesActive: 0,
    usersActive: 1,
    usageResetAt: getNextMonthReset(),
  };

  const subscription: Subscription = {
    plan,
    status,
    rcSubscriberId: subscriberId,
    subscribedAt: company.subscription?.subscribedAt || new Date().toISOString(),
    expiresAt,
    limits,
    usage: currentUsage,
  };

  await updateDocument(collection, companyId, {
    subscription,
    updatedAt: new Date().toISOString(),
  });

  console.log(`[Subscription] Updated company ${companyId} to plan ${plan} (${status})`);
  return true;
}

/**
 * Cancel subscription (revert to free)
 */
export async function cancelSubscription(companyId: string): Promise<boolean> {
  const collection = getRootCollection('companies');
  const company = await getDocument<{ subscription?: Subscription }>(collection, companyId);
  if (!company) return false;

  const currentUsage = company.subscription?.usage || {
    photosThisMonth: 0,
    formTemplatesActive: 0,
    usersActive: 1,
    usageResetAt: getNextMonthReset(),
  };

  const subscription: Subscription = {
    plan: 'free',
    status: 'cancelled',
    cancelledAt: new Date().toISOString(),
    limits: PLAN_LIMITS.free,
    usage: currentUsage,
  };

  await updateDocument(collection, companyId, {
    subscription,
    updatedAt: new Date().toISOString(),
  });

  console.log(`[Subscription] Cancelled subscription for company ${companyId}`);
  return true;
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
// RevenueCat Webhook Handling
// ============================================================================

export interface RevenueCatWebhookEvent {
  type: string;
  id: string;
  event_timestamp_ms: number;
  app_user_id: string;
  product_id?: string;
  entitlement_id?: string;
  expiration_at_ms?: number;
  subscriber?: {
    original_app_user_id: string;
    entitlements?: Record<string, {
      product_identifier: string;
      expires_date?: string;
    }>;
  };
}

/**
 * Process RevenueCat webhook event
 */
export async function processRevenueCatWebhook(event: RevenueCatWebhookEvent): Promise<boolean> {
  const { type, app_user_id, product_id, expiration_at_ms } = event;

  // app_user_id should be the companyId
  const companyId = app_user_id;
  if (!companyId) {
    console.error('[Webhook] Missing app_user_id (companyId)');
    return false;
  }

  console.log(`[Webhook] Processing ${type} for company ${companyId}`);

  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE': {
      if (!product_id) {
        console.error('[Webhook] Missing product_id for purchase event');
        return false;
      }
      const expiresAt = expiration_at_ms
        ? new Date(expiration_at_ms).toISOString()
        : undefined;
      return updateSubscriptionFromWebhook(
        companyId,
        product_id,
        'active',
        expiresAt,
        event.subscriber?.original_app_user_id
      );
    }

    case 'CANCELLATION':
    case 'EXPIRATION':
      return cancelSubscription(companyId);

    case 'BILLING_ISSUE':
      // Mark as past_due but don't cancel yet
      if (product_id) {
        const expiresAtBilling = expiration_at_ms
          ? new Date(expiration_at_ms).toISOString()
          : undefined;
        return updateSubscriptionFromWebhook(
          companyId,
          product_id,
          'past_due',
          expiresAtBilling
        );
      }
      return false;

    case 'SUBSCRIBER_ALIAS':
    case 'TRANSFER':
      // These don't change subscription state
      console.log(`[Webhook] Ignoring event type: ${type}`);
      return true;

    default:
      console.log(`[Webhook] Unknown event type: ${type}`);
      return true;
  }
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
