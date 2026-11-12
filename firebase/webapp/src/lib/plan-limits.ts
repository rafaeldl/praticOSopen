/**
 * Plan limits on the web: the same rule as the app (FeatureGateService over
 * Subscription) and the server (plan-limits.service.ts), with the numbers of
 * the plan table (docs/plans/plans.json, generated into src/generated/plan-table.ts).
 * Shared cases: docs/web-app/contract-cases/plan-limits.json (tests/contract-cases.test.ts).
 */
import { PLAN_IDS, PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION, type PlanId, type PlanRow } from '@/generated/plan-table'

export type { PlanId, PlanRow }
export { PLAN_IDS }

/**
 * The app applies plan limits only where paid plans can be bought
 * (FeatureGateService.planLimitsEnforced = SubscriptionService.paidPlansEnabled),
 * and that is false in a browser (kIsWeb). The web follows, for checklists and
 * for team seats alike: no limit, so a Free company is never stuck without a
 * place to buy a plan. The counts still show (Plano, Equipe).
 */
export const WEB_PLAN_LIMITS_ENFORCED = false

/** What companies/{id}.subscription stores as limits. -1 is no limit. */
export interface SubscriptionLimits {
  photosPerMonth: number
  formTemplates: number
  users: number
  pdfWatermark: boolean
}

export type PlanResource = 'photo' | 'formTemplate' | 'collaborator'

/** The current table, by plan. */
export const currentPlanRows = (): Readonly<Record<PlanId, PlanRow>> => PLAN_TABLES[PLAN_TABLE_CURRENT_VERSION] as Readonly<Record<PlanId, PlanRow>>

const limitsOfRow = (row: PlanRow): SubscriptionLimits => ({
  photosPerMonth: row.photosPerMonth,
  formTemplates: row.formTemplates,
  users: row.users,
  pdfWatermark: row.pdfWatermark,
})

/** Default limits of a plan (SubscriptionLimits.forPlan). */
export const planLimits = (plan: PlanId): SubscriptionLimits => limitsOfRow(currentPlanRows()[plan])

type Json = Record<string, unknown>
const record = (value: unknown): Json => (value && typeof value === 'object' && !Array.isArray(value) ? (value as Json) : {})
const intOr = (value: unknown, fallback: number) => (typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : fallback)

/** ISO string, Firestore Timestamp ({toDate} or {seconds}) or epoch millis; anything else is null. */
export function dateOf(value: unknown): Date | null {
  if (value === null || value === undefined) return null
  if (typeof value === 'string') {
    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : date
  }
  if (typeof value === 'number') return new Date(value)
  const stamp = value as { toDate?: () => Date; seconds?: number }
  if (typeof stamp.toDate === 'function') return stamp.toDate()
  if (typeof stamp.seconds === 'number') return new Date(stamp.seconds * 1000)
  return null
}

/** Subscription.plan: missing or unknown is Free. */
export function storedPlan(subscription: unknown): PlanId {
  const plan = record(subscription).plan
  return (PLAN_IDS as readonly unknown[]).includes(plan) ? (plan as PlanId) : 'free'
}

/** Subscription.effectivePlan: the plan while expiresAt is null or in the future, Free afterwards. */
export function effectivePlan(subscription: unknown, now: Date): PlanId {
  const expires = dateOf(record(subscription).expiresAt)
  return !expires || expires.getTime() > now.getTime() ? storedPlan(subscription) : 'free'
}

/** SubscriptionLimits.fromJson: a missing field takes the Free default; `collaborators` is the old `users`. */
function storedLimits(json: Json): SubscriptionLimits {
  const free = planLimits('free')
  return {
    photosPerMonth: intOr(json.photosPerMonth, free.photosPerMonth),
    formTemplates: intOr(json.formTemplates, free.formTemplates),
    users: intOr(json.users ?? json.collaborators, free.users),
    pdfWatermark: typeof json.pdfWatermark === 'boolean' ? json.pdfWatermark : free.pdfWatermark,
  }
}

/** Subscription.effectiveLimits: stored limits (else the plan's) while the plan is in force, Free's after it expires. */
export function effectiveLimits(subscription: unknown, now: Date): SubscriptionLimits {
  const current = effectivePlan(subscription, now)
  if (current !== storedPlan(subscription)) return planLimits(current)
  const limits = record(subscription).limits
  return limits && typeof limits === 'object' && !Array.isArray(limits) ? storedLimits(limits as Json) : planLimits(current)
}

const limitOf = (limits: SubscriptionLimits, resource: PlanResource): number =>
  resource === 'photo' ? limits.photosPerMonth : resource === 'formTemplate' ? limits.formTemplates : limits.users

export interface PlanLimitCheck {
  allowed: boolean
  /** -1 = no limit (also when limits are off). */
  limit: number
  plan: PlanId
}

/** FeatureGateService._check. */
export function checkPlanLimit(input: { subscription: unknown; resource: PlanResource; usage: number; adding?: number; enforced: boolean; now: Date }): PlanLimitCheck {
  const adding = input.adding ?? 1
  const limit = input.enforced ? limitOf(effectiveLimits(input.subscription, input.now), input.resource) : -1
  return { allowed: limit === -1 || input.usage + adding <= limit, limit, plan: effectivePlan(input.subscription, input.now) }
}

/** FeatureGateService.shouldShowPdfWatermark. */
export function shouldShowPdfWatermark(subscription: unknown, enforced: boolean, now: Date): boolean {
  return enforced && effectiveLimits(subscription, now).pdfWatermark
}
