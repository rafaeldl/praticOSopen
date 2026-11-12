/**
 * Plan limits on the server (docs/PLAN_LIMITS_SERVER.md): the same check as
 * the app (lib/services/feature_gate_service.dart, lib/models/subscription.dart)
 * and the web (firebase/webapp/src/lib/plan-limits.ts), with the numbers of
 * the plan table (docs/plans/plans.json) and the usage counted here.
 *
 * Shared cases: docs/web-app/contract-cases/plan-limits.json (Dart, here and web).
 *
 * One switch for the three: `config/paidPlans.enabled` (Firestore), off by
 * default; off, every limit is -1. The app also needs a build that can sell
 * (App Review 3.1.1), see FeatureGateService.planLimitsEnforced.
 */

import { db, getRootCollection, getTenantCollection } from './firestore.service';
import { PLAN_LIMITS, limitsOfRow, planRow, tableVersionOf } from './subscription-plans';
import { PLAN_IDS } from './plan-table.generated';
import { instantOfWall, wallClockOf } from './contract-generation';
import type { SubscriptionLimits, SubscriptionPlan } from '../models/types';

export type PlanResource = 'order' | 'photo' | 'formTemplate' | 'collaborator';

export const PLAN_RESOURCES: readonly PlanResource[] = ['order', 'photo', 'formTemplate', 'collaborator'];

type Json = Record<string, unknown>;

/** Where the usage stands after what enters: no limit, under 80%, from 80%, at the limit, over it. */
export type UsageLevel = 'unlimited' | 'ok' | 'near' | 'atLimit' | 'over';

export interface PlanLimitCheck {
  allowed: boolean;
  resource: PlanResource;
  /** -1 = unlimited (also when limits are off). */
  limit: number;
  usage: number;
  adding: number;
  /** Plan in force (Free once expiresAt has passed). */
  plan: SubscriptionPlan;
  /** Usage plus what enters, against the limit: when to warn (80% and 100%). */
  level: UsageLevel;
  /** Allowed only because of the month of grace (orders over the limit for the first month). */
  grace: boolean;
  /** Over the limit on a plan that never blocks (Business): talk to us. */
  contactUs: boolean;
}

/** `_dateFromJson`: ISO string, Firestore Timestamp or epoch millis; anything else is null. */
function dateOf(value: unknown): Date | null {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string') {
    const time = Date.parse(value);
    return Number.isNaN(time) ? null : new Date(time);
  }
  if (typeof value === 'number') return new Date(value);
  if (typeof value === 'object' && typeof (value as { toDate?: unknown }).toDate === 'function') {
    return (value as { toDate(): Date }).toDate();
  }
  return null;
}

/** Subscription.plan with unknownEnumValue: free (missing or unknown is Free). */
function storedPlan(subscription: Json | null | undefined): SubscriptionPlan {
  const plan = subscription?.plan;
  return PLAN_IDS.includes(plan as SubscriptionPlan) ? (plan as SubscriptionPlan) : 'free';
}

/** Subscription.effectivePlan: the plan while expiresAt is null or in the future, Free afterwards. */
export function effectivePlan(subscription: Json | null | undefined, now: Date): SubscriptionPlan {
  const plan = storedPlan(subscription);
  const expires = dateOf(subscription?.expiresAt);
  if (!expires || expires.getTime() > now.getTime()) return plan;
  return 'free';
}

const isInt = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

/** The more generous of two limits (-1 is no limit). */
export function moreGenerous(a: number, b: number): number {
  return a === -1 || b === -1 ? -1 : Math.max(a, b);
}

/**
 * Stored limits over the table's: each number takes the more generous of the
 * two, so a stricter table never takes anything from what a subscriber has
 * stored, and a better one reaches them; a missing field is the table's.
 * `collaborators` is the old `users`. No watermark wins.
 */
function mergeStored(row: SubscriptionLimits, json: Json): SubscriptionLimits {
  const users = json.users ?? json.collaborators;
  const pick = (stored: unknown, table: number) => (isInt(stored) ? moreGenerous(Math.trunc(stored), table) : table);
  return {
    ordersPerMonth: pick(json.ordersPerMonth, row.ordersPerMonth),
    photosPerMonth: pick(json.photosPerMonth, row.photosPerMonth),
    formTemplates: pick(json.formTemplates, row.formTemplates),
    users: pick(users, row.users),
    pdfWatermark: row.pdfWatermark && json.pdfWatermark !== false,
  };
}

/**
 * Subscription.effectiveLimits: while the plan is in force, the row of its
 * table version merged with the stored limits; after it expires, Free of the
 * current table.
 */
export function effectiveLimits(subscription: Json | null | undefined, now: Date): SubscriptionLimits {
  const current = effectivePlan(subscription, now);
  if (current !== storedPlan(subscription)) return { ...PLAN_LIMITS[current] };
  const row = limitsOfRow(planRow(current, tableVersionOf(subscription)));
  const limits = subscription?.limits;
  if (limits && typeof limits === 'object' && !Array.isArray(limits)) return mergeStored(row, limits as Json);
  return row;
}

