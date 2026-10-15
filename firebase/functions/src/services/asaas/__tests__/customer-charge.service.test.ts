jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { setAsaasCredentialProvider } from '../credential-provider';
import { createOrderCharge } from '../charge.service';
import { AsaasApiError } from '../asaas-client';
import {
  cancelCustomerCharge,
  createCustomerCharge,
  customerChargeExternalReference,
  describeCustomerCharge,
} from '../customer-charge.service';

const USER = { id: 'u1', name: 'Ana' };
const CPF = '52998224725';
const PAST = '2026-10-01T10:00:00.000Z';
const CC = (id: string) => `companies/c1/customerCharges/${id}`;

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  createPayment: jest.fn(),
  deletePayment: jest.fn(),
  deleteInstallment: jest.fn(),
};

function seedOrder(id: string, data: Record<string, unknown> = {}) {
  seed(`companies/c1/orders/${id}`, {
    number: Number(id.replace(/\D/g, '')) || 1,
    status: 'approved',
    total: 100,
    discount: 0,
    paidAmount: 0,
    customer: { id: 'cust1', name: 'João' },
    ...data,
  });
}

function seedBase() {
  seed('companies/c1', { name: 'Oficina da Ana' });
  seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
  seed('companies/c1/private/asaas', { mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active' });
  seed('companies/c1/customers/cust1', { name: 'João', taxId: CPF });
  seedOrder('o182', { total: 100, createdAt: '2026-09-01T10:00:00.000Z' });
  seedOrder('o190', { total: 200, paidAmount: 50, createdAt: '2026-09-10T10:00:00.000Z' });
  seedOrder('o201', { total: 300, createdAt: '2026-10-01T10:00:00.000Z' });
}

describe('customer-charge.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.findCustomerByExternalReference.mockResolvedValue({ id: 'cus_1' });
    client.createPayment.mockResolvedValue({ id: 'pay_cc', invoiceUrl: 'https://sandbox.asaas.com/i/pay_cc', status: 'PENDING' });
    client.deletePayment.mockResolvedValue(undefined);
    seedBase();
  });
  afterEach(() => jest.restoreAllMocks());
  afterAll(() => setAsaasCredentialProvider(null));

  it('referência externa curta, sem lista de OS', () => {
    expect(customerChargeExternalReference('c1', 'abc')).toBe('c1:cc:abc');
  });

  it('descrição com os números das OS cabe em 500 caracteres', () => {
    expect(describeCustomerCharge([182, 190], 'Oficina')).toBe('OS 182, 190 - Oficina');
    const many = Array.from({ length: 200 }, (_, i) => 100000 + i);
    const text = describeCustomerCharge(many, 'Oficina');
    expect(text.length).toBeLessThanOrEqual(500);
    expect(text).toMatch(/e mais \d+ - Oficina$/);
  });

  it('cria uma cobrança para várias OS: valor total, repartição da mais antiga para a mais nova', async () => {
    const charge = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182', 'o190', 'o201'], value: 300 }, USER);

    expect(client.createPayment).toHaveBeenCalledTimes(1);
    const input = client.createPayment.mock.calls[0][0];
    expect(input.value).toBe(300);
    expect(input.externalReference).toBe(`c1:cc:${charge.id}`);
    expect(input.description).toBe('OS 182, 190, 201 - Oficina da Ana');

    const stored = read(CC(charge.id))!;
    expect(stored.allocations).toEqual([
      { orderId: 'o182', orderNumber: 182, amount: 100 },
      { orderId: 'o190', orderNumber: 190, amount: 150 },
      { orderId: 'o201', orderNumber: 201, amount: 50 },
    ]);
    expect(stored.orderIds).toEqual(['o182', 'o190', 'o201']);
    expect(stored.status).toBe('pending');
    expect(stored.customer).toEqual({ id: 'cust1', name: 'João' });
  });

  it('recusa valor acima do que as OS devem', async () => {
    await expect(
      createCustomerCharge('c1', 'cust1', { orderIds: ['o182', 'o190'], value: 251 }, USER),
    ).rejects.toMatchObject({ code: 'INVALID_VALUE' });
    expect(client.createPayment).not.toHaveBeenCalled();
  });

  it('recusa OS de outro cliente, orçamento e cancelada', async () => {
    seedOrder('o300', { customer: { id: 'other' } });
    seedOrder('o301', { status: 'quote' });
    seedOrder('o302', { status: 'canceled' });
    await expect(createCustomerCharge('c1', 'cust1', { orderIds: ['o182', 'o300'], value: 10 }, USER)).rejects.toMatchObject({
      code: 'ORDER_NOT_OF_CUSTOMER',
    });
    await expect(createCustomerCharge('c1', 'cust1', { orderIds: ['o301'], value: 10 }, USER)).rejects.toMatchObject({
      code: 'ORDER_NOT_PAYABLE',
    });
    await expect(createCustomerCharge('c1', 'cust1', { orderIds: ['o302'], value: 10 }, USER)).rejects.toMatchObject({
      code: 'ORDER_NOT_PAYABLE',
    });
    expect(client.createPayment).not.toHaveBeenCalled();
  });

  it('cancela as cobranças de uma OS abertas e a cobrança anterior de várias OS do cliente', async () => {
    seed('companies/c1/orders/o182/charges/ch1', {
      id: 'ch1', asaasPaymentId: 'pay_single', mode: 'single', value: 100, dueDate: '2026-10-20',
      status: 'pending', invoiceUrl: 'x', paidAsaasPaymentIds: [], createdBy: USER, createdAt: PAST,
    });
    seed(CC('old'), {
      id: 'old', customer: { id: 'cust1' }, asaasPaymentId: 'pay_old', value: 100, dueDate: '2026-10-20',
      status: 'overdue', invoiceUrl: 'x', orderIds: ['o182'], allocations: [{ orderId: 'o182', amount: 100 }],
      paidAsaasPaymentIds: [], createdBy: USER, createdAt: PAST,
    });

    const charge = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182', 'o201'], value: 400 }, USER);

    expect(client.deletePayment).toHaveBeenCalledWith('pay_single');
    expect(client.deletePayment).toHaveBeenCalledWith('pay_old');
    expect(read('companies/c1/orders/o182/charges/ch1')!.status).toBe('canceled');
    expect(read(CC('old'))!.status).toBe('canceled');
    expect(read(CC(charge.id))!.status).toBe('pending');
  });

  it('não cancela nada quando o Asaas recusa a cobrança nova', async () => {
    seed(CC('old'), {
      id: 'old', customer: { id: 'cust1' }, asaasPaymentId: 'pay_old', value: 100, dueDate: '2026-10-20',
      status: 'pending', invoiceUrl: 'x', orderIds: ['o182'], allocations: [{ orderId: 'o182', amount: 100 }],
      paidAsaasPaymentIds: [], createdBy: USER, createdAt: PAST,
    });
    client.createPayment.mockRejectedValue(new Error('boom'));

    await expect(createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER)).rejects.toThrow('boom');
    expect(client.deletePayment).not.toHaveBeenCalled();
    expect(read(CC('old'))!.status).toBe('pending');
  });

  it('cobrança de uma OS é recusada enquanto a OS está numa cobrança de várias OS aberta', async () => {
    const charge = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER);
    client.createPayment.mockClear();

    await expect(createOrderCharge('c1', 'o182', { value: 100, mode: 'single' }, USER)).rejects.toMatchObject({
      code: 'CUSTOMER_CHARGE_OPEN',
    });
    expect(client.createPayment).not.toHaveBeenCalled();

    await cancelCustomerCharge('c1', 'cust1', charge.id);
    client.createPayment.mockResolvedValue({ id: 'pay_s', invoiceUrl: 'https://sandbox.asaas.com/i/s', status: 'PENDING' });
    await expect(createOrderCharge('c1', 'o182', { value: 100, mode: 'single' }, USER)).resolves.toMatchObject({
      status: 'pending',
    });
  });

  it('cancelar: só cobrança do mesmo cliente e aberta', async () => {
    const charge = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER);

    await expect(cancelCustomerCharge('c1', 'other', charge.id)).rejects.toMatchObject({ code: 'CHARGE_NOT_FOUND' });
    const canceled = await cancelCustomerCharge('c1', 'cust1', charge.id);
    expect(canceled.status).toBe('canceled');
    expect(client.deletePayment).toHaveBeenCalledWith('pay_cc');
    await expect(cancelCustomerCharge('c1', 'cust1', charge.id)).rejects.toMatchObject({ code: 'CHARGE_NOT_OPEN' });
  });

  describe('uma cobrança por dívida mesmo com criações ao mesmo tempo', () => {
    const OLD_CC = {
      id: 'old', customer: { id: 'cust1' }, asaasPaymentId: 'pay_old', value: 100, dueDate: '2026-10-20',
      status: 'pending', invoiceUrl: 'x', orderIds: ['o182'], allocations: [{ orderId: 'o182', amount: 100 }],
      paidAsaasPaymentIds: [], createdBy: USER, createdAt: PAST,
    };
    const SINGLE = {
      id: 'ch1', asaasPaymentId: 'pay_single', mode: 'single', value: 100, dueDate: '2026-10-20',
      status: 'pending', invoiceUrl: 'x', paidAsaasPaymentIds: [], createdBy: USER, createdAt: PAST,
    };
    // createdAt has millisecond precision: let the clock move between creates.
    const tick = () => new Promise((resolve) => setTimeout(resolve, 5));
    const openCustomerCharges = (ids: string[]) => ids.map((id) => read(CC(id))?.status);

    it('dois pedidos juntos (repetição depois de erro de rede): fica só o mais novo', async () => {
      let first: { id: string } | undefined;
      client.createPayment
        .mockImplementationOnce(async () => {
          // While the first request waits for Asaas, the retry runs to the end.
          first = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER);
          await tick();
          return { id: 'pay_a', invoiceUrl: 'https://sandbox.asaas.com/i/a', status: 'PENDING' };
        })
        .mockResolvedValueOnce({ id: 'pay_b', invoiceUrl: 'https://sandbox.asaas.com/i/b', status: 'PENDING' });

      const second = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER);

      expect(openCustomerCharges([first!.id, second.id])).toEqual(['canceled', 'pending']);
      expect(client.deletePayment).toHaveBeenCalledWith('pay_b');
    });

    it('apareceu um link mais novo antes de terminar: este é desfeito e o mais novo fica', async () => {
      client.createPayment.mockImplementationOnce(async () => {
        seed(CC('newer'), { ...OLD_CC, id: 'newer', asaasPaymentId: 'pay_newer', createdAt: '2099-01-01T00:00:00.000Z' });
        return { id: 'pay_cc', invoiceUrl: 'x', status: 'PENDING' };
      });

      await expect(
        createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER),
      ).rejects.toMatchObject({ code: 'CHARGE_SUPERSEDED' });
      expect(read(CC('newer'))!.status).toBe('pending');
      expect(client.deletePayment).toHaveBeenCalledWith('pay_cc');
      expect(client.deletePayment).not.toHaveBeenCalledWith('pay_newer');
    });

    it('cobrança de uma OS criada junto com a de várias OS: a mais nova fica, a outra é cancelada', async () => {
      let customerCharge: { id: string } | undefined;
      client.createPayment
        .mockImplementationOnce(async () => {
          // The single-order request passed the "no open multi-order charge" check;
          // meanwhile the multi-order charge is created.
          customerCharge = await createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER);
          await tick();
          return { id: 'pay_s', invoiceUrl: 'x', status: 'PENDING' };
        })
        .mockResolvedValueOnce({ id: 'pay_cc', invoiceUrl: 'x', status: 'PENDING' });

      const single = await createOrderCharge('c1', 'o182', { value: 100, mode: 'single' }, USER);

      expect(read(`companies/c1/orders/o182/charges/${single.id}`)!.status).toBe('pending');
      expect(read(CC(customerCharge!.id))!.status).toBe('canceled');
    });

    it('confere de novo antes de cancelar: parcelamento pago aparecido no meio desfaz o novo sem cancelar nada', async () => {
      seed(CC('old'), OLD_CC);
      client.createPayment.mockImplementationOnce(async () => {
        seed('companies/c1/orders/o182/charges/ch2', {
          ...SINGLE, id: 'ch2', mode: 'cardInstallments', asaasInstallmentId: 'ins_1', paidAsaasPaymentIds: ['p1'],
        });
        return { id: 'pay_cc', invoiceUrl: 'x', status: 'PENDING' };
      });

      await expect(
        createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER),
      ).rejects.toMatchObject({ code: 'INSTALLMENTS_IN_PROGRESS' });
      expect(read(CC('old'))!.status).toBe('pending');
      expect(client.deletePayment).toHaveBeenCalledTimes(1);
      expect(client.deletePayment).toHaveBeenCalledWith('pay_cc');
      expect(client.deleteInstallment).not.toHaveBeenCalled();
    });

    it('um link anterior já cancelado e outro falhou: desfaz o novo e pede um link novo', async () => {
      seed('companies/c1/orders/o182/charges/ch1', SINGLE);
      seed(CC('old'), OLD_CC);
      client.deletePayment.mockImplementation(async (id: string) => {
        if (id === 'pay_old') throw new AsaasApiError(500, [], '/payments/pay_old');
      });

      await expect(
        createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER),
      ).rejects.toMatchObject({ code: 'PREVIOUS_LINK_CANCELED', httpStatus: 409 });
      expect(read('companies/c1/orders/o182/charges/ch1')!.status).toBe('canceled');
      const created = client.createPayment.mock.calls.length;
      expect(created).toBe(1);
      expect(client.deletePayment).toHaveBeenCalledWith('pay_cc');
    });

    it('nada cancelado ainda quando falha: devolve o erro original', async () => {
      seed(CC('old'), OLD_CC);
      client.deletePayment.mockImplementation(async (id: string) => {
        if (id === 'pay_old') throw new AsaasApiError(500, [], '/payments/pay_old');
      });

      await expect(
        createCustomerCharge('c1', 'cust1', { orderIds: ['o182'], value: 100 }, USER),
      ).rejects.toBeInstanceOf(AsaasApiError);
      expect(read(CC('old'))!.status).toBe('pending');
    });
  });
});
