jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import {
  ASAAS_ACTOR,
  applyAsaasPayment,
  asaasTransactionId,
  buildAsaasTransaction,
  computePaymentFields,
  describeAsaasPayment,
} from '../order-payment.service';
import type { AsaasPaymentEvent, OrderCharge } from '../../../models/asaas.types';

const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

function seedOrder(overrides: Record<string, unknown> = {}) {
  seed(ORDER_PATH, {
    number: 42,
    total: 1000,
    paidAmount: 0,
    paid: false,
    payment: 'unpaid',
    transactions: [],
    ...overrides,
  });
}

function seedCharge(overrides: Partial<OrderCharge> = {}) {
  seed(CHARGE_PATH, {
    id: 'ch1',
    asaasPaymentId: 'pay_1',
    mode: 'single',
    value: 1000,
    dueDate: '2026-10-10',
    status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/1',
    paidAsaasPaymentIds: [],
    createdBy: { id: 'u1', name: 'Ana' },
    createdAt: '2026-10-04T10:00:00.000Z',
    ...overrides,
  });
}

function payment(overrides: Partial<AsaasPaymentEvent> = {}): AsaasPaymentEvent {
  return {
    id: 'pay_1',
    value: 1000,
    netValue: 990.01,
    billingType: 'PIX',
    status: 'RECEIVED',
    externalReference: 'c1:o1:ch1',
    installment: null,
    description: 'OS #42 - Oficina',
    ...overrides,
  };
}

function hasUndefined(value: unknown): boolean {
  if (value === undefined) return true;
  if (Array.isArray(value)) return value.some(hasUndefined);
  if (value && typeof value === 'object') return Object.values(value).some(hasUndefined);
  return false;
}

