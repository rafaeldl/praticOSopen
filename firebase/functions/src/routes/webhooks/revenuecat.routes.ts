/**
 * RevenueCat Webhook Routes
 * Handles subscription events from RevenueCat
 */

import { Router, Request, Response } from 'express';
import type { Router as RouterType } from 'express';
import crypto from 'crypto';
import {
  processRevenueCatWebhook,
  RevenueCatWebhookEvent,
} from '../../services/subscription.service';

const router: RouterType = Router();

// RevenueCat webhook secret (set in Firebase Functions config)
const REVENUECAT_WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET || '';

/**
 * Verify RevenueCat webhook signature
 */
function verifySignature(req: Request): boolean {
  if (!REVENUECAT_WEBHOOK_SECRET) {
    console.warn('[Webhook] REVENUECAT_WEBHOOK_SECRET not configured, skipping verification');
    return true; // Allow in development
  }

  const signature = req.headers['x-revenuecat-signature'] as string;
  if (!signature) {
    console.error('[Webhook] Missing x-revenuecat-signature header');
    return false;
  }

  const payload = JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', REVENUECAT_WEBHOOK_SECRET)
    .update(payload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

/**
 * POST /webhooks/revenuecat
 * Handle RevenueCat subscription events
 */
router.post('/', async (req: Request, res: Response) => {
  try {
    // Verify webhook signature
    if (!verifySignature(req)) {
      console.error('[Webhook] Invalid signature');
      return res.status(401).json({
        success: false,
        error: { code: 'INVALID_SIGNATURE', message: 'Invalid webhook signature' },
      });
    }

    const event = req.body.event as RevenueCatWebhookEvent;
    if (!event || !event.type) {
      return res.status(400).json({
        success: false,
        error: { code: 'INVALID_PAYLOAD', message: 'Missing event data' },
      });
    }

    console.log(`[Webhook] Received RevenueCat event: ${event.type}`, {
      id: event.id,
      app_user_id: event.app_user_id,
      product_id: event.product_id,
    });

    // Process the webhook event
    const success = await processRevenueCatWebhook(event);

    if (success) {
      return res.status(200).json({
        success: true,
        message: `Event ${event.type} processed successfully`,
      });
    } else {
      return res.status(422).json({
        success: false,
        error: { code: 'PROCESSING_FAILED', message: 'Failed to process event' },
      });
    }
  } catch (error) {
    console.error('[Webhook] Error processing RevenueCat webhook:', error);
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
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
