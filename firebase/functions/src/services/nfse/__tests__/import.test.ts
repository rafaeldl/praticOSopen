jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { parseDfePage, parseEvent, parseNfse } from '../adn-reader';
import { NfseServiceError } from '../errors';
import {
  buildProposal,
  chooseDpsSeries,
  learnDescriptionStyle,
  rankOrdersForNota,
  sameName,
  similarName,
  uniqueLinks,
  type ImportNota,
  type ImportOrder,
} from '../import-proposal';
import {
  applyImport,
  continueImport,
  externalInvoiceId,
  linkCandidates,
  linkInvoiceToOrder,
  startImport,
  syncCompanyMailboxes,
  undoImport,
  unlinkInvoice,
  type ImportDeps,
} from '../import.service';
import type { HttpRequest } from '../sefin-client';
import { accessKeyOf, cancelEventXml, dfeAnswer, EMITTER_TAX_ID, nfseXml, type MailboxItem } from './import-fixture';

// Invented companies only: REVENDA EXEMPLO (stores Loja Norte/Loja Sul), AUTO PECAS MODELO, a CPF.
const USER = { id: 'u1', name: 'Dono' };
const REVENDA = '00000000000272';
const MODELO = '00000000000353';
const NOVA = '00000000000434';
const CPF = '00000000191';

// ----------------------------------------------------------------------------
// Reading the XML
// ----------------------------------------------------------------------------

describe('adn-reader', () => {
  it('reads an issued nota: emitter, recipient, DPS, service and value', () => {
    const nota = parseNfse(nfseXml({ n: 7, value: 250.5, date: '2026-10-01', recipient: { taxId: REVENDA, name: 'REVENDA EXEMPLO LTDA', email: 'nota@example.com' } }))!;
    expect(nota).toMatchObject({
      accessKey: accessKeyOf(7),
      number: '7',
      competenceDate: '2026-10-01',
      regime: 'simples',
      simplesOption: 1,
      simplesTaxRate: 8,
      series: '900',
      dpsNumber: 7,
      value: 250.5,
      emitter: { taxId: EMITTER_TAX_ID, municipalRegistration: '12345', address: { cityCode: '4200000', postalCode: '88000000' } },
      recipient: { taxId: REVENDA, name: 'REVENDA EXEMPLO LTDA', email: 'nota@example.com', address: { street: 'Rua Exemplo', number: '10', cityCode: '4200000' } },
      service: { nationalCode: '140101', description: 'TROCA DE OLEO - FILTRO', name: 'Lubrificação, limpeza e revisão de máquinas' },
    });
    expect(parseNfse('<other/>')).toBeNull();
  });

  it('reads a MEI nota and a CPF recipient', () => {
    const nota = parseNfse(nfseXml({ n: 1, value: 10, date: '2026-10-01', simplesNationalOption: '2', recipient: { taxId: CPF, name: 'Pessoa Exemplo' } }))!;
    expect(nota.regime).toBe('mei');
    expect(nota.simplesOption).toBeNull();
    expect(nota.recipient?.taxId).toBe(CPF);
  });

  it('reads a cancel event', () => {
    expect(parseEvent(cancelEventXml(7))).toEqual({ accessKey: accessKeyOf(7), code: 'e101101', cancels: true, processedAt: '2026-10-02T10:00:00-03:00' });
  });

  it('reads a page: sorted by NSU, done under 50, empty mailbox (404 → null) done', () => {
    const items: MailboxItem[] = [2, 1].map((nsu) => ({ nsu, type: 'NFSE', xml: nfseXml({ n: nsu, value: 1, date: '2026-10-01' }) }));
    const page = parseDfePage(JSON.parse(dfeAnswer(items, 0).body));
    expect(page.documents.map((d) => [d.nsu, d.kind])).toEqual([[1, 'nfse'], [2, 'nfse']]);
    expect(page.done).toBe(true);
    expect(parseDfePage(null)).toEqual({ documents: [], done: true });
  });
});

// ----------------------------------------------------------------------------
// Proposal (pure)
// ----------------------------------------------------------------------------

