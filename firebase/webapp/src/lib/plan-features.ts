/**
 * Features of each plan (#724) on the web: the same check as the app
 * (FeatureGateService.checkFeature) and the server
 * (firebase/functions/src/services/plan-features.service.ts), from the
 * `features` lists of the plan table (docs/plans/plans.json).
 * Shared cases: docs/web-app/contract-cases/plan-features.json (tests/contract-cases.test.ts).
 *
 * Behind the one switch of the plan limits (`config/paidPlans.enabled`): off,
 * every feature is allowed. The check only guards creating or turning on
 * something new; what a company already has keeps working.
 */
import type { MessageKey } from '@/generated/message-keys'
import { PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION } from '@/generated/plan-table'
import { ApiError } from './api'
import { currentPlanRows, effectivePlan, storedPlan, tableVersionOf, PLAN_IDS, type PlanId } from './plan-limits'

/** Features that depend on the plan. The basics (what Free has) and the assistant never do. */
export type PlanFeature =
  | 'nfse'
  | 'brandedPdf'
  | 'ownChecklists'
  | 'charges'
  | 'teamRoles'
  | 'perPersonAgenda'
  | 'workStages'
  | 'tvMode'
  | 'contracts'
  | 'aiFinance'
  | 'spreadsheetExport'
  | 'bulkActions'
  | 'mcp'
  | 'api'

/** The feature's name, said to people (the app's arb keys). */
export const PLAN_FEATURE_NAME: Record<PlanFeature, MessageKey> = {
  nfse: 'planFeatureNfse',
  brandedPdf: 'planFeatureBrandedPdf',
  ownChecklists: 'planFeatureOwnChecklists',
  charges: 'planFeatureCharges',
  teamRoles: 'planFeatureTeamRoles',
  perPersonAgenda: 'planFeaturePerPersonAgenda',
  workStages: 'planFeatureWorkStages',
  tvMode: 'planFeatureTvMode',
  contracts: 'planFeatureContracts',
  aiFinance: 'planFeatureAiFinance',
  spreadsheetExport: 'planFeatureSpreadsheetExport',
  bulkActions: 'planFeatureBulkActions',
  mcp: 'planFeatureMcp',
  api: 'planFeatureApi',
}

/** A feature the web knows by name (the server may send others). */
export const isPlanFeature = (value: unknown): value is PlanFeature => typeof value === 'string' && value in PLAN_FEATURE_NAME

/** In every plan whatever the table says: the assistant has only its usage ceilings. */
const NEVER_GATED = new Set(['ai'])

export interface PlanFeatureCheck {
  allowed: boolean
  feature: string
  /** Plan in force (Free once expiresAt has passed). */
  plan: PlanId
  /** First plan of the current table with the feature: the one to move to. Null if none. */
  requiredPlan: PlanId | null
}

/** First plan of the current table that has [feature], or null. */
export function requiredPlanFor(feature: string): PlanId | null {
  if (NEVER_GATED.has(feature)) return 'free'
  const rows = currentPlanRows()
  return PLAN_IDS.find((plan) => rows[plan].features.includes(feature)) ?? null
}

/**
 * Whether the plan in force has [feature]. Allowed when the switch is off,
 * for the basics and the assistant, for a feature no plan lists, and on a
 * table version that lists no feature at all (version 1, before #724).
 */
export function checkPlanFeature(input: { subscription: unknown; feature: string; enforced: boolean; now: Date }): PlanFeatureCheck {
  const plan = effectivePlan(input.subscription, input.now)
  const requiredPlan = requiredPlanFor(input.feature)
  const result = (allowed: boolean): PlanFeatureCheck => ({ allowed, feature: input.feature, plan, requiredPlan })
  if (!input.enforced || NEVER_GATED.has(input.feature) || requiredPlan === null) return result(true)
  // The subscription's own version while its plan is in force; Free of the current table after it expires.
  const version = plan === storedPlan(input.subscription) ? tableVersionOf(input.subscription) : PLAN_TABLE_CURRENT_VERSION
  const row = (PLAN_TABLES[version] ?? currentPlanRows())[plan]
  if (row.features.length === 0) return result(true)
  return result(row.features.includes(input.feature))
}

/** Roles that need `teamRoles` (Pro); owner and admin are in every plan. */
export const TEAM_ROLES_FEATURE_ROLES: readonly string[] = ['manager', 'supervisor', 'consultant', 'technician']

/** The feature a role needs, or null (owner, admin, or not a role: validation answers that). */
export function featureForRole(role: unknown): PlanFeature | null {
  return typeof role === 'string' && TEAM_ROLES_FEATURE_ROLES.includes(role) ? 'teamRoles' : null
}

/** The refusal the server sends (402 PLAN_FEATURE), or null for any other error. */
export function planFeatureRefusal(error: unknown): PlanFeatureCheck | null {
  if (!(error instanceof ApiError) || error.code !== 'PLAN_FEATURE') return null
  const details = error.details ?? {}
  const planOf = (value: unknown): PlanId | null => ((PLAN_IDS as readonly unknown[]).includes(value) ? (value as PlanId) : null)
  const feature = typeof details.feature === 'string' ? details.feature : ''
  return { allowed: false, feature, plan: planOf(details.plan) ?? 'free', requiredPlan: planOf(details.requiredPlan) ?? requiredPlanFor(feature) }
}
