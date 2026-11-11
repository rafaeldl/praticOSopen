jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { openCertificate } from '../certificate';
import {
  autoIssueApplies,
  processDirectAutoIssue,
  processPendingDirectAutoIssues,
  requestDirectAutoIssue,
  STALE_PROCESSING_MS,
  type AutoIssueDeps,
} from '../auto-issue.service';
import type { CertificateUse } from '../certificate-vault.service';
import { gzipBase64, type HttpRequest, type HttpResponse } from '../sefin-client';
import { testPki } from './test-certificates';

// Synthetic company, emitter and customer; the government is a recorded fixture.
const pki = testPki();
const cert = openCertificate(pki.pfx(), 'senha-teste', { now: new Date('2026-11-05T12:00:00Z'), trustedRoots: [pki.rootPem] });
const KEY = `42000002200000000000191${'1'.padStart(27, '0')}`;
const nfseXml = `<NFSe xmlns="http://www.sped.fazenda.gov.br/nfse"><infNFSe Id="NFS${KEY}"><nNFSe>29</nNFSe></infNFSe></NFSe>`;
const REQUEST = 'companies/c1/private/nfse/autoIssue/o1';

let now: Date;
let calls: HttpRequest[];
let answer: (req: HttpRequest) => HttpResponse;
let uses: CertificateUse[];
let deps: Partial<AutoIssueDeps>;

const json = (status: number, body: unknown): HttpResponse => ({ status, body: JSON.stringify(body) });

function seedCompany({ rule = 'allOrders', customerSwitch, emitter = {} }: { rule?: unknown; customerSwitch?: boolean | null; emitter?: Record<string, unknown> } = {}) {
  seed('companies/c1/settings/payments', { nfseDirectEnabled: true });
  seed('companies/c1/settings/nfse', { provider: 'direct', defaultEmitterId: 'e1', autoIssue: rule });
  seed('companies/c1/fiscalEmitters/e1', {
    taxId: '00000000000191',
    legalName: 'OFICINA EXEMPLO LTDA',
    regime: 'simples',
    simplesOption: 1,
    cityCode: '4200000',
    cityName: 'Cidade Exemplo',
    enabledInCity: true,
    service: { nationalCode: '140101', name: 'Lubrificação, limpeza e revisão', issRate: 2.5, simplesTaxRate: 6 },
    descriptionStyle: { uppercase: true, separator: ' - ' },
    dpsSeries: '10',
    certificate: { holderName: 'OFICINA EXEMPLO LTDA', notAfter: '2027-03-12T00:00:00.000Z', status: 'active' },
    ...emitter,
  });
  seed('companies/c1/customers/cu1', {
    name: 'Revenda Exemplo',
    taxId: '00000000000272',
    legalName: 'REVENDA EXEMPLO LTDA',
    fiscalAddress: { postalCode: '88000000', street: 'Rua Exemplo', number: '10', district: 'Centro', cityCode: '4200000', state: 'SC' },
    email: 'nota@example.com',
    ...(customerSwitch === undefined ? {} : { autoIssueInvoice: customerSwitch }),
  });
  seed('companies/c1/orders/o1', {
    number: 182,
    status: 'done',
    customer: { id: 'cu1', name: 'Revenda Exemplo' },
    services: [{ service: { id: 's1', name: 'Troca de óleo' }, value: 300 }],
  });
}

