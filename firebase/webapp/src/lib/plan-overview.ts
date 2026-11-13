/**
 * What the Plan screen shows (#725), the same as the app
 * (lib/services/plan_overview.dart). Cases:
 * docs/web-app/contract-cases/plan-overview.json (tests/contract-cases.test.ts).
 * No assistant counter.
 */
import { PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION } from '@/generated/plan-table'
import { currentPlanRows, effectiveLimits, effectivePlan, ordersUsage, PLAN_IDS, storedPlan, tableVersionOf, type PlanId, type PlanRow } from './plan-limits'
import { isPlanFeature, type PlanFeature } from './plan-features'
import { paidPlansConfig } from './plan-limits'
import { lastMonthCounts } from './paid-plans-config'

export type OverviewResource = 'orders' | 'people' | 'taxIds'
export type OverviewLevel = 'unlimited' | 'ok' | 'near' | 'atLimit' | 'over'
export type OverviewNotice =
  | 'ordersNear'
  | 'ordersAtLimit'
  | 'ordersGrace'
  | 'ordersBlocked'
  | 'ordersContactUs'
  | 'peopleAtLimit'
  | 'peopleContactUs'

export interface OverviewRow {
  resource: OverviewResource
  used: number
  limit: number
  level: OverviewLevel
}

export interface PlanOverview {
  plan: PlanId
  rows: OverviewRow[]
  notice: OverviewNotice | null
  /** The next plan and what it adds; null on Business. */
  next: { plan: PlanId; features: PlanFeature[] } | null
}

function levelOf(used: number, limit: number): OverviewLevel {
  if (limit < 0) return 'unlimited'
  if (used > limit) return 'over'
  if (used === limit) return 'atLimit'
  return used >= limit * 0.8 ? 'near' : 'ok'
}

/** Row of the table in force: the subscription's version while its plan is in force, Free of the current table after. */
function rowInForce(subscription: unknown, now: Date): PlanRow {
  const plan = effectivePlan(subscription, now)
  const version = plan === storedPlan(subscription) ? tableVersionOf(subscription) : PLAN_TABLE_CURRENT_VERSION
  return (PLAN_TABLES[version] ?? PLAN_TABLES[PLAN_TABLE_CURRENT_VERSION])![plan] as PlanRow
}

/** `people` are members plus invites that still work; `taxIds` the fiscal emitters; `enforced` the switch config/paidPlans. */
export function planOverview(input: { subscription: unknown; people: number; taxIds: number; enforced: boolean; now: Date; limitsStartAt?: Date | null }): PlanOverview {
  const { subscription, people, taxIds, enforced: on, now } = input
  // In the month from config/paidPlans.limitsStartAt the month before does not take the grace away (checkPlanLimit).
  const lastCounts = lastMonthCounts(input.limitsStartAt === undefined ? paidPlansConfig().limitsStartAt : input.limitsStartAt, now)
  const plan = effectivePlan(subscription, now)
  const limits = effectiveLimits(subscription, now)
  const row = rowInForce(subscription, now)
  const usage = subscription && typeof subscription === 'object' ? (subscription as Record<string, unknown>).usage : undefined
  const orders = ordersUsage(usage, now)
  const limit = (value: number) => (on ? value : -1)

  const ordersLimit = limit(limits.ordersPerMonth)
  const peopleLimit = limit(limits.users)
  const taxIdsLimit = limit(row.nfseCnpjs)
  const peopleLevel: OverviewLevel = peopleLimit === 1 ? 'ok' : levelOf(people, peopleLimit)
  const rows: OverviewRow[] = [
    { resource: 'orders', used: orders.thisMonth, limit: ordersLimit, level: levelOf(orders.thisMonth, ordersLimit) },
    { resource: 'people', used: people, limit: peopleLimit, level: peopleLevel },
  ]
  if (row.nfseCnpjs !== 0) rows.push({ resource: 'taxIds', used: taxIds, limit: taxIdsLimit, level: levelOf(taxIds, taxIdsLimit) })

  let notice: OverviewNotice | null = null
  if (on) {
    const level = rows[0]!.level
    const overage = row.overageAllowed
    if (level === 'over' && overage) notice = 'ordersContactUs'
    else if ((level === 'over' || level === 'atLimit') && lastCounts && orders.lastMonth > ordersLimit) notice = 'ordersBlocked'
    else if (level === 'over') notice = 'ordersGrace'
    else if (level === 'atLimit') notice = 'ordersAtLimit'
    else if (level === 'near') notice = 'ordersNear'
    else if (peopleLevel === 'over' && overage) notice = 'peopleContactUs'
    else if (peopleLevel === 'over' || peopleLevel === 'atLimit') notice = 'peopleAtLimit'
  }

  const index = PLAN_IDS.indexOf(plan)
  const nextPlan = PLAN_IDS[index + 1]
  let next: PlanOverview['next'] = null
  if (nextPlan) {
    const rows2 = currentPlanRows()
    const have = new Set(rows2[plan].features)
    next = { plan: nextPlan, features: rows2[nextPlan].features.filter((key): key is PlanFeature => !have.has(key) && isPlanFeature(key)) }
  }
  return { plan, rows, notice, next }
}