function nota(id: string, over: Partial<ImportNota> = {}): ImportNota {
  return {
    invoiceId: id,
    canceled: false,
    date: '2026-10-01',
    value: 100,
    recipient: { taxId: REVENDA, legalName: 'REVENDA EXEMPLO LTDA', address: { street: 'Rua Exemplo', cityCode: '4200000' }, email: null },
    series: '900',
    description: 'TROCA DE OLEO - FILTRO',
    service: { nationalCode: '140101', municipalCode: null, nbs: null, name: 'Lubrificação', issRate: null },
    regime: 'simples',
    simplesOption: 1,
    simplesTaxRate: 8,
    municipalRegistration: '12345',
    cityCode: '4200000',
    cityName: 'Cidade Exemplo',
    linked: false,
    ...over,
  };
}

function order(id: string, over: Partial<ImportOrder> = {}): ImportOrder {
  return { id, number: Number(id.replace(/\D/g, '')) || null, customerId: 'cu1', customerName: 'Cliente', value: 100, date: '2026-10-01', done: true, locked: false, ...over };
}

describe('import-proposal', () => {
  it('names: ignores LTDA/ME and accents; similar shares a meaningful word', () => {
    expect(sameName('Revenda Exemplo', 'REVENDA EXEMPLO LTDA')).toBe(true);
    expect(sameName('Auto Peças Modelo ME', 'AUTO PECAS MODELO')).toBe(true);
    expect(sameName('Revenda', 'REVENDA EXEMPLO LTDA')).toBe(false);
    expect(similarName('Loja Exemplo Norte', 'REVENDA EXEMPLO LTDA')).toBe(true);
    expect(similarName('Auto Center', 'AUTO PECAS MODELO')).toBe(false);
  });

  it('series: 10 unless used; never continues another issuer', () => {
    expect(chooseDpsSeries(['900', '70000', '1'])).toBe('10');
    expect(chooseDpsSeries(['10', '00011', '900'])).toBe('12');
  });

  it('description style: uppercase and the separator most used', () => {
    expect(learnDescriptionStyle(['TROCA DE OLEO - FILTRO', 'PINTURA - CAPO', 'ALINHAMENTO'])).toEqual({ uppercase: true, separator: ' - ' });
    expect(learnDescriptionStyle(['Troca de óleo', 'Revisão'])).toEqual({ uppercase: false, separator: ', ' });
    expect(learnDescriptionStyle([])).toBeNull();
  });

  it('links a nota only with exactly one order of its value nearby, wanted by no other nota', () => {
    const orders = [order('o1', { value: 100 }), order('o2', { value: 200 }), order('o3', { value: 200, date: '2026-10-03' }), order('o4', { value: 300, date: '2026-12-01' })];
    const links = uniqueLinks([nota('a', { value: 100 }), nota('b', { value: 200 }), nota('c', { value: 300 })], orders);
    expect([...links.entries()].map(([k, o]) => [k, o.id])).toEqual([['a', 'o1']]);
    // Two notas of the same value want the same order: neither links.
    expect(uniqueLinks([nota('a'), nota('b')], [order('o1')]).size).toBe(0);
    // Orders that already have a nota are out.
    expect(uniqueLinks([nota('a')], [order('o1', { locked: true })]).size).toBe(0);
  });

  it('matches by CNPJ (complete, only empty fields), by name + order, and asks or creates', () => {
    const proposal = buildProposal({
      emitter: { taxId: EMITTER_TAX_ID, legalName: 'OFICINA EXEMPLO LTDA' },
      notas: [
        nota('n1', { value: 100, recipient: { taxId: MODELO, legalName: 'AUTO PECAS MODELO LTDA', address: { street: 'Rua B' }, email: 'b@example.com' } }),
        nota('n2', { value: 150, date: '2026-10-05' }),
        nota('n3', { value: 999, recipient: { taxId: NOVA, legalName: 'NOVA EMPRESA EXEMPLO', address: null, email: null } }),
        nota('n4', { value: 50, recipient: { taxId: CPF, legalName: 'Fulano Exemplo', address: null, email: null } }),
      ],
      customers: [
        { id: 'cm', name: 'Auto Peças Modelo', taxId: MODELO, legalName: 'Typed by the owner', email: 'own@example.com' },
        { id: 'cr', name: 'Revenda Exemplo' },
        { id: 'cf', name: 'Fulano Exemplo' },
      ],
      orders: [order('o1', { customerId: 'cm', value: 100 }), order('o2', { customerId: 'cr', value: 150, date: '2026-10-06' })],
    });
    const byKey = Object.fromEntries(proposal.groups.map((g) => [g.key, g]));
    expect(byKey[MODELO]).toMatchObject({ action: 'complete', reason: 'taxId', customerId: 'cm', fills: ['fiscalAddress'] });
    expect(byKey[MODELO].links.map((l) => l.orderId)).toEqual(['o1']);
    expect(byKey[REVENDA]).toMatchObject({ action: 'complete', reason: 'nameAndOrders', customerId: 'cr', fills: ['taxId', 'legalName', 'fiscalAddress'] });
    expect(byKey[NOVA]).toMatchObject({ action: 'create', customerId: null });
    expect(byKey[CPF]).toMatchObject({ action: 'ask', reason: 'name', customerId: 'cf' });
    expect(proposal.counts).toMatchObject({ notas: 4, customers: 4, newCustomers: 1, completedCustomers: 2, ask: 1, linked: 2, historyOnly: 2 });
    expect(proposal.emitter.fill).toMatchObject({
      regime: 'simples',
      simplesOption: 1,
      cityCode: '4200000',
      municipalRegistration: '12345',
      dpsSeries: '10',
      descriptionStyle: { uppercase: true, separator: ' - ' },
      service: { nationalCode: '140101', simplesTaxRate: 8 },
    });
  });

  it('stores billed on one CNPJ: the CNPJ goes to the most used, the others point to it', () => {
    const notas = [1, 2, 3, 4, 5, 6].map((i) => nota(`n${i}`, { value: 100 + i, date: `2026-10-0${i}` }));
    const orders = [
      ...[1, 2, 3, 4].map((i) => order(`o${i}`, { customerId: 'norte', customerName: 'Loja Exemplo Norte', value: 100 + i, date: `2026-10-0${i}` })),
      ...[5, 6].map((i) => order(`o${i}`, { customerId: 'sul', customerName: 'Loja Exemplo Sul', value: 100 + i, date: `2026-10-0${i}` })),
    ];
    const proposal = buildProposal({
      emitter: { taxId: EMITTER_TAX_ID, dpsSeries: '10', service: { nationalCode: '1', name: 'x', issRate: 2 } },
      notas,
      customers: [
        { id: 'norte', name: 'Loja Exemplo Norte' },
        { id: 'sul', name: 'Loja Exemplo Sul' },
      ],
      orders,
    });
    const group = proposal.groups[0];
    // 4 orders and a shared word: sure without asking.
    expect(group).toMatchObject({ action: 'complete', reason: 'orders', customerId: 'norte', stores: [{ customerId: 'sul', orders: 2 }] });
    expect(group.links).toHaveLength(6);
    // Only empty fields of the emitter are proposed.
    expect(proposal.emitter.fill.dpsSeries).toBeUndefined();
    expect(proposal.emitter.fill.service).toBeUndefined();
    // A nota in every done order since the first nota: suggested, never turned on.
    expect(proposal.autoIssue).toEqual([{ customerId: 'norte', customerName: 'Loja Exemplo Norte', orders: 6, withNota: 6 }]);
  });

  it('few order matches with another name are asked', () => {
    const proposal = buildProposal({
      emitter: { taxId: EMITTER_TAX_ID },
      notas: [nota('n1')],
      customers: [{ id: 'x', name: 'Outro Nome' }],
      orders: [order('o1', { customerId: 'x' })],
    });
    expect(proposal.groups[0]).toMatchObject({ action: 'ask', reason: 'orders', customerId: 'x' });
    expect(proposal.counts.linked).toBe(0);
  });

  it('ranks orders for "Ligar a uma OS": same customer, then closest value and date; with a nota last', () => {
    const ranked = rankOrdersForNota({ value: 100, date: '2026-10-01', customerIds: ['cu1'] }, [
      order('far', { value: 500, date: '2026-12-01' }),
      order('locked', { locked: true }),
      order('other', { customerId: 'cu2' }),
      order('close', { value: 101 }),
      order('exact'),
    ]);
    expect(ranked.map((o) => o.id)).toEqual(['exact', 'close', 'far', 'other', 'locked']);
  });
});

