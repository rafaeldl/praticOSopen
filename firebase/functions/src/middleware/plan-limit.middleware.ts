/**
 * Plan limit before a write (docs/PLAN_LIMITS_SERVER.md). Mount after the
 * permission checks.
 *
 * One switch, off by default: `config/paidPlans.enabled == true` (Firestore,
 * the same document the app and the web read). Off, the middleware passes
 * without counting anything; with it off the only read is that document
 * (cached a minute per instance).
 * At the limit: 402 { error: { code: 'PLAN_LIMIT', resource, limit, usage, adding, plan } },
 * the same body for the app and the web.
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../models/types';
import {
  checkCompanyPlanLimit,
  isPaidPlansEnabled,
  planLimitError,
  type PlanLimitCheck,
  type PlanResource,
} from '../services/plan-limits.service';

export interface PlanLimitDeps {
  /** The switch. False: the request goes on without counting. */
  enabled: () => boolean | Promise<boolean>;
  check: (companyId: string, resource: PlanResource, adding: number) => Promise<PlanLimitCheck>;
}

export const defaultPlanLimitDeps: PlanLimitDeps = {
  enabled: () => isPaidPlansEnabled(),
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
    try {
      if (!(await deps.enabled())) return next();
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

/**
 * The same check inside a route, after its own validation (a bad request
 * stays a 400, not a 402). Sends the 402 and returns false when it does not fit.
 */
export async function ensurePlanCapacity(
  res: Response,
  companyId: string,
  resource: PlanResource,
  adding = 1,
  deps: PlanLimitDeps = defaultPlanLimitDeps,
): Promise<boolean> {
  if (!(await deps.enabled())) return true;
  const check = await deps.check(companyId, resource, adding);
  if (check.allowed) return true;
  res.status(402).json(planLimitError(check));
  return false;
}
