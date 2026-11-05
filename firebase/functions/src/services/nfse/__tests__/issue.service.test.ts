jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { openCertificate } from '../certificate';
import { NfseServiceError } from '../errors';
import {
  cancelDirectInvoice,
  issueDirectInvoice,
  previewDirectInvoice,
  reconcileDirectInvoice,
  type IssueDeps,
} from '../issue.service';
import { gunzipBase64, gzipBase64, type HttpRequest, type HttpResponse } from '../sefin-client';
import { testPki } from './test-certificates';

// Synthetic company, emitter and customers; the government is a recorded fixture.
const pki = testPki();
const cert = openCertificate(pki.pfx(), 'senha-teste', { now: new Date('2026-11-05T12:00:00Z'), trustedRoots: [pki.rootPem] });
const USER = { id: 'u1', name: 'Dono' };
const KEY = (n: number) => `42000002200000000000191${String(n).padStart(27, '0')}`;
const nfseXml = (n: number) =>
  `<NFSe xmlns="http://www.sped.fazenda.gov.br/nfse"><infNFSe Id="NFS${KEY(n)}"><nNFSe>${28 + n}</nNFSe></infNFSe></NFSe>`;

let now: Date;
let calls: HttpRequest[];
let answer: (req: HttpRequest) => HttpResponse | Promise<HttpResponse>;
let saved: Record<string, string>;
let deps: Partial<IssueDeps>;

const json = (status: number, body: unknown): HttpResponse => ({ status, body: JSON.stringify(body) });
const issuedAnswer = (n = 1) => json(201, { chaveAcesso: KEY(n), nfseXmlGZipB64: gzipBase64(nfseXml(n)) });
const sentDps = (i = 0) => gunzipBase64((calls.filter((c) => c.url.endsWith('/nfse'))[i].body as { dpsXmlGZipB64: string }).dpsXmlGZipB64);

function seedCompany(emitter: Record<string, unknown> = {}) {
  seed('companies/c1/settings/payments', { nfseDirectEnabled: true });
  seed('companies/c1/fiscalEmitters/e1', {
    taxId: '00000000000191',
    legalName: 'OFICINA EXEMPLO LTDA',
    regime: 'simples',
    simplesOption: 1,
    cityCode: '4200000',
    cityName: 'Cidade Exemplo',
    municipalRegistration: '12345',
    enabledInCity: true,
    service: { nationalCode: '140101', municipalCode: '001', name: 'Lubrificação, limpeza e revisão', issRate: 2.5, simplesTaxRate: 6 },
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
  });
  seed('companies/c1/orders/o1', {
    number: 182,
    status: 'done',
    customer: { id: 'cu1', name: 'Revenda Exemplo' },
    services: [{ service: { id: 's1', name: 'Conserto/Pintura de Capô' }, description: 'Capo', value: 300 }],
    products: [{ product: { id: 'p1', name: 'Tinta' }, value: 100, quantity: 1 }],
    discount: 40,
  });
  seed('companies/c1/orders/o2', {
    number: 190,
    status: 'done',
    customer: { id: 'cu1', name: 'Revenda Exemplo' },
    services: [{ service: { id: 's2', name: 'Troca de óleo' }, value: 120 }],
  });
}

