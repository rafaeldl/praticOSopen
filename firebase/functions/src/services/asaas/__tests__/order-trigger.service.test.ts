jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../charge.service', () => ({ handleOrderStatusChange: jest.fn(async () => undefined) }));

import { fakeDb, read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { handleOrderStatusChange } from '../charge.service';
import { applyAsaasPayment } from '../order-payment.service';
import { handleOrderUpdatedAsaas } from '../order-trigger.service';

const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;
const SETTINGS_PATH = 'companies/c1/settings/payments';
const handleStatus = handleOrderStatusChange as jest.Mock;

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
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('sem mudança de status nem de transactions: não lê o Firestore', async () => {
    const collection = jest.spyOn(fakeDb, 'collection');
    const transaction = jest.spyOn(fakeDb, 'runTransaction');
    const before = { status: 'approved', total: 100, transactions: [] };
    const after = { status: 'done', total: 200, transactions: [] };

    await handleOrderUpdatedAsaas('c1', 'o1', before, after);

    expect(collection).not.toHaveBeenCalled();
    expect(transaction).not.toHaveBeenCalled();
    expect(handleStatus).not.toHaveBeenCalled();
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
});
