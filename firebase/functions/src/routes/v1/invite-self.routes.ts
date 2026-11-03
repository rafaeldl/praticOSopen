/**
 * Invite routes that act on the caller's own invites.
 *
 * They also serve an account that has no company yet (onboarding), so they are
 * mounted behind bearerAuthAllowingNoCompany — see app-invites.mount.ts. Such
 * an account only sees and accepts invites sent to its verified email or phone.
 */

import { Router, Response, RequestHandler } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as inviteService from '../../services/invite.service';

function callerOf(req: AuthenticatedRequest): inviteService.InviteCaller {
  return {
    email: req.auth?.email,
    emailVerified: req.auth?.emailVerified,
    phone: req.auth?.phone,
  };
}

/**
 * @param auth Authentication for these two routes only; requests to any other
 * path fall through untouched.
 */
export function createSelfInviteRouter(auth: RequestHandler[]): Router {
  const router: Router = Router();

  /**
   * GET /v1/app/invites/pending
   * Pending invites sent to the caller's verified email or phone.
   */
  router.get('/pending', ...auth, async (req: AuthenticatedRequest, res: Response) => {
    try {
      if (!req.auth?.userId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
        });
        return;
      }

      const invites = await inviteService.listAddressedTo(callerOf(req));

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
   * POST /v1/app/invites/:token/accept
   * A member of some company accepts by code (token). An account without a
   * company accepts only an invite sent to its verified email or phone.
   */
  router.post('/:token/accept', ...auth, async (req: AuthenticatedRequest, res: Response) => {
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

      if (!req.auth?.companyId) {
        const invite = await inviteService.getByToken(token);
        if (!invite || !inviteService.isInviteAddressedTo(invite, callerOf(req))) {
          res.status(403).json({
            success: false,
            error: { code: 'FORBIDDEN', message: 'This invite was not sent to this account' },
          });
          return;
        }
      }

      const userName = req.userContext?.userName ?? req.auth?.userName ?? '';
      const result = await inviteService.acceptInvite(token, userId, userName, req.auth?.email);

      if (!result.success && result.code === 'ALREADY_MEMBER') {
        res.status(409).json({
          success: false,
          error: { code: 'ALREADY_MEMBER', message: result.error },
        });
        return;
      }

      if (!result.success) {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_INVITE', message: result.error },
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

  return router;
}
