/**
 * Plan limit before a write (docs/PLAN_LIMITS_SERVER.md). Mount after the
 * permission checks. Passes untouched while config/paidPlans.enabled is off.
 * At the limit: 402 { error: { code: 'PLAN_LIMIT', resource, limit, usage, adding, plan } }.
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../models/types';
import { checkCompanyPlanLimit, planLimitError, type PlanResource } from '../services/plan-limits.service';

/**
 * [adding] says how many units the request adds (default 1). Returning 0
 * skips the check (e.g. a form template saved inactive is not counted).
 */
export function requirePlanCapacity(
  resource: PlanResource,
  adding: (req: AuthenticatedRequest) => number | Promise<number> = () => 1,
) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const companyId = req.userContext?.companyId ?? req.auth?.companyId;
      const count = await adding(req);
      if (!companyId || count <= 0) return next();
      const check = await checkCompanyPlanLimit(companyId, resource, count);
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
