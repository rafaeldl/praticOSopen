/**
 * Account routes (Flutter app). Mounted at /v1/app/account of the dedicated
 * `accountApi` function (540 s) — docs/ACCOUNT_DELETION.md
 *
 * DELETE /  →  deletes the signed-in user's account
 * Header: Authorization: Bearer {Firebase ID token}. No X-Company-Id: the
 * deletion is per user, so this route does its own token check instead of
 * bearerAuth + resolveCompanyContext (which require a company).
 * The uid comes only from the verified token (checked for revocation), never
 * from the body.
 *
 * 200  { success: true, data: { deletedCompanies, leftCompanies } }
 * 200  { success: true, data: { alreadyDeleted: true } } when the Auth user is
 *      already gone (retry after a timeout); no recent sign-in required
 * 401  UNAUTHORIZED | TOKEN_EXPIRED | REQUIRES_RECENT_LOGIN (auth_time > 5 min)
 * 409  COMPANY_HAS_MEMBERS (owner of a company with other members; nothing deleted)
 * 409  OWNERSHIP_MISMATCH (owner field and member map disagree; nothing deleted)
 * 500  INTERNAL_ERROR (safe to retry: every step is idempotent)
 */

import { Router, Request, Response } from 'express';
import {
  ACCOUNT_DELETION_HTTP_STATUS,
  AccountDeletionDeps,
  AccountDeletionError,
  assertRecentLogin,
  deleteAccount,
} from '../../services/account-deletion.service';

export interface VerifiedIdToken {
  uid: string;
  auth_time?: number;
}

export interface AccountRouterOptions {
  /** Must check revocation (Admin SDK: verifyIdToken(token, true)). */
  verifyIdToken: (token: string) => Promise<VerifiedIdToken>;
  depsFactory: () => AccountDeletionDeps;
  now?: () => number;
}

function sendError(res: Response, status: number, code: string, message: string): void {
  res.status(status).json({ success: false, error: { code, message } });
}

export function createAccountRouter(options: AccountRouterOptions): Router {
  const now = options.now ?? Date.now;
  const router: Router = Router();

  router.delete('/', async (req: Request, res: Response) => {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      sendError(res, 401, 'UNAUTHORIZED', 'Bearer token is required');
      return;
    }

    let decoded: VerifiedIdToken;
    try {
      decoded = await options.verifyIdToken(header.slice('Bearer '.length).trim());
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === 'auth/user-not-found') {
        // Valid signature, but the Auth user is gone: an earlier attempt
        // already finished (Auth is deleted last). Idempotent success.
        console.log('[accountDeletion] auth user already deleted');
        res.json({ success: true, data: { alreadyDeleted: true } });
        return;
      }
      if (code === 'auth/id-token-expired') {
        sendError(res, 401, 'TOKEN_EXPIRED', 'Token has expired');
      } else {
        sendError(res, 401, 'UNAUTHORIZED', 'Invalid token');
      }
      return;
    }

    const uid = decoded.uid;
    const started = now();
    try {
      assertRecentLogin(decoded.auth_time, now());
      const result = await deleteAccount(uid, options.depsFactory());
      console.log(`[accountDeletion] uid=${uid} ok ms=${now() - started}`);
      res.json({
        success: true,
        data: { deletedCompanies: result.deletedCompanies, leftCompanies: result.leftCompanies },
      });
    } catch (error) {
      if (error instanceof AccountDeletionError) {
        console.warn(`[accountDeletion] uid=${uid} code=${error.code}`);
        sendError(res, ACCOUNT_DELETION_HTTP_STATUS[error.code], error.code, error.message);
        return;
      }
      console.error(`[accountDeletion] uid=${uid} unexpected error ms=${now() - started}`, (error as Error)?.name);
      sendError(res, 500, 'INTERNAL_ERROR', 'Unexpected error');
    }
  });

  return router;
}
