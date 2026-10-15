jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../notification.service', () => ({
  notifyAsaasPaymentReceived: jest.fn().mockResolvedValue(undefined),
}));

import { read as readDoc, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';

const read = (path: string) => readDoc(path) as any;
import { handleAsaasEvent, parseCustomerChargeReference, parseExternalReference } from '../webhook.service';
import { repairAsaasTransactions } from '../order-payment.service';
import type { AsaasPaymentEvent, AsaasWebhookEvent } from '../../../models/asaas.types';

const CC = 'companies/c1/customerCharges/cc1';
const O1 = 'companies/c1/orders/o1';
const O2 = 'companies/c1/orders/o2';
const RECEIPT = 'companies/c1/receipts/asaas_pay_cc';

function seedAll(charge: Record<string, unknown> = {}) {
  seed(O1, { number: 182, status: 'done', total: 100, paidAmount: 0, transactions: [], customer: { id: 'cust1' } });
  seed(O2, { number: 190, status: 'done', total: 200, paidAmount: 0, transactions: [], customer: { id: 'cust1' } });
  seed(CC, {
    id: 'cc1',
    customer: { id: 'cust1', name: 'João' },
    asaasPaymentId: 'pay_cc',
    value: 250,
    dueDate: '2026-10-20',
    status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/cc',
    orderIds: ['o1', 'o2'],
    allocations: [
      { orderId: 'o1', orderNumber: 182, amount: 100 },
      { orderId: 'o2', orderNumber: 190, amount: 150 },
    ],
    paidAsaasPaymentIds: [],
    createdBy: { id: 'u1', name: 'Ana' },
    createdAt: '2026-10-10T10:00:00.000Z',
    ...charge,
  });
}

let n = 0;
function event(name: string, payment: Partial<AsaasPaymentEvent> = {}, id?: string): AsaasWebhookEvent {
  n += 1;
  return {
    id: id ?? `evt_cc_${n}`,
    event: name,
    dateCreated: '2026-10-12 10:00:00',
    payment: {
      id: 'pay_cc', value: 250, netValue: 248, billingType: 'PIX', status: 'RECEIVED',
      externalReference: 'c1:cc:cc1', installment: null, description: 'OS 182, 190', ...payment,
    },
  };
}

describe('webhook - cobrança de várias OS', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    seedAll();
  });
  afterEach(() => jest.restoreAllMocks());

  it('referência externa: a nova não é confundida com a de uma OS', () => {
    expect(parseCustomerChargeReference('c1:cc:cc1')).toEqual({ companyId: 'c1', chargeId: 'cc1' });
    expect(parseExternalReference('c1:cc:cc1')).toBeNull();
    expect(parseExternalReference('c1:o1:ch1')).toEqual({ companyId: 'c1', orderId: 'o1', chargeId: 'ch1' });
    expect(parseCustomerChargeReference('c1:o1:ch1')).toBeNull();
  });

  it('pagamento: reparte pelas OS, cria o recebimento e marca a cobrança paga', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));

    const o1 = read(O1)!;
    const o2 = read(O2)!;
    expect(o1.paidAmount).toBe(100);
    expect(o1.paid).toBe(true);
    expect(o2.paidAmount).toBe(150);
    expect(o1.transactions[0]).toMatchObject({ id: 'asaas_pay_cc_0', amount: 100, receiptGroupId: 'asaas_pay_cc' });
    expect(o2.transactions[0]).toMatchObject({ id: 'asaas_pay_cc_1', amount: 150, receiptGroupId: 'asaas_pay_cc' });

    const receipt = read(RECEIPT)!;
    expect(receipt.amount).toBe(250);
    expect(receipt.createdBy).toEqual({ id: 'asaas', name: 'Asaas' });
    expect(receipt.allocations.map((a: any) => a.transactionId)).toEqual(['asaas_pay_cc_0', 'asaas_pay_cc_1']);
    expect(receipt.status).toBe('active');

    const charge = read(CC)!;
    expect(charge.status).toBe('paid');
    expect(charge.paidAsaasPaymentIds).toEqual(['pay_cc']);
    expect(charge.receiptId).toBe('asaas_pay_cc');
  });

  it('valor pago diferente: menos vai da mais antiga, mais vai para a última', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { value: 120 }));
    expect(read(O1)!.paidAmount).toBe(100);
    expect(read(O2)!.paidAmount).toBe(20);
  });

  it('idempotente: evento repetido e RECEIVED depois de CONFIRMED não lançam de novo', async () => {
    const e = event('PAYMENT_CONFIRMED');
    await handleAsaasEvent('c1', e);
    await handleAsaasEvent('c1', e);
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    expect(read(O1)!.transactions).toHaveLength(1);
    expect(read(O2)!.transactions).toHaveLength(1);
    expect(read(O2)!.paidAmount).toBe(150);
  });

  it('pagamento de outra cobrança com a mesma referência é ignorado', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { id: 'pay_other' }));
    expect(read(O1)!.transactions).toHaveLength(0);
  });

  it('referência de outra empresa é ignorada', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { externalReference: 'c2:cc:cc1' }));
    expect(read(O1)!.transactions).toHaveLength(0);
  });

  it('estorno tira o dinheiro de todas as OS e cancela o recebimento', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    await handleAsaasEvent('c1', event('PAYMENT_REFUNDED', { status: 'REFUNDED' }));

    expect(read(O1)!.paidAmount).toBe(0);
    expect(read(O1)!.transactions).toHaveLength(0);
    expect(read(O2)!.paidAmount).toBe(0);
    expect(read(RECEIPT)!.status).toBe('canceled');
    expect(read(CC)!.status).toBe('refunded');

    // Late CONFIRMED after the refund is never booked.
    await handleAsaasEvent('c1', event('PAYMENT_CONFIRMED'));
    expect(read(O1)!.transactions).toHaveLength(0);
  });

  it('a recuperação não traz de volta parte estornada que uma cópia velha do app gravou', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    const stale = read(O1)!.transactions;
    await handleAsaasEvent('c1', event('PAYMENT_REFUNDED', { status: 'REFUNDED' }));
    seed(O1, { ...read(O1)!, transactions: stale, paidAmount: 100 });

    await repairAsaasTransactions('c1', 'o1');
    expect(read(O1)!.transactions).toHaveLength(0);
    expect(read(O1)!.paidAmount).toBe(0);
  });

  it('a recuperação devolve a parte que uma cópia velha do app apagou', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    seed(O2, { ...read(O2)!, transactions: [], paidAmount: 0 });

    await repairAsaasTransactions('c1', 'o2');
    expect(read(O2)!.transactions.map((t: any) => t.id)).toEqual(['asaas_pay_cc_1']);
    expect(read(O2)!.paidAmount).toBe(150);
  });

  it('vencida e excluída mudam só a situação de cobrança aberta', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_OVERDUE', { status: 'OVERDUE' }));
    expect(read(CC)!.status).toBe('overdue');
    await handleAsaasEvent('c1', event('PAYMENT_DELETED', { status: 'DELETED' }));
    expect(read(CC)!.status).toBe('canceled');
  });

  it('baixa feita por nós (receiveInCash) não lança de novo', async () => {
    seedAll({ status: 'paid', paidOutside: true });
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { status: 'RECEIVED_IN_CASH' }));
    expect(read(O1)!.transactions).toHaveLength(0);
    expect(read(RECEIPT)).toBeUndefined();

    seedAll({ settlingOutsideAt: '2026-10-12T10:00:00.000Z' });
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { status: 'RECEIVED_IN_CASH' }));
    expect(read(O1)!.transactions).toHaveLength(0);
    expect(read(CC)!).toMatchObject({ status: 'paid', paidOutside: true });
  });

  it('desfazer a baixa em dinheiro reabre a cobrança que nós baixamos', async () => {
    seedAll({ status: 'paid', paidOutside: true, paidAt: '2026-10-12T10:00:00.000Z', dueDate: '2099-01-01' });
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED_IN_CASH_UNDONE', { status: 'PENDING' }));
    const charge = read(CC)!;
    expect(charge.status).toBe('pending');
    expect(charge.paidOutside).toBe(false);
    expect(charge.paidAt).toBeUndefined();
  });

  it('estorno parcial não mexe nas OS e não quebra a fila', async () => {
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    const e = event('PAYMENT_PARTIALLY_REFUNDED', { status: 'RECEIVED' });
    await handleAsaasEvent('c1', e);
    expect(read(O1)!.paidAmount).toBe(100);
    expect(read(O2)!.paidAmount).toBe(150);
    expect(read(`companies/c1/private/asaas/events/${e.id}`)).toBeDefined();
  });
});
