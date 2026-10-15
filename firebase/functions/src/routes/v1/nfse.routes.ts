/**
 * NFS-e routes (Flutter app, bearer auth). Mounted at /v1/app/nfse.
 * Only when the company has `nfseEnabled` (server flag) and Asaas connected.
 *
 * Setup (owner/admin):
 * - GET  /setup                         what is filled and what is missing
 * - POST /setup/fiscal-info             saves the fiscal info in Asaas
 * - GET  /setup/municipal-services?q=   municipal services of the city
 * - PUT  /setup/service                 default service of the notas
 *
 * Notas ('manage:payments': owner, admin, manager):
 * - POST /invoices/preview              value, description, customer of one or more orders
 * - POST /invoices                      issues one nota for one or more orders of a customer
 * - POST /invoices/:invoiceId/cancel    cancels it
 *
 * See docs/NFSE_ASAAS.md.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { requirePermission } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import { validateInput } from '../../utils/validation.utils';
import { toHttpError } from '../../services/asaas/errors';
import {
  cancelInvoice,
  createInvoice,
  MAX_INVOICE_ORDERS,
  previewInvoice,
} from '../../services/asaas/invoice.service';
import {
  getNfseSetup,
  saveFiscalInfo,
  saveNfseService,
  searchMunicipalServices,
} from '../../services/asaas/nfse-setup.service';

const router: Router = Router();

const SETUP_ROLES = ['owner', 'admin'];
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const id = z.string().regex(ID_PATTERN);
const percent = z.number().min(0).max(100);

export const fiscalInfoSchema = z.object({
  email: z.string().trim().email().max(200),
  simplesNacional: z.boolean(),
  municipalInscription: z.string().trim().max(30).optional(),
  cnae: z.string().trim().regex(/^[0-9./-]{0,12}$/).optional(),
  specialTaxRegime: z.string().trim().max(30).optional(),
  serviceListItem: z.string().trim().max(20).optional(),
  rpsSerie: z.string().trim().max(10).optional(),
  rpsNumber: z.number().int().min(0).max(999999999).optional(),
  loteNumber: z.number().int().min(0).max(999999999).optional(),
});

export const serviceSchema = z
  .object({
    municipalServiceId: z.string().trim().max(64).nullable().optional(),
    municipalServiceCode: z.string().trim().max(30).nullable().optional(),
    municipalServiceName: z.string().trim().min(1).max(500),
    taxes: z.object({
      retainIss: z.boolean(),
      iss: percent,
      pis: percent,
      cofins: percent,
      csll: percent,
      inss: percent,
      ir: percent,
    }),
    descriptionTemplate: z.string().max(1000).optional(),
  })
  .refine((data) => !!(data.municipalServiceId || data.municipalServiceCode), {
    message: 'municipalServiceId or municipalServiceCode is required',
    path: ['municipalServiceId'],
  });

export const previewSchema = z.object({
  orderIds: z.array(id).min(1).max(MAX_INVOICE_ORDERS),
  customerId: id.optional(),
});

export const createInvoiceSchema = previewSchema.extend({
  serviceDescription: z.string().max(2000).optional(),
  effectiveDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'effectiveDate must be YYYY-MM-DD').optional(),
  customerTaxId: z.string().max(20).optional(),
});

export const cancelSchema = z.object({
  onlyOnAsaas: z.boolean().optional(),
});

function ensureSetupRole(req: AuthenticatedRequest, res: Response): boolean {
  const role = req.userContext?.role;
  if (!role || !SETUP_ROLES.includes(role)) {
    res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: 'Only owners and admins can set up notas' },
    });
    return false;
  }
  return true;
}

function badRequest(res: Response, errors: string[]): void {
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
}

function fail(res: Response, error: unknown, label: string): void {
  // Never log the error object: it may carry request details.
  console.error(`${label} error:`, (error as Error).name);
  const { status, body } = toHttpError(error, `${label} failed`);
  res.status(status).json(body);
}

router.get('/setup', async (req: AuthenticatedRequest, res: Response) => {
  if (!ensureSetupRole(req, res)) return;
  try {
    res.json({ success: true, data: await getNfseSetup(req.userContext!.companyId) });
  } catch (error) {
    fail(res, error, 'NFS-e setup');
  }
});

router.post('/setup/fiscal-info', async (req: AuthenticatedRequest, res: Response) => {
  if (!ensureSetupRole(req, res)) return;
  const validation = validateInput(fiscalInfoSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const data = await saveFiscalInfo(req.userContext!.companyId, validation.data);
    res.json({ success: true, data });
  } catch (error) {
    fail(res, error, 'NFS-e fiscal info');
  }
});

router.get('/setup/municipal-services', async (req: AuthenticatedRequest, res: Response) => {
  if (!ensureSetupRole(req, res)) return;
  const q = typeof req.query.q === 'string' ? req.query.q.slice(0, 100) : undefined;
  try {
    const data = await searchMunicipalServices(req.userContext!.companyId, q);
    res.json({ success: true, data });
  } catch (error) {
    fail(res, error, 'NFS-e municipal services');
  }
});

router.put('/setup/service', async (req: AuthenticatedRequest, res: Response) => {
  if (!ensureSetupRole(req, res)) return;
  const validation = validateInput(serviceSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const data = await saveNfseService(req.userContext!.companyId, validation.data, getUserAggr(req));
    res.json({ success: true, data });
  } catch (error) {
    fail(res, error, 'NFS-e service');
  }
});

router.post(
  '/invoices/preview',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    const validation = validateInput(previewSchema, req.body);
    if (!validation.success) return badRequest(res, validation.errors);
    try {
      const { orderIds, customerId } = validation.data;
      const data = await previewInvoice(req.userContext!.companyId, orderIds, customerId);
      res.json({ success: true, data });
    } catch (error) {
      fail(res, error, 'NFS-e preview');
    }
  },
);

router.post('/invoices', requirePermission('manage:payments'), async (req: AuthenticatedRequest, res: Response) => {
  const validation = validateInput(createInvoiceSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const { customerId, ...input } = validation.data;
    const data = await createInvoice(req.userContext!.companyId, input, getUserAggr(req), customerId);
    res.status(201).json({ success: true, data });
  } catch (error) {
    fail(res, error, 'NFS-e create');
  }
});

router.post(
  '/invoices/:invoiceId/cancel',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    const invoiceId = String(req.params.invoiceId);
    if (!ID_PATTERN.test(invoiceId)) {
      res.status(404).json({ success: false, error: { code: 'INVOICE_NOT_FOUND', message: 'Invoice not found' } });
      return;
    }
    const validation = validateInput(cancelSchema, req.body ?? {});
    if (!validation.success) return badRequest(res, validation.errors);
    try {
      const data = await cancelInvoice(req.userContext!.companyId, invoiceId, validation.data.onlyOnAsaas === true);
      res.json({ success: true, data });
    } catch (error) {
      fail(res, error, 'NFS-e cancel');
    }
  },
);

export default router;
