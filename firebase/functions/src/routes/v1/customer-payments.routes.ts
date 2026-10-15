/**
 * "Receber de João" routes (Flutter app, bearer auth). Mounted at
 * /v1/app/customers, before the generic customer routes.
 *
 * - GET  /:customerId/open-orders            open orders of the customer (number, open amount, date)
 * - POST /:customerId/receipts               receipt over orders incl. others' (consultant)
 * - POST /:customerId/charges                one Asaas charge for several orders ('manage:payments')
 * - DELETE /:customerId/charges/:chargeId    cancel it ('manage:payments')
 *
 * Receiving: owner, admin, manager, or consultant, when the company uses
 * values and billing (same as the app's `canReceivePayments`).
 */
import { Router, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { requirePermission } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import { validateInput } from '../../utils/validation.utils';
import { db } from '../../services/firestore.service';
import { toHttpError } from '../../services/asaas/errors';
import {
  cancelCustomerCharge,
  createCustomerCharge,
  MAX_CHARGE_ORDERS,
  publicCustomerCharge,
} from '../../services/asaas/customer-charge.service';
import {
  canReceiveForCustomer,
  listCustomerOpenOrders,
  MAX_RECEIPT_ORDERS,
  registerCustomerReceipt,
} from '../../services/customer-receipt.service';

const router: Router = Router();

const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const id = z.string().regex(ID_PATTERN);

export const customerReceiptSchema = z.object({
  receiptId: id,
  paidAt: z.string().min(10).max(40),
  allocations: z
    .array(z.object({ orderId: id, amount: z.number().positive() }))
    .min(1)
    .max(MAX_RECEIPT_ORDERS),
  receiptFile: z
    .object({
      url: z.string().url().max(2048),
      storagePath: z.string().max(512),
      fileName: z.string().max(256).optional(),
      contentType: z.string().max(100),
    })
    .optional(),
});

export const customerChargeSchema = z.object({
  orderIds: z.array(id).min(1).max(MAX_CHARGE_ORDERS),
  value: z.number().positive(),
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dueDate must be YYYY-MM-DD').optional(),
  customerTaxId: z.string().max(20).optional(),
});

function param(value: string | string[]): string {
  return Array.isArray(value) ? value[0] : value;
}

function customerNotFound(res: Response): void {
  res.status(404).json({ success: false, error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found' } });
}

/** Owner, admin, manager or consultant, when the company uses values. */
async function requireReceive(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const companyId = req.userContext?.companyId;
    const company = companyId ? await db.collection('companies').doc(companyId).get() : null;
    const useFinancial = company?.data()?.useFinancial as boolean | undefined;
    if (!canReceiveForCustomer(req.userContext?.role, useFinancial)) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Not allowed to receive payments' } });
      return;
    }
    next();
  } catch (error) {
    console.error('Receive permission check error:', (error as Error).name);
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Internal error' } });
  }
}

function validationError(res: Response, errors: string[]): void {
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
}

router.get('/:customerId/open-orders', requireReceive, async (req: AuthenticatedRequest, res: Response) => {
  const customerId = param(req.params.customerId);
  if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
  try {
    const orders = await listCustomerOpenOrders(req.userContext!.companyId, customerId, req.userContext!.userId);
    res.json({ success: true, data: orders });
  } catch (error) {
    console.error('List open orders error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to list open orders');
    res.status(status).json(body);
  }
});

router.post('/:customerId/receipts', requireReceive, async (req: AuthenticatedRequest, res: Response) => {
  const customerId = param(req.params.customerId);
  if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
  const validation = validateInput(customerReceiptSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  try {
    const result = await registerCustomerReceipt(
      req.userContext!.companyId,
      customerId,
      validation.data,
      getUserAggr(req),
    );
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    console.error('Register receipt error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to register receipt');
    res.status(status).json(body);
  }
});

router.post(
  '/:customerId/charges',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    const customerId = param(req.params.customerId);
    if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
    const validation = validateInput(customerChargeSchema, req.body);
    if (!validation.success) return validationError(res, validation.errors);
    try {
      const charge = await createCustomerCharge(
        req.userContext!.companyId,
        customerId,
        validation.data,
        getUserAggr(req),
      );
      res.status(201).json({ success: true, data: publicCustomerCharge(charge) });
    } catch (error) {
      console.error('Create customer charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to create charge');
      res.status(status).json(body);
    }
  },
);

router.delete(
  '/:customerId/charges/:chargeId',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    const customerId = param(req.params.customerId);
    const chargeId = param(req.params.chargeId);
    if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
    if (!ID_PATTERN.test(chargeId)) {
      res.status(404).json({ success: false, error: { code: 'CHARGE_NOT_FOUND', message: 'Charge not found' } });
      return;
    }
    try {
      const charge = await cancelCustomerCharge(req.userContext!.companyId, customerId, chargeId);
      res.json({ success: true, data: charge });
    } catch (error) {
      console.error('Cancel customer charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to cancel charge');
      res.status(status).json(body);
    }
  },
);

export default router;
