/**
 * Plan limits on the server (docs/PLAN_LIMITS_SERVER.md): the same check as
 * the app (lib/services/feature_gate_service.dart, lib/models/subscription.dart),
 * with the usage counted here instead of read from the counters the app writes.
 *
 * Shared cases: docs/web-app/contract-cases/plan-limits.json (Dart and here).
 *
 * The app enforces limits only where paid plans are on (`paidPlansEnabled`,
 * a real store key in the build). The server has no build: its switch is
 * `config/paidPlans.enabled`, off by default, and then every check passes,
 * like an app build without the key.
 */

import { db, getRootCollection, getTenantCollection } from './firestore.service';
import { PLAN_LIMITS } from './subscription-plans';
import { instantOfWall, wallClockOf } from './contract-generation';
import type { SubscriptionLimits, SubscriptionPlan } from '../models/types';

export type PlanResource = 'photo' | 'formTemplate' | 'collaborator';

export const PLAN_RESOURCES: readonly PlanResource[] = ['photo', 'formTemplate', 'collaborator'];

const PLANS: readonly SubscriptionPlan[] = ['free', 'starter', 'pro', 'business'];

type Json = Record<string, unknown>;

export interface PlanLimitCheck {
  allowed: boolean;
  resource: PlanResource;
  /** -1 = unlimited (also when limits are off). */
  limit: number;
  usage: number;
  adding: number;
  /** Plan in force (Free once expiresAt has passed). */
  plan: SubscriptionPlan;
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
  return PLANS.includes(plan as SubscriptionPlan) ? (plan as SubscriptionPlan) : 'free';
}

/** Subscription.effectivePlan: the plan while expiresAt is null or in the future, Free afterwards. */
export function effectivePlan(subscription: Json | null | undefined, now: Date): SubscriptionPlan {
  const plan = storedPlan(subscription);
  const expires = dateOf(subscription?.expiresAt);
  if (!expires || expires.getTime() > now.getTime()) return plan;
  return 'free';
}

const intOr = (value: unknown, fallback: number): number =>
  typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : fallback;

/** SubscriptionLimits.fromJson: each missing field takes the Free default; `collaborators` is the old `users`. */
function storedLimits(json: Json): SubscriptionLimits {
  return {
    photosPerMonth: intOr(json.photosPerMonth, 30),
    formTemplates: intOr(json.formTemplates, 1),
    users: intOr(json.users ?? json.collaborators, 1),
    pdfWatermark: typeof json.pdfWatermark === 'boolean' ? json.pdfWatermark : true,
  };
}

/**
 * Subscription.effectiveLimits: the stored limits (else the plan defaults)
 * while the plan is in force, Free defaults after it expires.
 */
export function effectiveLimits(subscription: Json | null | undefined, now: Date): SubscriptionLimits {
  const current = effectivePlan(subscription, now);
  if (current !== storedPlan(subscription)) return { ...PLAN_LIMITS[current] };
  const limits = subscription?.limits;
  if (limits && typeof limits === 'object' && !Array.isArray(limits)) return storedLimits(limits as Json);
  return { ...PLAN_LIMITS[current] };
}

function limitOf(limits: SubscriptionLimits, resource: PlanResource): number {
  switch (resource) {
    case 'photo':
      return limits.photosPerMonth;
    case 'formTemplate':
      return limits.formTemplates;
    case 'collaborator':
      return limits.users;
  }
}

export interface CheckInput {
  /** companies/{id}.subscription; null or missing is the Free plan. */
  subscription: Json | null | undefined;
  resource: PlanResource;
  /** Usage counted by the server. */
  usage: number;
  adding?: number;
  /** config/paidPlans.enabled (the app's `paidPlansEnabled`). */
  enforced: boolean;
  now: Date;
}

/** FeatureGateService._check. */
export function checkPlanLimit(input: CheckInput): PlanLimitCheck {
  const adding = input.adding ?? 1;
  const limit = input.enforced ? limitOf(effectiveLimits(input.subscription, input.now), input.resource) : -1;
  return {
    allowed: limit === -1 || input.usage + adding <= limit,
    resource: input.resource,
    limit,
    usage: input.usage,
    adding,
    plan: effectivePlan(input.subscription, input.now),
  };
}

/** FeatureGateService.shouldShowPdfWatermark. */
export function shouldShowPdfWatermark(subscription: Json | null | undefined, enforced: boolean, now: Date): boolean {
  if (!enforced) return false;
  return effectiveLimits(subscription, now).pdfWatermark;
}

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
 * Active form templates in companies/{id}/forms (isActive missing counts as
 * active, like FormDefinition). The app's own counter queries `formTemplates`,
 * a collection the rules don't allow, so the stored counter never moves.
 */
export async function countFormTemplates(companyId: string): Promise<number> {
  const snapshot = await getTenantCollection(companyId, 'forms').get();
  return snapshot.docs.filter((doc) => doc.get('isActive') !== false).length;
}

/**
 * Order photos this month: `subscription.usage.photosThisMonth`, the counter
 * the order triggers keep (usage-counter.service.ts, countNewOrderPhotos) and
 * the monthly job resets. One document read: Storage is never listed (M2 of
 * the #526 review). The triggers count only with
 * `config/usageCounters.serverOnly` on; with it off the app writes the counter
 * (admin only), so turn that flag on before PLAN_LIMITS_ENABLED.
 */
export async function countPhotosThisMonth(companyId: string): Promise<number> {
  const company = await getRootCollection('companies').doc(companyId).get();
  const value = Number((company.exists ? company.data()?.subscription?.usage?.photosThisMonth : 0) ?? 0);
  return Number.isFinite(value) && value > 0 ? Math.trunc(value) : 0;
}

export async function countUsage(companyId: string, resource: PlanResource, now: Date): Promise<number> {
  switch (resource) {
    case 'photo':
      return countPhotosThisMonth(companyId);
    case 'formTemplate':
      return countFormTemplates(companyId);
    case 'collaborator':
      return countCollaborators(companyId, now);
  }
}

/** Global switch: `config/paidPlans.enabled == true` (the app's paidPlansEnabled). */
export async function isPaidPlansEnabled(): Promise<boolean> {
  const snap = await db.collection('config').doc('paidPlans').get();
  return snap.exists && snap.get('enabled') === true;
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
  const usage = await countUsage(companyId, resource, now);
  return checkPlanLimit({ subscription, resource, usage, adding, enforced, now });
}

/** Body of the 402 the routes send (the screen reads code, resource, limit and usage). */
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