// ----------------------------------------------------------------------------
// Service: read, propose, apply, undo, link, sync
// ----------------------------------------------------------------------------

let mailbox: MailboxItem[];
let calls: HttpRequest[];
let saved: Record<string, string>;
let clock: number;
let deps: Partial<ImportDeps>;

function seedCompany() {
  seed('companies/c1', { name: 'Oficina Exemplo' });
  seed('companies/c1/settings/payments', { nfseDirectEnabled: true });
  seed('companies/c1/fiscalEmitters/e1', {
    taxId: EMITTER_TAX_ID,
    legalName: 'OFICINA EXEMPLO LTDA',
    enabledInCity: false,
    certificate: { holderName: 'OFICINA EXEMPLO LTDA', notAfter: '2027-03-12T00:00:00.000Z', status: 'active' },
  });
  // Revenda: the owner typed the name only. Its two stores have orders billed on its CNPJ.
  seed('companies/c1/customers/norte', { name: 'Loja Exemplo Norte', email: 'norte@example.com' });
  seed('companies/c1/customers/sul', { name: 'Loja Exemplo Sul' });
  seed('companies/c1/customers/modelo', { name: 'Auto Peças Modelo', taxId: MODELO, legalName: 'Nome que o dono digitou' });
  for (let i = 1; i <= 4; i++) {
    seed(`companies/c1/orders/o${i}`, {
      number: 100 + i,
      status: 'done',
      customer: { id: 'norte', name: 'Loja Exemplo Norte' },
      services: [{ service: { id: 's', name: 'Troca de óleo' }, value: 100 + i }],
      createdAt: `2026-09-2${i}T12:00:00.000Z`,
      completedAt: `2026-10-0${i}T15:00:00.000Z`,
    });
  }
  for (const i of [5, 6]) {
    seed(`companies/c1/orders/o${i}`, {
      number: 100 + i,
      status: 'done',
      customer: { id: 'sul', name: 'Loja Exemplo Sul' },
      services: [{ service: { id: 's', name: 'Troca de óleo' }, value: 100 + i }],
      createdAt: `2026-10-0${i}T12:00:00.000Z`,
    });
  }
  seed('companies/c1/orders/o9', {
    number: 109,
    status: 'done',
    customer: { id: 'modelo', name: 'Auto Peças Modelo' },
    services: [{ service: { id: 's', name: 'Pintura' }, value: 80 }],
    createdAt: '2026-10-09T12:00:00.000Z',
  });

  mailbox = [];
  let nsu = 0;
  const push = (type: MailboxItem['type'], xml: string) => mailbox.push({ nsu: ++nsu, type, xml });
  for (let i = 1; i <= 6; i++) {
    push('NFSE', nfseXml({ n: i, value: 100 + i, date: `2026-10-0${i}`, recipient: { taxId: REVENDA, name: 'REVENDA EXEMPLO LTDA', email: 'fiscal@example.com' } }));
  }
  push('NFSE', nfseXml({ n: 9, value: 80, date: '2026-10-09', recipient: { taxId: MODELO, name: 'AUTO PECAS MODELO LTDA' } }));
  push('NFSE', nfseXml({ n: 10, value: 55, date: '2026-10-10', recipient: { taxId: NOVA, name: 'NOVA EMPRESA EXEMPLO' } }));
  push('NFSE', nfseXml({ n: 11, value: 70, date: '2026-10-11', recipient: { taxId: NOVA, name: 'NOVA EMPRESA EXEMPLO' } }));
  push('EVENTO', cancelEventXml(11));
  // A nota received from a supplier (the emitter is the tomador).
  push('NFSE', nfseXml({ n: 1, issuerTaxId: '00000000000515', issuerName: 'GUINCHO EXEMPLO', value: 300, date: '2026-10-12', recipient: { taxId: EMITTER_TAX_ID, name: 'OFICINA EXEMPLO LTDA' } }));
  // Old notas of other issuers fill the first pages (more than 50 documents in all).
  for (let i = 0; i < 45; i++) push('NFSE', nfseXml({ n: 500 + i, issuerTaxId: '00000000000607', value: 1, date: '2026-10-13', recipient: { taxId: '00000000000698', name: 'TERCEIRO' } }));
}

