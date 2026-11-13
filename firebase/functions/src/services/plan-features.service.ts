/**
 * Features of each plan (#724) on the server: the same check as the app
 * (FeatureGateService.checkFeature) and the web (src/lib/plan-features.ts),
 * from the `features` lists of the plan table (docs/plans/plans.json).
 *
 * Shared cases: docs/web-app/contract-cases/plan-features.json.
 *
 * Behind the one switch of the plan limits, `config/paidPlans.enabled`: off,
 * every feature is allowed. The check only guards creating or turning on
 * something new: what a company already has (contracts, stages, members)
 * keeps working after it moves to a smaller plan.
 */

import { getRootCollection } from './firestore.service';
import { PLAN_IDS, type PlanId } from './plan-table.generated';
import { currentPlanRows, planRow, tableVersionOf } from './subscription-plans';
import { effectivePlan, isPaidPlansEnabled } from './plan-limits.service';

/** Features that depend on the plan. The basics (what Free has) and the assistant never do. */
export type PlanFeature =
  | 'nfse'
  | 'brandedPdf'
  | 'ownChecklists'
  | 'charges'
  | 'reviewRequest'
  | 'teamRoles'
  | 'perPersonAgenda'
  | 'workStages'
  | 'tvMode'
  | 'contracts'
  | 'aiFinance'
  | 'spreadsheetExport'
  | 'bulkActions'
  | 'mcp'
  | 'api';

/** In every plan whatever the table says: the assistant has only its usage ceilings. */
const NEVER_GATED = new Set(['ai']);

type Json = Record<string, unknown>;

export interface PlanFeatureCheck {
  allowed: boolean;
  feature: string;
  /** Plan in force (Free once expiresAt has passed). */
  plan: PlanId;
  /** First plan of the current table with the feature: the one to move to. Null if none. */
  requiredPlan: PlanId | null;
}

/** First plan of the current table that has [feature], or null. */
export function requiredPlanFor(feature: string): PlanId | null {
  if (NEVER_GATED.has(feature)) return 'free';
  const rows = currentPlanRows();
  return PLAN_IDS.find((plan) => rows[plan].features.includes(feature)) ?? null;
}

/**
 * Whether the plan in force has [feature]. Allowed when the switch is off,
 * for the basics and the assistant, for a feature no plan lists, and on a
 * table version that lists no feature at all (version 1, before #724).
 */
export function checkPlanFeature(input: {
  subscription: Json | null | undefined;
  feature: string;
  enforced: boolean;
  now: Date;
}): PlanFeatureCheck {
  const plan = effectivePlan(input.subscription, input.now);
  const requiredPlan = requiredPlanFor(input.feature);
  const result = (allowed: boolean): PlanFeatureCheck => ({ allowed, feature: input.feature, plan, requiredPlan });
  if (!input.enforced || NEVER_GATED.has(input.feature) || requiredPlan === null) return result(true);
  // The subscription's own version while its plan is in force; Free of the current table after it expires.
  const stored = input.subscription?.plan;
  const version = plan === stored ? tableVersionOf(input.subscription) : undefined;
  const row = planRow(plan, version);
  if (row.features.length === 0) return result(true);
  return result(row.features.includes(input.feature));
}

/** Roles that need `teamRoles` (Pro); owner and admin are in every plan. */
export const TEAM_ROLES_FEATURE_ROLES: readonly string[] = ['manager', 'supervisor', 'consultant', 'technician'];

/** The feature a role needs, or null (owner, admin, or not a role: validation answers that). */
export function featureForRole(role: unknown): PlanFeature | null {
  return typeof role === 'string' && TEAM_ROLES_FEATURE_ROLES.includes(role) ? 'teamRoles' : null;
}

/** The check for a company: reads only the switch while it is off. */
export async function checkCompanyPlanFeature(
  companyId: string,
  feature: PlanFeature,
  now: Date = new Date(),
): Promise<PlanFeatureCheck> {
  const enforced = await isPaidPlansEnabled();
  if (!enforced) return checkPlanFeature({ subscription: null, feature, enforced, now });
  const company = await getRootCollection('companies').doc(companyId).get();
  const subscription = (company.exists ? company.get('subscription') : null) as Json | null;
  return checkPlanFeature({ subscription, feature, enforced, now });
}

/** Body of the 402 the routes send, the same for app and web (they read code, feature and requiredPlan). */
export function planFeatureError(check: PlanFeatureCheck) {
  return {
    success: false as const,
    error: {
      code: 'PLAN_FEATURE' as const,
      message: `Feature ${check.feature} is not in the ${check.plan} plan`,
      feature: check.feature,
      plan: check.plan,
      requiredPlan: check.requiredPlan,
    },
  };
}
