jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { fakeDb, list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { AsaasApiError } from '../asaas-client';
import { setAsaasCredentialProvider } from '../credential-provider';
import {
  addDays,
  cancelOpenChargesForOrder,
  cancelOrderCharge,
  createOrderCharge,
  defaultDueDate,
  getOpenOrLatestPaidCharge,
  handleOrderStatusChange,
  todayInSaoPaulo,
} from '../charge.service';

const USER = { id: 'u1', name: 'Ana' };
const CPF = '52998224725';
const ORDER_PATH = 'companies/c1/orders/o1';

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  createPayment: jest.fn(),
  deletePayment: jest.fn(),
  deleteInstallment: jest.fn(),
};

function seedBase(options: { taxId?: string; order?: Record<string, unknown>; connected?: boolean } = {}) {
  seed('companies/c1', { name: 'Oficina da Ana' });
  seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: options.connected ?? true });
  seed('companies/c1/customers/cust1', {
    name: 'João',
    email: 'joao@cliente.com',
    ...(options.taxId !== undefined ? { taxId: options.taxId } : {}),
  });
  seed(ORDER_PATH, {
    number: 42,
    status: 'approved',
    total: 1000,
    discount: 0,
    paidAmount: 0,
    customer: { id: 'cust1', name: 'João' },
    ...options.order,
  });
}

function seedCharge(id: string, data: Record<string, unknown>) {
  seed(`${ORDER_PATH}/charges/${id}`, {
    id,
    asaasPaymentId: `pay_${id}`,
    mode: 'single',
    value: 100,
    dueDate: '2026-10-07',
    status: 'pending',
    invoiceUrl: `https://sandbox.asaas.com/i/${id}`,
    paidAsaasPaymentIds: [],
    createdBy: USER,
    createdAt: '2026-10-04T10:00:00.000Z',
    ...data,
  });
}

