/**
 * Asaas connection routes (Flutter app, bearer auth).
 * Mounted at /v1/app/payments/asaas. Owner/admin only.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import {
  connectAsaas,
  disconnectAsaas,
  getPaymentSettings,
} from '../../services/asaas/connection.service';
import { toHttpError } from '../../services/asaas/errors';

const router: Router = Router();

const MANAGER_ROLES = ['owner', 'admin'];

const connectSchema = z.object({
  apiKey: z.string().trim().min(1, 'apiKey is required').max(500),
});

function ensureManager(req: AuthenticatedRequest, res: Response): boolean {
  const role = req.userContext?.role;
  if (!role || !MANAGER_ROLES.includes(role)) {
    res.status(403).json({
      success: false,
      error: {
        code: 'FORBIDDEN',
        message: 'Only owners and admins can manage the Asaas connection',
      },
    });
    return false;
  }
  return true;
}

router.get('/settings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;
    const data = await getPaymentSettings(req.userContext!.companyId);
    res.json({ success: true, data });
  } catch (error) {
    console.error('Get Asaas settings error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to get payment settings');
    res.status(status).json(body);
  }
});

router.post('/connect', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;

    const validation = validateInput(connectSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    const { companyId, userId, userName } = req.userContext!;
    const data = await connectAsaas(companyId, validation.data.apiKey, { id: userId, name: userName });
    res.json({ success: true, data });
  } catch (error) {
    // Never log the error object: it may carry request details.
    console.error('Connect Asaas error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to connect Asaas account');
    res.status(status).json(body);
  }
});

router.delete('/connect', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;
    await disconnectAsaas(req.userContext!.companyId);
    res.json({ success: true });
  } catch (error) {
    console.error('Disconnect Asaas error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to disconnect Asaas account');
    res.status(status).json(body);
  }
});

export default router;