beforeEach(() => {
  resetFakeDb();
  seedCompany();
  now = new Date('2026-11-05T13:00:00Z');
  calls = [];
  saved = {};
  answer = () => issuedAnswer(1);
  deps = {
    now: () => now,
    loadCertificate: async () => ({ keyPem: cert.keyPem, chainPem: cert.chainPem, taxId: cert.taxId, notAfter: cert.notAfter.toISOString() }),
    config: async () => ({ environment: 'test', layoutByEnvironment: {}, meiAnnualLimit: 81000, appVersion: 'PraticOS-1.104.0' }),
    transport: async (req) => {
      calls.push(req);
      return answer(req);
    },
    saveFile: async (path, contents) => {
      saved[path] = contents;
    },
  };
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

async function codeOf(promise: Promise<unknown>) {
  try {
    await promise;
  } catch (error) {
    return error as NfseServiceError;
  }
  throw new Error('expected an error');
}

describe('issueDirectInvoice', () => {
  it('issues: number from the counter, DPS with the order data, XML saved, emitter and customer updated', async () => {
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);

    expect(invoice).toMatchObject({ status: 'authorized', number: '29', accessKey: KEY(1), provider: 'direct', source: 'praticos' });
    const stored = read(`companies/c1/invoices/${invoice.id}`)!;
    expect(stored).toMatchObject({
      status: 'authorized',
      value: 270,
      dps: { series: '10', number: 1 },
      emitter: { id: 'e1', taxId: '00000000000191', regime: 'simples' },
      recipient: { customerId: 'cu1', taxId: '00000000000272', legalName: 'REVENDA EXEMPLO LTDA' },
      xmlPath: `tenants/c1/invoices/${invoice.id}/nfse.xml`,
      serviceDescription: 'CONSERTO/PINTURA DE CAPÔ',
      observations: 'OS 182 · Emitida pelo PraticOS (praticos.app)',
      effectiveDate: '2026-11-05',
    });
    expect(saved[`tenants/c1/invoices/${invoice.id}/nfse.xml`]).toBe(nfseXml(1));
    expect(read('companies/c1/private/nfse/emitters/e1')!.nextDpsNumber).toBe(2);
    expect(read('companies/c1/private/nfse/orders/o1')!.invoiceId).toBe(invoice.id);
    expect(read('companies/c1/customers/cu1')!.lastEmitterId).toBe('e1');
    expect(read('companies/c1/fiscalEmitters/e1')!.totals).toEqual({ year: 2026, yearValue: 270, month: 11, monthValue: 270 });

    const dps = sentDps();
    expect(dps).toContain('<nDPS>1</nDPS>');
    expect(dps).toContain('<vServ>270.00</vServ>');
    expect(dps).toContain('<xDescServ>CONSERTO/PINTURA DE CAPÔ</xDescServ>');
    expect(dps).toContain('<xInfComp>OS 182 · Emitida pelo PraticOS (praticos.app)</xInfComp>');
    expect(dps).toContain('<dhEmi>2026-11-05T09:59:55-03:00</dhEmi>');
    expect(dps).toContain('<toma><CNPJ>00000000000272</CNPJ>');
    expect(dps).toContain('<Signature');
    expect(calls[0]).toMatchObject({ keyPem: cert.keyPem, chainPem: cert.chainPem });
  });

  it('numbers never repeat: the next nota takes the next number', async () => {
    await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    answer = () => issuedAnswer(2);
    const second = await issueDirectInvoice('c1', { orderIds: ['o2'] }, USER, {}, deps);
    expect(read(`companies/c1/invoices/${second.id}`)!.dps).toMatchObject({ number: 2 });
    expect(sentDps(1)).toContain('<nDPS>2</nDPS>');
  });

  it('several orders: one line per order and both numbers in the complementary info', async () => {
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o2', 'o1'] }, USER, {}, deps);
    expect(read(`companies/c1/invoices/${invoice.id}`)).toMatchObject({
      value: 390,
      serviceDescription: 'OS 182: CONSERTO/PINTURA DE CAPÔ\nOS 190: TROCA DE ÓLEO',
      observations: 'OS 182, 190 · Emitida pelo PraticOS (praticos.app)',
    });
  });

  it('refusal: error with the code, orders free again, the number is not reused', async () => {
    answer = () => json(400, { erros: [{ Codigo: 'E0312', Descricao: 'Código de tributação não administrado pelo município' }] });
    const error = await codeOf(issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps));
    expect(error.code).toBe('NFSE_REFUSED');
    expect((error.details!.refusal as { group: string }).group).toBe('emitterSetup');

    const invoiceId = error.details!.invoiceId as string;
    expect(read(`companies/c1/invoices/${invoiceId}`)).toMatchObject({ status: 'error', errorCode: 'E0312', dps: { number: 1 } });
    expect(read('companies/c1/private/nfse/orders/o1')).toBeUndefined();

    answer = () => issuedAnswer(2);
    const retry = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    expect(read(`companies/c1/invoices/${retry.id}`)!.dps).toMatchObject({ number: 2 });
  });

  it('no clear answer: kept creating and locked; the reconcile sends the SAME DPS again', async () => {
    answer = () => Promise.reject(new Error('timeout'));
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    expect(invoice.status).toBe('creating');
    expect(read('companies/c1/private/nfse/orders/o1')!.invoiceId).toBe(invoice.id);
    const dpsId = (read(`companies/c1/invoices/${invoice.id}`)!.dps as { id: string }).id;

    // Too early: nothing happens.
    expect((await reconcileDirectInvoice('c1', invoice.id, deps))!.status).toBe('creating');
    expect(calls).toHaveLength(1);

    now = new Date('2026-11-05T13:05:00Z');
    answer = (req) => (req.method === 'GET' ? json(404, {}) : issuedAnswer(1));
    const settled = await reconcileDirectInvoice('c1', invoice.id, deps);
    expect(settled!.status).toBe('authorized');
    expect(calls.map((c) => `${c.method} ${c.url.split('SefinNacional/')[1]}`)).toEqual(['POST nfse', `GET dps/${dpsId}`, 'POST nfse']);
    expect(sentDps(1)).toContain(`Id="${dpsId}"`);
    expect(read('companies/c1/private/nfse/emitters/e1')!.nextDpsNumber).toBe(2);
  });

  it('reconcile finds the DPS already became a nota: saves it without sending again', async () => {
    answer = () => Promise.reject(new Error('socket hang up'));
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    now = new Date('2026-11-05T13:05:00Z');
    answer = (req) =>
      req.url.includes('/dps/') ? json(200, { chaveAcesso: KEY(1) }) : json(200, { nfseXmlGZipB64: gzipBase64(nfseXml(1)) });
    const settled = await reconcileDirectInvoice('c1', invoice.id, deps);
    expect(settled).toMatchObject({ status: 'authorized', accessKey: KEY(1), number: '29' });
    expect(calls.filter((c) => c.method === 'POST')).toHaveLength(1);
  });

  it('an order with an active nota cannot get another one', async () => {
    await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    expect((await codeOf(issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps))).code).toBe('ORDER_HAS_INVOICE');
  });

  it('"Nota fiscal para": the branch\'s nota goes to the customer that holds the CNPJ', async () => {
    seed('companies/c1/customers/cu2', { name: 'Loja Centro', invoiceRecipient: { id: 'cu1', name: 'Revenda Exemplo' } });
    seed('companies/c1/orders/o3', {
      number: 200, status: 'done', customer: { id: 'cu2', name: 'Loja Centro' }, services: [{ service: { name: 'Revisão' }, value: 80 }],
    });
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o3'] }, USER, {}, deps);
    expect(read(`companies/c1/invoices/${invoice.id}`)!.recipient).toMatchObject({ customerId: 'cu1', taxId: '00000000000272' });
    // The emitter is remembered for the order's customer (the branch).
    expect(read('companies/c1/customers/cu2')!.lastEmitterId).toBe('e1');
  });

  it('recipient without CPF/CNPJ is refused before anything; typed data fills only empty fields', async () => {
    seed('companies/c1/customers/cu1', { name: 'Fulano', email: 'fulano@example.com' });
    expect((await codeOf(issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps))).code).toBe('RECIPIENT_TAX_ID_REQUIRED');
    expect(list('companies/c1/invoices')).toEqual([]);

    await issueDirectInvoice('c1', { orderIds: ['o1'], recipient: { taxId: '123.456.789-09', email: 'outro@example.com' } }, USER, {}, deps);
    expect(read('companies/c1/customers/cu1')).toMatchObject({ taxId: '12345678909', email: 'fulano@example.com' });
    expect(read('companies/c1/customers/cu1')!.invoiceEmail).toBeUndefined();
    expect(sentDps()).toContain('<toma><CPF>12345678909</CPF><xNome>Fulano</xNome><email>fulano@example.com</email></toma>');
  });

  it.each([
    [{ certificate: { status: 'active', notAfter: '2026-10-01T00:00:00.000Z' } }, 'CERT_EXPIRED'],
    [{ certificate: { status: 'deleted' } }, 'EMITTER_NOT_READY'],
    [{ enabledInCity: false }, 'EMITTER_NOT_READY'],
    [{ service: null }, 'EMITTER_NOT_READY'],
  ])('emitter that cannot issue (%p) → %s, nothing sent', async (emitter, code) => {
    seedCompany(emitter);
    expect((await codeOf(issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps))).code).toBe(code);
    expect(calls).toEqual([]);
  });

  it('company outside the pilot', async () => {
    seed('companies/c1/settings/payments', { nfseDirectEnabled: false });
    expect((await codeOf(issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps))).code).toBe('NFSE_DIRECT_NOT_ENABLED');
  });

  it('MEI emitter: the DPS goes without regApTribSN and tribFed', async () => {
    seedCompany({ regime: 'mei', municipalRegistration: null, simplesOption: null });
    await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    const dps = sentDps();
    expect(dps).toContain('<opSimpNac>2</opSimpNac>');
    expect(dps).not.toContain('regApTribSN');
    expect(dps).not.toContain('tribFed');
    expect(dps).toContain('<indTotTrib>0</indTotTrib>');
  });

  it('emitter marked: asked > last used for the customer > default > the only one', async () => {
    seed('companies/c1/fiscalEmitters/e2', { ...read('companies/c1/fiscalEmitters/e1')!, taxId: '11222333000181', regime: 'mei' });
    seed('companies/c1/settings/nfse', { provider: 'direct', defaultEmitterId: 'e2' });
    const preview = await previewDirectInvoice('c1', { orderIds: ['o1'] }, deps);
    expect(preview.emitter.id).toBe('e2');
    seed('companies/c1/customers/cu1', { ...read('companies/c1/customers/cu1')!, lastEmitterId: 'e1' });
    expect((await previewDirectInvoice('c1', { orderIds: ['o1'] }, deps)).emitter.id).toBe('e1');
    expect((await previewDirectInvoice('c1', { orderIds: ['o1'], emitterId: 'e2' }, deps)).emitter.id).toBe('e2');
  });
});

