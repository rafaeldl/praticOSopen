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
 * POST /form-photo    →  aiFormPhoto (docs/AI_ORDER_ASSIST.md, "Foto do checklist")
 * Body: { photo: {mimeType, data}, question: {label, type, options?}, device?: {category?, name?},
 *         segment?, locale?, lastReading?: {value, unit?} }
 * 200  { success: true, data: { answer?, note?, optionNotes?, photoNote?, photoIssue?, confident, usage } }
 * Same errors as /order-assist. Counts 1 per photo read, a bad photo too.
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
import { FormPhotoDeps, formPhotoInputSchema, runFormPhoto } from '../../services/ai/form-photo.service';
import { defaultFormPhotoDeps } from '../../services/ai/form-photo.deps';

export function createAiRouter(
  depsFactory: () => OrderAssistDeps = defaultOrderAssistDeps,
  formPhotoDepsFactory: () => FormPhotoDeps = defaultFormPhotoDeps,
): Router {
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
        `[aiOrderAssist] company=${companyId} items=${draft.items.length} actions=${!!draft.actions} history=${validation.data.history?.length ?? 0} context=${!!validation.data.context} ms=${Date.now() - started}`,
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

  router.post('/form-photo', requireAppPermission('editOrder'), async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context is required' } });
      return;
    }
    const validation = validateInput(formPhotoInputSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: validation.errors },
      });
      return;
    }
    // Only the company, the question type, the error code and the time: never the photo or any text.
    const type = validation.data.question.type;
    const started = Date.now();
    try {
      const answer = await runFormPhoto(companyId, validation.data, formPhotoDepsFactory());
      console.log(`[aiFormPhoto] company=${companyId} type=${type} ms=${Date.now() - started}`);
      res.json({ success: true, data: answer });
    } catch (error) {
      if (error instanceof OrderAssistError) {
        console.warn(`[aiFormPhoto] company=${companyId} type=${type} code=${error.code} ms=${Date.now() - started}`);
        res.status(ORDER_ASSIST_HTTP_STATUS[error.code]).json({
          success: false,
          error: { code: error.code, message: error.message, ...(error.details ? { details: error.details } : {}) },
        });
        return;
      }
      console.error(`[aiFormPhoto] company=${companyId} type=${type} unexpected error`, (error as Error)?.name);
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Unexpected error' } });
    }
  });

  return router;
}

export default createAiRouter();
