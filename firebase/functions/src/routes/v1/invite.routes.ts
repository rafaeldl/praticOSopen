/**
 * Invite Routes
 * Endpoints for collaborator invitation management (app-based)
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import { requirePermission, hasPermission } from '../../middleware/auth.middleware';
import * as inviteService from '../../services/invite.service';
import { validateInput } from '../../utils/validation.utils';
import { requirePlanCapacity, requirePlanFeature } from '../../middleware/plan-limit.middleware';
import { featureForRole } from '../../services/plan-features.service';

const router: Router = Router();

// Validation schemas
const createInviteSchema = z.object({
  name: z.string().max(100).optional(),
  email: z.string().email().optional(),
  phone: z.string().min(1).max(50).optional(),
  role: z.enum(['admin', 'supervisor', 'manager', 'consultant', 'technician']),
}).refine((data) => data.email || data.phone, {
  message: 'Either email or phone is required',
});

/**
 * POST /api/v1/invites
 * Create a new invite
 */
router.post(
  '/',
  requirePermission('manage:members'),
  requirePlanCapacity('collaborator'),
  // Technician, manager, consultant and supervisor are Pro (#724).
  requirePlanFeature((req) => featureForRole(req.body?.role)),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const companyId = req.auth?.companyId;
      if (!companyId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Company context required' },
        });
        return;
      }

      // Validate input
      const validation = validateInput(createInviteSchema, req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: validation.errors.join(', '),
          },
        });
        return;
      }

      const { name, email, phone, role } = validation.data;
      const invitedBy = getUserAggr(req);

      const result = await inviteService.createInvite({
        companyId,
        companyName: req.userContext?.companyName || '',
        name,
        email,
        phone,
        role,
        invitedBy,
        channel: 'app',
      });

      res.status(201).json({
        success: true,
        data: {
          token: result.token,
          expiresAt: result.expiresAt,
        },
      });
    } catch (error) {
      console.error('Create invite error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to create invite' },
      });
    }
  }
);

/**
 * GET /api/v1/invites
 * List invites for current company
 */
router.get(
  '/',
  requirePermission('manage:members'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const companyId = req.auth?.companyId;
      if (!companyId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Company context required' },
        });
        return;
      }

      const invites = await inviteService.listByCompany(companyId);

      res.json({
        success: true,
        data: {
          invites: invites.map((inv: inviteService.Invite) => ({
            token: inv.token,
            name: inv.name,
            email: inv.email,
            phone: inv.phone,
            role: inv.role,
            status: inv.status,
            createdAt: inv.createdAt,
            expiresAt: inv.expiresAt,
            invitedBy: inv.invitedBy,
          })),
        },
      });
    } catch (error) {
      console.error('List invites error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to list invites' },
      });
    }
  }
);

/**
 * DELETE /api/v1/invites/:token
 * Cancel an invite
 */
router.delete('/:token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    const userId = req.auth?.userId;

    if (!companyId || !userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
      });
      return;
    }

    const token = String(req.params.token);

    // Get the invite to check permissions
    const invite = await inviteService.getByToken(token);
    if (!invite) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Invite not found' },
      });
      return;
    }

    // Verify invite belongs to this company
    if (invite.company?.id !== companyId) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Invite not found' },
      });
      return;
    }

    // Check if user is admin or the creator
    const isAdmin = hasPermission(req.userContext || {}, 'manage:members');
    const isCreator = invite.invitedBy?.id === userId;

    if (!isAdmin && !isCreator) {
      res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: 'You do not have permission to cancel this invite' },
      });
      return;
    }

    // The company was checked above: an owner/admin cancels any of its invites.
    const deleted = await inviteService.cancelInvite(token, userId, { asManager: isAdmin });

    if (!deleted) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_REQUEST', message: 'Invite cannot be cancelled (may already be accepted)' },
      });
      return;
    }

    res.json({
      success: true,
      data: { success: true },
    });
  } catch (error) {
    console.error('Cancel invite error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to cancel invite' },
    });
  }
});

// GET /pending, GET /:token and POST /:token/accept live in
// invite-self.routes.ts: they also serve an account without a company and are
// mounted before this router.

export default router;
