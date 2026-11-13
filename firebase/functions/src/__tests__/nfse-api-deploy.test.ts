/**
 * nfseApi, nfseAutoIssue, nfseChargeInvoice, nfseDaily and freeLimitsNotices (only for the e-mail key) are deployed and run as nfse-api@, the only account
 * with decrypt on the nfse-certs key ring. Any other runtime account (the
 * default compute one of the other functions) cannot open a certificate.
 */
import { readFileSync } from 'fs';
import path from 'path';

const src = (file: string) => readFileSync(path.join(__dirname, '..', file), 'utf8');

describe('nfseApi deploy', () => {
  it('index.ts exports nfseApi, nfseAutoIssue, nfseChargeInvoice, nfseDaily and freeLimitsNotices', () => {
    expect(src('index.ts')).toMatch(/export \{ nfseApi, nfseAutoIssue, nfseChargeInvoice, nfseDaily, freeLimitsNotices \} from '\.\/nfse-api';/);
  });

  it('the five functions run as the nfse-api service account', () => {
    const api = src('nfse-api.ts');
    expect(api).toMatch(/NFSE_SERVICE_ACCOUNT = `nfse-api@\$\{process\.env\.GCLOUD_PROJECT \|\| 'praticos'\}\.iam\.gserviceaccount\.com`/);
    expect(api.match(/serviceAccount: NFSE_SERVICE_ACCOUNT/g)).toHaveLength(5);
  });

  it('no other function opens the vault directly', () => {
    const index = src('index.ts');
    expect(index).not.toMatch(/certificate-vault|key-vault|nfse-certificate\.routes|nfse-direct\.routes/);
  });

  it('the order trigger only requests the automatic nota; the nfse-api account issues it', () => {
    const trigger = src('services/asaas/order-trigger.service.ts');
    expect(trigger).toMatch(/requestDirectAutoIssue/);
    expect(trigger).not.toMatch(/processDirectAutoIssue|issueDirectInvoice/);
    expect(src('nfse-api.ts')).toMatch(/document: 'companies\/\{companyId\}\/private\/nfse\/autoIssue\/\{orderId\}'/);
  });

  it('the web billing webhook only requests the nota of a paid charge; the nfse-api account issues it', () => {
    const billing = src('services/web-billing/web-billing.service.ts');
    expect(billing).toMatch(/requestChargeInvoice/);
    expect(billing).not.toMatch(/processChargeInvoice|issueDirectChargeInvoice|cancelDirectInvoice/);
    expect(src('nfse-api.ts')).toMatch(/document: 'companies\/\{companyId\}\/private\/nfse\/chargeInvoices\/\{requestId\}'/);
  });
});
