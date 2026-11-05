/**
 * Notas issued directly in the national system (issue #563).
 * Mounted at /v1/app/nfse/direct by the nfseApi function. Issuing and
 * canceling: owner, admin and manager (spec decision 12).
 *
 *   POST /invoices/preview          { orderIds, emitterId? }        what the sheet shows
 *   POST /invoices                  { orderIds, emitterId?, description?, recipient? }
 *   POST /invoices/:id/cancel       { reason: 'issueError' | 'serviceNotProvided' }
 *   POST /invoices/:id/reconcile    check a nota that got no clear answer
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import { AsaasServiceError, toHttpError } from '../../services/asaas/errors';
import { NfseServiceError, toNfseHttpError } from '../../services/nfse/errors';
import {
  cancelDirectInvoice,
  issueDirectInvoice,
  previewDirectInvoice,
  reconcileDirectInvoice,
} from '../../services/nfse/issue.service';

const router: Router = Router();

const ISSUE_ROLES = ['owner', 'admin', 'manager'];

const id = z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
const orderIds = z.array(id).min(1).max(50);
const address = z
  .object({
    postalCode: z.string().max(9).nullish(),
    street: z.string().max(255).nullish(),
    number: z.string().max(60).nullish(),
    complement: z.string().max(156).nullish(),
    district: z.string().max(60).nullish(),
    cityCode: z.string().max(7).nullish(),
    cityName: z.string().max(100).nullish(),
    state: z.string().max(2).nullish(),
  })
  .strict();

const previewSchema = z.object({ orderIds, emitterId: id.nullish() });
const issueSchema = z.object({
  orderIds,
  emitterId: id.nullish(),
  description: z.string().max(2000).nullish(),
  recipient: z
    .object({
      customerId: id.nullish(),
      taxId: z.string().max(20).nullish(),
      legalName: z.string().max(300).nullish(),
      address: address.nullish(),
      email: z.string().max(80).nullish(),
    })
    .nullish(),
});
const cancelSchema = z.object({ reason: z.enum(['issueError', 'serviceNotProvided']) });

function ensureRole(req: AuthenticatedRequest) {
  const role = req.userContext?.role;
  if (!role || !ISSUE_ROLES.includes(role)) {
    throw new NfseServiceError('FORBIDDEN', 'Only owners, admins and managers can issue notas');
  }
}

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = validateInput(schema, body);
  if (!result.success) throw new NfseServiceError('VALIDATION_ERROR', result.errors.join(', '));
  return result.data;
}

const userOf = (req: AuthenticatedRequest) => ({ id: req.userContext!.userId, name: req.userContext!.userName ?? '' });

function fail(res: Response, error: unknown, label: string) {
  if (error instanceof AsaasServiceError) {
    // Order checks shared with the Asaas nota (ORDER_NOT_FOUND, NO_SERVICES...).
    const { status, body } = toHttpError(error, 'Nota request failed');
    res.status(status).json(body);
    return;
  }
  console.error(`[nfse] ${label}:`, (error as NfseServiceError)?.code ?? (error as Error)?.name);
  const { status, body } = toNfseHttpError(error, 'Nota request failed');
  res.status(status).json(body);
}

router.post('/invoices/preview', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const input = parse(previewSchema, req.body);
    res.json({ success: true, data: await previewDirectInvoice(req.userContext!.companyId, input) });
  } catch (error) {
    fail(res, error, 'preview');
  }
});

router.post('/invoices', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const input = parse(issueSchema, req.body);
    const invoice = await issueDirectInvoice(req.userContext!.companyId, input, userOf(req));
    // 202: the government gave no clear answer yet; the reconcile finishes it.
    res.status(invoice.status === 'creating' ? 202 : 201).json({ success: true, data: invoice });
  } catch (error) {
    fail(res, error, 'issue');
  }
});

router.post('/invoices/:invoiceId/cancel', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const invoiceId = parse(id, req.params.invoiceId);
    const { reason } = parse(cancelSchema, req.body);
    res.json({ success: true, data: await cancelDirectInvoice(req.userContext!.companyId, invoiceId, reason, userOf(req)) });
  } catch (error) {
    fail(res, error, 'cancel');
  }
});

router.post('/invoices/:invoiceId/reconcile', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const invoiceId = parse(id, req.params.invoiceId);
    const invoice = await reconcileDirectInvoice(req.userContext!.companyId, invoiceId, undefined, true);
    if (!invoice) throw new NfseServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
    res.json({ success: true, data: invoice });
  } catch (error) {
    fail(res, error, 'reconcile');
  }
});

export default router;
