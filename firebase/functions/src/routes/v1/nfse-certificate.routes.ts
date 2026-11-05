/**
 * Certificate of the fiscal emitters (NFS-e direct, issue #561, spec §4.2 and §6).
 * Mounted at /v1/app/nfse/emitters by the nfseApi function (its own service
 * account, the only one allowed to use the KMS keys). Owner and admin only.
 *
 *   POST   /certificate               add a CNPJ: { pfxBase64, password, termsVersion }
 *   PUT    /:emitterId/certificate    replace the certificate (same body)
 *   DELETE /:emitterId/certificate    delete it for good (crypto-shredding)
 *
 * The password and the file are never logged: errors log only their code.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import { db } from '../../services/firestore.service';
import {
  deleteCertificate,
  storeCertificate,
  type CertificateActor,
} from '../../services/nfse/certificate-vault.service';
import { NfseServiceError, toNfseHttpError } from '../../services/nfse/errors';

const router: Router = Router();

/** Spec decision 12: only the owner and admins handle certificates (for now). */
const CERTIFICATE_ROLES = ['owner', 'admin'];

/** A .pfx is a few KB; 64 KB of file is ~88 KB in base64. */
const MAX_PFX_BASE64 = 90_000;

const uploadSchema = z.object({
  pfxBase64: z.string().min(1).max(MAX_PFX_BASE64).regex(/^[A-Za-z0-9+/=\s]+$/, 'pfxBase64 must be base64'),
  password: z.string().min(1).max(200),
  termsVersion: z.string().min(1).max(40),
});

const emitterIdSchema = z.string().regex(/^[A-Za-z0-9_-]{1,56}$/);

async function ensureAllowed(req: AuthenticatedRequest): Promise<void> {
  const role = req.userContext?.role;
  if (!role || !CERTIFICATE_ROLES.includes(role)) {
    throw new NfseServiceError('FORBIDDEN', 'Only owners and admins can manage certificates');
  }
  const settings = await db.collection('companies').doc(req.userContext!.companyId).collection('settings').doc('payments').get();
  if (settings.data()?.nfseDirectEnabled !== true) {
    throw new NfseServiceError('NFSE_DIRECT_NOT_ENABLED', 'NFS-e direct is not enabled for this company');
  }
}

function actorOf(req: AuthenticatedRequest): CertificateActor {
  const device = req.get('x-app-version') || req.get('user-agent') || null;
  return {
    user: { id: req.userContext!.userId, name: req.userContext!.userName ?? '' },
    device: device ? device.slice(0, 200) : null,
    ip: req.ip ?? null,
  };
}

function fail(res: Response, error: unknown, label: string) {
  console.error(`[nfse] ${label}:`, (error as NfseServiceError)?.code ?? (error as Error)?.name);
  const { status, body } = toNfseHttpError(error, 'Certificate request failed');
  res.status(status).json(body);
}

function parseUpload(req: AuthenticatedRequest) {
  const validation = validateInput(uploadSchema, req.body);
  if (!validation.success) {
    // Zod messages name the field, never its value.
    throw new NfseServiceError('VALIDATION_ERROR', validation.errors.join(', '));
  }
  return { ...validation.data, pfx: Buffer.from(validation.data.pfxBase64, 'base64') };
}

router.post('/certificate', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await ensureAllowed(req);
    const body = parseUpload(req);
    const data = await storeCertificate({
      companyId: req.userContext!.companyId,
      pfx: body.pfx,
      password: body.password,
      termsVersion: body.termsVersion,
      actor: actorOf(req),
    });
    res.status(201).json({ success: true, data });
  } catch (error) {
    fail(res, error, 'certificate upload');
  }
});

router.put('/:emitterId/certificate', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await ensureAllowed(req);
    const emitterId = emitterIdSchema.safeParse(req.params.emitterId);
    if (!emitterId.success) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    const body = parseUpload(req);
    const data = await storeCertificate({
      companyId: req.userContext!.companyId,
      emitterId: emitterId.data,
      pfx: body.pfx,
      password: body.password,
      termsVersion: body.termsVersion,
      actor: actorOf(req),
    });
    res.json({ success: true, data });
  } catch (error) {
    fail(res, error, 'certificate replace');
  }
});

router.delete('/:emitterId/certificate', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await ensureAllowed(req);
    const emitterId = emitterIdSchema.safeParse(req.params.emitterId);
    if (!emitterId.success) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    const deleted = await deleteCertificate({
      companyId: req.userContext!.companyId,
      emitterId: emitterId.data,
      actor: actorOf(req),
    });
    if (!deleted) throw new NfseServiceError('CERT_NOT_FOUND', 'Emitter has no certificate');
    res.json({ success: true, data: { emitterId: emitterId.data } });
  } catch (error) {
    fail(res, error, 'certificate delete');
  }
});

export default router;
