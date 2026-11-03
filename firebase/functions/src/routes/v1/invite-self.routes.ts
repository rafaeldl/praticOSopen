/**
 * Invite routes that act on the caller's own invites: the pending list, the
 * lookup by code and the acceptance.
 *
 * They also serve an account that has no company yet (onboarding), so they are
 * mounted behind bearerAuthAllowingNoCompany — see app-invites.mount.ts.
 * - The code (token) is the secret: anyone signed in who has it can look the
 *   invite up and accept it, with or without a company.
 * - An admin invite is only accepted by its recipient (verified email or the
 *   login phone), whoever asks.
 * - Unknown codes are counted per user (invite-attempts.service.ts): after 10
 *   in an hour, lookup and acceptance answer 429.
 */

import { Router, Response, RequestHandler } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as inviteService from '../../services/invite.service';
import * as attempts from '../../services/invite-attempts.service';
import { maskTokenForLog } from '../../utils/log-redaction.utils';

function callerOf(req: AuthenticatedRequest): inviteService.InviteCaller {
  return {
    email: req.auth?.email,
    emailVerified: req.auth?.emailVerified,
    phone: req.auth?.phone,
  };
}

function unauthorized(res: Response): void {
  res.status(401).json({
    success: false,
    error: { code: 'UNAUTHORIZED', message: 'Authentication required' },
  });
}

function tooManyWrongCodes(res: Response): void {
  res.status(429).json({
    success: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many wrong invite codes, try again later' },
  });
}

/** Looks the code up, counting an unknown one; null when unknown. */
async function findInvite(userId: string, token: string): Promise<inviteService.Invite | null> {
  const invite = await inviteService.getByToken(token);
  if (!invite) {
    console.warn(`[Invite] unknown code: invite=${maskTokenForLog(token)} uid=${userId.slice(0, 6)}`);
    await attempts.recordWrongCode(userId);
  }
  return invite;
}

/**
 * @param auth Authentication for these routes only; requests to any other
 * path fall through untouched.
 */
export function createSelfInviteRouter(auth: RequestHandler[]): Router {
  const router: Router = Router();

  /**
   * GET /v1/app/invites/pending
   * Pending invites sent to the caller's verified email or phone.
   * Defined before /:token so "pending" is never read as a code.
   */
  router.get('/pending', ...auth, async (req: AuthenticatedRequest, res: Response) => {
    try {
      if (!req.auth?.userId) return unauthorized(res);

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
            expiresAt: inviteService.inviteExpiresAt(inv)?.toISOString(),
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
   * GET /v1/app/invites/:token
   * Invite details for the code entry flow (limited info).
   */
  router.get('/:token', ...auth, async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.auth?.userId;
      if (!userId) return unauthorized(res);
      if (await attempts.isBlocked(userId)) return tooManyWrongCodes(res);

      const invite = await findInvite(userId, String(req.params.token));
      if (!invite) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Invite not found' },
        });
        return;
      }

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

      if (inviteService.isInviteExpired(invite)) {
        res.status(400).json({
          success: false,
          error: { code: 'EXPIRED', message: 'Invite has expired' },
        });
        return;
      }

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
          expiresAt: inviteService.inviteExpiresAt(invite)?.toISOString(),
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
   * POST /v1/app/invites/:token/accept
   * Accepts by code, with or without a company. An admin invite only by its
   * recipient.
   */
  router.post('/:token/accept', ...auth, async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.auth?.userId;
      if (!userId) return unauthorized(res);
      if (await attempts.isBlocked(userId)) return tooManyWrongCodes(res);

      const token = String(req.params.token);
      const invite = await findInvite(userId, token);
      if (!invite) {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_INVITE', message: 'Invalid invite code' },
        });
        return;
      }

      if (invite.role === 'admin' && !inviteService.isInviteAddressedTo(invite, callerOf(req))) {
        res.status(403).json({
          success: false,
          error: { code: 'FORBIDDEN', message: 'This invite was sent to someone else' },
        });
        return;
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