/** Over the limit does not block: the plan's `overageAllowed` (Business), for orders and people. */
function overageAllowed(subscription: Json | null | undefined, now: Date, resource: PlanResource): boolean {
  if (resource !== 'order' && resource !== 'collaborator') return false;
  const plan = effectivePlan(subscription, now);
  const version = plan === storedPlan(subscription) ? tableVersionOf(subscription) : undefined;
  return planRow(plan, version).overageAllowed;
}

function limitOf(limits: SubscriptionLimits, resource: PlanResource): number {
  switch (resource) {
    case 'order':
      return limits.ordersPerMonth;
    case 'photo':
      return limits.photosPerMonth;
    case 'formTemplate':
      return limits.formTemplates;
    case 'collaborator':
      return limits.users;
  }
}

/** PlanUsage.level: from 80% "near", at 100% "atLimit", past it "over". */
export function usageLevel(total: number, limit: number): UsageLevel {
  if (limit < 0) return 'unlimited';
  if (total > limit) return 'over';
  if (total === limit) return 'atLimit';
  return total >= limit * 0.8 ? 'near' : 'ok';
}

export interface CheckInput {
  /** companies/{id}.subscription; null or missing is the Free plan. */
  subscription: Json | null | undefined;
  resource: PlanResource;
  /** Usage counted by the server (orders: this month's). */
  usage: number;
  adding?: number;
  /** Orders only: the month before (the month of grace is gone when it was over the limit). */
  lastMonthUsage?: number;
  /** config/paidPlans.enabled (the one switch). */
  enforced: boolean;
  now: Date;
}

/**
 * FeatureGateService._check. Orders have a soft limit: the first month over
 * the limit still creates (`grace`), and only when the month before was also
 * over does a new order wait for a plan change. Business never blocks orders
 * nor people (`contactUs`). Nothing here ever touches an order already open.
 */
export function checkPlanLimit(input: CheckInput): PlanLimitCheck {
  const adding = input.adding ?? 1;
  const limit = input.enforced ? limitOf(effectiveLimits(input.subscription, input.now), input.resource) : -1;
  const total = input.usage + adding;
  const fits = limit === -1 || total <= limit;
  const contactUs = !fits && overageAllowed(input.subscription, input.now, input.resource);
  const grace = !fits && !contactUs && input.resource === 'order' && (input.lastMonthUsage ?? 0) <= limit;
  return {
    allowed: fits || contactUs || grace,
    resource: input.resource,
    limit,
    usage: input.usage,
    adding,
    plan: effectivePlan(input.subscription, input.now),
    level: usageLevel(total, limit),
    grace,
    contactUs,
  };
}

/** FeatureGateService.shouldShowPdfWatermark. */
export function shouldShowPdfWatermark(subscription: Json | null | undefined, enforced: boolean, now: Date): boolean {
  if (!enforced) return false;
  return effectiveLimits(subscription, now).pdfWatermark;
}

// ============================================================================
// Orders of the month (subscription.usage.ordersThisMonth)
// ============================================================================

const SAO_PAULO_OFFSET_MS = 3 * 60 * 60 * 1000;

/** Month in São Paulo (UTC-3, no daylight saving since 2019), "YYYY-MM". */
export function orderMonthKey(now: Date): string {
  return new Date(now.getTime() - SAO_PAULO_OFFSET_MS).toISOString().slice(0, 7);
}

/** The month before a "YYYY-MM" key. */
export function previousMonthKey(key: string): string {
  const [year, month] = key.split('-').map(Number);
  return month === 1 ? `${year - 1}-12` : `${year}-${String(month - 1).padStart(2, '0')}`;
}

/**
 * This month's and last month's orders from `subscription.usage`, turning the
 * month when `ordersMonth` is behind: the counter needs no reset job.
 */
export function ordersUsage(usage: unknown, now: Date): { thisMonth: number; lastMonth: number } {
  const map = (usage && typeof usage === 'object' ? usage : {}) as Json;
  const count = (value: unknown) => (isInt(value) && value > 0 ? Math.trunc(value) : 0);
  const key = orderMonthKey(now);
  if (map.ordersMonth === key) return { thisMonth: count(map.ordersThisMonth), lastMonth: count(map.ordersLastMonth) };
  if (map.ordersMonth === previousMonthKey(key)) return { thisMonth: 0, lastMonth: count(map.ordersThisMonth) };
  return { thisMonth: 0, lastMonth: 0 };
}

/** Sample orders of the first access (bootstrap) never count. */
export const isSampleOrder = (order: Json | null | undefined): boolean => order?.isSample === true;

// ============================================================================
// Usage counted on the server
// ============================================================================

/**
 * First instant of the current month in America/Sao_Paulo. The monthly reset
 * job runs at 03:00 on the 1st; counting from midnight follows the calendar.
 */
export function monthStart(now: Date): Date {
  const wall = new Date(wallClockOf(now));
  return instantOfWall(Date.UTC(wall.getUTCFullYear(), wall.getUTCMonth(), 1));
}