describe('order-payment.service - applyAsaasPayment', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('lança o pagamento Pix na OS e marca a cobrança como paga', async () => {
    seedOrder();
    seedCharge();

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    expect(result).toEqual({ applied: true });
    const order = read(ORDER_PATH)!;
    expect(order.paidAmount).toBe(1000);
    expect(order.paid).toBe(true);
    expect(order.payment).toBe('paid');
    expect(order.total).toBe(1000);
    expect(order.updatedAt).toEqual(expect.stringMatching(ISO));
    expect(order.updatedBy).toEqual({ id: 'asaas', name: 'Asaas' });
    expect(order.transactions).toEqual([
      {
        id: 'asaas_pay_1',
        type: 'payment',
        amount: 1000,
        description: 'Asaas • Pix',
        createdAt: expect.stringMatching(ISO),
        createdBy: { id: 'asaas', name: 'Asaas' },
      },
    ]);
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('paid');
    expect(charge.paidAt).toEqual(expect.stringMatching(ISO));
    expect(charge.paidAsaasPaymentIds).toEqual(['pay_1']);
    expect(charge.appliedTransactions).toEqual(order.transactions);
  });

  it('não lança duas vezes o mesmo pagamento (CONFIRMED + RECEIVED)', async () => {
    seedOrder();
    seedCharge();

    const first = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'CREDIT_CARD', status: 'CONFIRMED' }));
    const second = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'CREDIT_CARD' }));

    expect(first).toEqual({ applied: true });
    expect(second).toEqual({ applied: false });
    const order = read(ORDER_PATH)!;
    expect(order.transactions).toHaveLength(1);
    expect(order.paidAmount).toBe(1000);
    expect(read(CHARGE_PATH)!.appliedTransactions).toHaveLength(1);
  });

  it('entrada menor que o total deixa a OS unpaid e a cobrança à vista paga', async () => {
    seedOrder();
    seedCharge({ value: 300 });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 300, billingType: 'BOLETO' }));

    const order = read(ORDER_PATH)!;
    expect(order.paidAmount).toBe(300);
    expect(order.paid).toBe(false);
    expect(order.payment).toBe('unpaid');
    expect((order.transactions as any[])[0].description).toBe('Asaas • Boleto');
    expect(read(CHARGE_PATH)!.status).toBe('paid');
  });

  it('parcelado: só marca a cobrança paga quando todas as parcelas entram', async () => {
    seedOrder({ total: 900 });
    seedCharge({ mode: 'cardInstallments', installmentCount: 3, value: 900, asaasInstallmentId: 'ins_1' });

    for (const n of [1, 2]) {
      await applyAsaasPayment('c1', 'o1', 'ch1', payment({
        id: `pay_${n}`, value: 300, billingType: 'CREDIT_CARD', installment: 'ins_1', installmentNumber: n,
      }));
    }
    const partial = read(CHARGE_PATH)!;
    expect(partial.status).toBe('pending');
    expect(partial.paidAt).toBeUndefined();
    expect(partial.paidAsaasPaymentIds).toEqual(['pay_1', 'pay_2']);
    expect(read(ORDER_PATH)!.payment).toBe('unpaid');
    expect(read(ORDER_PATH)!.paidAmount).toBe(600);

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({
      id: 'pay_3', value: 300, billingType: 'CREDIT_CARD', installment: 'ins_1', installmentNumber: 3,
    }));

    const order = read(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.description)).toEqual([
      'Asaas • Cartão 1/3',
      'Asaas • Cartão 2/3',
      'Asaas • Cartão 3/3',
    ]);
    expect(order.paidAmount).toBe(900);
    expect(order.payment).toBe('paid');
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('paid');
    expect(charge.appliedTransactions).toEqual(order.transactions);
  });

  it('marca cobrança vencida como paga quando o pagamento entra', async () => {
    seedOrder();
    seedCharge({ status: 'overdue' });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'BOLETO' }));

    expect(read(CHARGE_PATH)!.status).toBe('paid');
  });

  it('mantém pagamentos manuais e desconto existentes ao lançar', async () => {
    seedOrder({
      total: 900,
      discount: 100,
      paidAmount: 200,
      transactions: [
        {
          id: 'manual1', type: 'payment', amount: 200, description: 'Dinheiro',
          createdAt: '2026-10-01T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
        },
        {
          id: 'disc1', type: 'discount', amount: 100,
          createdAt: '2026-10-01T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
        },
      ],
    });
    seedCharge({ value: 700 });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 700 }));

    const order = read(ORDER_PATH)!;
    expect(order.paidAmount).toBe(900);
    expect(order.total).toBe(900);
    expect(order.discount).toBe(100);
    expect(order.payment).toBe('paid');
    expect(order.paid).toBe(true);
    expect((order.transactions as any[]).map((t) => t.id)).toEqual(['manual1', 'disc1', 'asaas_pay_1']);
  });

  it('arredonda centavos ao somar (0,10 + 0,20)', async () => {
    seedOrder({ total: 0.3, paidAmount: 0.1 });
    seedCharge({ value: 0.2 });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 0.2 }));

    const order = read(ORDER_PATH)!;
    expect(order.paidAmount).toBe(0.3);
    expect(order.payment).toBe('paid');
  });

  it('não grava undefined nos documentos', async () => {
    seedOrder({ transactions: undefined, paidAmount: undefined });
    seedCharge({ paidAsaasPaymentIds: undefined as unknown as string[] });
    const writes: unknown[] = [];
    const fake = jest.requireMock('../../firestore.service').db;
    const original = fake.write.bind(fake);
    const spy = jest.spyOn(fake, 'write').mockImplementation((...args: unknown[]) => {
      writes.push(args[1]);
      return original(...(args as [string, Record<string, unknown>, 'set' | 'merge' | 'update']));
    });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ description: undefined, installmentNumber: undefined }));
    spy.mockRestore();

    expect(writes).toHaveLength(2);
    expect(writes.some(hasUndefined)).toBe(false);
    expect(read(ORDER_PATH)!.paidAmount).toBe(1000);
  });

  it('estornado: reentrega do mesmo pagamento não grava nada', async () => {
    seedOrder();
    seedCharge({ status: 'refunded', refundedAsaasPaymentIds: ['pay_1'] });
    const orderBefore = read(ORDER_PATH);
    const chargeBefore = read(CHARGE_PATH);

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    expect(result).toEqual({ applied: false });
    expect(read(ORDER_PATH)).toEqual(orderBefore);
    expect(read(CHARGE_PATH)).toEqual(chargeBefore);
  });

  it('cobrança refunded recebendo outro pagamento: lança o dinheiro mas mantém status refunded', async () => {
    seedOrder({ total: 900 });
    seedCharge({
      mode: 'cardInstallments', installmentCount: 1, value: 300, status: 'refunded',
      refundedAsaasPaymentIds: ['pay_1'],
    });

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ id: 'pay_2', value: 300 }));

    expect(result).toEqual({ applied: true });
    expect(read(ORDER_PATH)!.paidAmount).toBe(300);
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAt).toBeUndefined();
    expect(charge.paidAsaasPaymentIds).toEqual(['pay_2']);
  });

  it('cobrança cancelada recebendo pagamento: dinheiro real entrou, lança na OS e marca paga', async () => {
    seedOrder();
    seedCharge({ status: 'canceled' });

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'BOLETO' }));

    expect(result).toEqual({ applied: true });
    expect(read(ORDER_PATH)!.paidAmount).toBe(1000);
    expect(read(ORDER_PATH)!.payment).toBe('paid');
    expect(read(CHARGE_PATH)!.status).toBe('paid');
  });

  it('transação já na OS mas fora de paidAsaasPaymentIds: reconcilia a cobrança sem lançar de novo', async () => {
    const existing = {
      id: 'asaas_pay_1', type: 'payment', amount: 1000, description: 'Asaas • Pix',
      createdAt: '2026-10-04T10:00:00.000Z', createdBy: { id: 'asaas', name: 'Asaas' },
    };
    seedOrder({ paidAmount: 1000, paid: true, payment: 'paid', transactions: [existing] });
    seedCharge();

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    expect(result).toEqual({ applied: false });
    const order = read(ORDER_PATH)!;
    expect(order.paidAmount).toBe(1000);
    expect(order.transactions).toEqual([existing]);
    expect(read(CHARGE_PATH)!.paidAsaasPaymentIds).toEqual(['pay_1']);
    expect(read(CHARGE_PATH)!.status).toBe('paid');
    expect(console.warn).toHaveBeenCalled();
  });

  it('parcelado sem installmentCount: avisa e trata como pagamento único', async () => {
    seedOrder();
    seedCharge({ mode: 'cardInstallments' });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'CREDIT_CARD' }));

    expect(read(CHARGE_PATH)!.status).toBe('paid');
    expect(console.warn).toHaveBeenCalledWith(
      expect.stringContaining('installmentCount'),
      { companyId: 'c1', orderId: 'o1', chargeId: 'ch1' },
    );
  });

  it('retorna applied=false quando a OS não existe', async () => {
    seedCharge();
    await expect(applyAsaasPayment('c1', 'o1', 'ch1', payment())).resolves.toEqual({ applied: false });
    expect(read(CHARGE_PATH)!.paidAsaasPaymentIds).toEqual([]);
  });

  it('retorna applied=false quando a cobrança não existe, sem mexer na OS', async () => {
    seedOrder();
    await expect(applyAsaasPayment('c1', 'o1', 'ch1', payment())).resolves.toEqual({ applied: false });
    expect(read(ORDER_PATH)!.paidAmount).toBe(0);
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
  });
});

