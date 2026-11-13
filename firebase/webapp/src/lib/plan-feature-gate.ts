// "Does the company's plan have X?" for the views (#724): the check of
// lib/plan-features.ts over the session's company document and the reactive
// copy of the one switch (config/paidPlans.enabled).
import { computed, ref, shallowReactive, type ComputedRef } from 'vue'
import { loadLimitsSwitch, planLimitsEnforced, type PlanId } from './plan-limits'
import { checkPlanFeature, isPlanFeature, planFeatureRefusal, requiredPlanFor, type PlanFeature, type PlanFeatureCheck } from './plan-features'
import { session } from './session'

/** The switch, reactive: false until read (and when it cannot be read). */
const enforcedNow = ref(planLimitsEnforced())

/** Reads the switch (once per page) into the reactive copy the views watch. */
export function watchPlanSwitch(): Promise<boolean> {
  return loadLimitsSwitch().then((value) => (enforcedNow.value = value))
}

/** Tests: set the reactive switch. */
export function setPlanSwitchForTests(value: boolean): void {
  enforcedNow.value = value
}

/** Owner and admin can change the plan; everyone else asks them. */
export const canChangePlan = (role: string | null | undefined = session.role): boolean => role === 'owner' || role === 'admin'

/**
 * "Does the company's plan have X?", reactive over the switch and the company
 * document of the session. Allowed while the switch is off or not read yet,
 * and while the company document has not loaded (the server decides anyway).
 */
export function planFeatureCheck(feature: PlanFeature, now: () => Date = () => new Date()): PlanFeatureCheck {
  const company = session.company as { subscription?: unknown } | null
  return checkPlanFeature({ subscription: company?.subscription ?? null, feature, enforced: enforcedNow.value && company !== null, now: now() })
}

/** Composable: the check as a computed; starts reading the switch. */
export function usePlanFeature(feature: PlanFeature): ComputedRef<PlanFeatureCheck> {
  void watchPlanSwitch()
  return computed(() => planFeatureCheck(feature))
}

/** The notice open as a dialog (PlanFeatureDialog in the shell), or null. */
export const planNotice = shallowReactive<{ open: { feature: PlanFeature; requiredPlan: PlanId | null } | null }>({ open: null })

/** Opens "Recurso do plano X" (the app's showPlanFeatureNotice). */
export function showPlanFeatureNotice(feature: PlanFeature, requiredPlan?: PlanId | null): void {
  planNotice.open = { feature, requiredPlan: requiredPlan ?? requiredPlanFor(feature) }
}

/** Whether the plan has [feature]; shows the notice and answers false when it does not (the app's ensurePlanFeature). */
export function ensurePlanFeature(feature: PlanFeature): boolean {
  const check = planFeatureCheck(feature)
  if (check.allowed) return true
  showPlanFeatureNotice(feature, check.requiredPlan)
  return false
}

/** A 402 PLAN_FEATURE from the server opens the notice; answers whether it did (other errors stay with the caller). */
export function handlePlanFeatureError(error: unknown): boolean {
  const refusal = planFeatureRefusal(error)
  if (!refusal || !isPlanFeature(refusal.feature)) return false
  showPlanFeatureNotice(refusal.feature, refusal.requiredPlan)
  return true
}
