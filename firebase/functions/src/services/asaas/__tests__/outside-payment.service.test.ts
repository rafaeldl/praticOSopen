jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { AsaasApiError } from '../asaas-client';
import { setAsaasCredentialProvider } from '../credential-provider';
import {
  decideOutsideAction,
  paidOutsideSince,
  reconcileOutsidePayments,
} from '../outside-payment.service';

const client = {
  receiveInCash: jest.fn(),
  updatePayment: jest.fn(),
  deletePayment: jest.fn(),
  deleteInstallment: jest.fn(),
};

const CREATED = '2026-10-10T10:00:00.000Z';
const AFTER = '2026-10-11T10:00:00.000Z';
const BEFORE = '2026-10-09T10:00:00.000Z';
const ORDER = 'companies/c1/orders/o1';
const CHARGE = `${ORDER}/charges/ch1`;
const CC = 'companies/c1/customerCharges/cc1';

function pay(id: string, amount: number, createdAt = AFTER, type = 'payment') {
  return { id, type, amount, createdAt, createdBy: { id: 'u1', name: 'Ana' } };
}

function seedOrder(path: string, data: Record<string, unknown>) {
  seed(path, { status: 'done', total: 100, paidAmount: 0, transactions: [], customer: { id: 'cust1' }, ...data });
}

function seedSingle(data: Record<string, unknown> = {}) {
  seed(CHARGE, {
    id: 'ch1', asaasPaymentId: 'pay_1', mode: 'single', value: 100, dueDate: '2026-10-20', status: 'pending',
    invoiceUrl: 'x', paidAsaasPaymentIds: [], createdBy: { id: 'u1', name: 'Ana' }, createdAt: CREATED, ...data,
  });
}

function seedCustomerCharge(data: Record<string, unknown> = {}) {
  seed(CC, {
    id: 'cc1', customer: { id: 'cust1' }, asaasPaymentId: 'pay_cc', value: 300, dueDate: '2026-10-20',
    status: 'pending', invoiceUrl: 'x', orderIds: ['o1', 'o2'],
    allocations: [
      { orderId: 'o1', orderNumber: 1, amount: 100 },
      { orderId: 'o2', orderNumber: 2, amount: 200 },
    ],
    paidAsaasPaymentIds: [], createdBy: { id: 'u1', name: 'Ana' }, createdAt: CREATED, ...data,
  });
}