describe('order-payment.service - helpers', () => {
  it('asaasTransactionId prefixa o id do pagamento', () => {
    expect(asaasTransactionId('pay_9')).toBe('asaas_pay_9');
  });

  it('describeAsaasPayment cobre tipos conhecidos, desconhecidos e parcela sem número', () => {
    const single = { mode: 'single' as const };
    expect(describeAsaasPayment(payment({ billingType: 'DEBIT_CARD' }), single)).toBe('Asaas • Cartão');
    expect(describeAsaasPayment(payment({ billingType: 'RECEIVED_IN_CASH' }), single)).toBe('Asaas');
    expect(
      describeAsaasPayment(
        payment({ billingType: 'CREDIT_CARD', installmentNumber: null }),
        { mode: 'cardInstallments', installmentCount: 4 },
        2,
      ),
    ).toBe('Asaas • Cartão 2/4');
  });

  it('buildAsaasTransaction usa o valor bruto arredondado e o ator Asaas', () => {
    const now = new Date('2026-10-04T12:00:00.000Z');
    expect(buildAsaasTransaction(payment({ value: 10.005 }), { mode: 'single' }, now)).toEqual({
      id: 'asaas_pay_1',
      type: 'payment',
      amount: 10.01,
      description: 'Asaas • Pix',
      createdAt: '2026-10-04T12:00:00.000Z',
      createdBy: ASAAS_ACTOR,
    });
  });
});

describe('order-payment.service - computePaymentFields', () => {
  it('preserva paidAmount legado sem transações', () => {
    const fields = computePaymentFields(
      { total: 1000, paidAmount: 200, transactions: [] },
      [{ id: 'asaas_x', type: 'payment', amount: 300, createdAt: '2026-10-04T00:00:00.000Z', createdBy: { id: 'asaas', name: 'Asaas' } }],
    );
    expect(fields.paidAmount).toBe(500);
    expect(fields.payment).toBe('unpaid');
  });

  it('remover uma transação baixa o paidAmount', () => {
    const tx = { id: 'asaas_x', type: 'payment' as const, amount: 300, createdAt: '2026-10-04T00:00:00.000Z', createdBy: ASAAS_ACTOR };
    const fields = computePaymentFields({ total: 300, paidAmount: 300, transactions: [tx] }, []);
    expect(fields).toEqual({ transactions: [], paidAmount: 0, paid: false, payment: 'unpaid' });
  });

  it('descontos não contam como pagamento', () => {
    const discount = { id: 'd1', type: 'discount' as const, amount: 50, createdAt: '2026-10-04T00:00:00.000Z', createdBy: ASAAS_ACTOR };
    const fields = computePaymentFields({ total: 950, paidAmount: 0, transactions: [discount] }, [discount]);
    expect(fields.paidAmount).toBe(0);
  });

  it('OS com total zero nunca fica paga', () => {
    const fields = computePaymentFields({ total: 0, paidAmount: 0, transactions: [] }, []);
    expect(fields).toEqual({ transactions: [], paidAmount: 0, paid: false, payment: 'unpaid' });
  });
});
