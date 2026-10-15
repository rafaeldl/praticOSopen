jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { fakeDb, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { setAsaasCredentialProvider } from '../credential-provider';
import { AsaasApiError } from '../asaas-client';
import { addDays, todayInSaoPaulo } from '../charge.service';
import {
  applyDescriptionTemplate,
  applyInvoiceEvent,
  canMoveInvoiceStatus,
  cancelInvoice,
  createInvoice,
  describeOrderNumbers,
  describeServices,
  invoiceDocumentId,
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
};

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
  });
  seed('companies/c1/private/asaas', { mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active' });
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

    it('nota com erro, cancelada ou presa em "criando" não conta como ativa', () => {
      expect(isActiveInvoice({ status: 'error', createdAt: '' })).toBe(false);
      expect(isActiveInvoice({ status: 'canceled', createdAt: '' })).toBe(false);
      expect(isActiveInvoice({ status: 'authorized', createdAt: '' })).toBe(true);
      const old = new Date(Date.now() - 60 * 60 * 1000).toISOString();
      expect(isActiveInvoice({ status: 'creating', createdAt: old })).toBe(false);
      expect(isActiveInvoice({ status: 'creating', createdAt: new Date().toISOString() })).toBe(true);
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
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true });
      await fakeDb.doc('companies/c1/settings/nfse').delete();
      await expect(previewInvoice('c1', ['o182'])).rejects.toMatchObject({ code: 'NFSE_NOT_READY' });
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
      expect(read(LOCK('o182'))!.invoiceId).toBe(invoice.id);
    });

    it('com código digitado manda o código, nunca os dois', async () => {
      seed('companies/c1/settings/nfse', {
        municipalServiceId: null, municipalServiceCode: '14.01', municipalServiceName: 'Manutenção', taxes: TAXES,
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

    it('quando o Asaas recusa, apaga a nota e libera a OS', async () => {
      client.createInvoice.mockRejectedValue(new AsaasApiError(400, [{ code: 'x', description: 'y' }], '/invoices'));
      await expect(createInvoice('c1', { orderIds: ['o182'] }, USER)).rejects.toBeInstanceOf(AsaasApiError);
      expect(read(LOCK('o182'))).toBeUndefined();
    });

    it('falha no authorize deixa a nota agendada (o Asaas emite na data)', async () => {
      client.authorizeInvoice.mockRejectedValue(new AsaasApiError(400, [], '/invoices/inv_1/authorize'));
      const invoice = await createInvoice('c1', { orderIds: ['o182'] }, USER);
      expect(read(INV(invoice.id))!.status).toBe('scheduled');
    });

    it('não mexe em outra empresa', async () => {
      seed('companies/c2/settings/payments', { asaasEnabled: true, asaasConnected: true });
      await expect(createInvoice('c2', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'NFSE_NOT_ENABLED' });
      seed('companies/c2/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true });
      seed('companies/c2/settings/nfse', { municipalServiceId: 'x', municipalServiceName: 'x', taxes: TAXES });
      await expect(createInvoice('c2', { orderIds: ['o182'] }, USER)).rejects.toMatchObject({ code: 'ORDER_NOT_FOUND' });
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

    it('emitida: guarda número, PDF, XML e põe o PDF nos arquivos de cada OS (sem repetir)', async () => {
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
      for (const orderId of ['o182', 'o190']) {
        const docs = read(`companies/c1/orders/${orderId}`)!.documents as any[];
        expect(docs).toHaveLength(1);
        expect(docs[0]).toMatchObject({ id: invoiceDocumentId(id), type: 'invoice', url: 'https://asaas/pdf' });
      }
    });

    it('evento atrasado não volta a situação; cancelada tira o PDF da OS', async () => {
      const id = await created();
      const ref = `c1:nf:${id}`;
      await applyInvoiceEvent('c1', 'INVOICE_AUTHORIZED', { id: 'inv_1', status: 'AUTHORIZED', externalReference: ref, pdfUrl: 'p' });
      await applyInvoiceEvent('c1', 'INVOICE_SYNCHRONIZED', { id: 'inv_1', status: 'SYNCHRONIZED', externalReference: ref });
      expect(read(INV(id))!.status).toBe('authorized');

      await applyInvoiceEvent('c1', 'INVOICE_CANCELED', { id: 'inv_1', status: 'CANCELED', externalReference: ref });
      expect(read(INV(id))!.status).toBe('canceled');
      expect(read('companies/c1/orders/o182')!.documents).toEqual([]);
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
  });
});
