/**
 * Team Routes (app)
 * Role change and removal of a company member — owner/admin only.
 * Mounted at /v1/app/team behind bearerAuth + resolveCompanyContext.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest, RoleType } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import { requirePermission } from '../../middleware/auth.middleware';
import * as teamService from '../../services/team.service';
import { validateInput } from '../../utils/validation.utils';

const router: Router = Router();

const changeRoleSchema = z.object({
  role: z.enum(['admin', 'supervisor', 'manager', 'consultant', 'technician']),
});

const TEAM_ERROR_STATUS: Record<teamService.TeamErrorCode, number> = {
  COMPANY_NOT_FOUND: 404,
  MEMBER_NOT_FOUND: 404,
  OWNER_PROTECTED: 403,
  LAST_ADMIN: 409,
};

function sendError(res: Response, error: unknown, fallback: string) {
  if (error instanceof teamService.TeamError) {
    res.status(TEAM_ERROR_STATUS[error.code]).json({
      success: false,
      error: { code: error.code, message: error.message },
    });
    return;
  }
  console.error(`${fallback}:`, error);
  res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: fallback } });
}

/**
 * PATCH /v1/app/team/members/:userId
 * Body: { role }
 */
router.patch(
  '/members/:userId',
  requirePermission('manage:members'),
  async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    const validation = validateInput(changeRoleSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    const userId = String(req.params.userId);
    try {
      await teamService.changeMemberRole(companyId, userId, validation.data.role as RoleType, getUserAggr(req));
      res.json({ success: true, data: { userId, role: validation.data.role } });
    } catch (error) {
      sendError(res, error, 'Failed to change member role');
    }
  }
);

/**
 * DELETE /v1/app/team/members/:userId
 */
router.delete(
  '/members/:userId',
  requirePermission('manage:members'),
  async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }

    const userId = String(req.params.userId);
    try {
      await teamService.removeTeamMember(companyId, userId, getUserAggr(req));
      res.json({ success: true, data: { userId, removed: true } });
    } catch (error) {
      sendError(res, error, 'Failed to remove member');
    }
  }
);

export default router;