beforeEach(() => {
  resetFakeDb();
  seedCompany();
  calls = [];
  saved = {};
  clock = 0;
  deps = {
    now: () => new Date('2026-11-05T13:00:00Z'),
    clock: () => clock,
    budgetMs: 1000,
    loadCertificate: async () => ({ keyPem: 'k', chainPem: 'c', taxId: EMITTER_TAX_ID, notAfter: '2027-03-12T00:00:00.000Z' }),
    config: async () => ({ environment: 'production', layoutByEnvironment: {}, meiAnnualLimit: 81000, appVersion: 'PraticOS-1' }),
    transport: async (req) => {
      calls.push(req);
      const nsu = Number(req.url.match(/DFe\/(\d+)/)?.[1] ?? 0);
      return dfeAnswer(mailbox, nsu);
    },
    saveFile: async (path, contents) => {
      saved[path] = contents;
    },
    lookupCnpj: async () => null,
    lookupCnc: async () => ({ municipalRegistration: '12345', enabledInCity: true, legalName: null }),
    cityUsesNationalIssuer: async () => true,
    issRate: async () => 2.5,
  };
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

async function errorOf(promise: Promise<unknown>) {
  try {
    await promise;
  } catch (error) {
    return (error as NfseServiceError).code;
  }
  throw new Error('expected an error');
}

async function proposed() {
  const batch = await startImport('c1', 'e1', USER, deps);
  expect(batch.status).toBe('proposed');
  return batch;
}

describe('import: reading', () => {
  it('reads every page from NSU 0, creates the issued notas, applies the cancel, records the received', async () => {
    const batch = await proposed();
    expect(calls[0].url).toBe(`https://adn.nfse.gov.br/contribuintes/DFe/0?cnpjConsulta=${EMITTER_TAX_ID}&lote=true`);
    expect(calls.length).toBeGreaterThanOrEqual(2);
    expect(batch.read.documents).toBe(mailbox.length);

    const invoices = list('companies/c1/invoices');
    expect(invoices).toHaveLength(9);
    const first = read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(1))}`)!;
    expect(first).toMatchObject({
      status: 'authorized',
      provider: 'direct',
      source: 'external',
      emitter: { id: 'e1', taxId: EMITTER_TAX_ID },
      recipient: { taxId: REVENDA, legalName: 'REVENDA EXEMPLO LTDA', customerId: null },
      customer: null,
      orderIds: [],
      value: 101,
      effectiveDate: '2026-10-01',
      number: '1',
      dps: { series: '900', number: 1 },
      importBatchId: batch.id,
      xmlPath: `tenants/c1/invoices/${externalInvoiceId(accessKeyOf(1))}/nfse.xml`,
    });
    expect(saved[first.xmlPath as string]).toContain('<nNFSe>1</nNFSe>');
    expect(read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(11))}`)).toMatchObject({ status: 'canceled', canceledOutside: true });

    const received = list('companies/c1/private/nfse/emitters/e1/received');
    expect(received).toHaveLength(1);
    expect(received[0].data).toMatchObject({ providerTaxId: '00000000000515', providerName: 'GUINCHO EXEMPLO', value: 300, status: 'issued' });
    expect(read('companies/c1/private/nfse/emitters/e1')).toMatchObject({ lastNsu: mailbox.length });
    // Totals of the year from the imported notas (canceled out).
    expect(read('companies/c1/fiscalEmitters/e1')).toMatchObject({ totals: { year: 2026, yearValue: 101 + 102 + 103 + 104 + 105 + 106 + 80 + 55 } });
  });

  it('stops at the time budget and continues where it stopped', async () => {
    deps.transport = async (req) => {
      calls.push(req);
      clock += 2000;
      return dfeAnswer(mailbox, Number(req.url.match(/DFe\/(\d+)/)?.[1]));
    };
    const first = await startImport('c1', 'e1', USER, deps);
    expect(first.status).toBe('reading');
    expect(first.read.documents).toBe(50);
    const second = await continueImport('c1', first.id, deps);
    expect(second.status).toBe('proposed');
    expect(second.read.documents).toBe(mailbox.length);
    // The second call asked from the last NSU kept (and dropped the repeated one).
    expect(calls[1].url).toContain('/DFe/50?');
    expect(list('companies/c1/invoices')).toHaveLength(9);
  });

  it('a nota the PraticOS issued is not created again', async () => {
    seed('companies/c1/invoices/mine', { status: 'authorized', provider: 'direct', source: 'praticos', accessKey: accessKeyOf(9), emitter: { id: 'e1' }, orderIds: ['o9'] });
    await proposed();
    expect(read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(9))}`)).toBeUndefined();
  });

  it('needs the flag and the certificate', async () => {
    seed('companies/c1/settings/payments', { nfseDirectEnabled: false });
    expect(await errorOf(startImport('c1', 'e1', USER, deps))).toBe('NFSE_DIRECT_NOT_ENABLED');
    seed('companies/c1/settings/payments', { nfseDirectEnabled: true });
    seed('companies/c1/fiscalEmitters/e1', { taxId: EMITTER_TAX_ID, certificate: { status: 'deleted' } });
    expect(await errorOf(startImport('c1', 'e1', USER, deps))).toBe('CERT_NOT_FOUND');
  });

  it('the proposal: emitter data, stores, customers and the "Emitir sozinha" suggestion', async () => {
    const batch = await proposed();
    const p = batch.proposal!;
    expect(batch.enabledInCity).toBe(true);
    expect(p.emitter.fill).toMatchObject({ regime: 'simples', cityCode: '4200000', municipalRegistration: '12345', dpsSeries: '10', descriptionStyle: { uppercase: true, separator: ' - ' } });
    expect(p.emitter.fill.service).toMatchObject({ nationalCode: '140101', issRate: 2.5, simplesTaxRate: 8 });
    const byKey = Object.fromEntries(p.groups.map((g) => [g.key, g]));
    expect(byKey[REVENDA]).toMatchObject({ action: 'complete', customerId: 'norte', stores: [{ customerId: 'sul' }] });
    expect(byKey[MODELO]).toMatchObject({ action: 'complete', customerId: 'modelo', fills: ['fiscalAddress'] });
    expect(byKey[NOVA]).toMatchObject({ action: 'create', notas: 2 });
    expect(p.counts).toMatchObject({ notas: 9, canceled: 1, linked: 7, historyOnly: 2 });
    expect(p.autoIssue.map((s) => s.customerId)).toEqual(['norte']);
  });
});

describe('import: apply and undo', () => {
  it('fills only the empty, creates the new, points the store, links and locks the orders', async () => {
    const batch = await proposed();
    // The owner typed an e-mail on Loja Norte meanwhile: kept.
    const applied = await applyImport('c1', batch.id, { autoIssueCustomerIds: ['norte', 'not-suggested'] }, USER, deps);
    expect(applied.status).toBe('applied');
    expect(applied.expiresAt).toBe('2026-12-05T13:00:00.000Z');

    expect(read('companies/c1/customers/norte')).toMatchObject({
      name: 'Loja Exemplo Norte',
      email: 'norte@example.com',
      taxId: REVENDA,
      legalName: 'REVENDA EXEMPLO LTDA',
      fiscalAddress: { street: 'Rua Exemplo', cityCode: '4200000' },
      autoIssueInvoice: true,
    });
    // The e-mail of the nota does not replace the customer's own.
    expect(read('companies/c1/customers/norte')!.invoiceEmail).toBeUndefined();
    expect(read('companies/c1/customers/sul')).toMatchObject({ invoiceRecipient: { id: 'norte', name: 'Loja Exemplo Norte' } });
    expect(read('companies/c1/customers/sul')!.taxId).toBeUndefined();
    expect(read('companies/c1/customers/modelo')).toMatchObject({ taxId: MODELO, legalName: 'Nome que o dono digitou' });
    expect(read('companies/c1/customers/not-suggested')).toBeUndefined();

    const created = list('companies/c1/customers').filter((c) => c.data.importBatchId === batch.id);
    expect(created).toHaveLength(1);
    expect(created[0].data).toMatchObject({ name: 'NOVA EMPRESA EXEMPLO', taxId: NOVA, legalName: 'NOVA EMPRESA EXEMPLO', company: { id: 'c1', name: 'Oficina Exemplo' } });

    const n5 = read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(5))}`)!;
    expect(n5).toMatchObject({ orderIds: ['o5'], orders: [{ orderId: 'o5', orderNumber: 105, value: 105 }], customer: { id: 'sul' }, recipient: { customerId: 'norte' } });
    expect(read('companies/c1/private/nfse/orders/o5')).toMatchObject({ invoiceId: externalInvoiceId(accessKeyOf(5)) });
    expect(read('companies/c1/private/nfse/orders/o9')).toMatchObject({ invoiceId: externalInvoiceId(accessKeyOf(9)) });
    expect(read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(10))}`)).toMatchObject({ customer: { id: created[0].id }, orderIds: [] });

    expect(read('companies/c1/fiscalEmitters/e1')).toMatchObject({ regime: 'simples', dpsSeries: '10', enabledInCity: true, importBatchId: batch.id, municipalRegistration: '12345' });
    expect(read('companies/c1/settings/nfse')).toMatchObject({ defaultEmitterId: 'e1', provider: 'direct' });
    expect(await errorOf(applyImport('c1', batch.id, {}, USER, deps))).toBe('IMPORT_NOT_READY');
  });

  it('"Não, criar outro" (or no answer) creates a customer and links nothing', async () => {
    seed('companies/c1/customers/modelo', { name: 'Outra Coisa' });
    seed('companies/c1/customers/fulano', { name: 'Nova Empresa Exemplo' });
    const batch = await proposed();
    const group = batch.proposal!.groups.find((g) => g.key === NOVA)!;
    expect(group).toMatchObject({ action: 'ask', customerId: 'fulano' });
    await applyImport('c1', batch.id, { sameCustomer: { [NOVA]: false } }, USER, deps);
    expect(read('companies/c1/customers/fulano')!.taxId).toBeUndefined();
    expect(list('companies/c1/customers').some((c) => c.data.taxId === NOVA && c.id !== 'fulano')).toBe(true);
  });

  it('"Sim" completes the existing customer', async () => {
    seed('companies/c1/customers/fulano', { name: 'Nova Empresa Exemplo' });
    const batch = await proposed();
    await applyImport('c1', batch.id, { sameCustomer: { [NOVA]: true } }, USER, deps);
    expect(read('companies/c1/customers/fulano')).toMatchObject({ taxId: NOVA, legalName: 'NOVA EMPRESA EXEMPLO' });
  });

  it('undo: deletes the created without orders, empties what is unchanged, unlinks; the notas stay', async () => {
    const batch = await proposed();
    await applyImport('c1', batch.id, { autoIssueCustomerIds: ['norte'] }, USER, deps);
    // The owner changed the legal name of Loja Norte afterwards: that one stays.
    seed('companies/c1/customers/norte', { ...read('companies/c1/customers/norte'), legalName: 'Editado' });

    const undone = await undoImport('c1', batch.id, USER, deps);
    expect(undone).toMatchObject({ status: 'undone', undo: { customersDeleted: 1, customersKept: 0 } });
    const norte = read('companies/c1/customers/norte')!;
    expect(norte).toMatchObject({ name: 'Loja Exemplo Norte', legalName: 'Editado' });
    expect(norte.taxId).toBeUndefined();
    expect(norte.fiscalAddress).toBeUndefined();
    expect(norte.autoIssueInvoice).toBeUndefined();
    expect(read('companies/c1/customers/sul')!.invoiceRecipient).toBeUndefined();
    expect(read('companies/c1/customers/modelo')).toMatchObject({ taxId: MODELO });
    expect(list('companies/c1/customers').some((c) => c.data.taxId === NOVA)).toBe(false);
    expect(read('companies/c1/private/nfse/orders/o5')).toBeUndefined();
    const n5 = read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(5))}`)!;
    expect(n5).toMatchObject({ orderIds: [], customer: null, recipient: { customerId: null }, status: 'authorized' });
    expect(list('companies/c1/invoices')).toHaveLength(9);
    expect(await errorOf(undoImport('c1', batch.id, USER, deps))).toBe('IMPORT_NOT_READY');
  });

  it('undo keeps a created customer that got an order, and expires after 30 days', async () => {
    const batch = await proposed();
    await applyImport('c1', batch.id, {}, USER, deps);
    const created = list('companies/c1/customers').find((c) => c.data.taxId === NOVA)!;
    seed('companies/c1/orders/new', { number: 200, status: 'approved', customer: { id: created.id, name: 'x' } });
    const late = { ...deps, now: () => new Date('2026-12-06T13:00:00Z') };
    expect(await errorOf(undoImport('c1', batch.id, USER, late))).toBe('IMPORT_UNDO_EXPIRED');
    const undone = await undoImport('c1', batch.id, USER, deps);
    expect(undone.undo).toEqual({ customersDeleted: 0, customersKept: 1 });
    expect(read(`companies/c1/customers/${created.id}`)).toBeDefined();
  });
});

