/**
 * Mounts /v1/app/invites for the app.
 *
 * Two routes act on the caller's own invites and also serve an account with no
 * company yet (onboarding): GET /pending and POST /:token/accept. They run
 * behind bearerAuthAllowingNoCompany. Every other invite route keeps requiring
 * a verified company (bearerAuth + resolveCompanyContext).
 */

import { Express, RequestHandler } from 'express';
import { bearerAuth, bearerAuthAllowingNoCompany } from '../../middleware/auth.middleware';
import { resolveCompanyContext } from '../../middleware/company.middleware';
import inviteRoutes from './invite.routes';
import { createSelfInviteRouter } from './invite-self.routes';

export function mountAppInviteRoutes(
  app: Express,
  limiters: { ip?: RequestHandler; user?: RequestHandler } = {}
): void {
  const pass: RequestHandler = (_req, _res, next) => next();
  const ip = limiters.ip ?? pass;
  const user = limiters.user ?? pass;

  // Auth runs per route inside this router, so other paths fall through to the
  // company-bound mount below without being authenticated twice.
  app.use('/v1/app/invites', createSelfInviteRouter([ip, bearerAuthAllowingNoCompany, user]));
  app.use('/v1/app/invites', ip, bearerAuth, user, resolveCompanyContext, inviteRoutes);
}
