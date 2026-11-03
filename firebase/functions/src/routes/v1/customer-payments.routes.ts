/**
 * "Receber de João" routes (Flutter app, bearer auth). Mounted at
 * /v1/app/customers, before the generic customer routes.
 *
 * - GET  /:customerId/open-orders            open orders of the customer (number, open amount, date)
 * - POST /:customerId/receipts               receipt over orders incl. others' (consultant)
 * - POST /:customerId/charges                one Asaas charge for several orders ('chargeOrder')
 * - DELETE /:customerId/charges/:chargeId    cancel it ('chargeOrder')
 * - GET  /:customerId/receipts               receipts (financial: all; consultant: own)
 * - POST /:customerId/receipts/:id/cancel    undo a receipt ("Desfazer recebimento")
 * - PUT/DELETE /:customerId/receipts/:id/file  attach or remove its proof
 *
 * Receiving: owner, admin, manager, or consultant, when the company uses
 * values and billing (same as the app's `canReceivePayments`).
 */
import { Router, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { can, requireAppPermission } from '../../middleware/app-permission.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import { receiptFileSchema, validateInput } from '../../utils/validation.utils';
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
  cancelCustomerReceipt,
  listCustomerOpenOrders,
  listCustomerReceipts,
  MAX_RECEIPT_ORDERS,
  ReceiptAccess,
  registerCustomerReceipt,
  setCustomerReceiptFile,
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
  receiptFile: receiptFileSchema.optional(),
  paymentMethod: z.enum(['pix', 'cash', 'card', 'other']).optional(),
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
  requireAppPermission('chargeOrder'),
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
  requireAppPermission('chargeOrder'),
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

// ----------------------------------------------------------------------------
// Receipts of the customer: list, undo, proof (web). Financial access sees
// and changes every receipt; a consultant, the ones they registered
// (AuthorizationService.canManageReceiptFor, firestore.rules receipts).
// ----------------------------------------------------------------------------

async function receiptAccess(req: AuthenticatedRequest, res: Response): Promise<ReceiptAccess> {
  const financial = await can(req, res, 'viewFinancialReports');
  const userId = req.userContext?.userId;
  return (receipt) => financial || (!!userId && receipt.createdBy?.id === userId);
}

function receiptId(req: AuthenticatedRequest, res: Response): string | null {
  const id = param(req.params.receiptId);
  if (ID_PATTERN.test(id)) return id;
  res.status(404).json({ success: false, error: { code: 'RECEIPT_NOT_FOUND', message: 'Receipt not found' } });
  return null;
}

router.get('/:customerId/receipts', requireReceive, async (req: AuthenticatedRequest, res: Response) => {
  const customerId = param(req.params.customerId);
  if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
  try {
    const receipts = await listCustomerReceipts(req.userContext!.companyId, customerId, await receiptAccess(req, res));
    res.json({ success: true, data: receipts });
  } catch (error) {
    console.error('List receipts error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to list receipts');
    res.status(status).json(body);
  }
});

router.post('/:customerId/receipts/:receiptId/cancel', requireReceive, async (req: AuthenticatedRequest, res: Response) => {
  const customerId = param(req.params.customerId);
  if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
  const id = receiptId(req, res);
  if (!id) return;
  try {
    const receipt = await cancelCustomerReceipt(
      req.userContext!.companyId, customerId, id, getUserAggr(req), await receiptAccess(req, res),
    );
    res.json({ success: true, data: receipt });
  } catch (error) {
    console.error('Cancel receipt error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to cancel receipt');
    res.status(status).json(body);
  }
});

async function setFile(req: AuthenticatedRequest, res: Response, attach: boolean): Promise<void> {
  const customerId = param(req.params.customerId);
  if (!ID_PATTERN.test(customerId)) return customerNotFound(res);
  const id = receiptId(req, res);
  if (!id) return;
  let file: z.infer<typeof receiptFileSchema> | null = null;
  if (attach) {
    const validation = validateInput(z.object({ receiptFile: receiptFileSchema }), req.body);
    if (!validation.success) return validationError(res, validation.errors);
    file = validation.data.receiptFile;
  }
  try {
    const receipt = await setCustomerReceiptFile(
      req.userContext!.companyId, customerId, id, file, getUserAggr(req), await receiptAccess(req, res),
    );
    res.json({ success: true, data: receipt });
  } catch (error) {
    console.error('Receipt file error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to change the receipt file');
    res.status(status).json(body);
  }
}

router.put('/:customerId/receipts/:receiptId/file', requireReceive, (req: AuthenticatedRequest, res: Response) => setFile(req, res, true));
router.delete('/:customerId/receipts/:receiptId/file', requireReceive, (req: AuthenticatedRequest, res: Response) => setFile(req, res, false));

export default router;
