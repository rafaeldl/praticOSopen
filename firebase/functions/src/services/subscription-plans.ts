/**
 * Pure subscription rules shared by the Functions and one-off scripts:
 * plan limits, RevenueCat subscriber → plan/status, launch grace period.
 * No Firestore here, so scripts can import it without initializing
 * firebase-admin. subscription.service.ts re-exports the public API.
 */

import type {
  Subscription,
  SubscriptionExtras,
  SubscriptionLimits,
  SubscriptionPlan,
  SubscriptionStatus,
  SubscriptionStore,
  SubscriptionUsage,
} from '../models/types';
import type { RcSubscriber } from './revenuecat.client';
import {
  PLAN_EXTRAS,
  PLAN_IDS,
  PLAN_TABLES_IN_FORCE,
  PLAN_TABLE_CURRENT_VERSION,
  PLAN_TABLE_LEGACY_VERSION,
  type PlanRow,
} from './plan-table.generated';

/** The plan table in force (docs/plans/plans.json), by plan. */
export function currentPlanRows(): Readonly<Record<SubscriptionPlan, PlanRow>> {
  return PLAN_TABLES_IN_FORCE[PLAN_TABLE_CURRENT_VERSION];
}

/**
 * Version of the table a subscription follows (#726): its `tableVersion` when
 * it is one of the table's versions; else, for a paid plan bought before the
 * current table (no `tableVersion`; the courtesy too, which keeps the old
 * Pro), the legacy version;
 * else the current one (also for a version this code does not know). The
 * webhook writes `tableVersion` on every plan change.
 */
export function tableVersionOf(
  subscription: { tableVersion?: unknown; plan?: unknown; source?: unknown } | null | undefined,
): string {
  const version = subscription?.tableVersion;
  if (typeof version === 'string') return version in PLAN_TABLES_IN_FORCE ? version : PLAN_TABLE_CURRENT_VERSION;
  const plan = subscription?.plan;
  const paid = typeof plan === 'string' && plan !== 'free' && (PLAN_IDS as readonly string[]).includes(plan);
  return paid ? PLAN_TABLE_LEGACY_VERSION : PLAN_TABLE_CURRENT_VERSION;
}

/** Row of a plan in a version of the table (the current one by default). */
export function planRow(plan: SubscriptionPlan, version: string = PLAN_TABLE_CURRENT_VERSION): PlanRow {
  return (PLAN_TABLES_IN_FORCE[version] ?? currentPlanRows())[plan] ?? currentPlanRows().free;
}

/** The limits a subscription stores, from a row of the table. */
export function limitsOfRow(row: PlanRow): SubscriptionLimits {
  return {
    ordersPerMonth: row.ordersPerMonth,
    photosPerMonth: row.photosPerMonth,
    formTemplates: row.formTemplates,
    users: row.users,
    pdfWatermark: row.pdfWatermark,
  };
}

/** Default limits per plan, from the current table. -1 = unlimited. */
export const PLAN_LIMITS: Record<SubscriptionPlan, SubscriptionLimits> = Object.fromEntries(
  PLAN_IDS.map((plan) => [plan, limitsOfRow(currentPlanRows()[plan])]),
) as Record<SubscriptionPlan, SubscriptionLimits>;

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
  /** Business packs in force; zero unless the plan is Business (#737). */
  extras: SubscriptionExtras;
}

export const NO_EXTRAS: SubscriptionExtras = Object.freeze({ users: 0, ordersPerMonth: 0 });

/** Store product prefix of the Business packs: `praticos_extra_users_5` → `extra_users_5`. */
const EXTRA_PRODUCT_PREFIX = 'praticos_';

/** The pack an entitlement is, by its id or, as a fallback, its product id. */
function extraOf(entitlementId: string, productId: string): string | undefined {
  if (entitlementId in PLAN_EXTRAS) return entitlementId;
  // Play reports subscriptions as `productId:basePlanId`.
  const product = productId.split(':')[0];
  const id = product.startsWith(EXTRA_PRODUCT_PREFIX) ? product.slice(EXTRA_PRODUCT_PREFIX.length) : product;
  return id in PLAN_EXTRAS ? id : undefined;
}

/**
 * Adds packs to limits. A field with no limit (-1) stays -1. Negative extras
 * take them out again (used to swap the packs of a stored subscription).
 */
export function addExtras(limits: SubscriptionLimits, extras: SubscriptionExtras, sign: 1 | -1 = 1): SubscriptionLimits {
  const add = (limit: number, extra: number) => (limit === -1 ? -1 : Math.max(0, limit + sign * extra));
  return {
    ...limits,
    users: add(limits.users, extras.users),
    ordersPerMonth: add(limits.ordersPerMonth, extras.ordersPerMonth),
  };
}

