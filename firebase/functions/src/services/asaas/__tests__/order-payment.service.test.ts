jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { SERVER_TIMESTAMP, list, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import {
  ASAAS_ACTOR,
  applyAsaasPayment,
  asaasTransactionId,
  buildAsaasTransaction,
  computePaymentFields,
  describeAsaasPayment,
  repairAsaasTransactions,
  revertAsaasPayment,
  transactionsChanged,
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

describe('order-payment.service - revertAsaasPayment', () => {
  const COMMENTS_PATH = `${ORDER_PATH}/comments`;

  beforeEach(() => {
    resetFakeDb();
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('remove a transação, recalcula, marca refunded e registra no histórico', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: true });
    const order = read(ORDER_PATH)!;
    expect(order.transactions).toEqual([]);
    expect(order.paidAmount).toBe(0);
    expect(order.paid).toBe(false);
    expect(order.payment).toBe('unpaid');
    expect(order.updatedAt).toEqual(expect.stringMatching(ISO));
    expect(order.updatedBy).toEqual({ id: 'asaas', name: 'Asaas' });

    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAsaasPaymentIds).toEqual([]);
    expect(charge.appliedTransactions).toEqual([]);
    expect(charge.refundedAsaasPaymentIds).toEqual(['pay_1']);

    const comments = list(COMMENTS_PATH);
    expect(comments).toHaveLength(1);
    const comment = comments[0].data;
    expect(comment).toEqual({
      text: expect.any(String),
      authorType: 'internal',
      author: { name: 'Asaas' },
      source: 'asaas',
      isInternal: true,
      createdAt: SERVER_TIMESTAMP,
    });
    expect(comment.text).toContain('estornado');
    expect(comment.text).toContain('1.000,00');
    expect(comment.text).toContain('Asaas • Pix');
  });

  it('pagamento nunca lançado: só registra o id em refundedAsaasPaymentIds', async () => {
    seedOrder();
    seedCharge();
    const orderBefore = read(ORDER_PATH);
    const chargeBefore = read(CHARGE_PATH)!;

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: false });
    expect(read(ORDER_PATH)).toEqual(orderBefore);
    expect(read(CHARGE_PATH)).toEqual({ ...chargeBefore, refundedAsaasPaymentIds: ['pay_1'] });
    expect(list(COMMENTS_PATH)).toHaveLength(0);

    const again = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');
    expect(again).toEqual({ reverted: false });
    expect(read(CHARGE_PATH)!.refundedAsaasPaymentIds).toEqual(['pay_1']);
  });

  it('estorno antes do CONFIRMED: o CONFIRMED atrasado não é lançado', async () => {
    seedOrder();
    seedCharge();
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ status: 'CONFIRMED' }));

    expect(result).toEqual({ applied: false });
    const order = read(ORDER_PATH)!;
    expect(order.transactions).toEqual([]);
    expect(order.paidAmount).toBe(0);
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('pending');
    expect(charge.paidAsaasPaymentIds).toEqual([]);
  });

  it('é idempotente: estornar de novo o mesmo pagamento não grava nada', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');
    const orderBefore = read(ORDER_PATH);
    const chargeBefore = read(CHARGE_PATH);

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: false });
    expect(read(ORDER_PATH)).toEqual(orderBefore);
    expect(read(CHARGE_PATH)).toEqual(chargeBefore);
    expect(list(COMMENTS_PATH)).toHaveLength(1);
  });

  it('reentrega do CONFIRMED depois do estorno não lança de novo', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ status: 'CONFIRMED' }));
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ status: 'CONFIRMED' }));

    expect(result).toEqual({ applied: false });
    const order = read(ORDER_PATH)!;
    expect(order.transactions).toEqual([]);
    expect(order.paidAmount).toBe(0);
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAsaasPaymentIds).toEqual([]);
  });

  it('parcelado: estorna só a parcela indicada e mantém as outras', async () => {
    seedOrder({ total: 600 });
    seedCharge({ mode: 'cardInstallments', installmentCount: 2, value: 600, asaasInstallmentId: 'ins_1' });
    for (const n of [1, 2]) {
      await applyAsaasPayment('c1', 'o1', 'ch1', payment({
        id: `pay_${n}`, value: 300, billingType: 'CREDIT_CARD', installment: 'ins_1', installmentNumber: n,
      }));
    }

    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    const order = read(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.id)).toEqual(['asaas_pay_2']);
    expect(order.paidAmount).toBe(300);
    expect(order.payment).toBe('unpaid');
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAsaasPaymentIds).toEqual(['pay_2']);
    expect((charge.appliedTransactions as any[]).map((t) => t.id)).toEqual(['asaas_pay_2']);
    expect(charge.refundedAsaasPaymentIds).toEqual(['pay_1']);
    expect(list(COMMENTS_PATH)[0].data.text).toContain('Asaas • Cartão 1/2');
  });

  it('acrescenta ao refundedAsaasPaymentIds existente', async () => {
    seedOrder({ total: 600 });
    seedCharge({ mode: 'cardInstallments', installmentCount: 2, value: 600 });
    for (const n of [1, 2]) {
      await applyAsaasPayment('c1', 'o1', 'ch1', payment({ id: `pay_${n}`, value: 300, billingType: 'CREDIT_CARD' }));
    }

    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_2');

    expect(read(CHARGE_PATH)!.refundedAsaasPaymentIds).toEqual(['pay_1', 'pay_2']);
    expect(read(ORDER_PATH)!.paidAmount).toBe(0);
    expect(list(COMMENTS_PATH)).toHaveLength(2);
  });

  it('transação apagada da OS por app antigo: ajusta a cobrança e usa a cópia para o histórico', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    seed(ORDER_PATH, { ...read(ORDER_PATH)!, transactions: [], paidAmount: 0, paid: false, payment: 'unpaid' });
    const orderBefore = read(ORDER_PATH);

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: true });
    expect(read(ORDER_PATH)).toEqual(orderBefore);
    const charge = read(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAsaasPaymentIds).toEqual([]);
    expect(charge.refundedAsaasPaymentIds).toEqual(['pay_1']);
    expect(list(COMMENTS_PATH)[0].data.text).toContain('1.000,00');
  });

  it('preserva pagamento manual e paidAmount legado ao estornar', async () => {
    seedOrder({
      total: 1000,
      paidAmount: 300,
      transactions: [{
        id: 'manual1', type: 'payment', amount: 200, description: 'Dinheiro',
        createdAt: '2026-10-01T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
      }],
    });
    seedCharge({ value: 700 });
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 700 }));
    expect(read(ORDER_PATH)!.payment).toBe('paid');

    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    const order = read(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.id)).toEqual(['manual1']);
    expect(order.paidAmount).toBe(300);
    expect(order.payment).toBe('unpaid');
  });

  it('não grava undefined nos documentos', async () => {
    seedOrder();
    seedCharge({ appliedTransactions: undefined });
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ description: undefined }));
    const writes: unknown[] = [];
    const fake = jest.requireMock('../../firestore.service').db;
    const original = fake.write.bind(fake);
    const spy = jest.spyOn(fake, 'write').mockImplementation((...args: unknown[]) => {
      writes.push(args[1]);
      return original(...(args as [string, Record<string, unknown>, 'set' | 'merge' | 'update']));
    });

    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');
    spy.mockRestore();

    expect(writes).toHaveLength(3);
    expect(writes.some(hasUndefined)).toBe(false);
  });

  it('retorna reverted=false quando a OS ou a cobrança não existe', async () => {
    seedCharge({ paidAsaasPaymentIds: ['pay_1'] });
    await expect(revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1')).resolves.toEqual({ reverted: false });
    expect(read(CHARGE_PATH)!.status).toBe('pending');

    resetFakeDb();
    seedOrder();
    await expect(revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1')).resolves.toEqual({ reverted: false });
    expect(list(COMMENTS_PATH)).toHaveLength(0);
  });
});