describe('previewDirectInvoice', () => {
  it('shows value, description, recipient, what is missing and the MEI warning', async () => {
    seedCompany({ regime: 'mei', totals: { year: 2026, yearValue: 64900, month: 11, monthValue: 100 } });
    seed('companies/c1/customers/cu1', { name: 'Revenda', taxId: '00000000000272' });
    const preview = await previewDirectInvoice('c1', { orderIds: ['o1'] }, deps);
    expect(preview).toMatchObject({
      value: 270,
      hasProducts: true,
      description: 'CONSERTO/PINTURA DE CAPÔ',
      complementaryInfo: 'OS 182 · Emitida pelo PraticOS (praticos.app)',
      recipient: { customerId: 'cu1', taxId: '00000000000272', viaInvoiceRecipient: false },
      missing: ['address', 'email'],
      meiWarning: 'near',
    });
    expect(preview.emitters).toHaveLength(1);
  });
});

describe('cancelDirectInvoice', () => {
  it('registers e101101, cancels, frees the order and the year total', async () => {
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    answer = () => json(201, { eventoXmlGZipB64: gzipBase64('<evento/>') });
    const canceled = await cancelDirectInvoice('c1', invoice.id, 'issueError', USER, deps);
    expect(canceled.status).toBe('canceled');
    expect(read(`companies/c1/invoices/${invoice.id}`)).toMatchObject({ status: 'canceled', cancelReason: 'issueError' });
    expect(read('companies/c1/private/nfse/orders/o1')).toBeUndefined();
    expect((read('companies/c1/fiscalEmitters/e1')!.totals as { yearValue: number }).yearValue).toBe(0);
    const event = gunzipBase64((calls[1].body as { pedidoRegistroEventoXmlGZipB64: string }).pedidoRegistroEventoXmlGZipB64);
    expect(event).toContain(`<chNFSe>${KEY(1)}</chNFSe>`);
    expect(event).toContain('<cMotivo>1</cMotivo>');
    expect(calls[1].url).toContain(`/nfse/${KEY(1)}/eventos`);
  });

  it('refused by the city: stays valid, the app points to the portal', async () => {
    const invoice = await issueDirectInvoice('c1', { orderIds: ['o1'] }, USER, {}, deps);
    answer = () => json(400, { erro: { codigo: 'E0840', descricao: 'Prazo para cancelamento expirado' } });
    const error = await codeOf(cancelDirectInvoice('c1', invoice.id, 'serviceNotProvided', USER, deps));
    expect(error.code).toBe('CANCEL_REFUSED');
    expect(error.details!.usePortal).toBe(true);
    expect(read(`companies/c1/invoices/${invoice.id}`)!.status).toBe('cancellationDenied');
    expect(read('companies/c1/private/nfse/orders/o1')!.invoiceId).toBe(invoice.id);
  });

  it('only issued direct notas', async () => {
    seed('companies/c1/invoices/asaas1', { status: 'authorized', orderIds: [] });
    expect((await codeOf(cancelDirectInvoice('c1', 'asaas1', 'issueError', USER, deps))).code).toBe('INVOICE_NOT_CANCELABLE');
    expect((await codeOf(cancelDirectInvoice('c1', 'missing', 'issueError', USER, deps))).code).toBe('INVOICE_NOT_FOUND');
  });
});
