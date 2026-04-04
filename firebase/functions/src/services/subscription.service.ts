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
  SubscriptionPlan,
  SubscriptionStatus,
  SubscriptionLimits,
} from '../models/types';

// ============================================================================
// Plan Limits Configuration
// ============================================================================

const PLAN_LIMITS: Record<SubscriptionPlan, SubscriptionLimits> = {
  free: {
    photosPerMonth: 30,
    formTemplates: 1,
    users: 1,
    pdfWatermark: true,
  },
  starter: {
    photosPerMonth: 200,
    formTemplates: 3,
    users: 3,
    pdfWatermark: false,
  },
  pro: {
    photosPerMonth: 500,
    formTemplates: 10,
    users: 5,
    pdfWatermark: false,
  },
  business: {
    photosPerMonth: -1, // unlimited
    formTemplates: -1,
    users: -1,
    pdfWatermark: false,
  },
};

// RevenueCat product ID to plan mapping
const PRODUCT_TO_PLAN: Record<string, SubscriptionPlan> = {
  'praticos_starter_monthly': 'starter',
  'praticos_starter_annual': 'starter',
  'praticos_pro_monthly': 'pro',
  'praticos_pro_annual': 'pro',
  'praticos_business_monthly': 'business',
  'praticos_business_annual': 'business',
};

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
    case 'PRODUCT_CHANGE':
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
// Helper Functions
// ============================================================================

/**
 * Get the first day of next month as ISO string
 */
function getNextMonthReset(): string {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return nextMonth.toISOString();
}

/**
 * Get plan limits by plan name
 */
export function getPlanLimits(plan: SubscriptionPlan): SubscriptionLimits {
  return PLAN_LIMITS[plan] || PLAN_LIMITS.free;
}
