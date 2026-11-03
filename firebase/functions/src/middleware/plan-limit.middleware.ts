/**
 * Plan limit before a write (docs/PLAN_LIMITS_SERVER.md). Mount after the
 * permission checks.
 *
 * Two switches, both off by default:
 * - `PLAN_LIMITS_ENABLED=true` in the functions env (deploy). Off, the
 *   middleware passes untouched and reads nothing: no Firestore, no Storage.
 * - `config/paidPlans.enabled == true` (runtime). Read only when the env
 *   switch is on; off, every limit is -1.
 * At the limit: 402 { error: { code: 'PLAN_LIMIT', resource, limit, usage, adding, plan } }.
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../models/types';
import {
  checkCompanyPlanLimit,
  planLimitError,
  type PlanLimitCheck,
  type PlanResource,
} from '../services/plan-limits.service';

export interface PlanLimitDeps {
  /** Deploy switch. False: the request goes on without any read. */
  enabled: () => boolean;
  check: (companyId: string, resource: PlanResource, adding: number) => Promise<PlanLimitCheck>;
}

/** `PLAN_LIMITS_ENABLED=true` in the functions env. */
export function planLimitsDeployed(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.PLAN_LIMITS_ENABLED === 'true';
}

export const defaultPlanLimitDeps: PlanLimitDeps = {
  enabled: () => planLimitsDeployed(),
  check: (companyId, resource, adding) => checkCompanyPlanLimit(companyId, resource, adding),
};

/**
 * [adding] says how many units the request adds (default 1). Returning 0
 * skips the check (e.g. a form template saved inactive is not counted).
 */
export function requirePlanCapacity(
  resource: PlanResource,
  adding: (req: AuthenticatedRequest) => number | Promise<number> = () => 1,
  deps: PlanLimitDeps = defaultPlanLimitDeps,
) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    if (!deps.enabled()) return next();
    try {
      const companyId = req.userContext?.companyId ?? req.auth?.companyId;
      const count = await adding(req);
      if (!companyId || count <= 0) return next();
      const check = await deps.check(companyId, resource, count);
      if (!check.allowed) {
        res.status(402).json(planLimitError(check));
        return;
      }
      next();
    } catch (error) {
      console.error('Plan limit check error:', error instanceof Error ? error.message : 'unknown');
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Internal error' } });
    }
  };
}