export function sameExtras(a: SubscriptionExtras | undefined, b: SubscriptionExtras | undefined): boolean {
  const x = a ?? NO_EXTRAS;
  const y = b ?? NO_EXTRAS;
  return x.users === y.users && x.ordersPerMonth === y.ordersPerMonth;
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
  // Play reports subscriptions as `productId:basePlanId`.
  return PRODUCT_TO_PLAN[productId.split(':')[0]];
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
  const active = Object.entries(subscriber.entitlements ?? {}).flatMap(([id, entitlement]) => {
    const subscription = subscriber.subscriptions?.[entitlement.product_identifier];
    let expiresAt = entitlement.expires_date;
    const graceEnd = subscription?.grace_period_expires_date;
    if (expiresAt !== null && graceEnd && Date.parse(graceEnd) > Date.parse(expiresAt)) {
      expiresAt = graceEnd;
    }
    if (expiresAt !== null && !isAfter(expiresAt, now)) return [];
    return [{ id, expiresAt, subscription, entitlement }];
  });
  const candidates = active.flatMap((item) => {
    const plan = planOf(item.id, item.entitlement.product_identifier);
    return plan && plan !== 'free' ? [{ ...item, plan }] : [];
  });
  candidates.sort((a, b) => PAID_PLANS_BY_RANK.indexOf(a.plan) - PAID_PLANS_BY_RANK.indexOf(b.plan));

  const best = candidates[0];
  if (!best) return { plan: 'free', status: 'expired', expiresAt: null, store: null, extras: { ...NO_EXTRAS } };

  // Packs count only on Business. Within a field the largest active pack wins:
  // the packs of a field are steps of one ladder (one store group), so two at
  // once only happen while one replaces the other.
  const extras: SubscriptionExtras = { ...NO_EXTRAS };
  if (best.plan === 'business') {
    for (const item of active) {
      const pack = extraOf(item.id, item.entitlement.product_identifier);
      if (!pack) continue;
      extras.users = Math.max(extras.users, PLAN_EXTRAS[pack].users ?? 0);
      extras.ordersPerMonth = Math.max(extras.ordersPerMonth, PLAN_EXTRAS[pack].ordersPerMonth ?? 0);
    }
  }

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
    extras,
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

/** Days before the end of the courtesy on which the owner is told, latest last. */
export const COURTESY_NOTICE_DAYS = [15, 3];

const DAY_MS = 24 * 60 * 60 * 1000;

/** Last end-of-courtesy push sent to a company. */
export interface CourtesyNoticeRecord {
  expiresAt: string;
  days: number;
}

/** A notice owed: its step (15 or 3) and the days really left. */
export interface DueCourtesyNotice {
  step: number;
  daysLeft: number;
}

/**
 * The end-of-courtesy notice owed at `now`, or null. A notice already
 * sent for this `expiresAt` (`last`) is not repeated; moving the date starts over.
 */
export function dueCourtesyNotice(
  subscription: Subscription | undefined,
  now: Date,
  last?: CourtesyNoticeRecord,
): DueCourtesyNotice | null {
  if (!isGraceActive(subscription, now)) return null;
  const expiresAt = subscription!.expiresAt as string;
  const daysLeft = Math.ceil((Date.parse(expiresAt) - now.getTime()) / DAY_MS);
  const step = [...COURTESY_NOTICE_DAYS].sort((a, b) => a - b).find((days) => daysLeft <= days);
  if (step === undefined) return null;
  if (last?.expiresAt === expiresAt && last.days <= step) return null;
  return { step, daysLeft };
}

function defaultUsage(): SubscriptionUsage {
  return { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1, usageResetAt: getNextMonthReset() };
}

/**
 * Grace subscription (Pro until expiresAt, source 'grace') keeping the
 * existing usage. Null when the company already has an active paid store
 * subscription, or a legacy paid one (set manually: paid plan, no source,
 * not expired, no expiry or expiry in the future). A missing plan is Free.
 */
export function buildGraceSubscription(
  existing: Subscription | undefined,
  expiresAt: Date,
  now: Date = new Date(),
): Subscription | null {
  // A map without plan (only usage, created by the app's dotted usage updates) is Free.
  const plan = existing?.plan ?? 'free';
  if (existing && existing.source === 'store' && plan !== 'free' && existing.status !== 'expired') {
    return null;
  }
  if (
    existing &&
    plan !== 'free' &&
    existing.source === undefined &&
    existing.status !== 'expired' &&
    (!existing.expiresAt || isAfter(existing.expiresAt, now))
  ) {
    return null;
  }
  return {
    plan: GRACE_PLAN,
    status: 'active',
    source: 'grace',
    store: null,
    expiresAt: expiresAt.toISOString(),
    // The courtesy keeps the old Pro until it ends (owner's decision, #726).
    limits: limitsOfRow(planRow(GRACE_PLAN, PLAN_TABLE_LEGACY_VERSION)),
    tableVersion: PLAN_TABLE_LEGACY_VERSION,
    usage: existing?.usage ?? defaultUsage(),
  };
}
