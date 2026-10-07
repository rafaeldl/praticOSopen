/**
 * Pure subscription rules shared by the Functions and one-off scripts:
 * plan limits, RevenueCat subscriber → plan/status, launch grace period.
 * No Firestore here, so scripts can import it without initializing
 * firebase-admin. subscription.service.ts re-exports the public API.
 */

import type {
  Subscription,
  SubscriptionLimits,
  SubscriptionPlan,
  SubscriptionStatus,
  SubscriptionStore,
  SubscriptionUsage,
} from '../models/types';
import type { RcSubscriber } from './revenuecat.client';

export const PLAN_LIMITS: Record<SubscriptionPlan, SubscriptionLimits> = {
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

/** RevenueCat product id → plan; fallback when an entitlement id is not a plan name. */
export const PRODUCT_TO_PLAN: Record<string, SubscriptionPlan> = {
  'praticos_starter_monthly': 'starter',
  'praticos_starter_annual': 'starter',
  'praticos_pro_monthly': 'pro',
  'praticos_pro_annual': 'pro',
  'praticos_business_monthly': 'business',
  'praticos_business_annual': 'business',
};

/** Paid plans, highest first. RevenueCat entitlement ids equal the plan names. */
export const PAID_PLANS_BY_RANK: SubscriptionPlan[] = ['business', 'pro', 'starter'];

/** Plan given during the launch grace period. */
export const GRACE_PLAN: SubscriptionPlan = 'pro';

export interface ResolvedSubscriptionState {
  plan: SubscriptionPlan;
  status: SubscriptionStatus;
  expiresAt: string | null;
  store: SubscriptionStore | null;
}

export function getPlanLimits(plan: SubscriptionPlan): SubscriptionLimits {
  return { ...(PLAN_LIMITS[plan] || PLAN_LIMITS.free) };
}

/** First day of the next month, 00:00 UTC, as ISO string. */
export function getNextMonthReset(now: Date = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();
}

function isAfter(iso: string, now: Date): boolean {
  const time = Date.parse(iso);
  return !Number.isNaN(time) && time > now.getTime();
}

function toStore(store: string | undefined): SubscriptionStore | null {
  return store === 'app_store' || store === 'play_store' ? store : null;
}

function planOf(entitlementId: string, productId: string): SubscriptionPlan | undefined {
  if ((PAID_PLANS_BY_RANK as string[]).includes(entitlementId)) return entitlementId as SubscriptionPlan;
  return PRODUCT_TO_PLAN[productId];
}

/**
 * Current subscription state from the RevenueCat subscriber:
 * - plan: highest active entitlement (business > pro > starter), else free;
 * - an entitlement is active while expires_date is null or in the future
 *   (extended by the store grace period of its subscription);
 * - status: past_due (billing issue) > cancelled (auto-renew off) > active;
 *   expired when no entitlement is active.
 */
export function resolveSubscriptionState(subscriber: RcSubscriber, now: Date): ResolvedSubscriptionState {
  const candidates = Object.entries(subscriber.entitlements ?? {}).flatMap(([id, entitlement]) => {
    const plan = planOf(id, entitlement.product_identifier);
    if (!plan || plan === 'free') return [];
    const subscription = subscriber.subscriptions?.[entitlement.product_identifier];
    let expiresAt = entitlement.expires_date;
    const graceEnd = subscription?.grace_period_expires_date;
    if (expiresAt !== null && graceEnd && Date.parse(graceEnd) > Date.parse(expiresAt)) {
      expiresAt = graceEnd;
    }
    if (expiresAt !== null && !isAfter(expiresAt, now)) return [];
    return [{ plan, expiresAt, subscription, entitlement }];
  });
  candidates.sort((a, b) => PAID_PLANS_BY_RANK.indexOf(a.plan) - PAID_PLANS_BY_RANK.indexOf(b.plan));

  const best = candidates[0];
  if (!best) return { plan: 'free', status: 'expired', expiresAt: null, store: null };

  const status: SubscriptionStatus = best.subscription?.billing_issues_detected_at
    ? 'past_due'
    : best.subscription?.unsubscribe_detected_at
      ? 'cancelled'
      : 'active';
  return {
    plan: best.plan,
    status,
    expiresAt: best.expiresAt,
    store: toStore(best.subscription?.store ?? best.entitlement.store),
  };
}

/** Launch grace period still running (webhook must not overwrite it with Free). */
export function isGraceActive(subscription: Subscription | undefined, now: Date): boolean {
  return (
    subscription?.source === 'grace' &&
    typeof subscription.expiresAt === 'string' &&
    isAfter(subscription.expiresAt, now)
  );
}

function defaultUsage(): SubscriptionUsage {
  return { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1, usageResetAt: getNextMonthReset() };
}

/**
 * Grace subscription (Pro until expiresAt, source 'grace') keeping the
 * existing usage. Null when the company already has an active paid store
 * subscription.
 */
export function buildGraceSubscription(existing: Subscription | undefined, expiresAt: Date): Subscription | null {
  if (existing && existing.source === 'store' && existing.plan !== 'free' && existing.status !== 'expired') {
    return null;
  }
  return {
    plan: GRACE_PLAN,
    status: 'active',
    source: 'grace',
    store: null,
    expiresAt: expiresAt.toISOString(),
    limits: getPlanLimits(GRACE_PLAN),
    usage: existing?.usage ?? defaultUsage(),
  };
}
