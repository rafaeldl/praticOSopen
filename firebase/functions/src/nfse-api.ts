/**
 * nfseApi: the only function that opens the A1 certificates (spec §5.1).
 * Runs with its own service account, the only one with
 * `cloudkms.cryptoKeyDecrypter` on the `nfse-certs` keys.
 *
 * Exported from index.ts. The key ring, the service account and its roles
 * are set by hand (docs/NFSE_DIRECT.md, "Cloud KMS"); the routes stay closed
 * while `nfseDirectEnabled` is off.
 *
 * Never logs request bodies: they carry the certificate password and customer data.
 */

import cors from 'cors';
import express, { Request, Response } from 'express';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { bearerAuth } from './middleware/auth.middleware';
import { resolveCompanyContext } from './middleware/company.middleware';
import { globalErrorHandler } from './middleware/error-handler.middleware';
import nfseCertificateRoutes from './routes/v1/nfse-certificate.routes';
import nfseDirectRoutes from './routes/v1/nfse-direct.routes';
import nfseSettingsRoutes from './routes/v1/nfse-settings.routes';
import { nfseImportRoutes, nfseLinkRoutes } from './routes/v1/nfse-import.routes';
import { db } from './services/firestore.service';
import { processPendingKeyDestructions, purgeExpiredCertificates } from './services/nfse/certificate-vault.service';
import { sendCertificateNotices } from './services/nfse/certificate-expiry-notice.service';
import { reconcileStaleDirectInvoices } from './services/nfse/issue.service';
import { processDirectAutoIssue, processPendingDirectAutoIssues } from './services/nfse/auto-issue.service';
import { RESEND_API_KEY } from './services/nfse/invoice-email.service';
import { syncCompanyMailboxes } from './services/nfse/import.service';
import { API_CORS_OPTIONS, createAppLimiters, noStore } from './utils/app-rate-limit.utils';
import { configureTrustProxy } from './utils/trust-proxy.utils';

/** Service account of the nfseApi and nfseDaily (created by hand, docs/NFSE_DIRECT.md). */
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
  app.use('/v1/app/nfse/setup', ...appBearer, nfseSettingsRoutes);
  app.use('/v1/app/nfse/imports', ...appBearer, nfseImportRoutes);
  app.use('/v1/app/nfse/links', ...appBearer, nfseLinkRoutes);
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
    // The nota goes to the customer's e-mail (issue #611); the reconcile in nfseDaily may issue too.
    secrets: [RESEND_API_KEY],
    // 1 GiB: the import of a CNPJ with ~200 notas in a workshop with years of
    // orders went past 512 MiB (it now reads only the fields it uses, page by
    // page; the margin stays for the PDF and the certificate work).
    memory: '1GiB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 10,
  },
  buildNfseApp(),
);

/**
 * Daily: automatic notas still pending, notas without a clear answer, the government mailbox of each emitter
 * (notas made elsewhere, cancellations, received notas), certificate expiry
 * notices, expired certificates (90 days) and pending key destructions.
 */
export async function runNfseDaily(): Promise<{ autoIssued: number; reconciled: number; read: number; noticed: number; purged: number; destroyed: number }> {
  const companies = await db.collectionGroup('settings').where('nfseDirectEnabled', '==', true).get();
  let autoIssued = 0;
  let reconciled = 0;
  let noticed = 0;
  let read = 0;
  for (const doc of companies.docs) {
    const companyId = doc.ref.parent.parent?.id;
    if (!companyId) continue;
    // Automatic notas the trigger below missed or left halfway (issue #571).
    autoIssued += await processPendingDirectAutoIssues(companyId).catch(() => 0);
    reconciled += await reconcileStaleDirectInvoices(companyId).catch(() => 0);
    read += await syncCompanyMailboxes(companyId).catch(() => 0);
    noticed += (await sendCertificateNotices(companyId, new Date()).catch(() => ({ sent: 0 }))).sent;
  }
  const purged = await purgeExpiredCertificates();
  const destroyed = await processPendingKeyDestructions();
  return { autoIssued, reconciled, read, noticed, purged, destroyed };
}

export const nfseDaily = onSchedule(
  {
    schedule: '30 6 * * *',
    timeZone: 'America/Sao_Paulo',
    region: 'southamerica-east1',
    serviceAccount: NFSE_SERVICE_ACCOUNT,
    secrets: [RESEND_API_KEY],
    timeoutSeconds: 540,
  },
  async () => {
    const result = await runNfseDaily();
    console.log(`[nfseDaily] ${JSON.stringify(result)}`);
  },
);

/**
 * Automatic nota when an order is done (issue #571): the order trigger
 * (default account, no certificate) only writes
 * companies/{cid}/private/nfse/autoIssue/{orderId}; this one, in the nfse-api
 * account, issues it. Created once per order (the id is the order), claimed in
 * a transaction, so a repeated event does nothing. No retry: what fails is
 * recorded on the order, and the daily sweep takes what was cut short.
 */
export const nfseAutoIssue = onDocumentCreated(
  {
    document: 'companies/{companyId}/private/nfse/autoIssue/{orderId}',
    region: 'southamerica-east1',
    serviceAccount: NFSE_SERVICE_ACCOUNT,
    secrets: [RESEND_API_KEY],
    memory: '512MiB',
    timeoutSeconds: 120,
    maxInstances: 10,
  },
  async (event) => {
    const { companyId, orderId } = event.params;
    await processDirectAutoIssue(companyId, orderId);
  },
);
