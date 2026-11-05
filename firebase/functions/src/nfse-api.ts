/**
 * nfseApi: the only function that opens the A1 certificates (spec §5.1).
 * Runs with its own service account, the only one with
 * `cloudkms.cryptoKeyDecrypter` on the `nfse-certs` keys.
 *
 * NOT exported from index.ts yet: exporting deploys it, and the deploy needs
 * the key ring and the service account first (manual step in issue #561,
 * docs/NFSE_DIRECT.md). After that step, add to index.ts:
 *
 *   export { nfseApi, nfseDaily } from './nfse-api';
 *
 * Never logs request bodies: they carry the certificate password and customer data.
 */

import cors from 'cors';
import express, { Request, Response } from 'express';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { bearerAuth } from './middleware/auth.middleware';
import { resolveCompanyContext } from './middleware/company.middleware';
import { globalErrorHandler } from './middleware/error-handler.middleware';
import nfseCertificateRoutes from './routes/v1/nfse-certificate.routes';
import nfseDirectRoutes from './routes/v1/nfse-direct.routes';
import { db } from './services/firestore.service';
import { processPendingKeyDestructions, purgeExpiredCertificates } from './services/nfse/certificate-vault.service';
import { reconcileStaleDirectInvoices } from './services/nfse/issue.service';
import { API_CORS_OPTIONS, createAppLimiters, noStore } from './utils/app-rate-limit.utils';
import { configureTrustProxy } from './utils/trust-proxy.utils';

/** Service account of the nfseApi (created by hand, see issue #561). */
export const NFSE_SERVICE_ACCOUNT = `nfse-api@${process.env.GCLOUD_PROJECT || 'praticos'}.iam.gserviceaccount.com`;

export function buildNfseApp(): express.Express {
  const app = express();
  configureTrustProxy(app);
  app.use(cors(API_CORS_OPTIONS));
  // A .pfx is a few KB; nothing here needs more.
  app.use(express.json({ limit: '200kb' }));
  app.use((req: Request, res: Response, next) => {
    const start = Date.now();
    res.on('finish', () => console.log(`[nfseApi] ${req.method} ${req.path} ${res.statusCode} ${Date.now() - start}ms`));
    next();
  });
  const { ipLimiter, userLimiter } = createAppLimiters();
  const appBearer = [ipLimiter, bearerAuth, userLimiter, resolveCompanyContext];
  app.use('/v1/app', noStore);
  app.use('/v1/app/nfse/emitters', ...appBearer, nfseCertificateRoutes);
  app.use('/v1/app/nfse/direct', ...appBearer, nfseDirectRoutes);
  app.use((_req: Request, res: Response) => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Endpoint not found' } });
  });
  app.use(globalErrorHandler);
  return app;
}

export const nfseApi = onRequest(
  {
    region: 'southamerica-east1',
    serviceAccount: NFSE_SERVICE_ACCOUNT,
    memory: '512MiB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 10,
  },
  buildNfseApp(),
);

/** Daily: notas without a clear answer, expired certificates (90 days) and pending key destructions. */
export async function runNfseDaily(): Promise<{ reconciled: number; purged: number; destroyed: number }> {
  const companies = await db.collectionGroup('settings').where('nfseDirectEnabled', '==', true).get();
  let reconciled = 0;
  for (const doc of companies.docs) {
    const companyId = doc.ref.parent.parent?.id;
    if (!companyId) continue;
    reconciled += await reconcileStaleDirectInvoices(companyId).catch(() => 0);
  }
  const purged = await purgeExpiredCertificates();
  const destroyed = await processPendingKeyDestructions();
  return { reconciled, purged, destroyed };
}

export const nfseDaily = onSchedule(
  {
    schedule: '30 6 * * *',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
    serviceAccount: NFSE_SERVICE_ACCOUNT,
    timeoutSeconds: 540,
  },
  async () => {
    const result = await runNfseDaily();
    console.log(`[nfseDaily] ${JSON.stringify(result)}`);
  },
);