describe('Ligar a uma OS / Desligar da OS', () => {
  const ten = () => externalInvoiceId(accessKeyOf(10));

  it('links a nota without order, locks the order, refuses an order with a nota', async () => {
    await proposed();
    seed('companies/c1/orders/o20', { number: 120, status: 'done', customer: { id: 'modelo', name: 'Auto Peças Modelo' }, services: [{ value: 55 }], createdAt: '2026-10-10T12:00:00.000Z' });
    const linked = await linkInvoiceToOrder('c1', ten(), 'o20', USER, deps);
    expect(linked).toMatchObject({ orderIds: ['o20'], customer: { id: 'modelo' }, linkedBy: USER });
    expect(read('companies/c1/private/nfse/orders/o20')).toMatchObject({ invoiceId: ten() });
    expect(await errorOf(linkInvoiceToOrder('c1', ten(), 'o9', USER, deps))).toBe('INVOICE_HAS_ORDER');

    seed('companies/c1/private/nfse/orders/o9', { invoiceId: 'other' });
    seed('companies/c1/invoices/other', { status: 'authorized', provider: 'direct', orderIds: ['o9'] });
    const nine = externalInvoiceId(accessKeyOf(9));
    expect(await errorOf(linkInvoiceToOrder('c1', nine, 'o9', USER, deps))).toBe('ORDER_HAS_INVOICE');
    expect(await errorOf(linkInvoiceToOrder('c1', externalInvoiceId(accessKeyOf(11)), 'o9', USER, deps))).toBe('INVOICE_NOT_LINKABLE');
  });

  it('unlinks an external nota and frees the order; a PraticOS nota cannot be unlinked', async () => {
    const batch = await proposed();
    await applyImport('c1', batch.id, {}, USER, deps);
    const one = externalInvoiceId(accessKeyOf(1));
    const unlinked = await unlinkInvoice('c1', one, USER, deps);
    expect(unlinked).toMatchObject({ orderIds: [], customer: { id: 'norte' } });
    expect(read('companies/c1/private/nfse/orders/o1')).toBeUndefined();
    seed('companies/c1/invoices/mine', { status: 'authorized', provider: 'direct', source: 'praticos', orderIds: ['o9'] });
    expect(await errorOf(unlinkInvoice('c1', 'mine', USER, deps))).toBe('INVOICE_NOT_LINKABLE');
  });

  it('candidates: orders of the customer and its stores first', async () => {
    const batch = await proposed();
    await applyImport('c1', batch.id, {}, USER, deps);
    await unlinkInvoice('c1', externalInvoiceId(accessKeyOf(5)), USER, deps);
    const orders = await linkCandidates('c1', externalInvoiceId(accessKeyOf(5)));
    expect(orders[0]).toMatchObject({ id: 'o5', value: 105, hasNota: false, sameCustomer: true });
    expect(orders.find((o) => o.id === 'o9')).toMatchObject({ sameCustomer: false, hasNota: true });
  });
});

