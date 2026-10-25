/**
 * AI assistant routes (Flutter app, bearer auth). Mounted at /v1/app/ai.
 *
 * GET  /status        →  is the assistant on for this company? (docs/AI_ORDER_ASSIST.md)
 * 200  { success: true, data: { enabled, usage?: { used, limit } } }
 *      The app shows Foto / Falar only when enabled. Counts nothing.
 * 403  INSUFFICIENT_PERMISSIONS (no editOrder: the app hides the buttons)
 *
 * POST /order-assist  →  aiOrderAssist (docs/AI_ORDER_ASSIST.md)
 * Body: { text?, audio?: {mimeType, data(base64)}, photos?: [{mimeType, data}], locale? }
 * 200  { success: true, data: OrderDraft }
 * 400  VALIDATION_ERROR · 403 INSUFFICIENT_PERMISSIONS | AI_DISABLED
 * 429  AI_QUOTA_EXCEEDED (details: used, limit) · 503 AI_UNAVAILABLE
 *
 * The company comes from the auth middleware (X-Company-Id checked against the
 * user's membership), never from the body. Logs carry no content.
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireAppPermission } from '../../middleware/app-permission.middleware';
import { validateInput } from '../../utils/validation.utils';
import {
  ORDER_ASSIST_HTTP_STATUS,
  OrderAssistDeps,
  OrderAssistError,
  orderAssistInputSchema,
  runOrderAssist,
} from '../../services/ai/order-assist.service';
import { defaultOrderAssistDeps } from '../../services/ai/order-assist.deps';

export function createAiRouter(depsFactory: () => OrderAssistDeps = defaultOrderAssistDeps): Router {
  const router: Router = Router();

  router.get('/status', requireAppPermission('editOrder'), async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context is required' } });
      return;
    }
    try {
      const deps = depsFactory();
      const settings = await deps.getSettings(companyId);
      const enabled = settings?.enabled === true;
      const usage = enabled && deps.getUsage ? await deps.getUsage(companyId, settings) : undefined;
      res.json({ success: true, data: { enabled, ...(usage ? { usage } : {}) } });
    } catch (error) {
      console.error(`[aiStatus] company=${companyId} unexpected error`, (error as Error)?.name);
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Unexpected error' } });
    }
  });

  router.post('/order-assist', requireAppPermission('editOrder'), async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context is required' } });
      return;
    }
    const validation = validateInput(orderAssistInputSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: validation.errors },
      });
      return;
    }
    const started = Date.now();
    try {
      const draft = await runOrderAssist(companyId, validation.data, depsFactory());
      console.log(
        `[aiOrderAssist] company=${companyId} items=${draft.items.length} ms=${Date.now() - started}`,
      );
      res.json({ success: true, data: draft });
    } catch (error) {
      if (error instanceof OrderAssistError) {
        console.warn(`[aiOrderAssist] company=${companyId} code=${error.code} ms=${Date.now() - started}`);
        res.status(ORDER_ASSIST_HTTP_STATUS[error.code]).json({
          success: false,
          error: { code: error.code, message: error.message, ...(error.details ? { details: error.details } : {}) },
        });
        return;
      }
      console.error(`[aiOrderAssist] company=${companyId} unexpected error`, (error as Error)?.name);
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Unexpected error' } });
    }
  });

  return router;
}

export default createAiRouter();