describe('order-payment.service - repairAsaasTransactions', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  /** Old app version saves a stale copy of the order without the Asaas payment. */
  function overwriteLikeOldApp(overrides: Record<string, unknown> = {}) {
    seed(ORDER_PATH, {
      ...read(ORDER_PATH)!,
      paidAmount: 0, paid: false, payment: 'unpaid', transactions: [],
      updatedBy: { id: 'u1', name: 'Ana' },
      ...overrides,
    });
  }

  it('reinsere a transação Asaas apagada por versão antiga do app', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const booked = read(ORDER_PATH)!.transactions;
    overwriteLikeOldApp();

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 1 });

    const order = read(ORDER_PATH)!;
    expect(order.transactions).toEqual(booked);
    expect(order.paidAmount).toBe(1000);
    expect(order.paid).toBe(true);
    expect(order.payment).toBe('paid');
    expect(order.updatedAt).toEqual(expect.stringMatching(ISO));
    expect(order.updatedBy).toEqual(ASAAS_ACTOR);
  });

  it('mantém pagamento manual adicionado depois e soma o Asaas reinserido', async () => {
    seedOrder({ total: 1000 });
    seedCharge({ value: 600 });
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 600 }));
    const manual = {
      id: 'manual1', type: 'payment', amount: 400, description: 'Dinheiro',
      createdAt: '2026-10-05T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
    };
    overwriteLikeOldApp({ paidAmount: 400, transactions: [manual] });

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 1 });

    const order = read(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.id)).toEqual(['manual1', 'asaas_pay_1']);
    expect(order.paidAmount).toBe(1000);
    expect(order.payment).toBe('paid');
  });

  it('não escreve quando nada falta e o status está coerente (sem loop no trigger)', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const before = read(ORDER_PATH);
    const writeSpy = jest.spyOn(jest.requireMock('../../firestore.service').db, 'write');

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });

    expect(writeSpy).not.toHaveBeenCalled();
    expect(read(ORDER_PATH)).toEqual(before);
  });

  it('segunda execução depois do reparo não escreve de novo', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    overwriteLikeOldApp();
    await repairAsaasTransactions('c1', 'o1');
    const writeSpy = jest.spyOn(jest.requireMock('../../firestore.service').db, 'write');

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(writeSpy).not.toHaveBeenCalled();
  });

  it('não reinsere pagamento estornado', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('não reinsere id que está em refundedAsaasPaymentIds mesmo se ainda listado como pago', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    seed(CHARGE_PATH, { ...read(CHARGE_PATH)!, refundedAsaasPaymentIds: ['pay_1'] });
    overwriteLikeOldApp();

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
    expect(read(ORDER_PATH)!.paidAmount).toBe(0);
  });

  it('pago sem cópia em appliedTransactions: avisa e não inventa transação', async () => {
    seedOrder();
    seedCharge({ paidAsaasPaymentIds: ['pay_1'], appliedTransactions: [] });

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
    expect(console.warn).toHaveBeenCalledWith(
      expect.stringContaining('[AsaasPayment]'),
      { companyId: 'c1', orderId: 'o1', chargeId: 'ch1', asaasPaymentId: 'pay_1' },
    );
  });

  it('parcelado: reinsere só as parcelas pagas que faltam, em várias cobranças', async () => {
    seedOrder({ total: 900 });
    seedCharge({ mode: 'cardInstallments', installmentCount: 2, value: 600, asaasInstallmentId: 'ins_1' });
    seed(`${ORDER_PATH}/charges/ch2`, { ...read(CHARGE_PATH)!, id: 'ch2', mode: 'single', installmentCount: undefined, value: 300, asaasPaymentId: 'pay_9' });
    for (const n of [1, 2]) {
      await applyAsaasPayment('c1', 'o1', 'ch1', payment({ id: `pay_${n}`, value: 300, billingType: 'CREDIT_CARD', installmentNumber: n }));
    }
    await applyAsaasPayment('c1', 'o1', 'ch2', payment({ id: 'pay_9', value: 300 }));
    const all = read(ORDER_PATH)!.transactions as any[];
    overwriteLikeOldApp({ paidAmount: 300, transactions: [all[0]] });

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 2 });

    const order = read(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.id).sort()).toEqual(['asaas_pay_1', 'asaas_pay_2', 'asaas_pay_9']);
    expect(order.paidAmount).toBe(900);
    expect(order.payment).toBe('paid');
  });

  it('corrige status inconsistente (incremento do app + status absoluto) sem mexer no resto', async () => {
    // App incremented paidAmount offline while computing payment from a stale local state.
    seedOrder({ total: 1000 });
    seedCharge({ value: 600 });
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 600 }));
    const order0 = read(ORDER_PATH)!;
    const manual = {
      id: 'manual1', type: 'payment', amount: 400,
      createdAt: '2026-10-05T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
    };
    seed(ORDER_PATH, {
      ...order0,
      transactions: [...(order0.transactions as any[]), manual],
      paidAmount: 1000,
      paid: false,
      payment: 'unpaid',
      updatedBy: { id: 'u1', name: 'Ana' },
      updatedAt: '2026-10-05T10:00:00.000Z',
    });

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });

    const order = read(ORDER_PATH)!;
    expect(order.paid).toBe(true);
    expect(order.payment).toBe('paid');
    expect(order.paidAmount).toBe(1000);
    expect((order.transactions as any[]).map((t) => t.id)).toEqual(['asaas_pay_1', 'manual1']);
    expect(order.updatedBy).toEqual({ id: 'u1', name: 'Ana' });
    expect(order.updatedAt).toBe('2026-10-05T10:00:00.000Z');
  });

  it('corrige "paid" que ficou acima do pago (status absoluto antigo) e arredonda centavos', async () => {
    seedOrder({ total: 0.3, paidAmount: 0.1 + 0.2 - 0.0000001, paid: false, payment: 'unpaid' });

    await repairAsaasTransactions('c1', 'o1');
    expect(read(ORDER_PATH)!.payment).toBe('paid');

    seed(ORDER_PATH, { ...read(ORDER_PATH)!, total: 500, paidAmount: 200, paid: true, payment: 'paid' });
    await repairAsaasTransactions('c1', 'o1');
    expect(read(ORDER_PATH)!.paid).toBe(false);
    expect(read(ORDER_PATH)!.payment).toBe('unpaid');
  });

  it('OS com total zero nunca fica paga', async () => {
    seedOrder({ total: 0, paidAmount: 0, paid: true, payment: 'paid' });
    await repairAsaasTransactions('c1', 'o1');
    expect(read(ORDER_PATH)!.payment).toBe('unpaid');
    expect(read(ORDER_PATH)!.paid).toBe(false);
  });

  it('não grava undefined', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ description: undefined }));
    overwriteLikeOldApp();
    const writes: unknown[] = [];
    const fake = jest.requireMock('../../firestore.service').db;
    const original = fake.write.bind(fake);
    jest.spyOn(fake, 'write').mockImplementation((...args: unknown[]) => {
      writes.push(args[1]);
      return original(...(args as [string, Record<string, unknown>, 'set' | 'merge' | 'update']));
    });

    await repairAsaasTransactions('c1', 'o1');

    expect(writes).toHaveLength(1);
    expect(writes.some(hasUndefined)).toBe(false);
  });

  it('OS inexistente: não faz nada', async () => {
    seedCharge();
    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(read(ORDER_PATH)).toBeUndefined();
  });
});

describe('order-payment.service - transactionsChanged', () => {
  const t = (id: string, amount = 10) => ({
    id, type: 'payment' as const, amount, createdAt: '2026-10-04T00:00:00.000Z', createdBy: ASAAS_ACTOR,
  });

  it('compara profundamente before/after', () => {
    expect(transactionsChanged({ transactions: [t('a')] }, { transactions: [t('a')] })).toBe(false);
    expect(transactionsChanged({}, { transactions: [] })).toBe(false);
    expect(transactionsChanged(undefined, undefined)).toBe(false);
    expect(transactionsChanged({ transactions: [t('a')] }, { transactions: [] })).toBe(true);
    expect(transactionsChanged({ transactions: [t('a', 10)] }, { transactions: [t('a', 20)] })).toBe(true);
    expect(transactionsChanged({ transactions: [] }, { transactions: [t('b')] })).toBe(true);
  });

  it('ignora a ordem das chaves dentro da transação', () => {
    const a = t('a');
    const reordered = { createdBy: a.createdBy, createdAt: a.createdAt, amount: a.amount, type: a.type, id: a.id };
    expect(transactionsChanged({ transactions: [a] }, { transactions: [reordered] })).toBe(false);
  });
});