describe('daily reading', () => {
  it('reads from lastNsu: a nota made on the portal goes to the only customer with its CNPJ', async () => {
    const batch = await proposed();
    await applyImport('c1', batch.id, {}, USER, deps);
    calls = [];
    const last = mailbox.length;
    mailbox.push({ nsu: last + 1, type: 'NFSE', xml: nfseXml({ n: 30, value: 90, date: '2026-11-04', recipient: { taxId: MODELO, name: 'AUTO PECAS MODELO LTDA' } }) });
    mailbox.push({ nsu: last + 2, type: 'EVENTO', xml: cancelEventXml(1) });

    expect(await syncCompanyMailboxes('c1', deps)).toBe(2);
    expect(calls[0].url).toContain(`/DFe/${last}?`);
    expect(read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(30))}`)).toMatchObject({ customer: { id: 'modelo' }, recipient: { customerId: 'modelo' }, importBatchId: null });
    // Canceled on the portal: the nota follows and its order is free again.
    expect(read(`companies/c1/invoices/${externalInvoiceId(accessKeyOf(1))}`)).toMatchObject({ status: 'canceled' });
    expect(read('companies/c1/private/nfse/orders/o1')).toBeUndefined();
    expect(read('companies/c1/private/nfse/emitters/e1')).toMatchObject({ lastNsu: last + 2 });
  });

  it('skips emitters without a valid certificate', async () => {
    seed('companies/c1/fiscalEmitters/e1', { taxId: EMITTER_TAX_ID, certificate: { status: 'active', notAfter: '2026-01-01T00:00:00.000Z' } });
    expect(await syncCompanyMailboxes('c1', deps)).toBe(0);
    expect(calls).toHaveLength(0);
  });
});