describe('outside-payment.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.receiveInCash.mockResolvedValue({ id: 'pay_1', status: 'RECEIVED_IN_CASH' });
    client.updatePayment.mockResolvedValue({ id: 'pay_1', status: 'PENDING' });
    client.deletePayment.mockResolvedValue(undefined);
    seed('companies/c1', { name: 'Oficina' });
  });
  afterEach(() => jest.restoreAllMocks());
  afterAll(() => setAsaasCredentialProvider(null));

  describe('decideOutsideAction (baixa x valor novo)', () => {
    it('ainda deve tudo: nada', () => {
      expect(decideOutsideAction(100, 100, 0)).toEqual({ action: 'none' });
      expect(decideOutsideAction(100, 150, 0)).toEqual({ action: 'none' });
    });
    it('pagou tudo por fora: baixa (receiveInCash) com o que entrou', () => {
      expect(decideOutsideAction(100, 0, 100)).toEqual({ action: 'receiveInCash', value: 100 });
      expect(decideOutsideAction(100, 0, 250)).toEqual({ action: 'receiveInCash', value: 100 });
    });
    it('pagou parte: valor novo (PUT), nunca baixa', () => {
      expect(decideOutsideAction(100, 40.5, 59.5)).toEqual({ action: 'update', value: 40.5 });
    });
    it('não deve mais nada sem dinheiro entrar (desconto, OS cancelada): cancela o link', () => {
      expect(decideOutsideAction(100, 0, 0)).toEqual({ action: 'cancel' });
    });
  });

  it('só conta pagamento registrado por fora depois do link', () => {
    const order = {
      transactions: [pay('a', 10, BEFORE), pay('b', 20), pay('asaas_pay_x', 30), pay('d', 5, AFTER, 'discount')],
    } as any;
    expect(paidOutsideSince(order, CREATED)).toBe(20);
  });

  describe('cobrança de uma OS', () => {
    it('pagou tudo por fora: receiveInCash e marca paga por fora', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedSingle();

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.receiveInCash).toHaveBeenCalledWith('pay_1', expect.objectContaining({ value: 100, notifyCustomer: false }));
      expect(client.updatePayment).not.toHaveBeenCalled();
      const charge = read(CHARGE)!;
      expect(charge).toMatchObject({ status: 'paid', paidOutside: true });
      expect(charge.settlingOutsideAt).toBeUndefined();
      expect(charge.adjustingUntil).toBeUndefined();
    });

    it('pagou parte por fora: PUT com o que falta, link continua', async () => {
      seedOrder(ORDER, { paidAmount: 60, transactions: [pay('t1', 60)] });
      seedSingle();

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.updatePayment).toHaveBeenCalledWith('pay_1', { value: 40 });
      expect(client.receiveInCash).not.toHaveBeenCalled();
      expect(read(CHARGE)!).toMatchObject({ status: 'pending', value: 40 });
    });

    it('Asaas recusa o valor novo (mínimo): cancela o link', async () => {
      seedOrder(ORDER, { paidAmount: 99, transactions: [pay('t1', 99)] });
      seedSingle();
      client.updatePayment.mockRejectedValue(new AsaasApiError(400, [], '/payments/pay_1'));

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.deletePayment).toHaveBeenCalledWith('pay_1');
      expect(read(CHARGE)!.status).toBe('canceled');
    });

    it('falha no receiveInCash não deixa a cobrança marcada e propaga o erro', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedSingle();
      client.receiveInCash.mockRejectedValue(new Error('down'));

      await expect(reconcileOutsidePayments('c1', 'o1')).rejects.toThrow('down');
      const charge = read(CHARGE)!;
      expect(charge.status).toBe('pending');
      expect(charge.settlingOutsideAt).toBeUndefined();
      expect(charge.adjustingUntil).toBeUndefined();
    });

    it('nada muda quando a OS ainda deve o valor do link', async () => {
      seedOrder(ORDER, { total: 300, paidAmount: 100, transactions: [pay('t1', 100)] });
      seedSingle();
      await reconcileOutsidePayments('c1', 'o1');
      expect(client.updatePayment).not.toHaveBeenCalled();
      expect(client.receiveInCash).not.toHaveBeenCalled();
    });

    it('parcelamento e OS cancelada ficam de fora', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedSingle({ mode: 'installments', asaasInstallmentId: 'ins_1' });
      await reconcileOutsidePayments('c1', 'o1');

      seedOrder(ORDER, { status: 'canceled', paidAmount: 0 });
      seedSingle();
      await reconcileOutsidePayments('c1', 'o1');

      expect(client.receiveInCash).not.toHaveBeenCalled();
      expect(client.updatePayment).not.toHaveBeenCalled();
      expect(client.deletePayment).not.toHaveBeenCalled();
    });

    it('com a vez tomada por outra execução, não faz nada', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedSingle({ adjustingUntil: new Date(Date.now() + 30000).toISOString() });
      await reconcileOutsidePayments('c1', 'o1');
      expect(client.receiveInCash).not.toHaveBeenCalled();
    });
  });

  describe('cobrança de várias OS', () => {
    it('recebido por fora em parte: valor novo e repartição atualizada', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedOrder('companies/c1/orders/o2', { total: 200 });
      seedCustomerCharge();

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.updatePayment).toHaveBeenCalledWith('pay_cc', { value: 200, description: 'OS 2 - Oficina' });
      const charge = read(CC)!;
      expect(charge.value).toBe(200);
      expect(charge.allocations).toEqual([{ orderId: 'o2', orderNumber: 2, amount: 200 }]);
      expect(charge.orderIds).toEqual(['o2']);
    });

    it('recebido por fora tudo: baixa', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedOrder('companies/c1/orders/o2', { total: 200, paidAmount: 200, transactions: [pay('t2', 200)] });
      seedCustomerCharge();

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.receiveInCash).toHaveBeenCalledWith('pay_cc', expect.objectContaining({ value: 300 }));
      expect(read(CC)!).toMatchObject({ status: 'paid', paidOutside: true });
    });

    it('as OS foram canceladas, nada recebido: cancela o link em vez de dar baixa', async () => {
      seedOrder(ORDER, { status: 'canceled' });
      seedOrder('companies/c1/orders/o2', { status: 'canceled', total: 200 });
      seedCustomerCharge();

      await reconcileOutsidePayments('c1', 'o1');

      expect(client.receiveInCash).not.toHaveBeenCalled();
      expect(client.deletePayment).toHaveBeenCalledWith('pay_cc');
      expect(read(CC)!.status).toBe('canceled');
    });

    it('cobrança já paga pelo Asaas não é mexida', async () => {
      seedOrder(ORDER, { paidAmount: 100, transactions: [pay('t1', 100)] });
      seedCustomerCharge({ status: 'paid', paidAsaasPaymentIds: ['pay_cc'] });
      await reconcileOutsidePayments('c1', 'o1');
      expect(client.receiveInCash).not.toHaveBeenCalled();
      expect(client.updatePayment).not.toHaveBeenCalled();
    });
  });
});
