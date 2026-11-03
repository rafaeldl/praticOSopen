/**
 * /v1/app/customers for the web app (docs/WEB_API.md, "Clientes e aparelhos").
 * Mounted before the generic customers router, so these handlers answer the
 * app paths; /v1/customers (API key: bot, MCP) keeps its own behavior.
 *
 * - GET /          every customer, with open/late badges of the orders the person reads
 * - GET /:id       customer, orders, devices, "gastou" and "falta receber" by role
 * - POST /         create (CPF/CNPJ validated, segment fields)
 * - PATCH /:id     edit: never rewrites createdAt/createdBy (the app does, defect 3)
 * - DELETE /:id    delete (the app has no error handling, defect 10)
 * - POST /import   spreadsheet import: up to 500 per call, repeat-safe by importId
 */
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import type { AuthenticatedRequest, Order } from '../../models/types';
import { can, canReceiveOnOrder, companyUsesFinancial, forbidden } from '../../middleware/app-permission.middleware';
import { getCompanyAggr, getUserAggr } from '../../middleware/company.middleware';
import * as directory from '../../services/app-directory.service';
import { isValidTaxId, normalizeTaxId } from '../../utils/tax-id.utils';
import { validateInput } from '../../utils/validation.utils';
import { sendOrderError } from './orders.routes';

const router: Router = Router();

type Handler = (req: AuthenticatedRequest, res: Response, companyId: string) => Promise<void>;

function route(fallback: string, handler: Handler) {
  return async (req: Request, res: Response): Promise<void> => {
    const authReq = req as AuthenticatedRequest;
    const companyId = authReq.auth?.companyId ?? authReq.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    try {
      await handler(authReq, res, companyId);
    } catch (error) {
      sendOrderError(res, error, fallback);
    }
  };
}

const param = (req: Request, name: string) => String(req.params[name]);
const validationError = (res: Response, errors: string[]) =>
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
const notFound = (res: Response) => res.status(404).json({ success: false, error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found' } });

/** What the person reads of the orders (firestore.rules). */
export async function orderScopeOf(req: AuthenticatedRequest, res: Response): Promise<directory.OrderScope> {
  return {
    all: await can(req, res, 'viewAllOrders'),
    userId: req.userContext?.userId ?? '',
    assigned: req.userContext?.role === 'technician',
  };
}

const optionalText = (max: number) => z.string().trim().max(max).nullable().optional();
/** Segment fields (custom_fields:customer): text, number or ISO date, by field name. */
const customDataSchema = z
  .record(z.string().min(1).max(100), z.union([z.string().max(2000), z.number(), z.boolean(), z.null()]))
  .refine((value) => Object.keys(value).length <= 100, 'Too many custom fields')
  .nullable()
  .optional();
const taxIdSchema = z
  .string()
  .nullable()
  .optional()
  .transform((value) => (value === undefined ? undefined : value === null ? null : normalizeTaxId(value) || null))
  .refine((value) => value === undefined || value === null || isValidTaxId(value), 'Invalid taxId');

const customerBody = {
  phone: optionalText(40),
  email: optionalText(200),
  address: optionalText(500),
  taxId: taxIdSchema,
  customData: customDataSchema,
};
const createSchema = z.object({ name: z.string().trim().min(1, 'Name is required').max(200), ...customerBody });
const updateSchema = z.object({ name: z.string().trim().min(1).max(200).optional(), ...customerBody, version: z.string().min(1).max(64).optional() });
const importSchema = z.object({
  importId: z.string().regex(/^[A-Za-z0-9-]{8,64}$/),
  customers: z
    .array(z.object({ name: z.string().trim().min(1).max(200), phone: optionalText(40), email: optionalText(200), address: optionalText(500), taxId: taxIdSchema }))
    .min(1)
    .max(500),
});

router.get('/', route('Failed to list customers', async (req, res, companyId) => {
  if (!(await can(req, res, 'viewCustomers'))) return forbidden(res, "Permission 'viewCustomers' is required");
  const scope = await orderScopeOf(req, res);
  const result = await directory.customerDirectory(companyId, scope);
  res.json({ success: true, data: result.customers, meta: { total: result.customers.length, truncated: result.truncated, partial: !scope.all } });
}));

router.post('/import', route('Failed to import customers', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageCustomers'))) return forbidden(res, "Permission 'manageCustomers' is required");
  const validation = validateInput(importSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const { importId, customers } = validation.data;
  const createdBy = getUserAggr(req);
  const company = getCompanyAggr(req);
  let created = 0;
  let existing = 0;
  // One id per line: the same file sent again after a failure finds what is already there.
  // 50 at a time: 500 creates one after the other took 10-25 s.
  for (let start = 0; start < customers.length; start += 50) {
    const results = await Promise.all(
      customers.slice(start, start + 50).map((customer, offset) =>
        directory.createCustomer(companyId, customer, createdBy, company, `${importId}-${start + offset}`),
      ),
    );
    for (const result of results) {
      if (result.created) created++;
      else existing++;
    }
  }
  res.json({ success: true, data: { created, existing } });
}));

router.get('/:id', route('Failed to get customer', async (req, res, companyId) => {
  if (!(await can(req, res, 'viewCustomers'))) return forbidden(res, "Permission 'viewCustomers' is required");
  const showPrices = await can(req, res, 'viewPrices');
  const useFinancial = await companyUsesFinancial(req, res);
  const screen = await directory.customerScreen(companyId, param(req, 'id'), await orderScopeOf(req, res), {
    showPrices,
    canReceive: (order: Order) => canReceiveOnOrder(req, order, useFinancial),
  });
  if (!screen) return void notFound(res);
  res.json({ success: true, data: screen });
}));

router.post('/', route('Failed to create customer', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageCustomers'))) return forbidden(res, "Permission 'manageCustomers' is required");
  const validation = validateInput(createSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const result = await directory.createCustomer(companyId, validation.data, getUserAggr(req), getCompanyAggr(req));
  res.status(201).json({ success: true, data: { id: result.id, name: validation.data.name } });
}));

router.patch('/:id', route('Failed to update customer', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageCustomers'))) return forbidden(res, "Permission 'manageCustomers' is required");
  const validation = validateInput(updateSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const { version, ...input } = validation.data;
  const updated = await directory.updateCustomer(companyId, param(req, 'id'), input, getUserAggr(req), version);
  if (updated === false) return void notFound(res);
  res.json({ success: true, data: { id: param(req, 'id'), updated: true, version: updated } });
}));

router.delete('/:id', route('Failed to delete customer', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageCustomers'))) return forbidden(res, "Permission 'manageCustomers' is required");
  const deleted = await directory.deleteCustomer(companyId, param(req, 'id'));
  if (!deleted) return void notFound(res);
  res.json({ success: true, data: { id: param(req, 'id'), deleted: true } });
}));

export default router;
