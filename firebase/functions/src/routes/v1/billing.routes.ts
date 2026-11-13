/**
 * Web checkout of PraticOS plans (issue #664, docs/WEB_CHECKOUT.md).
 * Mounted at /v1/app/billing (bearer auth + company). Owner/admin only, as
 * buying in the app (PaywallLauncher.canPurchase).
 *
 * - GET  /         offer (only when config/webCheckout.enabled), guard and the web subscription;
 * - POST /checkout { plan, cycle, billingType, name, taxId, email, postalCode, addressNumber } → { checkoutUrl };
 * - POST /cancel   { refund?: boolean } → { status }.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import { defaultWebBillingDeps } from '../../services/web-billing/default-deps';
import {
  WebBillingError,
  billingOverview,
  cancelWebSubscription,
  startCheckout,
  type WebBillingDeps,
} from '../../services/web-billing/web-billing.service';
import { WEB_BILLING_TYPES, WEB_CYCLES, WEB_PLANS } from '../../services/web-billing/web-billing-rules';

const MANAGER_ROLES = ['owner', 'admin'];

const checkoutSchema = z.object({
  plan: z.enum(WEB_PLANS as [string, ...string[]]),
  cycle: z.enum(WEB_CYCLES as [string, ...string[]]),
  billingType: z.enum(WEB_BILLING_TYPES as [string, ...string[]]),
  name: z.string().trim().min(2).max(200),
  taxId: z.string().trim().min(11).max(32),
  email: z.string().trim().email().max(200),
  // Asaas needs the address to issue the NFS-e; it fills street and city from the CEP.
  postalCode: z.string().trim().min(8).max(10),
  addressNumber: z.string().trim().min(1).max(20),
});

const cancelSchema = z.object({ refund: z.boolean().optional() });

function fail(res: Response, status: number, code: string, message: string) {
  res.status(status).json({ success: false, error: { code, message } });
}

function ensureManager(req: AuthenticatedRequest, res: Response): boolean {
  const role = req.userContext?.role;
  if (!role || !MANAGER_ROLES.includes(role)) {
    fail(res, 403, 'FORBIDDEN', 'Only owners and admins can manage the plan');
    return false;
  }
  return true;
}

function sendError(res: Response, error: unknown, what: string) {
  if (error instanceof WebBillingError) return fail(res, error.status, error.code, error.message);
  console.error(`[Billing] ${what} failed`, (error as Error)?.name);
  return fail(res, 500, 'INTERNAL_ERROR', 'Internal server error');
}

export function createBillingRouter(depsFactory: () => WebBillingDeps | null = defaultWebBillingDeps): Router {
  const router: Router = Router();

  const depsOr503 = (res: Response): WebBillingDeps | null => {
    const deps = depsFactory();
    if (!deps) fail(res, 503, 'NOT_CONFIGURED', 'Web checkout not configured');
    return deps;
  };

  router.get('/', async (req: AuthenticatedRequest, res: Response) => {
    try {
      if (!ensureManager(req, res)) return;
      res.json({ success: true, data: await billingOverview(req.userContext!.companyId) });
    } catch (error) {
      sendError(res, error, 'overview');
    }
  });

  router.post('/checkout', async (req: AuthenticatedRequest, res: Response) => {
    try {
      if (!ensureManager(req, res)) return;
      const validation = validateInput(checkoutSchema, req.body);
      if (!validation.success) return fail(res, 400, 'VALIDATION_ERROR', validation.errors.join(', '));
      const deps = depsOr503(res);
      if (!deps) return;
      const { companyId, userId } = req.userContext!;
      const data = await startCheckout(companyId, userId, validation.data as Parameters<typeof startCheckout>[2], deps);
      res.json({ success: true, data });
    } catch (error) {
      sendError(res, error, 'checkout');
    }
  });

  router.post('/cancel', async (req: AuthenticatedRequest, res: Response) => {
    try {
      if (!ensureManager(req, res)) return;
      const validation = validateInput(cancelSchema, req.body ?? {});
      if (!validation.success) return fail(res, 400, 'VALIDATION_ERROR', validation.errors.join(', '));
      const deps = depsOr503(res);
      if (!deps) return;
      const data = await cancelWebSubscription(req.userContext!.companyId, { refund: validation.data.refund === true }, deps);
      res.json({ success: true, data });
    } catch (error) {
      sendError(res, error, 'cancel');
    }
  });

  return router;
}

export default createBillingRouter();
