jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { fakeDb, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { setAsaasCredentialProvider } from '../credential-provider';
import { AsaasApiError } from '../asaas-client';
import { ASAAS_WEBHOOK_EVENTS } from '../webhook-events';
import { addDays, todayInSaoPaulo } from '../charge.service';
import {
  applyDescriptionTemplate,
  applyInvoiceEvent,
  autoIssueInvoice,
  canMoveInvoiceStatus,
  cancelInvoice,
  createInvoice,
  describeOrderNumbers,
  describeServices,
  invoiceValueOfOrder,
  isActiveInvoice,
  mapInvoiceStatus,
  parseInvoiceReference,
  municipalServiceNameForAsaas,
  previewInvoice,
  refusalCode,
} from '../invoice.service';

const USER = { id: 'u1', name: 'Ana' };
const CPF = '52998224725';
const TAXES = { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0 };
const INV = (id: string) => `companies/c1/invoices/${id}`;
const LOCK = (orderId: string) => `companies/c1/private/nfse/orders/${orderId}`;

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  getCustomer: jest.fn(),
  updateCustomer: jest.fn(),
  createInvoice: jest.fn(),
  authorizeInvoice: jest.fn(),
  cancelInvoice: jest.fn(),
  getMunicipalOptions: jest.fn(),
  getInvoice: jest.fn(),
  listInvoicesByExternalReference: jest.fn(),
};

/** Asaas customer with everything the city needs on a nota. */
const FULL_CONTACT = {
  email: 'joao@example.com', postalCode: '01310000', address: 'Av. Paulista', addressNumber: '1000', province: 'Bela Vista',
};
const CUSTOMER_REFUSAL = [
  { code: 'invalid_action', description: 'E-mail do cliente incompleto.' },
  { code: 'invalid_action', description: 'Endereço do cliente incompleto.' },
  { code: 'invalid_action', description: 'CEP do cliente é inválido.' },
];

/** Item 14.01 of LC 116 (mechanics): longer than the 250 characters Asaas accepts. */
const LONG_SERVICE_NAME =
  '14.01.01 - Lubrificação, limpeza, lustração, revisão, carga e recarga, conserto, restauração, blindagem, ' +
  'manutenção e conservação de máquinas, veículos, aparelhos, equipamentos, motores, elevadores ou de qualquer ' +
  'objeto (exceto peças e partes empregadas, que ficam sujeitas ao ICMS).';

const minutesAgo = (m: number) => new Date(Date.now() - m * 60 * 1000).toISOString();

function seedOrder(id: string, data: Record<string, unknown> = {}) {
  seed(`companies/c1/orders/${id}`, {
    number: Number(id.replace(/\D/g, '')) || 1,
    status: 'done',
    customer: { id: 'cust1', name: 'João' },
    services: [{ service: { name: 'Troca de óleo' }, value: 300 }],
    products: [{ product: { name: 'Filtro' }, value: 50, quantity: 2, total: 100 }],
    discount: 40,
    total: 360,
    ...data,
  });
}

function seedBase() {
  seed('companies/c1', { name: 'Oficina da Ana' });
  seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: true });
  seed('companies/c1/settings/nfse', {
    municipalServiceId: 'ms_1',
    municipalServiceCode: null,
    municipalServiceName: 'Manutenção de veículos',
    taxes: TAXES,
    descriptionTemplate: '{servicos}',
    asaasEnvironment: 'sandbox',
    asaasWalletId: 'w1',
  });
  seed('companies/c1/private/asaas', {
    mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active', webhookEvents: ASAAS_WEBHOOK_EVENTS,
  });
  seed('companies/c1/customers/cust1', { name: 'João', taxId: CPF });
  seedOrder('o182');
  seedOrder('o190', { services: [{ service: { name: 'Alinhamento' }, value: 100 }], products: [], discount: 0 });
}

