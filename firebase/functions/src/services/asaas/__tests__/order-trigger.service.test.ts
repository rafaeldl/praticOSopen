jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../charge.service', () => ({ handleOrderStatusChange: jest.fn(async () => undefined) }));
jest.mock('../outside-payment.service', () => ({ reconcileOutsidePayments: jest.fn(async () => undefined) }));
jest.mock('../invoice.service', () => ({ autoIssueInvoice: jest.fn(async () => undefined) }));

import { fakeDb, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { handleOrderStatusChange } from '../charge.service';
import { applyAsaasPayment } from '../order-payment.service';
import { handleOrderUpdatedAsaas } from '../order-trigger.service';
import { reconcileOutsidePayments } from '../outside-payment.service';
import { autoIssueInvoice } from '../invoice.service';

const reconcile = reconcileOutsidePayments as jest.Mock;

const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;
const SETTINGS_PATH = 'companies/c1/settings/payments';
const handleStatus = handleOrderStatusChange as jest.Mock;
const autoIssue = autoIssueInvoice as jest.Mock;

async function seedPaidOrderThenOverwrite() {
  seed(ORDER_PATH, { total: 1000, paidAmount: 0, paid: false, payment: 'unpaid', transactions: [], status: 'approved' });
  seed(CHARGE_PATH, {
    id: 'ch1', asaasPaymentId: 'pay_1', mode: 'single', value: 1000, dueDate: '2026-10-10', status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/1', paidAsaasPaymentIds: [],
    createdBy: { id: 'u1', name: 'Ana' }, createdAt: '2026-10-04T10:00:00.000Z',
  });
  await applyAsaasPayment('c1', 'o1', 'ch1', {
    id: 'pay_1', value: 1000, netValue: 990, billingType: 'PIX', status: 'RECEIVED',
    externalReference: 'c1:o1:ch1', installment: null,
  });
  const applied = read(ORDER_PATH)!.transactions as any[];
  seed(ORDER_PATH, { ...read(ORDER_PATH)!, paidAmount: 0, paid: false, payment: 'unpaid', transactions: [] });
  return applied;
}

describe('order-trigger.service - handleOrderUpdatedAsaas', () => {
  beforeEach(() => {
    resetFakeDb();
    handleStatus.mockClear();
    reconcile.mockClear();
    autoIssue.mockClear();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('sem mudança de status nem de transactions: não lê o Firestore', async () => {
    const collection = jest.spyOn(fakeDb, 'collection');
    const transaction = jest.spyOn(fakeDb, 'runTransaction');
    const before = { status: 'approved', total: 100, transactions: [] };
    const after = { status: 'progress', total: 100, transactions: [] };

    await handleOrderUpdatedAsaas('c1', 'o1', before, after);

    expect(collection).not.toHaveBeenCalled();
    expect(transaction).not.toHaveBeenCalled();
    expect(handleStatus).not.toHaveBeenCalled();
  });

  it('OS ficou paga: tenta a nota automática do momento "paga"', async () => {
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done', payment: 'unpaid' }, { status: 'done', payment: 'paid' });
    expect(autoIssue).toHaveBeenCalledTimes(1);
    expect(autoIssue).toHaveBeenCalledWith('c1', 'o1', 'paid');
  });

  it('OS foi concluída: tenta a nota automática do momento "concluída"', async () => {
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress' }, { status: 'done' });
    expect(autoIssue).toHaveBeenCalledTimes(1);
    expect(autoIssue).toHaveBeenCalledWith('c1', 'o1', 'completed');
  });

  it('OS já paga e já concluída salva de novo: não tenta nota', async () => {
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done', payment: 'paid' }, { status: 'done', payment: 'paid' });
    expect(autoIssue).not.toHaveBeenCalled();
  });

  it('status mudou para canceled: delega para handleOrderStatusChange', async () => {
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'approved' }, { status: 'canceled' });
    expect(handleStatus).toHaveBeenCalledWith('c1', 'o1', 'approved', 'canceled');
  });

  it('já estava canceled: não chama handleOrderStatusChange', async () => {
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'canceled' }, { status: 'canceled' });
    expect(handleStatus).not.toHaveBeenCalled();
  });

  it('transactions mudou e Asaas conectado: repara', async () => {
    seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    const applied = await seedPaidOrderThenOverwrite();

    await handleOrderUpdatedAsaas('c1', 'o1', { transactions: applied }, { transactions: [] });

    expect(read(ORDER_PATH)!.transactions).toEqual(applied);
    expect(read(ORDER_PATH)!.paidAmount).toBe(1000);
    expect(handleStatus).not.toHaveBeenCalled();
  });

  it('transactions mudou mas Asaas desconectado: não repara', async () => {
    seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: false });
    const applied = await seedPaidOrderThenOverwrite();
    const transaction = jest.spyOn(fakeDb, 'runTransaction');

    await handleOrderUpdatedAsaas('c1', 'o1', { transactions: applied }, { transactions: [] });

    expect(transaction).not.toHaveBeenCalled();
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('sem settings/payments: não repara', async () => {
    const applied = await seedPaidOrderThenOverwrite();
    await handleOrderUpdatedAsaas('c1', 'o1', { transactions: applied }, { transactions: [] });
    expect(read(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('cancelou e mexeu em transactions no mesmo update: faz as duas coisas', async () => {
    seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    const applied = await seedPaidOrderThenOverwrite();

    await handleOrderUpdatedAsaas(
      'c1', 'o1',
      { status: 'approved', transactions: applied },
      { status: 'canceled', transactions: [] },
    );

    expect(handleStatus).toHaveBeenCalledWith('c1', 'o1', 'approved', 'canceled');
    expect(read(ORDER_PATH)!.transactions).toEqual(applied);
  });

  it('erro no cancelamento não impede o reparo e é repassado', async () => {
    seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    const applied = await seedPaidOrderThenOverwrite();
    handleStatus.mockRejectedValueOnce(new Error('boom'));

    await expect(handleOrderUpdatedAsaas(
      'c1', 'o1',
      { status: 'approved', transactions: applied },
      { status: 'canceled', transactions: [] },
    )).rejects.toThrow('boom');

    expect(read(ORDER_PATH)!.transactions).toEqual(applied);
  });

  it('correção só de status não mexe em transactions', async () => {
    seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    const applied = await seedPaidOrderThenOverwrite();
    // App kept the transaction list but saved stale totals.
    seed(ORDER_PATH, { ...read(ORDER_PATH)!, transactions: applied });

    await handleOrderUpdatedAsaas('c1', 'o1', { transactions: [] }, { transactions: applied });

    const order = read(ORDER_PATH)!;
    expect(order.transactions).toEqual(applied);
    expect(order.paidAmount).toBe(1000);
    expect(order.payment).toBe('paid');
  });

  it('total mudou com Asaas conectado: confere os links abertos (dar baixa)', async () => {
    seed(SETTINGS_PATH, { asaasConnected: true });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'approved', total: 100 }, { status: 'approved', total: 80 });
    expect(reconcile).toHaveBeenCalledWith('c1', 'o1');
  });

  it('OS virou cancelada: também confere os links de várias OS', async () => {
    seed(SETTINGS_PATH, { asaasConnected: true });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'approved', total: 100 }, { status: 'canceled', total: 100 });
    expect(reconcile).toHaveBeenCalledWith('c1', 'o1');
  });

  it('sem Asaas conectado: não confere links', async () => {
    seed(SETTINGS_PATH, { asaasConnected: false });
    await handleOrderUpdatedAsaas('c1', 'o1', { total: 100, transactions: [] }, { total: 100, transactions: [{ id: 't1' }] as any });
    expect(reconcile).not.toHaveBeenCalled();
  });
});
