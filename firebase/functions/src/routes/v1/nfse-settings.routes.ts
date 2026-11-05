/**
 * What the owner edits about the NFS-e direct (issue #565, spec §4.1 and §4.7).
 * Mounted by the nfseApi at /v1/app/nfse/setup. Owner and admin only (spec decision 12).
 *
 *   PATCH /emitters/:emitterId   { municipalRegistration?, service?, descriptionStyle? }
 *   PUT   /settings              { defaultEmitterId?, autoIssue?, managerCanIssue? }
 *
 * `managerCanIssue` (may the manager issue and cancel notas) is the owner's
 * call only (issue #560).
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { NFSE_DIRECT_AUTO_ISSUE } from '../../models/nfse-direct.types';
import { validateInput } from '../../utils/validation.utils';
import { NfseServiceError, toNfseHttpError } from '../../services/nfse/errors';
import {
  DESCRIPTION_SEPARATORS,
  updateEmitter,
  updateNfseSettings,
} from '../../services/nfse/emitter-settings.service';

const router: Router = Router();

const SETTINGS_ROLES = ['owner', 'admin'];

const emitterIdSchema = z.string().regex(/^[A-Za-z0-9_-]{1,56}$/);

const serviceSchema = z
  .object({
    nationalCode: z.string().regex(/^\d{6}$/),
    municipalCode: z.string().max(20).nullish(),
    nbs: z.string().regex(/^\d{9}$/).nullish(),
    name: z.string().trim().min(1).max(200),
    issRate: z.number().min(0).max(10),
    simplesTaxRate: z.number().min(0).max(100).nullish(),
  })
  .strict();

const emitterSchema = z
  .object({
    municipalRegistration: z.string().max(20).regex(/^[A-Za-z0-9./-]*$/).nullish(),
    service: serviceSchema.nullish(),
    descriptionStyle: z
      .object({ uppercase: z.boolean(), separator: z.enum(DESCRIPTION_SEPARATORS) })
      .strict()
      .nullish(),
  })
  .strict();

const settingsSchema = z
  .object({
    defaultEmitterId: emitterIdSchema.optional(),
    autoIssue: z.enum(NFSE_DIRECT_AUTO_ISSUE as [string, ...string[]]).optional(),
    managerCanIssue: z.boolean().optional(),
  })
  .strict();

function ensureRole(req: AuthenticatedRequest) {
  const role = req.userContext?.role;
  if (!role || !SETTINGS_ROLES.includes(role)) {
    throw new NfseServiceError('FORBIDDEN', 'Only owners and admins can set up notas');
  }
}

function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = validateInput(schema, body);
  if (!result.success) throw new NfseServiceError('VALIDATION_ERROR', result.errors.join(', '));
  return result.data;
}

function fail(res: Response, error: unknown, label: string) {
  console.error(`[nfse] ${label}:`, (error as NfseServiceError)?.code ?? (error as Error)?.name);
  const { status, body } = toNfseHttpError(error, 'Nota settings request failed');
  res.status(status).json(body);
}

router.patch('/emitters/:emitterId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const emitterId = emitterIdSchema.safeParse(req.params.emitterId);
    if (!emitterId.success) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    const update = parse(emitterSchema, req.body);
    res.json({ success: true, data: await updateEmitter(req.userContext!.companyId, emitterId.data, update) });
  } catch (error) {
    fail(res, error, 'emitter update');
  }
});

router.put('/settings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    ensureRole(req);
    const update = parse(settingsSchema, req.body);
    if (update.managerCanIssue !== undefined && req.userContext?.role !== 'owner') {
      throw new NfseServiceError('FORBIDDEN', 'Only the owner decides whether managers issue notas');
    }
    res.json({ success: true, data: await updateNfseSettings(req.userContext!.companyId, update as never) });
  } catch (error) {
    fail(res, error, 'settings update');
  }
});

export default router;
