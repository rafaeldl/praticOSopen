/**
 * Plan limits on the web: the same rule as the app (FeatureGateService over
 * Subscription) and the server (plan-limits.service.ts), with the numbers of
 * the plan table (docs/plans/plans.json, generated into src/generated/plan-table.ts).
 * Shared cases: docs/web-app/contract-cases/plan-limits.json (tests/contract-cases.test.ts).
 */
import {
  PLAN_IDS,
  PLAN_TABLES_IN_FORCE,
  PLAN_TABLE_CURRENT_VERSION,
  PLAN_TABLE_LEGACY_VERSION,
  type PlanId,
  type PlanRow,
} from '@/generated/plan-table'

export type { PlanId, PlanRow }
export { PLAN_IDS }

/** Name of each plan, the same in every language (the app's SubscriptionPlan.displayName). */
export const PLAN_NAME: Record<PlanId, string> = { free: 'Free', starter: 'Starter', pro: 'Pro', business: 'Business' }

/**
 * The one switch of the plan limits, `config/paidPlans.enabled` (Firestore),
 * the same document the server and the app read (#723). Off until read, and
 * off when it cannot be read: the server still decides on its own writes.
 */
let switchOn = false
let switchLoad: Promise<boolean> | null = null

async function readSwitch(): Promise<boolean> {
  const [{ firestoreLite }, { doc, getDoc }] = await Promise.all([import('@/lib/firebase'), import('firebase/firestore/lite')])
  const snapshot = await getDoc(doc(await firestoreLite(), 'config', 'paidPlans'))
  return (snapshot.data() as Record<string, unknown> | undefined)?.enabled === true
}

/** Reads the switch once per page load; later calls get the same answer. */
export function loadLimitsSwitch(read: () => Promise<boolean> = readSwitch): Promise<boolean> {
  switchLoad ??= read()
    .catch((error) => {
      console.warn('plan: limits switch not read', error)
      return false
    })
    .then((value) => (switchOn = value))
  return switchLoad
}

/** Whether plan limits apply here (the switch, once read). */
export const planLimitsEnforced = (): boolean => switchOn

/** Tests: forget the switch. */
export function resetLimitsSwitch(): void {
  switchOn = false
  switchLoad = null
}

/** What companies/{id}.subscription stores as limits. -1 is no limit. */
export interface SubscriptionLimits {
  ordersPerMonth: number
  photosPerMonth: number
  formTemplates: number
  users: number
  pdfWatermark: boolean
}

export type PlanResource = 'order' | 'photo' | 'formTemplate' | 'collaborator'

/** The current table, by plan. */
export const currentPlanRows = (): Readonly<Record<PlanId, PlanRow>> => PLAN_TABLES_IN_FORCE[PLAN_TABLE_CURRENT_VERSION] as Readonly<Record<PlanId, PlanRow>>

const limitsOfRow = (row: PlanRow): SubscriptionLimits => ({
  ordersPerMonth: row.ordersPerMonth,
  photosPerMonth: row.photosPerMonth,
  formTemplates: row.formTemplates,
  users: row.users,
  pdfWatermark: row.pdfWatermark,
})

/** Default limits of a plan (SubscriptionLimits.forPlan). */
export const planLimits = (plan: PlanId): SubscriptionLimits => limitsOfRow(currentPlanRows()[plan])

/**
 * Version of the table a subscription follows (#726): its `tableVersion` when
 * the table has it; else, for a paid plan bought before the current table (no
 * `tableVersion`; the courtesy too, which keeps the old Pro), the legacy
 * version; else the current one
 * (also for a version this code does not know).
 */
export function tableVersionOf(subscription: unknown): string {
  const sub = subscription && typeof subscription === 'object' ? (subscription as Record<string, unknown>) : {}
  if (typeof sub.tableVersion === 'string') return sub.tableVersion in PLAN_TABLES_IN_FORCE ? sub.tableVersion : PLAN_TABLE_CURRENT_VERSION
  const paid = typeof sub.plan === 'string' && sub.plan !== 'free' && (PLAN_IDS as readonly string[]).includes(sub.plan)
  return paid ? PLAN_TABLE_LEGACY_VERSION : PLAN_TABLE_CURRENT_VERSION
}

const rowOf = (plan: PlanId, version: string): PlanRow => (PLAN_TABLES_IN_FORCE[version] ?? currentPlanRows())[plan] as PlanRow

/** The more generous of two limits (-1 is no limit). */
export const moreGenerous = (a: number, b: number): number => (a === -1 || b === -1 ? -1 : Math.max(a, b))

type Json = Record<string, unknown>
const record = (value: unknown): Json => (value && typeof value === 'object' && !Array.isArray(value) ? (value as Json) : {})

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

/** The plan in force, the version of the table it follows and its row. */
export interface PlanInForce {
  plan: PlanId
  version: string
  row: PlanRow
}

/**
 * Subscription.planInForce, the same answer on server, app and web to "what
 * does this company have now": the plan while expiresAt is null or in the
 * future, with its table version (tableVersionOf); after it expires, Free of
 * the current table. Limits, features and AI ceilings read this row.
 */
export function planInForce(subscription: unknown, now: Date): PlanInForce {
  const plan = effectivePlan(subscription, now)
  const version = plan === storedPlan(subscription) ? tableVersionOf(subscription) : PLAN_TABLE_CURRENT_VERSION
  return { plan, version, row: rowOf(plan, version) }
}