beforeEach(() => {
  resetFakeDb();
  now = new Date('2026-11-05T13:00:00Z');
  calls = [];
  uses = [];
  answer = () => json(201, { chaveAcesso: KEY, nfseXmlGZipB64: gzipBase64(nfseXml) });
  deps = {
    now: () => now,
    issue: {
      loadCertificate: async (_c, _e, use) => {
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

const invoices = () => list('companies/c1/invoices').map((d: { id: string; data: Record<string, unknown> }) => ({ ...d.data, id: d.id })) as Array<Record<string, any>>;

describe('autoIssueApplies (the three rules)', () => {
  it.each([
    ['never', true, false],
    ['never', undefined, false],
    ['selectedCustomers', true, true],
    ['selectedCustomers', undefined, false],
    ['selectedCustomers', null, false],
    ['selectedCustomers', false, false],
    ['allOrders', undefined, true],
    ['allOrders', null, true],
    ['allOrders', true, true],
    ['allOrders', false, false],
  ] as const)('%s with the customer switch %s → %s', (rule, customerSwitch, expected) => {
    expect(autoIssueApplies(rule, customerSwitch)).toBe(expected);
  });
});

describe('requestDirectAutoIssue (order trigger)', () => {
  it('allOrders: writes the request once, even when the trigger runs twice', async () => {
    seedCompany({ rule: 'allOrders' });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(true);
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
    expect(read(REQUEST)).toMatchObject({ orderId: 'o1', status: 'pending', rule: 'allOrders' });
    // The trigger never issues: no nota, no government call.
    expect(invoices()).toHaveLength(0);
    expect(calls).toHaveLength(0);
  });

  it('allOrders: a customer switched off is left out', async () => {
    seedCompany({ rule: 'allOrders', customerSwitch: false });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
    expect(read(REQUEST)).toBeUndefined();
  });

  it('selectedCustomers: only for a customer switched on', async () => {
    seedCompany({ rule: 'selectedCustomers' });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
    seed('companies/c1/customers/cu1', { ...read('companies/c1/customers/cu1')!, autoIssueInvoice: true });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(true);
  });

  it.each(['never', 'completed', 'paid', 'manual', null])('autoIssue %s (never, or an Asaas value) does nothing', async (rule) => {
    seedCompany({ rule, customerSwitch: true });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
    expect(read(REQUEST)).toBeUndefined();
  });

  it('does nothing without the NFS-e direct', async () => {
    seedCompany({ rule: 'allOrders' });
    seed('companies/c1/settings/payments', { nfseDirectEnabled: false, nfseEnabled: true });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
  });

  it('an order that already has a nota (any engine, any status) is left to the user', async () => {
    seedCompany({ rule: 'allOrders' });
    seed('companies/c1/invoices/i0', { status: 'canceled', orderIds: ['o1'] });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
  });

  it('an order no longer done, or without a customer, does nothing', async () => {
    seedCompany({ rule: 'allOrders' });
    seed('companies/c1/orders/o1', { ...read('companies/c1/orders/o1')!, status: 'progress' });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
    seed('companies/c1/orders/o1', { status: 'done', number: 1 });
    expect(await requestDirectAutoIssue('c1', 'o1', deps)).toBe(false);
  });
});

describe('processDirectAutoIssue (nfse-api)', () => {
  async function requested(options?: Parameters<typeof seedCompany>[0]) {
    seedCompany(options);
    await requestDirectAutoIssue('c1', 'o1', deps);
  }

  it('issues like the sheet: emitter, description, value; marked auto; certificate opened as autoIssue', async () => {
    await requested();
    const result = await processDirectAutoIssue('c1', 'o1', deps);

    const [invoice] = invoices();
    expect(result).toEqual({ invoiceId: invoice.id });
    expect(invoice).toMatchObject({
      status: 'authorized',
      provider: 'direct',
      auto: true,
      value: 300,
      serviceDescription: 'TROCA DE ÓLEO',
      emitter: { id: 'e1' },
      orderIds: ['o1'],
      createdBy: { id: 'system', name: 'PraticOS' },
    });
    expect(uses).toEqual([{ purpose: 'autoIssue', invoiceId: invoice.id, by: null }]);
    expect(read(REQUEST)).toMatchObject({ status: 'done', result: { invoiceId: invoice.id }, attempts: 1 });
    // The daily ceiling counts it.
    expect(read('companies/c1/private/nfse/emitters/e1')).toMatchObject({ issuedOn: '2026-11-05', issuedToday: 1 });
  });

  it('idempotent: a repeated event, or the sweep afterwards, issues nothing more', async () => {
    await requested();
    await processDirectAutoIssue('c1', 'o1', deps);
    expect(await processDirectAutoIssue('c1', 'o1', deps)).toBeNull();
    expect(await processPendingDirectAutoIssues('c1', deps)).toBe(0);
    expect(invoices()).toHaveLength(1);
    expect(calls.filter((c) => c.url.endsWith('/nfse'))).toHaveLength(1);
  });

  it('two runs at once: only the one that claims the request issues', async () => {
    await requested();
    await Promise.all([processDirectAutoIssue('c1', 'o1', deps), processDirectAutoIssue('c1', 'o1', deps)]);
    expect(invoices()).toHaveLength(1);
  });

  it('an order that got a nota by hand in the meantime is skipped', async () => {
    await requested();
    seed('companies/c1/invoices/manual', { status: 'authorized', provider: 'direct', orderIds: ['o1'] });
    expect(await processDirectAutoIssue('c1', 'o1', deps)).toEqual({ skipped: 'hasInvoice' });
    expect(calls).toHaveLength(0);
  });

  it('customer without CPF/CNPJ: auto-{orderId} in error with the reason, no government call', async () => {
    await requested();
    seed('companies/c1/customers/cu1', { name: 'Revenda Exemplo' });
    const result = await processDirectAutoIssue('c1', 'o1', deps);

    expect(result).toEqual({ errorCode: 'RECIPIENT_TAX_ID_REQUIRED' });
    expect(read('companies/c1/invoices/auto-o1')).toMatchObject({
      status: 'error',
      provider: 'direct',
      auto: true,
      errorCode: 'RECIPIENT_TAX_ID_REQUIRED',
      orderIds: ['o1'],
      orders: [{ orderId: 'o1', orderNumber: 182, value: 300 }],
      value: 300,
    });
    expect(calls).toHaveLength(0);
    // Expected: a warning, never the alert line.
    expect(console.error).not.toHaveBeenCalled();
  });

  it('expired certificate: CERT_EXPIRED on the order', async () => {
    await requested({ emitter: { certificate: { holderName: 'X', notAfter: '2026-10-01T00:00:00.000Z', status: 'active' } } });
    expect(await processDirectAutoIssue('c1', 'o1', deps)).toEqual({ errorCode: 'CERT_EXPIRED' });
    expect(read('companies/c1/invoices/auto-o1')!.errorCode).toBe('CERT_EXPIRED');
  });

  it('daily ceiling reached: DAILY_LIMIT_REACHED on the order', async () => {
    await requested();
    seed('companies/c1/private/nfse/emitters/e1', { nextDpsNumber: 61, issuedOn: '2026-11-05', issuedToday: 60 });
    expect(await processDirectAutoIssue('c1', 'o1', deps)).toEqual({ errorCode: 'DAILY_LIMIT_REACHED' });
    expect(read('companies/c1/invoices/auto-o1')!.errorCode).toBe('DAILY_LIMIT_REACHED');
    expect(calls).toHaveLength(0);
  });

  it('government out: the nota stays waiting (reconciled later), no error record', async () => {
    await requested();
    answer = () => json(503, {});
    const result = await processDirectAutoIssue('c1', 'o1', deps);
    const [invoice] = invoices();
    expect(invoice).toMatchObject({ status: 'creating', auto: true });
    expect(result).toEqual({ invoiceId: invoice.id });
    expect(read('companies/c1/invoices/auto-o1')).toBeUndefined();
  });

  it('refused by the government: the nota itself carries the refusal; no second record', async () => {
    await requested();
    answer = () => json(400, { erros: [{ Codigo: 'E0001', Descricao: 'Recusada' }] });
    const result = await processDirectAutoIssue('c1', 'o1', deps);
    const all = invoices();
    expect(all).toHaveLength(1);
    expect(all[0]).toMatchObject({ status: 'error', auto: true });
    expect(result).toMatchObject({ skipped: 'NFSE_REFUSED' });
  });

  it('unexpected failure: recorded as AUTO_ISSUE_FAILED and logged as an alert, never thrown', async () => {
    await requested();
    deps.issue!.config = async () => {
      throw new Error('boom');
    };
    await expect(processDirectAutoIssue('c1', 'o1', deps)).resolves.toEqual({ errorCode: 'AUTO_ISSUE_FAILED' });
    expect(read('companies/c1/invoices/auto-o1')!.errorCode).toBe('AUTO_ISSUE_FAILED');
    expect(console.error).toHaveBeenCalled();
  });

  it('an order with nothing to bill (no service value) is skipped silently', async () => {
    await requested();
    seed('companies/c1/orders/o1', { ...read('companies/c1/orders/o1')!, services: [] });
    expect(await processDirectAutoIssue('c1', 'o1', deps)).toEqual({ skipped: 'NO_SERVICES' });
    expect(invoices()).toHaveLength(0);
  });

  it('the sweep takes a request cut short while processing, after the stale time', async () => {
    await requested();
    seed(REQUEST, { ...read(REQUEST)!, status: 'processing', claimedAt: now.toISOString() });
    expect(await processPendingDirectAutoIssues('c1', deps)).toBe(0);
    now = new Date(now.getTime() + STALE_PROCESSING_MS);
    expect(await processPendingDirectAutoIssues('c1', deps)).toBe(1);
    expect(invoices()).toHaveLength(1);
    expect(read(REQUEST)).toMatchObject({ status: 'done', attempts: 1 });
  });
});
