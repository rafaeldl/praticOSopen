/**
 * RevenueCat Webhook Routes
 * POST /webhooks/revenuecat — RevenueCat sends the `Authorization` header value
 * configured on the webhook; it must equal the REVENUECAT_WEBHOOK_AUTH secret.
 *
 * The event only says which company changed (app_user_id = companyId). The
 * current state is read from GET /v1/subscribers/{companyId} with
 * REVENUECAT_SECRET_API_KEY and written by syncCompanySubscription, so
 * repeated or out-of-order events are harmless.
 *
 * Responses: 500 when a secret is missing (nothing processed), 401 bad or
 * missing Authorization, 400 no event, 200 processed or ignored, 500 when
 * processing throws so RevenueCat retries. Never logs the body or headers.
 */

import { Router, Request, Response } from 'express';
import type { Router as RouterType } from 'express';
import crypto from 'crypto';
import { syncCompanySubscription } from '../../services/subscription.service';
import { fetchSubscriber } from '../../services/revenuecat.client';

const router: RouterType = Router();

// Firestore auto ids; drops RevenueCat anonymous ids ($RCAnonymousID:...) and '/'.
const COMPANY_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export interface RevenueCatEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  transferred_from?: string[];
  transferred_to?: string[];
}

/** Constant-time comparison of the Authorization header with the configured secret. */
export function verifyWebhookAuth(header: string | undefined, secret: string | undefined): boolean {
  if (!secret || !header) return false;
  const received = Buffer.from(header, 'utf8');
  const expected = Buffer.from(secret, 'utf8');
  if (received.length !== expected.length) return false;
  return crypto.timingSafeEqual(received, expected);
}

/** Companies touched by the event: app_user_id plus both sides of a TRANSFER. */
export function collectCompanyIds(event: RevenueCatEvent): string[] {
  const candidates: unknown[] = [
    event.app_user_id,
    ...(Array.isArray(event.transferred_from) ? event.transferred_from : []),
    ...(Array.isArray(event.transferred_to) ? event.transferred_to : []),
  ];
  const ids = candidates.filter(
    (id): id is string => typeof id === 'string' && COMPANY_ID_PATTERN.test(id),
  );
  return [...new Set(ids)];
}

function errorBody(code: string, message: string) {
  return { success: false, error: { code, message } };
}

router.post('/', async (req: Request, res: Response) => {
  const secret = process.env.REVENUECAT_WEBHOOK_AUTH;
  const apiKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!secret || !apiKey) {
    console.error('[RevenueCatWebhook] REVENUECAT_WEBHOOK_AUTH or REVENUECAT_SECRET_API_KEY not configured');
    return res.status(500).json(errorBody('NOT_CONFIGURED', 'Webhook not configured'));
  }

  if (!verifyWebhookAuth(req.header('authorization'), secret)) {
    console.warn('[RevenueCatWebhook] rejected: invalid authorization');
    return res.status(401).json(errorBody('UNAUTHORIZED', 'Invalid authorization'));
  }

  const event = req.body?.event as RevenueCatEvent | undefined;
  if (!event || typeof event.type !== 'string' || !event.type) {
    console.warn('[RevenueCatWebhook] malformed event');
    return res.status(400).json(errorBody('INVALID_PAYLOAD', 'Missing event data'));
  }

  const logged = { eventId: String(event.id ?? '').slice(0, 200), type: event.type.slice(0, 64) };
  const companyIds = collectCompanyIds(event);
  if (companyIds.length === 0) {
    console.log('[RevenueCatWebhook] ignored: no company id', logged);
    return res.status(200).json({ success: true, ignored: true });
  }

  try {
    for (const companyId of companyIds) {
      const result = await syncCompanySubscription(companyId, {
        fetchSubscriber: (appUserId) => fetchSubscriber(appUserId, apiKey),
      });
      console.log('[RevenueCatWebhook] synced', { ...logged, companyId, result });
    }
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[RevenueCatWebhook] processing failed', {
      ...logged,
      companyIds,
      error: error instanceof Error ? error.message : 'unknown',
    });
    return res.status(500).json(errorBody('INTERNAL_ERROR', 'Internal server error'));
  }
});

/**
 * GET /webhooks/revenuecat/health
 * Health check endpoint for monitoring
 */
router.get('/health', (_req: Request, res: Response) => {
  res.json({
    success: true,
    service: 'revenuecat-webhook',
    timestamp: new Date().toISOString(),
  });
});

export default router;
