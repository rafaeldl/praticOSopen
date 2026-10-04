jest.mock('uuid', () => ({ v4: () => 'txn-1' }));

const mockTxGet = jest.fn();
const mockTxUpdate = jest.fn();
const mockOrderRef = { id: 'order1' };

jest.mock('../firestore.service', () => ({
  getTenantCollection: jest.fn(() => ({ doc: jest.fn(() => mockOrderRef) })),
  runTransaction: jest.fn((fn: (tx: unknown) => Promise<unknown>) =>
    fn({ get: mockTxGet, update: mockTxUpdate })
  ),
}));

import {
  addPayment,
  PaymentValidationError,
  applyPaymentTransaction,
  calculateRemainingBalance,
} from '../order.service';
import { Order, PaymentTransaction, UserAggr } from '../../models/types';

const user: UserAggr = { id: 'user1', name: 'Test User' };

function snapshot(data: Partial<Order> | null) {
  return { exists: !!data, id: 'order1', data: () => data };
}

function txn(type: 'payment' | 'discount', amount: number): PaymentTransaction {
  return {
    id: `t-${type}-${amount}`,
    type,
    amount,
    createdAt: '2026-10-04T10:00:00.000Z',
    createdBy: user,
  };
}

describe('calculateRemainingBalance', () => {
  it('usa total - paidAmount (total já é líquido de desconto)', () => {
    expect(calculateRemainingBalance({ total: 90, discount: 10, paidAmount: 30 } as Order)).toBe(60);
  });

  it('nunca retorna negativo', () => {
    expect(calculateRemainingBalance({ total: 50, discount: 0, paidAmount: 80 } as Order)).toBe(0);
  });

  it('trata valores ausentes como zero', () => {
    expect(calculateRemainingBalance({} as Order)).toBe(0);
  });
});

describe('applyPaymentTransaction', () => {
  it('pagamento soma em paidAmount e mantém o total', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 0, transactions: [] },
      txn('payment', 40)
    );
    expect(result).toMatchObject({
      total: 100,
      discount: 0,
      paidAmount: 40,
      paid: false,
      payment: 'unpaid',
      remainingBalance: 60,
    });
    expect(result.transactions).toHaveLength(1);
  });

  it('desconto reduz o total e acumula em discount', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 50 },
      txn('discount', 10)
    );
    expect(result).toMatchObject({
      total: 90,
      discount: 10,
      paidAmount: 50,
      paid: false,
      payment: 'unpaid',
      remainingBalance: 40,
    });
  });

  it('marca como pago quando paidAmount alcança o total líquido', () => {
    const result = applyPaymentTransaction(
      { total: 90, discount: 10, paidAmount: 50 },
      txn('payment', 40)
    );
    expect(result).toMatchObject({ paid: true, payment: 'paid', remainingBalance: 0 });
  });

  it('desconto que cobre o saldo marca como pago', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 90 },
      txn('discount', 10)
    );
    expect(result).toMatchObject({ total: 90, paid: true, payment: 'paid', remainingBalance: 0 });
  });

  it('arredonda para centavos', () => {
    const result = applyPaymentTransaction(
      { total: 0.3, discount: 0, paidAmount: 0.1 },
      txn('payment', 0.2)
    );
    expect(result.paidAmount).toBe(0.3);
    expect(result.payment).toBe('paid');
  });
});

describe('addPayment', () => {
  beforeEach(() => jest.clearAllMocks());

  it('retorna null quando a OS não existe', async () => {
    mockTxGet.mockResolvedValue(snapshot(null));

    await expect(addPayment('comp1', 'order1', 10, 'payment', undefined, user)).resolves.toBeNull();
    expect(mockTxUpdate).not.toHaveBeenCalled();
  });

  it('desconto reduz o total na transação e nunca grava partial', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 100, discount: 0, paidAmount: 20, transactions: [] }));

    const result = await addPayment('comp1', 'order1', 10, 'discount', 'Desconto', user);

    expect(result).toEqual({
      transactionId: 'txn-1',
      paidAmount: 20,
      remainingBalance: 70,
      isFullyPaid: false,
    });
    expect(mockTxUpdate).toHaveBeenCalledWith(
      mockOrderRef,
      expect.objectContaining({
        total: 90,
        discount: 10,
        paidAmount: 20,
        paid: false,
        payment: 'unpaid',
        transactions: [
          expect.objectContaining({ id: 'txn-1', type: 'discount', amount: 10, description: 'Desconto' }),
        ],
      })
    );
  });

  it('rejeita desconto maior que o saldo restante', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 100, discount: 0, paidAmount: 80, transactions: [] }));

    await expect(
      addPayment('comp1', 'order1', 25, 'discount', undefined, user)
    ).rejects.toBeInstanceOf(PaymentValidationError);
    expect(mockTxUpdate).not.toHaveBeenCalled();
  });

  it('aceita desconto igual ao saldo restante', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 100, discount: 0, paidAmount: 80, transactions: [] }));

    await expect(
      addPayment('comp1', 'order1', 20, 'discount', undefined, user)
    ).resolves.not.toBeNull();
  });

  it('omite description undefined (Firestore rejeita undefined)', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 50, discount: 0, paidAmount: 0 }));

    await addPayment('comp1', 'order1', 50, 'payment', undefined, user);

    const update = mockTxUpdate.mock.calls[0][1];
    expect(update.transactions[0]).not.toHaveProperty('description');
    expect(update.payment).toBe('paid');
    expect(update.paid).toBe(true);
  });
});
