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
  previewInvoice,
} from '../invoice.service';

const USER = { id: 'u1', name: 'Ana' };
const CPF = '52998224725';
const TAXES = { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0 };
const INV = (id: string) => `companies/c1/invoices/${id}`;
const LOCK = (orderId: string) => `companies/c1/private/nfse/orders/${orderId}`;

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  createInvoice: jest.fn(),
  authorizeInvoice: jest.fn(),
  cancelInvoice: jest.fn(),
  getMunicipalOptions: jest.fn(),
  getInvoice: jest.fn(),
  listInvoicesByExternalReference: jest.fn(),
};

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
      expect(preview.customer).toEqual({ id: 'cust1', name: 'João', hasTaxId: true });
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

    it('falha no authorize deixa a nota agendada (o Asaas emite na data)', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, [], '/invoices/inv_1/authorize'));
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(INV(invoice.id))!.status).toBe('scheduled');
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
        id: 'auto-o182', status: 'error', errorCode: 'ASAAS_REJECTED', statusDescription: 'Inscrição municipal inválida',
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
