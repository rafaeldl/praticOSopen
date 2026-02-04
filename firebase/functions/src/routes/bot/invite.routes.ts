/**
 * Bot Invite Routes
 * Endpoints for collaborator invitation management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, toDate } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as inviteService from '../../services/invite.service';
import { validateInput, createInviteSchema, acceptInviteSchema } from '../../utils/validation.utils';

const router: Router = Router();

/**
 * POST /api/bot/invite/create
 * Create a new invite code (admin/owner only)
 */
router.post('/create', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Check if user has permission to invite
    const role = req.userContext?.role;
    if (!role || !['owner', 'admin', 'supervisor', 'manager'].includes(role)) {
      res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You do not have permission to invite collaborators',
        },
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

    const { collaboratorName, role: inviteRole, email, phone } = validation.data;

    // Supervisors can only invite technicians
    if (role === 'supervisor' && inviteRole !== 'technician') {
      res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'Supervisors can only invite technicians',
        },
      });
      return;
    }

    const result = await inviteService.createInviteWithWhatsAppLink({
      companyId: req.userContext!.companyId,
      companyName: req.userContext!.companyName,
      name: collaboratorName,
      phone,
      email,
      role: inviteRole,
      invitedBy: { id: req.userContext!.userId, name: req.userContext!.userName },
      channel: 'whatsapp',
    });

    res.status(201).json({
      success: true,
      data: {
        inviteCode: result.code,
        inviteLink: result.link,
        expiresAt: result.expiresAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Create invite error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create invite' },
    });
  }
});

/**
 * POST /api/bot/invite/accept
 * Accept an invite code (for new collaborators)
 */
router.post('/accept', async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Validate input
    const validation = validateInput(acceptInviteSchema, req.body);
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

    const { inviteCode, whatsappNumber, name } = validation.data;

    const result = await inviteService.acceptInviteViaWhatsApp(inviteCode, whatsappNumber, name);

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
        userId: result.userId,
        userName: result.userName,
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

/**
 * GET /api/bot/invite/list
 * List invites created by the current user
 */
router.get('/list', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const invites = await inviteService.listByInviter(req.userContext!.userId);

    res.json({
      success: true,
      data: {
        invites: invites.map((inv) => ({
          code: inv.token,
          collaboratorName: inv.name || '',
          role: inv.role,
          createdAt: toDate(inv.createdAt)?.toISOString(),
          expiresAt: toDate(inv.expiresAt)?.toISOString(),
          accepted: inv.status === 'accepted',
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
});

/**
 * DELETE /api/bot/invite/:code
 * Delete/revoke an invite
 */
router.delete('/:code', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const normalizedCode = inviteService.normalizeInviteCode(String(req.params.code));
    const deleted = await inviteService.cancelInvite(
      normalizedCode,
      req.userContext!.userId
    );

    if (!deleted) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Invite not found or cannot be deleted',
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        success: true,
        message: 'Invite deleted successfully',
      },
    });
  } catch (error) {
    console.error('Delete invite error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete invite' },
    });
  }
});

export default router;
