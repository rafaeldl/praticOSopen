/**
 * Import of the notas already issued and links between notas and orders
 * (issue #569, spec §4.3 and §4.7). Mounted by the nfseApi:
 *
 *   /v1/app/nfse/imports (owner and admin, spec decision 12)
 *     POST /                     { emitterId }   start (or continue) reading the government
 *     POST /:batchId/continue                    read more; the proposal comes when all is read
 *     POST /:batchId/apply       { answers }     "Importar"
 *     POST /:batchId/undo                        "Desfazer importação" (30 days)
 *
 *   /v1/app/nfse/links (owner, admin and manager)
 *     GET  /invoices/:invoiceId/candidates       orders for "Ligar a uma OS"
 *     POST /invoices/:invoiceId/link  { orderId }
 *     POST /invoices/:invoiceId/unlink           "Desligar da OS" (notas made outside the PraticOS)
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import { NfseServiceError, toNfseHttpError } from '../../services/nfse/errors';
import {
  applyImport,
  continueImport,
  linkCandidates,
  linkInvoiceToOrder,
  startImport,
  undoImport,
  unlinkInvoice,
} from '../../services/nfse/import.service';

const id = z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
const startSchema = z.object({ emitterId: id }).strict();
const applySchema = z
  .object({
    answers: z
      .object({
        sameCustomer: z.record(z.string().regex(/^[0-9A-Z]{11,14}$/), z.boolean()).optional(),
        autoIssueCustomerIds: z.array(id).max(500).optional(),
      })
      .strict()
      .default({}),
  })
  .strict();
const linkSchema = z.object({ orderId: id }).strict();

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = validateInput(schema, body);
  if (!result.success) throw new NfseServiceError('VALIDATION_ERROR', result.errors.join(', '));
  return result.data;
}

function ensureRole(req: AuthenticatedRequest, roles: string[]) {
  const role = req.userContext?.role;
  if (!role || !roles.includes(role)) throw new NfseServiceError('FORBIDDEN', 'Not allowed');
}

const userOf = (req: AuthenticatedRequest) => ({ id: req.userContext!.userId, name: req.userContext!.userName ?? '' });

function fail(res: Response, error: unknown, label: string) {
  console.error(`[nfse-import] ${label}:`, (error as NfseServiceError)?.code ?? (error as Error)?.name);
  const { status, body } = toNfseHttpError(error, 'Import request failed');
  res.status(status).json(body);
}

const IMPORT_ROLES = ['owner', 'admin'];
const LINK_ROLES = ['owner', 'admin', 'manager'];

export const nfseImportRoutes: Router = Router();

nfseImportRoutes.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, IMPORT_ROLES);
    const { emitterId } = parse(startSchema, req.body);
    res.json({ success: true, data: await startImport(req.userContext!.companyId, emitterId, userOf(req)) });
  } catch (error) {
    fail(res, error, 'start');
  }
});

nfseImportRoutes.post('/:batchId/continue', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, IMPORT_ROLES);
    res.json({ success: true, data: await continueImport(req.userContext!.companyId, parse(id, req.params.batchId)) });
  } catch (error) {
    fail(res, error, 'continue');
  }
});

nfseImportRoutes.post('/:batchId/apply', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, IMPORT_ROLES);
    const { answers } = parse(applySchema, req.body ?? {});
    res.json({ success: true, data: await applyImport(req.userContext!.companyId, parse(id, req.params.batchId), answers ?? {}, userOf(req)) });
  } catch (error) {
    fail(res, error, 'apply');
  }
});

nfseImportRoutes.post('/:batchId/undo', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, IMPORT_ROLES);
    res.json({ success: true, data: await undoImport(req.userContext!.companyId, parse(id, req.params.batchId), userOf(req)) });
  } catch (error) {
    fail(res, error, 'undo');
  }
});

export const nfseLinkRoutes: Router = Router();

nfseLinkRoutes.get('/invoices/:invoiceId/candidates', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, LINK_ROLES);
    res.json({ success: true, data: { orders: await linkCandidates(req.userContext!.companyId, parse(id, req.params.invoiceId)) } });
  } catch (error) {
    fail(res, error, 'candidates');
  }
});

nfseLinkRoutes.post('/invoices/:invoiceId/link', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, LINK_ROLES);
    const { orderId } = parse(linkSchema, req.body);
    res.json({ success: true, data: await linkInvoiceToOrder(req.userContext!.companyId, parse(id, req.params.invoiceId), orderId, userOf(req)) });
  } catch (error) {
    fail(res, error, 'link');
  }
});

nfseLinkRoutes.post('/invoices/:invoiceId/unlink', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req, LINK_ROLES);
    res.json({ success: true, data: await unlinkInvoice(req.userContext!.companyId, parse(id, req.params.invoiceId), userOf(req)) });
  } catch (error) {
    fail(res, error, 'unlink');
  }
});