/** Members (memberships) plus pending invites not yet expired, like CollaboratorStore. */
export async function countCollaborators(companyId: string, now: Date): Promise<number> {
  const members = await getTenantCollection(companyId, 'memberships').get();
  const invites = await db
    .collection('links')
    .doc('invites')
    .collection('tokens')
    .where('company.id', '==', companyId)
    .where('status', '==', 'pending')
    .get();
  const pending = invites.docs.filter((doc) => {
    const expires = dateOf(doc.get('expiresAt'));
    return !expires || expires.getTime() >= now.getTime();
  });
  return members.size + pending.length;
}

/**
 * Own active checklists in companies/{id}/forms (isActive missing counts as
 * active, like FormDefinition). A copy of one of the segment's ready-made
 * checklists does not count: it has `sourceTemplateId`, or (copies of the
 * first access) the same id as the segment's.
 */
export async function countFormTemplates(companyId: string): Promise<number> {
  const company = await getRootCollection('companies').doc(companyId).get();
  const segment = company.exists ? company.get('segment') : null;
  const segmentId = typeof segment === 'string' ? segment : typeof segment?.id === 'string' ? segment.id : null;
  const [forms, ready] = await Promise.all([
    getTenantCollection(companyId, 'forms').get(),
    segmentId ? db.collection('segments').doc(segmentId).collection('forms').get() : Promise.resolve(null),
  ]);
  const readyIds = new Set(ready?.docs.map((doc) => doc.id) ?? []);
  return forms.docs.filter(
    (doc) => doc.get('isActive') !== false && !doc.get('sourceTemplateId') && !readyIds.has(doc.id),
  ).length;
}

/**
 * Order photos this month: `subscription.usage.photosThisMonth`, the counter
 * the order triggers keep (usage-counter.service.ts, countNewOrderPhotos) and
 * the monthly job resets. One document read: Storage is never listed (M2 of
 * the #526 review). Photos have no limit since the table of 2026-11.
 */
export async function countPhotosThisMonth(companyId: string): Promise<number> {
  const company = await getRootCollection('companies').doc(companyId).get();
  const value = Number((company.exists ? company.data()?.subscription?.usage?.photosThisMonth : 0) ?? 0);
  return Number.isFinite(value) && value > 0 ? Math.trunc(value) : 0;
}

export async function countUsage(companyId: string, resource: PlanResource, now: Date): Promise<number> {
  switch (resource) {
    case 'order': {
      const company = await getRootCollection('companies').doc(companyId).get();
      return ordersUsage(company.exists ? company.data()?.subscription?.usage : null, now).thisMonth;
    }
    case 'photo':
      return countPhotosThisMonth(companyId);
    case 'formTemplate':
      return countFormTemplates(companyId);
    case 'collaborator':
      return countCollaborators(companyId, now);
  }
}

const SWITCH_TTL_MS = 60_000;
let switchCache: { value: boolean; at: number } | undefined;

/** Clears the cached switch (tests). */
export function resetPaidPlansCache(): void {
  switchCache = undefined;
}

/**
 * The one switch of the plan limits: `config/paidPlans.enabled == true`. The
 * app and the web read the same document. Cached a minute per instance.
 */
export async function isPaidPlansEnabled(now = Date.now()): Promise<boolean> {
  if (switchCache && now - switchCache.at < SWITCH_TTL_MS) return switchCache.value;
  const snap = await db.collection('config').doc('paidPlans').get();
  const value = snap.exists && snap.get('enabled') === true;
  switchCache = { value, at: now };
  return value;
}

/**
 * The check for a company. Reads nothing more when limits are off or the
 * plan is unlimited for the resource; otherwise counts the usage.
 */
export async function checkCompanyPlanLimit(
  companyId: string,
  resource: PlanResource,
  adding = 1,
  now: Date = new Date(),
): Promise<PlanLimitCheck> {
  const enforced = await isPaidPlansEnabled();
  const company = enforced ? await getRootCollection('companies').doc(companyId).get() : null;
  const subscription = (company?.exists ? company.get('subscription') : null) as Json | null;
  const unlimited = checkPlanLimit({ subscription, resource, usage: 0, adding: 0, enforced, now });
  if (unlimited.limit === -1) return { ...unlimited, adding };
  if (resource === 'order') {
    const { thisMonth, lastMonth } = ordersUsage(subscription?.usage, now);
    return checkPlanLimit({ subscription, resource, usage: thisMonth, lastMonthUsage: lastMonth, adding, enforced, now });
  }
  const usage = await countUsage(companyId, resource, now);
  return checkPlanLimit({ subscription, resource, usage, adding, enforced, now });
}

/**
 * Body of the 402 the routes send, the same for app and web (the screen reads
 * code, resource, limit and usage).
 */
export function planLimitError(check: PlanLimitCheck) {
  return {
    success: false as const,
    error: {
      code: 'PLAN_LIMIT' as const,
      message: `Plan limit reached for ${check.resource} (${check.usage}/${check.limit})`,
      resource: check.resource,
      limit: check.limit,
      usage: check.usage,
      adding: check.adding,
      plan: check.plan,
    },
  };
}
