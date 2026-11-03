/**
 * /v1/app/services and /v1/app/products for the web app (docs/WEB_API.md,
 * "Catálogo"). One router per kind; /v1/services and /v1/products (API key:
 * bot, MCP) keep their own behavior.
 *
 * - GET /            every item; `value` only with viewPrices; meta.mostUsed
 * - GET /:id         one item, same projection
 * - POST /           create (manage*; a price also needs editPrices)
 * - PATCH /:id       edit, with the version read; never rewrites createdAt/createdBy
 * - DELETE /:id      delete, with the photo
 * - POST /import     spreadsheet import: up to 500 per call, repeat-safe by importId
 * - POST /prices     many prices at once, each with the price the person saw
 */
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import type { AuthenticatedRequest } from '../../models/types';
import { can, forbidden, type AppPermission } from '../../middleware/app-permission.middleware';
import { getCompanyAggr, getUserAggr } from '../../middleware/company.middleware';
import * as catalog from '../../services/app-catalog.service';
import { validateInput } from '../../utils/validation.utils';
import { orderScopeOf } from './app-customers.routes';
import { sendOrderError } from './orders.routes';

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
const notFound = (res: Response) => res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Item not found' } });

/** A price in the currency unit: "150" is 150. Never a string, never negative. */
const price = z.number().finite().min(0).max(1_000_000_000);
const name = z.string().trim().min(1, 'Name is required').max(200);
const customData = z
  .record(z.string().min(1).max(100), z.union([z.string().max(2000), z.number(), z.boolean(), z.null()]))
  .refine((value) => Object.keys(value).length <= 100, 'Too many custom fields')
  .nullable()
  .optional();
const photo = z.object({ url: z.string().max(2000), storagePath: z.string().max(500) }).nullable().optional();
const createSchema = z.object({ name, value: price.nullable().optional(), customData });
const updateSchema = z.object({ name: name.optional(), value: price.nullable().optional(), customData, photo, version: z.string().min(1).max(64).optional() });
const importSchema = z.object({
  importId: z.string().regex(/^[A-Za-z0-9-]{8,64}$/),
  items: z.array(z.object({ name, value: price.nullable().optional() })).min(1).max(500),
});
const pricesSchema = z.object({
  changes: z.array(z.object({ id: z.string().min(1).max(200), from: price.nullable(), to: price })).min(1).max(500),
});

export function catalogRoutes(kind: catalog.CatalogKind): Router {
  const router: Router = Router();
  const view: AppPermission = kind === 'service' ? 'viewServices' : 'viewProducts';
  const manage: AppPermission = kind === 'service' ? 'manageServices' : 'manageProducts';

  async function allowed(req: AuthenticatedRequest, res: Response, permission: AppPermission): Promise<boolean> {
    if (await can(req, res, permission)) return true;
    forbidden(res, `Permission '${permission}' is required`);
    return false;
  }
  /** Any write that carries a price (also `null`) needs editPrices: without it the stored price is kept. */
  async function pricesAllowed(req: AuthenticatedRequest, res: Response, sendsPrice: boolean): Promise<boolean> {
    return !sendsPrice || allowed(req, res, 'editPrices');
  }

  router.get('/', route('Failed to list catalog', async (req, res, companyId) => {
    if (!(await allowed(req, res, view))) return;
    const showPrices = await can(req, res, 'viewPrices');
    const result = await catalog.catalogList(companyId, kind, showPrices);
    const mostUsed = await catalog.mostUsed(companyId, kind, await orderScopeOf(req, res), new Set(result.items.map((item) => item.id))).catch((error) => {
      // A shortcut list: its failure never hides the catalog.
      console.warn('catalog: most used not read', (error as Error)?.name);
      return [];
    });
    res.json({ success: true, data: result.items, meta: { total: result.items.length, truncated: result.truncated, prices: showPrices, mostUsed } });
  }));

  router.post('/import', route('Failed to import catalog', async (req, res, companyId) => {
    if (!(await allowed(req, res, manage))) return;
    const validation = validateInput(importSchema, req.body);
    if (!validation.success) return void validationError(res, validation.errors);
    const { importId, items } = validation.data;
    if (!(await pricesAllowed(req, res, items.some((item) => item.value !== undefined)))) return;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);
    let created = 0;
    let existing = 0;
    // One id per line: the same file sent again after a failure finds what is already there.
    for (let start = 0; start < items.length; start += 50) {
      const results = await Promise.all(
        items.slice(start, start + 50).map((item, offset) => catalog.createItem(companyId, kind, item, createdBy, company, `${importId}-${start + offset}`)),
      );
      for (const result of results) {
        if (result.created) created++;
        else existing++;
      }
    }
    res.json({ success: true, data: { created, existing } });
  }));

  router.post('/prices', route('Failed to change prices', async (req, res, companyId) => {
    if (!(await allowed(req, res, manage)) || !(await allowed(req, res, 'editPrices'))) return;
    const validation = validateInput(pricesSchema, req.body);
    if (!validation.success) return void validationError(res, validation.errors);
    const result = await catalog.applyPrices(companyId, kind, validation.data.changes, getUserAggr(req));
    res.json({ success: true, data: result });
  }));

  router.get('/:id', route('Failed to get item', async (req, res, companyId) => {
    if (!(await allowed(req, res, view))) return;
    const item = await catalog.catalogItem(companyId, kind, param(req, 'id'), await can(req, res, 'viewPrices'));
    if (!item) return void notFound(res);
    res.json({ success: true, data: item });
  }));

  router.post('/', route('Failed to create item', async (req, res, companyId) => {
    if (!(await allowed(req, res, manage))) return;
    const validation = validateInput(createSchema, req.body);
    if (!validation.success) return void validationError(res, validation.errors);
    if (!(await pricesAllowed(req, res, validation.data.value !== undefined))) return;
    const result = await catalog.createItem(companyId, kind, validation.data, getUserAggr(req), getCompanyAggr(req));
    res.status(201).json({ success: true, data: { id: result.id, name: validation.data.name, version: result.version } });
  }));

  router.patch('/:id', route('Failed to update item', async (req, res, companyId) => {
    if (!(await allowed(req, res, manage))) return;
    const validation = validateInput(updateSchema, req.body);
    if (!validation.success) return void validationError(res, validation.errors);
    const { version, ...input } = validation.data;
    if (!(await pricesAllowed(req, res, input.value !== undefined))) return;
    const id = param(req, 'id');
    if (input.photo && !catalog.validPhoto(companyId, kind, id, input.photo)) return void validationError(res, ['photo must be a file of this item']);
    const updated = await catalog.updateItem(companyId, kind, id, input, getUserAggr(req), version);
    if (updated === false) return void notFound(res);
    res.json({ success: true, data: { id, updated: true, version: updated } });
  }));

  router.delete('/:id', route('Failed to delete item', async (req, res, companyId) => {
    if (!(await allowed(req, res, manage))) return;
    if (!(await catalog.deleteItem(companyId, kind, param(req, 'id')))) return void notFound(res);
    res.json({ success: true, data: { id: param(req, 'id'), deleted: true } });
  }));

  return router;
}
