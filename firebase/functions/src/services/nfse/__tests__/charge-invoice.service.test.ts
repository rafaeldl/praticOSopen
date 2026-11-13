jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { openCertificate } from '../certificate';
import {
  MAX_CHARGE_ATTEMPTS,
  processChargeInvoice,
  processPendingChargeInvoices,
  requestChargeInvoice,
  requestChargeInvoiceCancel,
  type ChargeInvoiceDeps,
  type ChargeInvoiceInput,
} from '../charge-invoice.service';
import type { CertificateUse } from '../certificate-vault.service';
import { NfseServiceError } from '../errors';
import { gzipBase64, type HttpRequest, type HttpResponse } from '../sefin-client';
import { testPki } from './test-certificates';

// Synthetic issuer, emitter and payer; the government is a recorded fixture.
const pki = testPki();
const cert = openCertificate(pki.pfx(), 'senha-teste', { now: new Date('2026-11-05T12:00:00Z'), trustedRoots: [pki.rootPem] });
const KEY = `42000002200000000000191${'1'.padStart(27, '0')}`;
const nfseXml = `<NFSe xmlns="http://www.sped.fazenda.gov.br/nfse"><infNFSe Id="NFS${KEY}"><nNFSe>29</nNFSe></infNFSe></NFSe>`;
const REQUEST = 'companies/issuer/private/nfse/chargeInvoices/webBilling-pay_1';

const INPUT: ChargeInvoiceInput = {
  charge: { key: 'webBilling-pay_1', source: 'webBilling', paymentId: 'pay_1' },
  payerCompanyId: 'payer1',
  value: 119.9,
  description: 'Assinatura do sistema PraticOS, plano Pro (mensal), vencimento 13/11/2026',
  recipient: { name: 'Oficina Exemplo', taxId: '00.000.000/0002-72', email: 'nota@example.com' },
};

let now: Date;
let calls: HttpRequest[];
let answer: (req: HttpRequest) => HttpResponse | Promise<HttpResponse>;
let uses: CertificateUse[];
let certificateDown: boolean;
let deps: Partial<ChargeInvoiceDeps>;

const json = (status: number, body: unknown): HttpResponse => ({ status, body: JSON.stringify(body) });
const issued = () => json(201, { chaveAcesso: KEY, nfseXmlGZipB64: gzipBase64(nfseXml) });
const canceledEvent = () => json(201, { eventoXmlGZipB64: gzipBase64('<evento/>') });

function seedIssuer() {
  seed('companies/issuer', { name: 'Emissora Exemplo' });
  seed('companies/issuer/settings/payments', { nfseDirectEnabled: true });
  seed('companies/issuer/settings/nfse', { provider: 'direct', defaultEmitterId: 'e1' });
  seed('companies/issuer/fiscalEmitters/e1', {
    taxId: '00000000000191',
    legalName: 'EMISSORA EXEMPLO LTDA',
    regime: 'simples',
    simplesOption: 1,
    cityCode: '4200000',
    cityName: 'Cidade Exemplo',
    enabledInCity: true,
    service: { nationalCode: '010501', name: 'Licenciamento de programas', issRate: 2, simplesTaxRate: 6 },
    dpsSeries: '20',
    certificate: { holderName: 'EMISSORA EXEMPLO LTDA', notAfter: '2027-03-12T00:00:00.000Z', status: 'active' },
  });
}

