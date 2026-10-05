/**
 * Asaas Webhook Routes
 * POST /webhooks/asaas/:companyId — one webhook per company, registered by
 * connectAsaas with a random authToken that is stored only as a SHA-256 hash
 * (companies/{cid}/private/asaas.webhookTokenHash).
 *
 * Responses: 401 bad/missing token (same body whether the company exists,
 * is connected or the token is wrong — no tenant enumeration), 400 malformed
 * event, 200 handled or acknowledged (handleAsaasEvent ignores what it cannot
 * process), 500 only when processing throws so Asaas retries the event.
 * Never logs the request body, headers or token — ids and event name only.
 */

import { Router, Request, Response } from 'express';
import type { Router as RouterType } from 'express';
import rateLimit from 'express-rate-limit';
import { db } from '../../services/firestore.service';
import { hashToken, safeEqualHex } from '../../services/asaas/crypto';
import { handleAsaasEvent } from '../../services/asaas/webhook.service';
import type { AsaasWebhookEvent } from '../../models/asaas.types';

const router: RouterType = Router();

// Firestore auto ids; also blocks '/' smuggled in via %2F (req.params is decoded).
const COMPANY_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

// Compared against when no hash is stored, so every rejection runs the same work.
const DUMMY_HASH = hashToken('asaas-webhook-no-token-configured');

/** companyId param when it is a valid Firestore id, else '' (never a path). */
function companyIdParam(req: Request): string {
  const value = req.params.companyId;
  return typeof value === 'string' && COMPANY_ID_PATTERN.test(value) ? value : '';
}

/** 300 req/min per companyId + client IP. */
export const asaasWebhookLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later' },
  },
  // Per company AND client IP: a flood with wrong tokens from one IP must not
  // exhaust the budget of Asaas' own deliveries for that company. req.ip is the
  // real client (trust-proxy.utils.ts); /webhooks/** has no Hosting rewrite.
  keyGenerator: (req: Request) => `asaas-webhook:${companyIdParam(req) || 'invalid'}:${req.ip || 'unknown'}`,
});

function unauthorized(res: Response): Response {
  return res.status(401).json({
    success: false,
    error: { code: 'UNAUTHORIZED', message: 'Invalid webhook token' },
  });
}

router.post('/:companyId', asaasWebhookLimiter, async (req: Request, res: Response) => {
  const companyId = companyIdParam(req);
  // Set only once the request is authenticated and well-formed (safe to log).
  let logged: { eventId: string; event: string } | undefined;
  try {
    const token = req.header('asaas-access-token');
    if (!companyId || !token) {
      console.warn('[AsaasWebhook] rejected: missing token or invalid company id');
      return unauthorized(res);
    }

    const connection = await db.collection('companies').doc(companyId).collection('private').doc('asaas').get();
    const storedHash = connection.exists ? connection.data()?.webhookTokenHash : undefined;
    const hasHash = typeof storedHash === 'string';
    const matches = safeEqualHex(hashToken(token), hasHash ? storedHash : DUMMY_HASH);
    if (!hasHash || !matches) {
      console.warn('[AsaasWebhook] rejected: invalid token', { companyId });
      return unauthorized(res);
    }

    const event = req.body as AsaasWebhookEvent | undefined;
    if (!event || typeof event.id !== 'string' || !event.id || typeof event.event !== 'string' || !event.event) {
      console.warn('[AsaasWebhook] malformed event', { companyId });
      return res.status(400).json({
        success: false,
        error: { code: 'INVALID_PAYLOAD', message: 'Missing event id or name' },
      });
    }

    logged = { eventId: event.id.slice(0, 200), event: event.event.slice(0, 64) };
    await handleAsaasEvent(companyId, event);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[AsaasWebhook] processing failed', {
      companyId,
      ...logged,
      error: error instanceof Error ? error.message : 'unknown',
    });
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  }
});

export default router;
