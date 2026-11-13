/**
 * Asaas webhook of Rafsoft's own account: PraticOS plans sold on the web
 * (issue #664, docs/WEB_CHECKOUT.md). Separate from /webhooks/asaas/:companyId,
 * which is the technician's account charging an order.
 *
 * POST /webhooks/asaas-billing — header `asaas-access-token` must equal the
 * ASAAS_BILLING_WEBHOOK_TOKEN secret (set on the webhook in Asaas).
 *
 * Responses: 500 NOT_CONFIGURED when a secret is missing, 401 bad token,
 * 400 malformed event, 200 handled/ignored/duplicate, 500 when processing
 * throws so Asaas retries. Never logs the body, headers or token.
 */

import { Router, Request, Response } from 'express';
import type { Router as RouterType } from 'express';
import rateLimit from 'express-rate-limit';
import { verifyWebhookAuth } from './revenuecat.routes';
import { defaultWebBillingDeps } from '../../services/web-billing/default-deps';
import { handleBillingEvent, type WebBillingDeps } from '../../services/web-billing/web-billing.service';
import type { BillingWebhookEvent } from '../../services/web-billing/web-billing-rules';

function errorBody(code: string, message: string) {
  return { success: false, error: { code, message } };
}

export function createAsaasBillingWebhookRouter(
  depsFactory: () => WebBillingDeps | null = defaultWebBillingDeps,
  tokenOf: () => string | undefined = () => process.env.ASAAS_BILLING_WEBHOOK_TOKEN,
): RouterType {
  const router: RouterType = Router();

  router.use(
    rateLimit({
      windowMs: 60 * 1000,
      max: 300,
      standardHeaders: true,
      legacyHeaders: false,
      message: errorBody('RATE_LIMIT_EXCEEDED', 'Too many requests, please try again later'),
    }),
  );

  router.post('/', async (req: Request, res: Response) => {
    const token = tokenOf();
    const deps = depsFactory();
    if (!token || !deps) {
      console.error('[AsaasBillingWebhook] secrets not configured');
      return res.status(500).json(errorBody('NOT_CONFIGURED', 'Webhook not configured'));
    }
    if (!verifyWebhookAuth(req.header('asaas-access-token'), token)) {
      console.warn('[AsaasBillingWebhook] rejected: invalid token');
      return res.status(401).json(errorBody('UNAUTHORIZED', 'Invalid webhook token'));
    }
    const event = req.body as BillingWebhookEvent | undefined;
    if (!event || typeof event.id !== 'string' || !event.id || typeof event.event !== 'string' || !event.event) {
      return res.status(400).json(errorBody('INVALID_PAYLOAD', 'Malformed event'));
    }
    const logged = { eventId: event.id.slice(0, 200), event: event.event.slice(0, 64) };
    try {
      const result = await handleBillingEvent(event, deps);
      console.log('[AsaasBillingWebhook] processed', { ...logged, result });
      return res.status(200).json({ success: true, result });
    } catch (error) {
      console.error('[AsaasBillingWebhook] processing failed', {
        ...logged,
        error: error instanceof Error ? error.message : 'unknown',
      });
      return res.status(500).json(errorBody('INTERNAL_ERROR', 'Internal server error'));
    }
  });

  return router;
}

export default createAsaasBillingWebhookRouter();