/**
 * Stored limits over the table's: each number takes the more generous of the
 * two (a subscriber never loses), a missing field is the table's; no
 * watermark wins; `collaborators` is the old `users`.
 */
function mergeStored(row: SubscriptionLimits, json: Json): SubscriptionLimits {
  const pick = (stored: unknown, table: number) => (typeof stored === 'number' && Number.isFinite(stored) ? moreGenerous(Math.trunc(stored), table) : table)
  return {
    ordersPerMonth: pick(json.ordersPerMonth, row.ordersPerMonth),
    photosPerMonth: pick(json.photosPerMonth, row.photosPerMonth),
    formTemplates: pick(json.formTemplates, row.formTemplates),
    users: pick(json.users ?? json.collaborators, row.users),
    pdfWatermark: row.pdfWatermark && json.pdfWatermark !== false,
  }
}

/** Subscription.effectiveLimits: the row of its table version merged with the stored limits while the plan is in force; Free of the current table after it expires. */
export function effectiveLimits(subscription: unknown, now: Date): SubscriptionLimits {
  const { plan, row: inForce } = planInForce(subscription, now)
  if (plan !== storedPlan(subscription)) return planLimits(plan)
  const row = limitsOfRow(inForce)
  const limits = record(subscription).limits
  return limits && typeof limits === 'object' && !Array.isArray(limits) ? mergeStored(row, limits as Json) : row
}

/** Passing orders or people does not block: the plan's `overageAllowed` (Business). */
function overageAllowed(subscription: unknown, now: Date, resource: PlanResource): boolean {
  if (resource !== 'order' && resource !== 'collaborator') return false
  return planInForce(subscription, now).row.overageAllowed
}

const limitOf = (limits: SubscriptionLimits, resource: PlanResource): number =>
  resource === 'order' ? limits.ordersPerMonth : resource === 'photo' ? limits.photosPerMonth : resource === 'formTemplate' ? limits.formTemplates : limits.users

export type UsageLevel = 'unlimited' | 'ok' | 'near' | 'atLimit' | 'over'

/** From 80% "near", at 100% "atLimit", past it "over"; -1 is no limit. */
export function usageLevelOf(total: number, limit: number): UsageLevel {
  if (limit < 0) return 'unlimited'
  if (total > limit) return 'over'
  if (total === limit) return 'atLimit'
  return total >= limit * 0.8 ? 'near' : 'ok'
}

export interface PlanLimitCheck {
  allowed: boolean
  /** -1 = no limit (also when limits are off). */
  limit: number
  plan: PlanId
  level: UsageLevel
  /** Allowed only because of the month of grace (orders). */
  grace: boolean
  /** Over the limit on a plan that never blocks (Business): only says it went over what is included (no outside purchase in the app, 3.1.1). */
  contactUs: boolean
}

/**
 * FeatureGateService._check. Orders have a soft limit: the first month over
 * still creates (`grace`); only when the month before was over too does a new
 * order wait for a plan. Business never blocks orders nor people (`contactUs`).
 */
export function checkPlanLimit(input: {
  subscription: unknown
  resource: PlanResource
  usage: number
  adding?: number
  /** Orders only: the month before. */
  lastMonthUsage?: number
  enforced: boolean
  now: Date
}): PlanLimitCheck {
  const adding = input.adding ?? 1
  const limit = input.enforced ? limitOf(effectiveLimits(input.subscription, input.now), input.resource) : -1
  const total = input.usage + adding
  const fits = limit === -1 || total <= limit
  const contactUs = !fits && overageAllowed(input.subscription, input.now, input.resource)
  const grace = !fits && !contactUs && input.resource === 'order' && (input.lastMonthUsage ?? 0) <= limit
  return { allowed: fits || contactUs || grace, limit, plan: effectivePlan(input.subscription, input.now), level: usageLevelOf(total, limit), grace, contactUs }
}

/** Month in São Paulo (UTC-3, no daylight saving since 2019), "YYYY-MM": the orders counter's month. */
export const orderMonthKey = (now: Date): string => new Date(now.getTime() - 3 * 60 * 60 * 1000).toISOString().slice(0, 7)

/** The month before a "YYYY-MM" key. */
export function previousMonthKey(key: string): string {
  const [year, month] = key.split('-').map(Number) as [number, number]
  return month === 1 ? `${year - 1}-12` : `${year}-${String(month - 1).padStart(2, '0')}`
}

/** This month's and last month's orders from subscription.usage, turning the month when it is behind (the server's ordersUsage). */
export function ordersUsage(usage: unknown, now: Date): { thisMonth: number; lastMonth: number } {
  const map = record(usage)
  const count = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) && value > 0 ? Math.trunc(value) : 0)
  const key = orderMonthKey(now)
  if (map.ordersMonth === key) return { thisMonth: count(map.ordersThisMonth), lastMonth: count(map.ordersLastMonth) }
  if (map.ordersMonth === previousMonthKey(key)) return { thisMonth: 0, lastMonth: count(map.ordersThisMonth) }
  return { thisMonth: 0, lastMonth: 0 }
}

/** FeatureGateService.shouldShowPdfWatermark. */
export function shouldShowPdfWatermark(subscription: unknown, enforced: boolean, now: Date): boolean {
  return enforced && effectiveLimits(subscription, now).pdfWatermark
}