describe('invoice.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.findCustomerByExternalReference.mockResolvedValue({ id: 'cus_1' });
    client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João', ...FULL_CONTACT });
    client.updateCustomer.mockResolvedValue({ id: 'cus_1' });
    client.createCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
    client.createInvoice.mockResolvedValue({ id: 'inv_1', status: 'SCHEDULED' });
    client.authorizeInvoice.mockResolvedValue({ id: 'inv_1', status: 'SYNCHRONIZED' });
    client.cancelInvoice.mockResolvedValue({ id: 'inv_1', status: 'PROCESSING_CANCELLATION' });
    client.getMunicipalOptions.mockResolvedValue({ supportsCancellation: true });
    client.listInvoicesByExternalReference.mockResolvedValue([]);
    seedBase();
  });
  afterEach(() => jest.restoreAllMocks());
  afterAll(() => setAsaasCredentialProvider(null));

  describe('regra do valor', () => {
    it('serviços menos a parte do desconto que cabe aos serviços', () => {
      const v = invoiceValueOfOrder({
        services: [{ value: 300 }] as any,
        products: [{ value: 50, quantity: 2, total: 100 }] as any,
        discount: 40,
      });
      expect(v).toEqual({ servicesTotal: 300, productsTotal: 100, discount: 40, value: 270 });
    });

    it('sem produtos o desconto inteiro sai dos serviços; sem serviços dá zero', () => {
      expect(invoiceValueOfOrder({ services: [{ value: 200 }] as any, products: [], discount: 50 }).value).toBe(150);
      expect(invoiceValueOfOrder({ services: [], products: [{ value: 10, quantity: 1 }] as any, discount: 0 }).value).toBe(0);
    });

    it('produto sem total usa valor x quantidade; item sem preço conta zero; centavos arredondados', () => {
      const v = invoiceValueOfOrder({
        services: [{ value: 100 }, { value: undefined }] as any,
        products: [{ value: 10, quantity: 3 }, { value: null }] as any,
        discount: 10,
      });
      expect(v.productsTotal).toBe(30);
      expect(v.value).toBe(92.31);
    });

    it('desconto maior que a OS não deixa valor negativo', () => {
      expect(invoiceValueOfOrder({ services: [{ value: 100 }] as any, products: [], discount: 500 }).value).toBe(0);
    });
  });

  describe('textos', () => {
    it('descrição com os serviços; várias OS em linhas com o número', () => {
      expect(describeServices([{ services: [{ service: { name: 'A' }, description: 'det' }, { service: { name: 'B' } }] } as any])).toBe('A - det; B');
      expect(describeServices([
        { number: 1, services: [{ service: { name: 'A' } }] },
        { number: 2, services: [{ service: { name: 'B' } }] },
      ] as any)).toBe('OS 1: A\nOS 2: B');
    });

    it('modelo troca {servicos} e {os}', () => {
      expect(applyDescriptionTemplate('Serviços: {servicos} ({os})', 'A; B', 'OS 1')).toBe('Serviços: A; B (OS 1)');
      expect(applyDescriptionTemplate('', 'A', 'OS 1')).toBe('A');
    });

    it('números das OS cabem nas observações', () => {
      expect(describeOrderNumbers([182, 190])).toBe('OS 182, 190');
      const many = Array.from({ length: 200 }, (_, i) => 100000 + i);
      expect(describeOrderNumbers(many).length).toBeLessThanOrEqual(500);
    });
  });

  describe('situações', () => {
    it('traduz a situação do Asaas e do evento', () => {
      expect(mapInvoiceStatus('AUTHORIZED')).toBe('authorized');
      expect(mapInvoiceStatus(undefined, 'INVOICE_ERROR')).toBe('error');
      expect(mapInvoiceStatus('???', 'INVOICE_UPDATED')).toBeNull();
    });

    it('só anda para frente; cancelada é final; erro pode voltar a agendada', () => {
      expect(canMoveInvoiceStatus('scheduled', 'authorized')).toBe(true);
      expect(canMoveInvoiceStatus('authorized', 'scheduled')).toBe(false);
      expect(canMoveInvoiceStatus('authorized', 'synchronized')).toBe(false);
      expect(canMoveInvoiceStatus('canceled', 'authorized')).toBe(false);
      expect(canMoveInvoiceStatus('error', 'scheduled')).toBe(true);
      expect(canMoveInvoiceStatus('cancellationDenied', 'canceled')).toBe(true);
    });

    it('nota com erro, cancelada ou em conflito não conta como ativa; "criando" antiga continua ativa', () => {
      expect(isActiveInvoice({ status: 'error', createdAt: '' })).toBe(false);
      expect(isActiveInvoice({ status: 'canceled', createdAt: '' })).toBe(false);
      expect(isActiveInvoice({ status: 'authorized', createdAt: '' })).toBe(true);
      expect(isActiveInvoice({ status: 'authorized', createdAt: '', conflict: true })).toBe(false);
      // Only the reconciliation with Asaas frees an old "creating" (it may exist there).
      expect(isActiveInvoice({ status: 'creating', createdAt: minutesAgo(60) })).toBe(true);
    });

    it('referência externa da nota', () => {
      expect(parseInvoiceReference('c1:nf:abc')).toEqual({ companyId: 'c1', invoiceId: 'abc' });
      expect(parseInvoiceReference('c1:cc:abc')).toBeNull();
      expect(parseInvoiceReference('c1:o1:abc')).toBeNull();
    });
  });

  describe('prévia', () => {
    it('mostra valor, descrição, se há produtos e se o cliente tem CPF', async () => {
      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.value).toBe(270);
      expect(preview.hasProducts).toBe(true);
      expect(preview.serviceDescription).toBe('Troca de óleo');
      expect(preview.observations).toBe('OS 182');
      expect(preview.customer).toEqual({
        id: 'cust1', name: 'João', hasTaxId: true, contact: FULL_CONTACT, missingData: [],
      });
      expect(preview.invoicedOrders).toEqual({});
    });

    it('recusa sem a opção ligada, sem o serviço configurado e OS sem serviço', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_NOT_ENABLED' });
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false, nfseEnabled: true });
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'ASAAS_NOT_CONNECTED' });
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: true });
      await fakeDb.doc('companies/c1/settings/nfse').delete();
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_NOT_READY' });
    });

    it('exige a configuração pronta (nfseReady), não só o serviço salvo', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: false });
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_NOT_READY' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_NOT_READY' });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('serviço configurado em outra conta do Asaas → NFSE_SETUP_NEEDED', async () => {
      seed('companies/c1/private/asaas', {
        mode: 'apiKey', environment: 'sandbox', walletId: 'w2', status: 'active', webhookEvents: ASAAS_WEBHOOK_EVENTS,
      });
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_SETUP_NEEDED' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_SETUP_NEEDED' });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey', environment: 'production', walletId: 'w1', status: 'active', webhookEvents: ASAAS_WEBHOOK_EVENTS,
      });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_SETUP_NEEDED' });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('conexão feita antes da nota fiscal (sem os eventos INVOICE_*) → NFSE_RECONNECT_NEEDED', async () => {
      seed('companies/c1/private/asaas', { mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active' });
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_RECONNECT_NEEDED' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_RECONNECT_NEEDED' });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active', webhookEvents: ['PAYMENT_RECEIVED'],
      });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_RECONNECT_NEEDED' });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('OS sem serviço ou orçamento não entram', async () => {
      seedOrder('o5', { services: [] });
      seedOrder('o6', { status: 'quote' });
      await expect(previewInvoice('c1', ['o5'])).rejects.toMatchObject({ code: 'NO_SERVICES' });
      await expect(previewInvoice('c1', ['o6'])).rejects.toMatchObject({ code: 'NFSE_ORDER_NOT_ALLOWED' });
    });
  });

  describe('emitir', () => {
    it('agenda a nota avulsa no Asaas com o valor dos serviços e emite na hora', async () => {
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);

      expect(client.createInvoice).toHaveBeenCalledTimes(1);
      const payload = client.createInvoice.mock.calls[0][0];
      expect(payload).toEqual({
        customer: 'cus_1',
        serviceDescription: 'Troca de óleo',
        observations: 'OS 182',
        externalReference: `c1:nf:${invoice.id}`,
        value: 270,
        deductions: 0,
        effectiveDate: todayInSaoPaulo(),
        municipalServiceName: 'Manutenção de veículos',
        municipalServiceId: 'ms_1',
        taxes: TAXES,
      });
      expect(payload.payment).toBeUndefined();
      expect(client.authorizeInvoice).toHaveBeenCalledWith('inv_1');

      const stored = read(INV(invoice.id))!;
      expect(stored.status).toBe('synchronized');
      expect(stored.asaasInvoiceId).toBe('inv_1');
      expect(stored.orderIds).toEqual(['o182']);
      expect(stored.orders).toEqual([{ orderId: 'o182', orderNumber: 182, value: 270 }]);
      expect(stored).toMatchObject({ asaasEnvironment: 'sandbox', asaasWalletId: 'w1' });
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
    });

    it('nome do serviço com mais de 250 caracteres vai cortado (o Asaas recusa maior)', async () => {
      expect(LONG_SERVICE_NAME.length).toBeGreaterThan(250);
      seed('companies/c1/settings/nfse', { ...read('companies/c1/settings/nfse')!, municipalServiceName: LONG_SERVICE_NAME });
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      const sent = client.createInvoice.mock.calls[0][0].municipalServiceName as string;
      expect(sent).toHaveLength(250);
      expect(sent.endsWith('…')).toBe(true);
      expect(LONG_SERVICE_NAME.startsWith(sent.slice(0, -1))).toBe(true);
      // The nota keeps the whole name for the app.
      expect(read(INV(invoice.id))!.municipalServiceName).toBe(LONG_SERVICE_NAME);
      expect(municipalServiceNameForAsaas('  Manutenção  ')).toBe('Manutenção');
    });

    it('classifica a recusa do Asaas: cliente, configuração da nota ou desconhecida', () => {
      const refusal = (description: string, code = 'x') => new AsaasApiError(400, [{ code, description }], '/invoices');
      expect(refusalCode(refusal('CEP do cliente é inválido.'))).toBe('CUSTOMER_DATA_REQUIRED');
      expect(refusalCode(refusal('E-mail do cliente incompleto.'))).toBe('CUSTOMER_DATA_REQUIRED');
      expect(refusalCode(refusal('Bairro do cliente não informado.'))).toBe('CUSTOMER_DATA_REQUIRED');
      // The sheet cannot edit a stored CPF: shows Asaas's text instead of looping.
      expect(refusalCode(refusal('CPF/CNPJ do cliente inválido.'))).toBe('ASAAS_REJECTED');
      // The company's e-mail is not the customer's.
      expect(refusalCode(refusal('E-mail da empresa não configurado.'))).toBe('ASAAS_REJECTED');
      // Municipal service name (invalid_name) → setup; the free-text description is edited on the sheet.
      const tooLong = 'A descrição do serviço deve ter no máximo 250 caracteres.';
      expect(refusalCode(refusal(tooLong, 'invalid_name'))).toBe('NFSE_SETUP_REJECTED');
      expect(refusalCode(refusal(tooLong, 'invalid_serviceDescription'))).toBe('ASAAS_REJECTED');
      expect(refusalCode(refusal('Serviço municipal não encontrado.'))).toBe('NFSE_SETUP_REJECTED');
      expect(refusalCode(refusal('Inscrição municipal inválida'))).toBe('NFSE_SETUP_REJECTED');
      expect(refusalCode(refusal('Alíquota de ISS inválida'))).toBe('NFSE_SETUP_REJECTED');
      expect(refusalCode(refusal('Valor acima do permitido'))).toBe('ASAAS_REJECTED');
    });

    it('create recusado por configuração: NFSE_SETUP_REJECTED com o texto do Asaas, OS livre', async () => {
      client.createInvoice.mockRejectedValueOnce(new AsaasApiError(400, [
        { code: 'invalid_name', description: 'A descrição do serviço deve ter no máximo 250 caracteres.' },
      ], '/invoices'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'NFSE_SETUP_REJECTED', detail: 'A descrição do serviço deve ter no máximo 250 caracteres.',
      });
      expect(read(LOCK('o182'))).toBeUndefined();
      expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('invalid_name: A descrição do serviço'));
    });

    it('create recusado por dados do cliente: CUSTOMER_DATA_REQUIRED (a folha pede os dados)', async () => {
      client.createInvoice.mockRejectedValueOnce(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED', detail: expect.stringContaining('CEP do cliente é inválido.'),
      });
    });

    it('com código digitado manda o código, nunca os dois', async () => {
      seed('companies/c1/settings/nfse', {
        municipalServiceId: null, municipalServiceCode: '14.01', municipalServiceName: 'Manutenção', taxes: TAXES,
        asaasEnvironment: 'sandbox', asaasWalletId: 'w1',
      });
      await createInvoice('c1', { orderIds: ['o182'] }, USER);
      const payload = client.createInvoice.mock.calls[0][0];
      expect(payload.municipalServiceCode).toBe('14.01');
      expect(payload.municipalServiceId).toBeUndefined();
    });

    it('data futura fica agendada (não chama authorize); data passada é recusada', async () => {
      const future = addDays(todayInSaoPaulo(), 5);
      await createInvoice('c1', { orderIds: ['o182'], effectiveDate: future }, USER);
      expect(client.authorizeInvoice).not.toHaveBeenCalled();
      await expect(
        createInvoice('c1', { orderIds: ['o190'], effectiveDate: addDays(todayInSaoPaulo(), -1) }, USER),
      ).rejects.toMatchObject({ code: 'INVALID_EFFECTIVE_DATE' });
    });

    it('uma nota com várias OS do mesmo cliente', async () => {
      const invoice = await createInvoice('c1', { orderIds: ['o190', 'o182'] }, USER, 'cust1');
      const payload = client.createInvoice.mock.calls[0][0];
      expect(payload.value).toBe(370);
      expect(payload.serviceDescription).toBe('OS 182: Troca de óleo\nOS 190: Alinhamento');
      expect(payload.observations).toBe('OS 182, 190');
      expect(read(INV(invoice.id))!.orderIds).toEqual(['o182', 'o190']);
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
      expect(read(LOCK('o190'))!.invoiceId).toBe(invoice.id);
    });

    it('recusa OS de outro cliente', async () => {
      seedOrder('o300', { customer: { id: 'other' } });
      await expect(createInvoice('c1', { orderIds: ['o182', 'o300'] }, USER)).rejects.toMatchObject({
        code: 'ORDER_NOT_OF_CUSTOMER',
      });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER, 'other')).rejects.toMatchObject({
        code: 'ORDER_NOT_OF_CUSTOMER',
      });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('só uma nota ativa por OS; com erro ou cancelada libera', async () => {
      const first = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      await expect(createInvoice('c1', { orderIds: ['o182', 'o190'] }, USER)).rejects.toMatchObject({
        code: 'ORDER_HAS_INVOICE',
      });
      expect(client.createInvoice).toHaveBeenCalledTimes(1);
      expect(read(LOCK('o190'))).toBeUndefined();

      seed(INV(first.id), { ...read(INV(first.id))!, status: 'error' });
      client.createInvoice.mockResolvedValue({ id: 'inv_2', status: 'SCHEDULED' });
      const second = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(LOCK('o182'))!.invoiceId).toBe(second.id);
    });

    it('pede CPF/CNPJ quando o cliente não tem', async () => {
      seed('companies/c1/customers/cust1', { name: 'João' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'TAX_ID_REQUIRED' });
      await createInvoice('c1', { orderIds: ['o182'], customerTaxId: CPF }, USER);
      expect(read('companies/c1/customers/cust1')!.taxId).toBe(CPF);
    });

    it('quando o Asaas recusa (400/422), apaga a nota e libera a OS', async () => {
      for (const status of [400, 422]) {
        client.createInvoice.mockRejectedValueOnce(new AsaasApiError(status, [{ code: 'x', description: 'y' }], '/invoices'));
        await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toBeInstanceOf(AsaasApiError);
        expect(read(LOCK('o182'))).toBeUndefined();
        expect(fakeDb.list('companies/c1/invoices')).toEqual([]);
      }
    });

    it('sem resposta certa do Asaas (timeout, 408, 5xx, rede) mantém a nota e a trava: o Asaas pode ter criado', async () => {
      const timeout = Object.assign(new Error('timeout'), { name: 'TimeoutError' });
      const failures = [timeout, new TypeError('fetch failed'), new AsaasApiError(503, [], '/invoices'), new AsaasApiError(408, [], '/invoices')];
      for (const [i, failure] of failures.entries()) {
        const orderId = `o${500 + i}`;
        seedOrder(orderId);
        client.createInvoice.mockRejectedValueOnce(failure);
        await expect(createInvoice('c1', { orderIds: [orderId] }, USER)).rejects.toBe(failure);
        const lock = read(LOCK(orderId));
        expect(lock).toBeDefined();
        expect(read(INV(lock!.invoiceId as string))!.status).toBe('creating');
        // Retrying right away does not create a second nota.
        await expect(createInvoice('c1', { orderIds: [orderId] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
      }
      expect(client.createInvoice).toHaveBeenCalledTimes(failures.length);
    });

    it('guarda o id do Asaas logo que a nota é criada, mesmo se o resto falhar', async () => {
      const original = fakeDb.runTransaction.bind(fakeDb);
      let calls = 0;
      jest.spyOn(fakeDb, 'runTransaction').mockImplementation(((fn: any) => {
        calls += 1;
        // 1st: reserve the orders; later ones (sync of the Asaas answer) fail.
        if (calls > 1) return Promise.reject(new Error('aborted'));
        return original(fn);
      }) as any);
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(invoice.asaasInvoiceId).toBe('inv_1');
      expect(read(INV(invoice.id))).toMatchObject({ asaasInvoiceId: 'inv_1', status: 'creating' });
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
    });

    it('authorize sem resposta certa deixa a nota agendada (o Asaas emite na data)', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(503, [], '/invoices/inv_1/authorize'));
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(INV(invoice.id))!.status).toBe('scheduled');
      expect(client.cancelInvoice).not.toHaveBeenCalled();
    });

    it('authorize recusado por dados do cliente: cancela a agendada, guarda o motivo e libera a OS', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices/inv_1/authorize'));
      client.cancelInvoice.mockResolvedValue({ id: 'inv_1', status: 'CANCELED' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED',
      });
      expect(client.cancelInvoice).toHaveBeenCalledWith('inv_1');
      const lock = read(LOCK('o182'))!;
      expect(read(INV(lock.invoiceId as string))).toMatchObject({
        status: 'error',
        canceledOnAsaas: true,
        errorCode: 'CUSTOMER_DATA_REQUIRED',
        statusDescription: 'E-mail do cliente incompleto. Endereço do cliente incompleto. CEP do cliente é inválido.',
      });

      // The late INVOICE_CANCELED of that Asaas nota keeps the reason.
      await applyInvoiceEvent('c1', 'INVOICE_CANCELED', {
        id: 'inv_1', status: 'CANCELED', externalReference: `c1:nf:${lock.invoiceId}`,
      } as any);
      expect(read(INV(lock.invoiceId as string))).toMatchObject({ status: 'error', errorCode: 'CUSTOMER_DATA_REQUIRED' });

      // The order is free: fixed data, a new nota.
      client.authorizeInvoice.mockResolvedValue({ id: 'inv_2', status: 'SYNCHRONIZED' });
      client.createInvoice.mockResolvedValue({ id: 'inv_2', status: 'SCHEDULED' });
      const second = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(LOCK('o182'))!.invoiceId).toBe(second.id);
    });

    it('authorize recusado por motivo desconhecido: devolve o erro do Asaas e guarda o texto dele', async () => {
      const refusal = new AsaasApiError(400, [{ code: 'x', description: 'Valor acima do permitido' }], '/invoices/inv_1/authorize');
      client.authorizeInvoice.mockRejectedValue(refusal);
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toBe(refusal);
      const lock = read(LOCK('o182'))!;
      expect(read(INV(lock.invoiceId as string))).toMatchObject({
        status: 'error', errorCode: 'ASAAS_REJECTED', statusDescription: 'Valor acima do permitido',
      });
    });

    it('authorize recusado pela configuração da nota: NFSE_SETUP_REJECTED (o app abre a configuração)', async () => {
      client.authorizeInvoice.mockRejectedValue(
        new AsaasApiError(400, [{ code: 'x', description: 'Alíquota inválida' }], '/invoices/inv_1/authorize'),
      );
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'NFSE_SETUP_REJECTED', detail: 'Alíquota inválida',
      });
      const lock = read(LOCK('o182'))!;
      expect(read(INV(lock.invoiceId as string))).toMatchObject({ status: 'error', errorCode: 'NFSE_SETUP_REJECTED' });
    });

    it('authorize recusado e cancelamento falhou: fica agendada com o motivo (OS presa até cancelar)', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices/inv_1/authorize'));
      client.cancelInvoice.mockRejectedValue(new AsaasApiError(503, [], '/invoices/inv_1/cancel'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED',
      });
      const lock = read(LOCK('o182'))!;
      expect(read(INV(lock.invoiceId as string))).toMatchObject({
        status: 'scheduled', errorCode: 'CUSTOMER_DATA_REQUIRED',
      });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
    });

    it('recusada e não cancelada continua viva no Asaas: erro e depois emitida voltam a valer e travam a OS', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices/inv_1/authorize'));
      client.cancelInvoice.mockRejectedValue(new AsaasApiError(503, [], '/invoices/inv_1/cancel'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'CUSTOMER_DATA_REQUIRED' });
      const id = read(LOCK('o182'))!.invoiceId as string;
      expect(read(INV(id))!.canceledOnAsaas).toBeUndefined();
      const ref = `c1:nf:${id}`;

      // Asaas tries on the date and fails: its error replaces our reason.
      await applyInvoiceEvent('c1', 'INVOICE_ERROR', {
        id: 'inv_1', status: 'ERROR', statusDescription: 'Endereço do cliente incompleto.', externalReference: ref,
      } as any);
      expect(read(INV(id))).toMatchObject({ status: 'error', statusDescription: 'Endereço do cliente incompleto.' });

      // The user fixes the customer in the Asaas panel and Asaas issues it.
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', {
        id: 'inv_1', status: 'AUTHORIZED', number: '55', externalReference: ref,
      } as any);
      const invoice = read(INV(id))!;
      expect(invoice).toMatchObject({ status: 'authorized', number: '55', errorCode: null });
      expect(invoice.conflict).toBeUndefined();
      expect(read(LOCK('o182'))!.invoiceId).toBe(id);
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
    });

    it('viva no Asaas mas a OS já tem outra nota: volta como conflito', async () => {
      client.authorizeInvoice.mockRejectedValueOnce(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices/inv_1/authorize'));
      client.cancelInvoice.mockRejectedValueOnce(new AsaasApiError(503, [], '/invoices/inv_1/cancel'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'CUSTOMER_DATA_REQUIRED' });
      const id = read(LOCK('o182'))!.invoiceId as string;
      await applyInvoiceEvent('c1', 'INVOICE_ERROR', { id: 'inv_1', status: 'ERROR', externalReference: `c1:nf:${id}` } as any);

      client.createInvoice.mockResolvedValue({ id: 'inv_2', status: 'SCHEDULED' });
      client.authorizeInvoice.mockResolvedValue({ id: 'inv_2', status: 'SYNCHRONIZED' });
      const second = await createInvoice('c1', { orderIds: ['o182'] }, USER);

      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: `c1:nf:${id}` } as any);
      expect(read(INV(id))).toMatchObject({ status: 'authorized', conflict: true });
      expect(read(LOCK('o182'))!.invoiceId).toBe(second.id);
    });

    it('não mexe em outra empresa', async () => {
      seed('companies/c2/settings/payments', { asaasEnabled: true, asaasConnected: true });
      await expect(createInvoice('c2', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_NOT_ENABLED' });
      seed('companies/c2/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: true });
      seed('companies/c2/private/asaas', { environment: 'sandbox', walletId: 'w9', status: 'active', webhookEvents: ASAAS_WEBHOOK_EVENTS });
      seed('companies/c2/settings/nfse', {
        municipalServiceId: 'x', municipalServiceName: 'x', taxes: TAXES, asaasEnvironment: 'sandbox', asaasWalletId: 'w9',
      });
      await expect(createInvoice('c2', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_NOT_FOUND' });
    });
  });

  describe('dados do cliente para a nota', () => {
    it('prévia diz o que falta no cliente do Asaas (e usa o e-mail do PraticOS)', async () => {
      seed('companies/c1/customers/cust1', { name: 'João', taxId: CPF, email: 'joao@oficina.com' });
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João', postalCode: '01310-000' });
      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.customer.contact).toEqual({ email: 'joao@oficina.com', postalCode: '01310000' });
      expect(preview.customer.missingData).toEqual(['address', 'addressNumber', 'province']);
    });

    it('prévia com cliente ainda fora do Asaas pede tudo, sem criar nada', async () => {
      client.findCustomerByExternalReference.mockResolvedValue(null);
      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.customer.missingData).toEqual(['email', 'postalCode', 'address', 'addressNumber', 'province']);
      expect(client.createCustomer).not.toHaveBeenCalled();
      expect(client.getCustomer).not.toHaveBeenCalled();
    });

    it('prévia não cai se o Asaas não responder', async () => {
      client.getCustomer.mockRejectedValue(new AsaasApiError(503, [], '/customers/cus_1'));
      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.customer.missingData).toContain('postalCode');
    });

    it('sem e-mail ou endereço: recusa antes de criar a nota (CUSTOMER_DATA_REQUIRED)', async () => {
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED',
      });
      expect(client.createInvoice).not.toHaveBeenCalled();
      expect(client.updateCustomer).not.toHaveBeenCalled();
      expect(read(LOCK('o182'))).toBeUndefined();
    });

    it('dados digitados vão para o cliente do Asaas (só o que mudou) e ficam no cadastro onde estava vazio', async () => {
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João', province: 'Bela Vista' });
      await createInvoice('c1', {
        orderIds: ['o182'],
        customerData: {
          email: ' joao@example.com ', postalCode: '01310-000', address: 'Av. Paulista', addressNumber: '1000',
          complement: 'sala 2', province: 'Bela Vista',
        },
      }, USER);
      expect(client.updateCustomer).toHaveBeenCalledWith('cus_1', {
        email: 'joao@example.com', postalCode: '01310000', address: 'Av. Paulista', addressNumber: '1000', complement: 'sala 2',
      });
      expect(client.createInvoice).toHaveBeenCalledTimes(1);
      expect(read('companies/c1/customers/cust1')).toMatchObject({
        email: 'joao@example.com',
        address: 'Av. Paulista, 1000, sala 2 - Bela Vista - CEP 01310-000',
      });
    });

    it('não troca e-mail nem endereço já escritos no cadastro do PraticOS', async () => {
      seed('companies/c1/customers/cust1', { name: 'João', taxId: CPF, email: 'antigo@x.com', address: 'Rua A, 1' });
      await createInvoice('c1', { orderIds: ['o182'], customerData: { ...FULL_CONTACT, email: 'novo@x.com' } }, USER);
      expect(client.updateCustomer).toHaveBeenCalledWith('cus_1', { email: 'novo@x.com' });
      expect(read('companies/c1/customers/cust1')).toMatchObject({ email: 'antigo@x.com', address: 'Rua A, 1' });
    });

    it('dado inválido conta como faltando (CEP com menos de 8 dígitos, e-mail sem @)', async () => {
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
      await expect(createInvoice('c1', {
        orderIds: ['o182'], customerData: { ...FULL_CONTACT, postalCode: '0131', email: 'joao' },
      }, USER)).rejects.toMatchObject({ code: 'CUSTOMER_DATA_REQUIRED', message: expect.stringContaining('email, postalCode') });
    });

    it('Asaas recusa salvar o endereço no cliente (PUT): CUSTOMER_DATA_REQUIRED com o texto dele', async () => {
      const badCep = new AsaasApiError(400, [{ code: 'invalid_postalCode', description: 'O CEP informado é inválido.' }], '/customers');
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
      client.updateCustomer.mockRejectedValue(badCep);
      await expect(createInvoice('c1', { orderIds: ['o182'], customerData: FULL_CONTACT }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED', detail: 'O CEP informado é inválido.',
      });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('Asaas recusa criar o cliente novo com o endereço digitado: CUSTOMER_DATA_REQUIRED', async () => {
      const badCep = new AsaasApiError(400, [{ code: 'invalid_postalCode', description: 'O CEP informado é inválido.' }], '/customers');
      client.findCustomerByExternalReference.mockResolvedValue(null);
      client.createCustomer.mockRejectedValue(badCep);
      await expect(createInvoice('c1', { orderIds: ['o182'], customerData: FULL_CONTACT }, USER)).rejects.toMatchObject({
        code: 'CUSTOMER_DATA_REQUIRED', detail: 'O CEP informado é inválido.',
      });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('outra recusa ao salvar o cliente (CPF) não reabre os campos: segue o erro do Asaas', async () => {
      const badCpf = new AsaasApiError(400, [{ code: 'invalid_cpfCnpj', description: 'CPF inválido.' }], '/customers');
      client.findCustomerByExternalReference.mockResolvedValue(null);
      client.createCustomer.mockRejectedValue(badCpf);
      await expect(createInvoice('c1', { orderIds: ['o182'], customerData: FULL_CONTACT }, USER)).rejects.toBe(badCpf);
    });

    it('cliente novo no Asaas já é criado com e-mail e endereço', async () => {
      client.findCustomerByExternalReference.mockResolvedValue(null);
      client.createCustomer.mockResolvedValue({ id: 'cus_9', name: 'João' });
      client.getCustomer.mockResolvedValue({ id: 'cus_9', name: 'João', ...FULL_CONTACT });
      await createInvoice('c1', { orderIds: ['o182'], customerData: FULL_CONTACT }, USER);
      expect(client.createCustomer).toHaveBeenCalledWith(expect.objectContaining({ ...FULL_CONTACT, cpfCnpj: CPF }));
      expect(client.updateCustomer).not.toHaveBeenCalled();
      expect(client.createInvoice.mock.calls[0][0].customer).toBe('cus_9');
    });
  });

  describe('conferir com o Asaas', () => {
    function seedInvoice(id: string, data: Record<string, unknown>) {
      seed(INV(id), {
        id, customer: { id: 'cust1', name: 'João' }, orderIds: ['o182'],
        orders: [{ orderId: 'o182', orderNumber: 182, value: 270 }], value: 270,
        serviceDescription: 'x', observations: 'OS 182', effectiveDate: todayInSaoPaulo(), municipalServiceName: 'M',
        createdBy: USER, asaasEnvironment: 'sandbox', asaasWalletId: 'w1', ...data,
      });
      seed(LOCK('o182'), { invoiceId: id });
    }

    it('"criando" antiga que o Asaas criou: acha pela referência e não emite outra', async () => {
      seedInvoice('nfA', { status: 'creating', createdAt: minutesAgo(10) });
      client.listInvoicesByExternalReference.mockResolvedValue([
        { id: 'inv_9', status: 'AUTHORIZED', externalReference: 'c1:nf:nfA', number: '77' },
      ]);
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
      expect(client.listInvoicesByExternalReference).toHaveBeenCalledWith('c1:nf:nfA');
      expect(client.createInvoice).not.toHaveBeenCalled();
      expect(read(INV('nfA'))).toMatchObject({ status: 'authorized', asaasInvoiceId: 'inv_9', number: '77' });

      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.invoicedOrders).toEqual({ o182: 'nfA' });
    });

    it('"criando" antiga que não chegou ao Asaas: libera a OS para uma nota nova', async () => {
      seedInvoice('nfA', { status: 'creating', createdAt: minutesAgo(10) });
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(INV('nfA'))).toBeUndefined();
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
      expect(client.createInvoice).toHaveBeenCalledTimes(1);
    });

    it('"criando" recente não chama o Asaas (o pedido pode estar a caminho)', async () => {
      seedInvoice('nfA', { status: 'creating', createdAt: minutesAgo(1) });
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
      expect(client.listInvoicesByExternalReference).not.toHaveBeenCalled();
    });

    it('Asaas fora do ar na conferência: a OS continua travada', async () => {
      seedInvoice('nfA', { status: 'creating', createdAt: minutesAgo(10) });
      client.listInvoicesByExternalReference.mockRejectedValue(new AsaasApiError(503, [], '/invoices'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_HAS_INVOICE' });
      expect(read(INV('nfA'))!.status).toBe('creating');
    });

    it('nota agendada antiga recusada pela prefeitura (webhook perdido): confere e libera a OS', async () => {
      seedInvoice('nfA', { status: 'scheduled', asaasInvoiceId: 'inv_A', createdAt: minutesAgo(30), updatedAt: minutesAgo(30) });
      client.getInvoice.mockResolvedValue({ id: 'inv_A', status: 'ERROR', statusDescription: 'Inscrição inválida' });
      client.createInvoice.mockResolvedValue({ id: 'inv_B', status: 'SCHEDULED' });
      client.authorizeInvoice.mockResolvedValue({ id: 'inv_B', status: 'SYNCHRONIZED' });
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(client.getInvoice).toHaveBeenCalledWith('inv_A');
      expect(read(INV('nfA'))).toMatchObject({ status: 'error', statusDescription: 'Inscrição inválida' });
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
    });

    it('prévia confere a nota antiga antes de dizer que a OS tem nota', async () => {
      seedInvoice('nfA', { status: 'synchronized', asaasInvoiceId: 'inv_A', createdAt: minutesAgo(30), updatedAt: minutesAgo(30) });
      client.getInvoice.mockResolvedValue({ id: 'inv_A', status: 'ERROR' });
      const preview = await previewInvoice('c1', ['o182']);
      expect(preview.invoicedOrders).toEqual({});
    });

    it('cancelar confere a situação antes (enviada que já foi emitida)', async () => {
      seedInvoice('nfA', { status: 'synchronized', asaasInvoiceId: 'inv_A', createdAt: minutesAgo(30), updatedAt: minutesAgo(30) });
      client.getInvoice.mockResolvedValue({ id: 'inv_A', status: 'AUTHORIZED' });
      client.cancelInvoice.mockResolvedValue({ id: 'inv_A', status: 'PROCESSING_CANCELLATION' });
      const result = await cancelInvoice('c1', 'nfA');
      expect(client.cancelInvoice).toHaveBeenCalledWith('inv_A', false);
      expect(result.status).toBe('processingCancellation');
    });

    it('cancelar "criando" sem id do Asaas: acha pela referência', async () => {
      seedInvoice('nfA', { status: 'creating', createdAt: minutesAgo(10) });
      client.listInvoicesByExternalReference.mockResolvedValue([{ id: 'inv_9', status: 'SCHEDULED', externalReference: 'c1:nf:nfA' }]);
      client.cancelInvoice.mockResolvedValue({ id: 'inv_9', status: 'CANCELED' });
      const result = await cancelInvoice('c1', 'nfA');
      expect(client.cancelInvoice).toHaveBeenCalledWith('inv_9', false);
      expect(result.status).toBe('canceled');
    });
  });

  describe('emitir sozinho', () => {
    const setAuto = (autoIssue: string) =>
      seed('companies/c1/settings/nfse', { ...read('companies/c1/settings/nfse')!, autoIssue });
    const invoicesOf = async (orderId: string) =>
      (await fakeDb.collection('companies/c1/invoices').where('orderIds', 'array-contains', orderId).get()).docs.map(
        (d: any) => ({ id: d.id, ...d.data() }),
      );

    it('no momento escolhido: emite a nota da OS, marcada como automática', async () => {
      setAuto('paid');
      await autoIssueInvoice('c1', 'o182', 'paid');

      const [invoice] = await invoicesOf('o182');
      expect(client.createInvoice).toHaveBeenCalledTimes(1);
      expect(invoice).toMatchObject({ auto: true, orderIds: ['o182'], value: 270, createdBy: { id: 'system' } });
      expect(read(LOCK('o182'))).toMatchObject({ invoiceId: invoice.id });
    });

    it('outro momento, "só quando eu pedir" ou sem escolha: não emite', async () => {
      await autoIssueInvoice('c1', 'o182', 'paid');
      setAuto('manual');
      await autoIssueInvoice('c1', 'o182', 'completed');
      setAuto('completed');
      await autoIssueInvoice('c1', 'o182', 'paid');

      expect(client.createInvoice).not.toHaveBeenCalled();
      expect(await invoicesOf('o182')).toEqual([]);
    });

    it('nota fiscal desligada ou configuração incompleta: não emite', async () => {
      setAuto('completed');
      seed('companies/c1/settings/payments', { asaasConnected: true, nfseEnabled: true, nfseReady: false });
      await autoIssueInvoice('c1', 'o182', 'completed');
      seed('companies/c1/settings/payments', { asaasConnected: true, nfseEnabled: false, nfseReady: true });
      await autoIssueInvoice('c1', 'o182', 'completed');

      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('OS que já teve nota (mesmo cancelada) fica com o usuário', async () => {
      setAuto('completed');
      seed(INV('old'), { status: 'canceled', orderIds: ['o182'], createdAt: minutesAgo(60) });
      await autoIssueInvoice('c1', 'o182', 'completed');

      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('cliente sem CPF: registra a nota com erro na OS, uma vez só', async () => {
      setAuto('completed');
      seed('companies/c1/customers/cust1', { name: 'João' });
      await autoIssueInvoice('c1', 'o182', 'completed');
      await autoIssueInvoice('c1', 'o182', 'completed');

      const invoices = await invoicesOf('o182');
      expect(invoices).toHaveLength(1);
      expect(invoices[0]).toMatchObject({
        id: 'auto-o182', status: 'error', errorCode: 'TAX_ID_REQUIRED', auto: true, value: 270,
        orders: [{ orderId: 'o182', orderNumber: 182, value: 270 }],
      });
      expect(read(LOCK('o182'))).toBeUndefined();
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('Asaas recusa: guarda o motivo dele na nota com erro', async () => {
      setAuto('paid');
      client.createInvoice.mockRejectedValue(
        new AsaasApiError(400, [{ code: 'invalid', description: 'Inscrição municipal inválida' }], '/invoices'),
      );
      await autoIssueInvoice('c1', 'o182', 'paid');

      const invoices = await invoicesOf('o182');
      expect(invoices).toHaveLength(1);
      expect(invoices[0]).toMatchObject({
        id: 'auto-o182', status: 'error', errorCode: 'NFSE_SETUP_REJECTED', statusDescription: 'Inscrição municipal inválida',
      });
    });

    it('cliente sem e-mail ou endereço: registra o erro de dados do cliente, sem criar nota no Asaas', async () => {
      setAuto('paid');
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
      await autoIssueInvoice('c1', 'o182', 'paid');

      const invoices = await invoicesOf('o182');
      expect(invoices).toHaveLength(1);
      expect(invoices[0]).toMatchObject({ id: 'auto-o182', status: 'error', errorCode: 'CUSTOMER_DATA_REQUIRED' });
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('emissão recusada depois de criada: fica só a nota com o motivo, sem registro duplicado', async () => {
      setAuto('paid');
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, CUSTOMER_REFUSAL, '/invoices/inv_1/authorize'));
      client.cancelInvoice.mockResolvedValue({ id: 'inv_1', status: 'CANCELED' });
      await autoIssueInvoice('c1', 'o182', 'paid');

      const invoices = await invoicesOf('o182');
      expect(invoices).toHaveLength(1);
      expect(invoices[0]).toMatchObject({
        status: 'error', errorCode: 'CUSTOMER_DATA_REQUIRED', auto: true, asaasInvoiceId: 'inv_1',
      });
    });

    it('Asaas sem resposta: a nota fica aguardando (conferida depois), sem registro de erro', async () => {
      setAuto('paid');
      client.createInvoice.mockRejectedValue(new AsaasApiError(503, [], '/invoices'));
      await expect(autoIssueInvoice('c1', 'o182', 'paid')).rejects.toThrow();

      const invoices = await invoicesOf('o182');
      expect(invoices).toHaveLength(1);
      expect(invoices[0]).toMatchObject({ status: 'creating', auto: true });
    });

    it('OS só com peças: registra o erro de "sem serviço"', async () => {
      setAuto('completed');
      seedOrder('o200', { services: [], discount: 0 });
      await autoIssueInvoice('c1', 'o200', 'completed');

      expect((await invoicesOf('o200'))[0]).toMatchObject({ status: 'error', errorCode: 'NO_SERVICES', value: 0 });
    });
  });

  describe('cancelar', () => {
    async function issued(status = 'authorized') {
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      seed(INV(invoice.id), { ...read(INV(invoice.id))!, status });
      return invoice.id;
    }

    it('pede o cancelamento ao Asaas', async () => {
      const id = await issued();
      const result = await cancelInvoice('c1', id);
      expect(client.cancelInvoice).toHaveBeenCalledWith('inv_1', false);
      expect(result.status).toBe('processingCancellation');
    });

    it('cidade que não cancela pela integração', async () => {
      client.getMunicipalOptions.mockResolvedValue({ supportsCancellation: false });
      const id = await issued();
      await expect(cancelInvoice('c1', id)).rejects.toMatchObject({ code: 'CANCEL_NOT_SUPPORTED' });
      await cancelInvoice('c1', id, true);
      expect(client.cancelInvoice).toHaveBeenCalledWith('inv_1', true);
    });

    it('nota de outra conta do Asaas → INVOICE_OTHER_ACCOUNT, sem chamar o Asaas', async () => {
      const id = await issued();
      seed(INV(id), { ...read(INV(id))!, asaasWalletId: 'w_old' });
      await expect(cancelInvoice('c1', id)).rejects.toMatchObject({ code: 'INVOICE_OTHER_ACCOUNT' });
      seed(INV(id), { ...read(INV(id))!, asaasWalletId: 'w1', asaasEnvironment: 'production' });
      await expect(cancelInvoice('c1', id)).rejects.toMatchObject({ code: 'INVOICE_OTHER_ACCOUNT' });
      expect(client.cancelInvoice).not.toHaveBeenCalled();
    });

    it('não cancela nota com erro, já cancelada ou de outra empresa', async () => {
      const id = await issued('error');
      await expect(cancelInvoice('c1', id)).rejects.toMatchObject({ code: 'INVOICE_NOT_CANCELABLE' });
      await expect(cancelInvoice('c1', 'nope')).rejects.toMatchObject({ code: 'INVOICE_NOT_FOUND' });
    });
  });

  describe('eventos do webhook', () => {
    async function created() {
      const invoice = await createInvoice('c1', { orderIds: ['o182', 'o190'] }, USER);
      return invoice.id;
    }

    it('emitida: guarda número, PDF e XML na nota e não mexe nos arquivos da OS', async () => {
      const userDoc = { id: 'd1', fileName: 'laudo.pdf', type: 'other' };
      seedOrder('o182', { documents: [userDoc] });
      const id = await created();
      const asaas = {
        id: 'inv_1', status: 'AUTHORIZED', externalReference: `c1:nf:${id}`,
        pdfUrl: 'https://asaas/pdf', xmlUrl: 'https://asaas/xml', number: '123',
      };
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', asaas);
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', asaas);

      const stored = read(INV(id))!;
      expect(stored).toMatchObject({ status: 'authorized', pdfUrl: 'https://asaas/pdf', xmlUrl: 'https://asaas/xml', number: '123' });
      expect(stored.authorizedAt).toBeDefined();
      // The app saves `documents` whole: the server never writes it (the nota lives in invoices/).
      expect(read('companies/c1/orders/o182')!.documents).toEqual([userDoc]);
      expect(read('companies/c1/orders/o190')!.documents).toBeUndefined();
    });

    it('evento atrasado não volta a situação; cancelada fica final', async () => {
      const id = await created();
      const ref = `c1:nf:${id}`;
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: ref, pdfUrl: 'p' });
      await applyInvoiceEvent('c1', 'INVOICE_SYNCHRONIZED', { id: 'inv_1', status: 'SYNCHRONIZED', externalReference: ref });
      expect(read(INV(id))!.status).toBe('authorized');

      await applyInvoiceEvent('c1', 'INVOICE_CANCELED', { id: 'inv_1', status: 'CANCELED', externalReference: ref });
      expect(read(INV(id))!.status).toBe('canceled');
      expect(read('companies/c1/orders/o182')!.documents).toBeUndefined();
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: ref });
      expect(read(INV(id))!.status).toBe('canceled');
    });

    it('erro guarda o motivo; acha a nota pelo id do Asaas quando falta a referência', async () => {
      const id = await created();
      await applyInvoiceEvent('c1', 'INVOICE_ERROR', { id: 'inv_1', status: 'ERROR', statusDescription: 'Inscrição inválida' });
      expect(read(INV(id))).toMatchObject({ status: 'error', statusDescription: 'Inscrição inválida' });
    });

    it('ignora nota de outra empresa, de outro id do Asaas ou emitida fora do PraticOS', async () => {
      const id = await created();
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: `c2:nf:${id}` });
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_X', status: 'AUTHORIZED', externalReference: `c1:nf:${id}` });
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_other', status: 'AUTHORIZED' });
      expect(read(INV(id))!.status).toBe('synchronized');
    });

    it('nota nossa sem o documento → ALERTA (não some em silêncio)', async () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_7', status: 'AUTHORIZED', externalReference: 'c1:nf:gone' });
      expect(JSON.stringify(errorSpy.mock.calls)).toContain('ALERT');
    });

    it('webhook completa a nota "criando" cujo retorno do Asaas se perdeu', async () => {
      client.createInvoice.mockRejectedValueOnce(new AsaasApiError(504, [], '/invoices'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toBeInstanceOf(AsaasApiError);
      const id = read(LOCK('o182'))!.invoiceId as string;
      await applyInvoiceEvent('c1', 'INVOICE_CREATED', { id: 'inv_5', status: 'SCHEDULED', externalReference: `c1:nf:${id}` });
      expect(read(INV(id))).toMatchObject({ status: 'scheduled', asaasInvoiceId: 'inv_5' });
    });

    describe('nota com erro que volta a valer', () => {
      it('sem outra nota na OS: segue normal', async () => {
        const id = await created();
        const ref = `c1:nf:${id}`;
        await applyInvoiceEvent('c1', 'INVOICE_ERROR', { id: 'inv_1', status: 'ERROR', externalReference: ref });
        await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: ref });
        expect(read(INV(id))!.status).toBe('authorized');
        expect(read(INV(id))!.conflict).toBeUndefined();
      });

      it('a OS já tem outra nota: grava a situação, marca conflito, não trava de novo e avisa', async () => {
        const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
        const a = await created();
        const refA = `c1:nf:${a}`;
        await applyInvoiceEvent('c1', 'INVOICE_ERROR', { id: 'inv_1', status: 'ERROR', externalReference: refA });

        client.createInvoice.mockResolvedValue({ id: 'inv_2', status: 'SCHEDULED' });
        client.authorizeInvoice.mockResolvedValue({ id: 'inv_2', status: 'SYNCHRONIZED' });
        const b = await createInvoice('c1', { orderIds: ['o182'] }, USER);

        await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: refA });
        expect(read(INV(a))).toMatchObject({ status: 'authorized', conflict: true });
        expect(read(LOCK('o182'))!.invoiceId).toBe(b.id);
        expect(read(LOCK('o190'))!.invoiceId).toBe(a);
        expect(JSON.stringify(errorSpy.mock.calls)).toContain('ALERT');
      });
    });
  });
});
