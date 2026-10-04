/**
 * Order charge routes (Flutter app, bearer auth).
 * Mounted at /v1/app/orders. Requires permission 'manage:payments'.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { requirePermission } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import { validateInput } from '../../utils/validation.utils';
import { cancelOrderCharge, createOrderCharge } from '../../services/asaas/charge.service';
import { toHttpError } from '../../services/asaas/errors';

const router: Router = Router();

export const createChargeSchema = z
  .object({
    value: z.number().positive(),
    mode: z.enum(['single', 'cardInstallments']),
    installmentCount: z.number().int().min(2).max(12).optional(),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dueDate must be YYYY-MM-DD').optional(),
    customerTaxId: z.string().max(20).optional(),
  })
  .refine((data) => data.mode !== 'cardInstallments' || data.installmentCount !== undefined, {
    message: 'installmentCount is required for cardInstallments',
    path: ['installmentCount'],
  });

function param(value: string | string[]): string {
  return Array.isArray(value) ? value[0] : value;
}

router.post(
  '/:orderId/charges',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const validation = validateInput(createChargeSchema, req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
        });
        return;
      }

      const charge = await createOrderCharge(
        req.userContext!.companyId,
        param(req.params.orderId),
        validation.data,
        getUserAggr(req),
      );
      res.status(201).json({ success: true, data: charge });
    } catch (error) {
      console.error('Create charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to create charge');
      res.status(status).json(body);
    }
  },
);

router.delete(
  '/:orderId/charges/:chargeId',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const charge = await cancelOrderCharge(
        req.userContext!.companyId,
        param(req.params.orderId),
        param(req.params.chargeId),
      );
      res.json({ success: true, data: charge });
    } catch (error) {
      console.error('Cancel charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to cancel charge');
      res.status(status).json(body);
    }
  },
);

export default router;