beforeEach(() => {
  resetFakeDb();
  seedIssuer();
  now = new Date('2026-11-13T13:00:00Z');
  calls = [];
  uses = [];
  certificateDown = false;
  answer = issued;
  deps = {
    now: () => now,
    issue: {
      loadCertificate: async (_c, _e, use) => {
        if (certificateDown) throw new NfseServiceError('KEY_VAULT_UNAVAILABLE', 'down');
        uses.push(use);
        return { keyPem: cert.keyPem, chainPem: cert.chainPem, taxId: cert.taxId, notAfter: cert.notAfter.toISOString() };
      },
      config: async () => ({ environment: 'test', layoutByEnvironment: {}, meiAnnualLimit: 81000, appVersion: 'PraticOS-1.104.0' }),
      transport: async (req) => {
        calls.push(req);
        return answer(req);
      },
      saveFile: async () => undefined,
      refreshPdf: async () => undefined,
      sendEmail: async () => null,
    },
  };
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

const invoices = () =>
  list('companies/issuer/invoices').map((d: { id: string; data: Record<string, unknown> }) => ({ ...d.data, id: d.id })) as Array<Record<string, any>>;
const issueCalls = () => calls.filter((c) => c.method === 'POST' && c.url.endsWith('/nfse'));

describe('paid charge → nota', () => {
  it('issues one nota for the payment, to a customer created from the checkout data', async () => {
    expect(await requestChargeInvoice('issuer', INPUT, now)).toBe(true);
    expect(await processChargeInvoice('issuer', 'webBilling-pay_1', deps)).toBe(true);

    const [invoice] = invoices();
    expect(invoice).toMatchObject({
      status: 'authorized',
      provider: 'direct',
      auto: true,
      value: 119.9,
      orderIds: [],
      serviceDescription: INPUT.description,
      emitter: { id: 'e1' },
      recipient: { taxId: '00000000000272', legalName: 'Oficina Exemplo', email: 'nota@example.com' },
      charge: { key: 'webBilling-pay_1', source: 'webBilling', paymentId: 'pay_1' },
      createdBy: { id: 'system', name: 'PraticOS' },
    });
    const customers = list('companies/issuer/customers');
    expect(customers).toHaveLength(1);
    expect(customers[0].data).toMatchObject({ name: 'Oficina Exemplo', taxId: '00000000000272', email: 'nota@example.com' });
    expect(invoice.customer.id).toBe(customers[0].id);
    expect(uses).toEqual([{ purpose: 'autoIssue', invoiceId: invoice.id, by: null }]);
    expect(read(REQUEST)).toMatchObject({ status: 'done', invoiceId: invoice.id, attempts: 1 });
  });

  it('reuses the customer with the same CPF/CNPJ (the next month)', async () => {
    seed('companies/issuer/customers/cu1', { name: 'Já cadastrada', taxId: '00000000000272', legalName: 'JA CADASTRADA LTDA' });
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(list('companies/issuer/customers')).toHaveLength(1);
    expect(invoices()[0]).toMatchObject({ customer: { id: 'cu1' }, recipient: { customerId: 'cu1', legalName: 'JA CADASTRADA LTDA' } });
  });

  it('idempotent: the same payment asked twice, the trigger twice and the sweep give one nota', async () => {
    expect(await requestChargeInvoice('issuer', INPUT, now)).toBe(true);
    expect(await requestChargeInvoice('issuer', INPUT, now)).toBe(false);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(await processChargeInvoice('issuer', 'webBilling-pay_1', deps)).toBe(false);
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(0);
    expect(invoices()).toHaveLength(1);
    expect(issueCalls()).toHaveLength(1);
  });

  it('a run cut short after the nota takes that nota instead of issuing another', async () => {
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    // As if the run died before saving `done`: still processing, 10+ minutes later.
    seed(REQUEST, { ...read(REQUEST)!, status: 'processing', claimedAt: now.toISOString(), invoiceId: null });
    now = new Date(now.getTime() + 11 * 60 * 1000);
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(1);
    expect(invoices()).toHaveLength(1);
    expect(read(REQUEST)).toMatchObject({ status: 'done', invoiceId: invoice.id });
  });
});

describe('government or key vault failing', () => {
  it('no answer from the government: the nota stays creating and the reconcile sends the same DPS', async () => {
    answer = () => Promise.reject(new Error('timeout'));
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    expect(invoice.status).toBe('creating');
    expect(read(REQUEST)).toMatchObject({ status: 'done', invoiceId: invoice.id });
  });

  it('a failure before the DPS is reserved (daily limit) is retried by the daily sweep until it works', async () => {
    seed('companies/issuer/private/nfse/emitters/e1', { issuedOn: '2026-11-13', issuedToday: 60, nextDpsNumber: 7 });
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(read(REQUEST)).toMatchObject({ status: 'retry', attempts: 1, lastErrorCode: 'DAILY_LIMIT_REACHED' });
    expect(invoices()).toHaveLength(0);
    // The trigger fired by that write does not retry: only the sweep does.
    expect(await processChargeInvoice('issuer', 'webBilling-pay_1', deps)).toBe(false);

    now = new Date('2026-11-14T13:00:00Z');
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(1);
    const [invoice] = invoices();
    expect(invoice).toMatchObject({ status: 'authorized', dps: { number: 7 } });
    expect(read(REQUEST)).toMatchObject({ status: 'done', invoiceId: invoice.id, attempts: 2 });
  });

  it('a failure after the DPS is reserved (certificate did not open) leaves that nota to the reconcile, never a second number', async () => {
    certificateDown = true;
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    expect(invoice.status).toBe('creating');
    expect(read(REQUEST)).toMatchObject({ status: 'done', invoiceId: invoice.id, lastErrorCode: 'KEY_VAULT_UNAVAILABLE' });
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(0);
    expect(invoices()).toHaveLength(1);
  });

  it(`gives up after ${MAX_CHARGE_ATTEMPTS} attempts and logs the alert`, async () => {
    seed('companies/issuer/settings/payments', { nfseDirectEnabled: false });
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    for (let i = 1; i < MAX_CHARGE_ATTEMPTS; i++) await processPendingChargeInvoices('issuer', deps);
    expect(read(REQUEST)).toMatchObject({ status: 'failed', attempts: MAX_CHARGE_ATTEMPTS, lastErrorCode: 'NFSE_DIRECT_NOT_ENABLED' });
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(0);
    expect(console.error).toHaveBeenCalledWith(expect.stringContaining('issue it by hand'));
  });

  it('a refusal by the government ends at once, with the refused nota in the list', async () => {
    answer = () => json(400, { erros: [{ Codigo: 'E0312', Descricao: 'Código de tributação inválido' }] });
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    expect(invoice.status).toBe('error');
    expect(read(REQUEST)).toMatchObject({ status: 'failed', lastErrorCode: 'NFSE_REFUSED', invoiceId: invoice.id });
  });
});

describe('refund → cancel the nota', () => {
  it('an issued nota is canceled (service not provided)', async () => {
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();

    answer = canceledEvent;
    expect(await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now)).toBe('requested');
    expect(await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now)).toBe('already');
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);

    expect(read(`companies/issuer/invoices/${invoice.id}`)).toMatchObject({ status: 'canceled', cancelReason: 'serviceNotProvided' });
    expect(read(REQUEST)).toMatchObject({ status: 'done', cancel: { status: 'done' } });
    // The charge is free again in the lock (a canceled nota does not hold it).
    expect(read('companies/issuer/private/nfse/charges/webBilling-pay_1')).toBeUndefined();
  });

  it('refunded before the nota came out: no nota at all', async () => {
    seed('companies/issuer/private/nfse/emitters/e1', { issuedOn: '2026-11-13', issuedToday: 60 });
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now)).toBe('notNeeded');
    now = new Date('2026-11-14T13:00:00Z');
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(0);
    expect(invoices()).toHaveLength(0);
    expect(read(REQUEST)).toMatchObject({ status: 'done', cancel: { status: 'notNeeded' } });
  });

  it('refunded while the nota waits for the government: canceled once the reconcile issues it', async () => {
    answer = () => Promise.reject(new Error('timeout'));
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    expect(await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now)).toBe('requested');
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(read(REQUEST)).toMatchObject({ cancel: { status: 'retry', lastErrorCode: 'INVOICE_CREATING' } });

    // The reconcile issued it; the next sweep cancels it.
    seed(`companies/issuer/invoices/${invoice.id}`, { ...read(`companies/issuer/invoices/${invoice.id}`)!, status: 'authorized', accessKey: KEY });
    answer = canceledEvent;
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(1);
    expect(read(`companies/issuer/invoices/${invoice.id}`)!.status).toBe('canceled');
  });

  it('the government refusing the cancel (deadline) ends failed with the alert', async () => {
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    answer = () => json(400, { erro: { codigo: 'E0840', descricao: 'Prazo para cancelamento expirado' } });
    await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(read(REQUEST)).toMatchObject({ cancel: { status: 'failed', lastErrorCode: 'CANCEL_REFUSED' } });
    expect(console.error).toHaveBeenCalledWith(expect.stringContaining('cancel it by hand'));
  });

  it('the government down during the cancel: the sweep tries again', async () => {
    await requestChargeInvoice('issuer', INPUT, now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    const [invoice] = invoices();
    answer = () => Promise.reject(new Error('socket hang up'));
    await requestChargeInvoiceCancel('issuer', 'webBilling-pay_1', now);
    await processChargeInvoice('issuer', 'webBilling-pay_1', deps);
    expect(read(REQUEST)).toMatchObject({ cancel: { status: 'retry', lastErrorCode: 'SEFIN_UNAVAILABLE' } });

    answer = canceledEvent;
    expect(await processPendingChargeInvoices('issuer', deps)).toBe(1);
    expect(read(`companies/issuer/invoices/${invoice.id}`)!.status).toBe('canceled');
  });

  it('an unknown charge has nothing to cancel', async () => {
    expect(await requestChargeInvoiceCancel('issuer', 'webBilling-pay_9', now)).toBe('unknown');
  });
});