describe('charge.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.findCustomerByExternalReference.mockResolvedValue(null);
    client.createCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
    client.createPayment.mockResolvedValue({
      id: 'pay_1',
      invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
      status: 'PENDING',
      installment: null,
    });
    client.deletePayment.mockResolvedValue(undefined);
    client.deleteInstallment.mockResolvedValue(undefined);
  });

  afterAll(() => setAsaasCredentialProvider(null));

  describe('datas', () => {
    it('hoje em America/Sao_Paulo', () => {
      // 02:00 UTC de 5/out = 23:00 de 4/out em São Paulo
      expect(todayInSaoPaulo(new Date('2026-10-05T02:00:00.000Z'))).toBe('2026-10-04');
    });

    it('vencimento padrão é hoje + 3 dias', () => {
      expect(defaultDueDate(new Date('2026-10-30T15:00:00.000Z'))).toBe('2026-11-02');
      expect(addDays('2026-12-30', 3)).toBe('2027-01-02');
    });
  });

  describe('createOrderCharge', () => {
    it('à vista: cria cliente, cobrança UNDEFINED e grava o documento', async () => {
      seedBase({ taxId: CPF });

      const charge = await createOrderCharge('c1', 'o1', { value: 1000, mode: 'single' }, USER);

      expect(client.createCustomer).toHaveBeenCalledWith({
        name: 'João',
        cpfCnpj: CPF,
        email: 'joao@cliente.com',
        externalReference: 'cust1',
        notificationDisabled: true,
      });
      expect(read('companies/c1/private/asaas/customers/cust1')).toEqual({ asaasCustomerId: 'cus_1' });

      const paymentInput = client.createPayment.mock.calls[0][0];
      expect(paymentInput).toEqual({
        customer: 'cus_1',
        billingType: 'UNDEFINED',
        value: 1000,
        dueDate: defaultDueDate(),
        description: 'OS #42 - Oficina da Ana',
        externalReference: `c1:o1:${charge.id}`,
      });

      expect(charge).toMatchObject({
        asaasPaymentId: 'pay_1',
        mode: 'single',
        value: 1000,
        status: 'pending',
        invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
        paidAsaasPaymentIds: [],
        createdBy: USER,
      });
      expect(read(`${ORDER_PATH}/charges/${charge.id}`)).toEqual(charge);
    });

    it('parcelado no cartão: CREDIT_CARD + installmentCount + totalValue', async () => {
      seedBase({ taxId: CPF });
      client.createPayment.mockResolvedValue({
        id: 'pay_1',
        invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
        installment: 'ins_1',
      });

      const charge = await createOrderCharge(
        'c1',
        'o1',
        { value: 700, mode: 'cardInstallments', installmentCount: 3, dueDate: '2099-01-10' },
        USER,
      );

      const paymentInput = client.createPayment.mock.calls[0][0];
      expect(paymentInput).toMatchObject({
        billingType: 'CREDIT_CARD',
        installmentCount: 3,
        totalValue: 700,
        dueDate: '2099-01-10',
      });
      expect(paymentInput.value).toBeUndefined();
      expect(charge).toMatchObject({ mode: 'cardInstallments', installmentCount: 3, asaasInstallmentId: 'ins_1' });
    });

    it('reusa o cliente mapeado sem chamar o Asaas', async () => {
      seedBase({ taxId: CPF });
      seed('companies/c1/private/asaas/customers/cust1', { asaasCustomerId: 'cus_mapped' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.findCustomerByExternalReference).not.toHaveBeenCalled();
      expect(client.createCustomer).not.toHaveBeenCalled();
      expect(client.createPayment.mock.calls[0][0].customer).toBe('cus_mapped');
    });

    it('acha cliente existente no Asaas pelo externalReference', async () => {
      seedBase({ taxId: CPF });
      client.findCustomerByExternalReference.mockResolvedValue({ id: 'cus_existing', name: 'João' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.findCustomerByExternalReference).toHaveBeenCalledWith('cust1');
      expect(client.createCustomer).not.toHaveBeenCalled();
      expect(read('companies/c1/private/asaas/customers/cust1')).toEqual({ asaasCustomerId: 'cus_existing' });
    });

    it('valor acima do saldo restante → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF, order: { paidAmount: 300 } });
      const error = await createOrderCharge('c1', 'o1', { value: 700.01, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');
      expect(client.createPayment).not.toHaveBeenCalled();
    });

    it('valor zero → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge('c1', 'o1', { value: 0, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');
    });

    it('parcelas fora de 2–12 → INVALID_INSTALLMENT_COUNT', async () => {
      seedBase({ taxId: CPF });
      for (const installmentCount of [1, 13, undefined]) {
        const error = await createOrderCharge(
          'c1', 'o1', { value: 100, mode: 'cardInstallments', installmentCount }, USER,
        ).catch((e) => e);
        expect(error.code).toBe('INVALID_INSTALLMENT_COUNT');
      }
    });

    it('vencimento no passado → INVALID_DUE_DATE', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', dueDate: '2020-01-01' }, USER,
      ).catch((e) => e);
      expect(error.code).toBe('INVALID_DUE_DATE');
    });

    it('conta não conectada → ASAAS_NOT_CONNECTED', async () => {
      seedBase({ taxId: CPF, connected: false });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_NOT_CONNECTED');
    });

    it('OS inexistente → ORDER_NOT_FOUND', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge('c1', 'nope', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ORDER_NOT_FOUND');
    });

    it('OS cancelada → ORDER_CANCELED', async () => {
      seedBase({ taxId: CPF, order: { status: 'canceled' } });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ORDER_CANCELED');
    });

    it('OS sem cliente → CUSTOMER_REQUIRED', async () => {
      seedBase({ taxId: CPF, order: { customer: null } });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('CUSTOMER_REQUIRED');
    });

    it('cliente sem taxId e sem customerTaxId → TAX_ID_REQUIRED', async () => {
      seedBase();
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('TAX_ID_REQUIRED');
      expect(client.createPayment).not.toHaveBeenCalled();
    });

    it('falha de validação não cancela a cobrança aberta existente', async () => {
      seedBase();
      seedCharge('old', { status: 'pending' });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('TAX_ID_REQUIRED');
      expect(client.deletePayment).not.toHaveBeenCalled();
      expect(read(`${ORDER_PATH}/charges/old`)!.status).toBe('pending');
    });

    it('customerTaxId inválido → INVALID_TAX_ID', async () => {
      seedBase();
      const error = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', customerTaxId: '111.111.111-11' }, USER,
      ).catch((e) => e);
      expect(error.code).toBe('INVALID_TAX_ID');
    });

    it('customerTaxId válido é salvo no cliente normalizado', async () => {
      seedBase();
      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single', customerTaxId: '529.982.247-25' }, USER);
      expect(read('companies/c1/customers/cust1')!.taxId).toBe(CPF);
      expect(client.createCustomer.mock.calls[0][0].cpfCnpj).toBe(CPF);
    });

    it('CNPJ alfanumérico do corpo é aceito e salvo em maiúsculas', async () => {
      seedBase();
      await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', customerTaxId: '12.abc.345/01de-35' }, USER,
      );
      expect(read('companies/c1/customers/cust1')!.taxId).toBe('12ABC34501DE35');
      expect(client.createCustomer.mock.calls[0][0].cpfCnpj).toBe('12ABC34501DE35');
    });

    it('taxId do cliente com máscara é normalizado e não reescrito sem customerTaxId', async () => {
      seedBase({ taxId: '529.982.247-25' });
      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);
      expect(client.createCustomer.mock.calls[0][0].cpfCnpj).toBe(CPF);
      expect(read('companies/c1/customers/cust1')!.taxId).toBe('529.982.247-25');
    });

    it('taxId salvo inválido e sem customerTaxId → INVALID_TAX_ID', async () => {
      seedBase({ taxId: '11111111111' });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_TAX_ID');
      expect(client.createPayment).not.toHaveBeenCalled();
    });

    it('lê o taxId do documento do cliente, não do agregado da OS', async () => {
      seedBase({ taxId: CPF, order: { customer: { id: 'cust1', name: 'João', taxId: '11111111111' } } });
      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);
      expect(client.createCustomer.mock.calls[0][0].cpfCnpj).toBe(CPF);
    });

    it('cliente da OS sem documento → CUSTOMER_REQUIRED', async () => {
      seedBase({ taxId: CPF, order: { customer: { id: 'ghost', name: 'Fantasma' } } });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('CUSTOMER_REQUIRED');
    });

    it('saldo = total − pago (total já é líquido de desconto)', async () => {
      seedBase({ taxId: CPF, order: { total: 900, discount: 100, paidAmount: 0 } });
      const error = await createOrderCharge('c1', 'o1', { value: 900.01, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');

      const charge = await createOrderCharge('c1', 'o1', { value: 900, mode: 'single' }, USER);
      expect(charge.value).toBe(900);
    });

    it('arredonda o valor a centavos (tolerância de meio centavo)', async () => {
      seedBase({ taxId: CPF, order: { paidAmount: 300 } });
      const charge = await createOrderCharge('c1', 'o1', { value: 700.004, mode: 'single' }, USER);
      expect(charge.value).toBe(700);
      expect(client.createPayment.mock.calls[0][0].value).toBe(700);
    });

    it('OS já quitada → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF, order: { paidAmount: 1000 } });
      const error = await createOrderCharge('c1', 'o1', { value: 0.01, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');
    });

    it('valor não numérico → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF });
      for (const value of [NaN, -10, Infinity, 'abc' as unknown as number]) {
        const error = await createOrderCharge('c1', 'o1', { value, mode: 'single' }, USER).catch((e) => e);
        expect(error.code).toBe('INVALID_VALUE');
      }
    });

    it('parcela não inteira → INVALID_INSTALLMENT_COUNT', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'cardInstallments', installmentCount: 2.5 }, USER,
      ).catch((e) => e);
      expect(error.code).toBe('INVALID_INSTALLMENT_COUNT');
    });

    it('à vista ignora installmentCount', async () => {
      seedBase({ taxId: CPF });
      const charge = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', installmentCount: 3 }, USER,
      );
      expect(client.createPayment.mock.calls[0][0].installmentCount).toBeUndefined();
      expect(charge.installmentCount).toBeUndefined();
    });

    it('vencimento com formato ou data inválida → INVALID_DUE_DATE', async () => {
      seedBase({ taxId: CPF });
      for (const dueDate of ['10/01/2099', '2099-13-01', '2099-02-30', '2099-1-1']) {
        const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single', dueDate }, USER)
          .catch((e) => e);
        expect(error.code).toBe('INVALID_DUE_DATE');
      }
    });

    it('vencimento hoje é aceito', async () => {
      seedBase({ taxId: CPF });
      const today = todayInSaoPaulo();
      const charge = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single', dueDate: today }, USER);
      expect(charge.dueDate).toBe(today);
    });

    it('e-mail inválido do cliente não é enviado ao Asaas', async () => {
      seedBase({ taxId: CPF });
      seed('companies/c1/customers/cust1', { name: 'João', email: 'not-an-email', taxId: CPF });
      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);
      expect(client.createCustomer.mock.calls[0][0]).not.toHaveProperty('email');
    });

    it('erro do Asaas ao criar cobrança propaga e não grava documento', async () => {
      seedBase({ taxId: CPF });
      client.createPayment.mockRejectedValue(new AsaasApiError(400, [{ code: 'x', description: 'bad' }], '/payments'));
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error).toBeInstanceOf(AsaasApiError);
      expect(list(`${ORDER_PATH}/charges`)).toHaveLength(0);
    });

    it('falha ao gravar a cobrança → cancela no Asaas e propaga', async () => {
      seedBase({ taxId: CPF });
      client.createPayment.mockResolvedValue({
        id: 'pay_1',
        invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
        installment: 'ins_1',
      });
      const originalSet = fakeDb.write.bind(fakeDb);
      const writeSpy = jest.spyOn(fakeDb, 'write').mockImplementation((path, data, mode) => {
        if (path.startsWith(`${ORDER_PATH}/charges/`) && mode === 'set') throw new Error('write failed');
        return originalSet(path, data, mode);
      });

      const error = await createOrderCharge(
        'c1', 'o1', { value: 300, mode: 'cardInstallments', installmentCount: 3 }, USER,
      ).catch((e) => e);
      writeSpy.mockRestore();

      expect(error.message).toBe('write failed');
      expect(client.deleteInstallment).toHaveBeenCalledWith('ins_1');
    });

    it('cancela a cobrança aberta anterior antes de criar outra', async () => {
      seedBase({ taxId: CPF });
      seedCharge('old', { status: 'pending' });
      seedCharge('oldInst', { status: 'overdue', mode: 'cardInstallments', asaasInstallmentId: 'ins_old' });
      seedCharge('paid', { status: 'paid' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.deletePayment).toHaveBeenCalledWith('pay_old');
      expect(client.deleteInstallment).toHaveBeenCalledWith('ins_old');
      expect(read(`${ORDER_PATH}/charges/old`)!.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/oldInst`)!.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/paid`)!.status).toBe('paid');
      expect(list(`${ORDER_PATH}/charges`).filter((c) => c.data.status === 'pending')).toHaveLength(1);
    });
  });

  describe('cancelOrderCharge', () => {
    it('cancela cobrança à vista com deletePayment', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});

      const charge = await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(client.deletePayment).toHaveBeenCalledWith('pay_ch1');
      expect(charge.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/ch1`)!.status).toBe('canceled');
    });

    it('cancela parcelamento com deleteInstallment', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', { mode: 'cardInstallments', asaasInstallmentId: 'ins_1' });

      await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(client.deleteInstallment).toHaveBeenCalledWith('ins_1');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });

    it('404 no Asaas conta como já cancelada', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});
      client.deletePayment.mockRejectedValue(new AsaasApiError(404, [], '/payments/pay_ch1'));

      const charge = await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(charge.status).toBe('canceled');
    });

    it('cobrança inexistente → CHARGE_NOT_FOUND', async () => {
      seedBase({ taxId: CPF });
      const error = await cancelOrderCharge('c1', 'o1', 'nope').catch((e) => e);
      expect(error.code).toBe('CHARGE_NOT_FOUND');
    });

    it('erro do Asaas (não 404) propaga e mantém a cobrança aberta', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});
      client.deletePayment.mockRejectedValue(new AsaasApiError(400, [], '/payments/pay_ch1'));

      const error = await cancelOrderCharge('c1', 'o1', 'ch1').catch((e) => e);

      expect(error).toBeInstanceOf(AsaasApiError);
      expect(read(`${ORDER_PATH}/charges/ch1`)!.status).toBe('pending');
    });

    it('não sobrescreve status pago gravado pelo webhook durante o cancelamento', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});
      client.deletePayment.mockImplementation(async () => {
        // Webhook marks the charge paid while the Asaas call is in flight.
        seed(`${ORDER_PATH}/charges/ch1`, { ...read(`${ORDER_PATH}/charges/ch1`), status: 'paid' });
      });

      const charge = await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(read(`${ORDER_PATH}/charges/ch1`)!.status).toBe('paid');
      expect(charge.status).toBe('paid');
    });

    it('cobrança paga → CHARGE_NOT_OPEN', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', { status: 'paid' });
      const error = await cancelOrderCharge('c1', 'o1', 'ch1').catch((e) => e);
      expect(error.code).toBe('CHARGE_NOT_OPEN');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });
  });

  describe('cancelOpenChargesForOrder / handleOrderStatusChange', () => {
    it('cancela todas as abertas e continua se uma falhar', async () => {
      seedBase({ taxId: CPF });
      seedCharge('a', {});
      seedCharge('b', {});
      client.deletePayment.mockImplementation(async (id: string) => {
        if (id === 'pay_a') throw new AsaasApiError(500, [], '/payments/pay_a');
      });
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);

      await cancelOpenChargesForOrder('c1', 'o1');

      expect(read(`${ORDER_PATH}/charges/a`)!.status).toBe('pending');
      expect(read(`${ORDER_PATH}/charges/b`)!.status).toBe('canceled');
      expect(errorSpy).toHaveBeenCalled();
      errorSpy.mockRestore();
    });

    it('OS mudou para canceled com Asaas conectado → cancela', async () => {
      seedBase({ taxId: CPF });
      seedCharge('a', {});
      await handleOrderStatusChange('c1', 'o1', 'approved', 'canceled');
      expect(read(`${ORDER_PATH}/charges/a`)!.status).toBe('canceled');
    });

    it('ignora quando não mudou para canceled ou Asaas desconectado', async () => {
      seedBase({ taxId: CPF, connected: false });
      seedCharge('a', {});
      await handleOrderStatusChange('c1', 'o1', 'approved', 'canceled');
      await handleOrderStatusChange('c1', 'o1', 'canceled', 'canceled');
      await handleOrderStatusChange('c1', 'o1', 'approved', 'done');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });
  });

  describe('getOpenOrLatestPaidCharge', () => {
    it('prefere a aberta; senão a última paga; senão null', async () => {
      expect(await getOpenOrLatestPaidCharge('c1', 'o1')).toBeNull();

      seedCharge('paid1', { status: 'paid', paidAt: '2026-10-01T10:00:00.000Z' });
      seedCharge('paid2', { status: 'paid', paidAt: '2026-10-02T10:00:00.000Z' });
      seedCharge('canceled', { status: 'canceled', createdAt: '2026-10-05T10:00:00.000Z' });
      expect((await getOpenOrLatestPaidCharge('c1', 'o1'))!.id).toBe('paid2');

      seedCharge('open', { status: 'overdue' });
      expect((await getOpenOrLatestPaidCharge('c1', 'o1'))!.id).toBe('open');
    });
  });
});

