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
    if (invite.company.id !== companyId) {
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

    const deleted = await inviteService.cancelInvite(token, userId);

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

/**
 * GET /api/v1/invites/pending
 * List pending invites for current user (by email/phone)
 * NOTE: This route MUST be defined before /:token to avoid matching "pending" as a token
 */
router.get('/pending', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
      });
      return;
    }

    // Get user's email from userContext (phone lookup would need to fetch from user doc)
    const userEmail = req.userContext?.userName; // This is actually the name, we need email from somewhere else

    // For now, use the listByUser with whatever context we have
    // In a full implementation, we would fetch the user's email/phone from their profile
    const invites = await inviteService.listByUser(userEmail, undefined);

    res.json({
      success: true,
      data: {
        invites: invites.map((inv: inviteService.Invite) => ({
          token: inv.token,
          companyId: inv.company.id,
          companyName: inv.company.name,
          role: inv.role,
          createdAt: inv.createdAt,
          expiresAt: inv.expiresAt,
          invitedBy: inv.invitedBy?.name,
        })),
      },
    });
  } catch (error) {
    console.error('List pending invites error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list pending invites' },
    });
  }
});

/**
 * GET /api/v1/invites/:token
 * Get invite details by token (for code entry flow)
 * Returns invite info without requiring company membership
 */
router.get('/:token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
      });
      return;
    }

    const token = String(req.params.token);

    // Get the invite
    const invite = await inviteService.getByToken(token);
    if (!invite) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Invite not found' },
      });
      return;
    }

    // Check if invite is valid
    if (invite.status !== 'pending') {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_INVITE',
          message: invite.status === 'accepted' ? 'Invite already used' : 'Invite is no longer valid',
        },
      });
      return;
    }

    // Check expiration
    if (invite.expiresAt && new Date(invite.expiresAt) < new Date()) {
      res.status(400).json({
        success: false,
        error: { code: 'EXPIRED', message: 'Invite has expired' },
      });
      return;
    }

    // Return invite details (limited info for security)
    res.json({
      success: true,
      data: {
        token: invite.token,
        company: {
          id: invite.company.id,
          name: invite.company.name,
        },
        role: invite.role,
        invitedBy: invite.invitedBy?.name,
        expiresAt: invite.expiresAt,
      },
    });
  } catch (error) {
    console.error('Get invite error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get invite' },
    });
  }
});

/**
 * POST /api/v1/invites/:token/accept
 * Accept an invite
 */
router.post('/:token/accept', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.auth?.userId;

    if (!userId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
      });
      return;
    }

    const token = String(req.params.token);

    // Get user info
    const userAggr = getUserAggr(req);

    const result = await inviteService.acceptInvite(token, userId, userAggr.name);

    if (!result.success) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_INVITE',
          message: result.error,
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        success: true,
        companyId: result.companyId,
        companyName: result.companyName,
        role: result.role,
      },
    });
  } catch (error) {
    console.error('Accept invite error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to accept invite' },
    });
  }
});

export default router;
