jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read as readDoc, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import {
  canReceiveForCustomer,
  listCustomerOpenOrders,
  registerCustomerReceipt,
} from '../customer-receipt.service';

const read = (path: string) => readDoc(path) as any;

const CONSULTANT = { id: 'cons1', name: 'Bia' };
const PAID_AT = '2026-10-14T15:00:00.000Z';

function seedOrder(id: string, data: Record<string, unknown> = {}) {
  seed(`companies/c1/orders/${id}`, {
    number: Number(id.replace(/\D/g, '')),
    status: 'done',
    total: 100,
    paidAmount: 0,
    transactions: [],
    customer: { id: 'cust1', name: 'João' },
    createdBy: { id: 'other', name: 'Caio' },
    ...data,
  });
}

describe('customer-receipt.service', () => {
  beforeEach(() => {
    resetFakeDb();
    seedOrder('o1', { createdAt: '2026-09-01T10:00:00.000Z', createdBy: CONSULTANT });
    seedOrder('o2', { total: 200, paidAmount: 50, createdAt: '2026-09-10T10:00:00.000Z' });
    seedOrder('o3', { status: 'quote', createdAt: '2026-09-11T10:00:00.000Z' });
    seedOrder('o4', { status: 'canceled', createdAt: '2026-09-12T10:00:00.000Z' });
    seedOrder('o5', { paidAmount: 100, createdAt: '2026-09-13T10:00:00.000Z' });
    seedOrder('o6', { customer: { id: 'cust2' }, createdAt: '2026-09-14T10:00:00.000Z' });
  });

  it('papéis que recebem: financeiro e consultor, só com valores ligados', () => {
    expect(canReceiveForCustomer('owner', true)).toBe(true);
    expect(canReceiveForCustomer('admin', undefined)).toBe(true);
    expect(canReceiveForCustomer('manager', true)).toBe(true);
    expect(canReceiveForCustomer('consultant', true)).toBe(true);
    expect(canReceiveForCustomer('technician', true)).toBe(false);
    expect(canReceiveForCustomer('supervisor', true)).toBe(false);
    expect(canReceiveForCustomer('owner', false)).toBe(false);
    expect(canReceiveForCustomer(undefined, true)).toBe(false);
  });

  it('lista só número, aberto e data das OS em aberto do cliente, mais antigas primeiro', async () => {
    const list = await listCustomerOpenOrders('c1', 'cust1', 'cons1');
    expect(list).toEqual([
      { id: 'o1', number: 1, open: 100, createdAt: '2026-09-01T10:00:00.000Z', own: true },
      { id: 'o2', number: 2, open: 150, createdAt: '2026-09-10T10:00:00.000Z', own: false },
    ]);
    expect(Object.keys(list[1]).sort()).toEqual(['createdAt', 'id', 'number', 'open', 'own']);
  });

  it('registra o recebimento em OS de outra pessoa: só campos de pagamento + recebimento', async () => {
    const result = await registerCustomerReceipt(
      'c1',
      'cust1',
      { receiptId: 'r1', paidAt: PAID_AT, allocations: [{ orderId: 'o1', amount: 100 }, { orderId: 'o2', amount: 50 }] },
      CONSULTANT,
    );
    expect(result).toEqual({ receiptId: 'r1', amount: 150 });

    const o1 = read('companies/c1/orders/o1');
    const o2 = read('companies/c1/orders/o2');
    expect(o1).toMatchObject({ paidAmount: 100, paid: true, total: 100, status: 'done' });
    expect(o2).toMatchObject({ paidAmount: 100, total: 200 });
    expect(o2.transactions[0]).toMatchObject({
      id: 'r1_1', type: 'payment', amount: 50, paidAt: PAID_AT, receiptGroupId: 'r1', createdBy: CONSULTANT,
    });
    expect(o2.createdBy).toEqual({ id: 'other', name: 'Caio' });

    const receipt = read('companies/c1/receipts/r1');
    expect(receipt).toMatchObject({
      amount: 150, status: 'active', createdBy: CONSULTANT, customer: { id: 'cust1', name: 'João' },
    });
    expect(receipt.allocations).toEqual([
      { orderId: 'o1', orderNumber: 1, amount: 100, transactionId: 'r1_0' },
      { orderId: 'o2', orderNumber: 2, amount: 50, transactionId: 'r1_1' },
    ]);
  });

  it('com comprovante: documento na OS ligado ao pagamento', async () => {
    await registerCustomerReceipt(
      'c1',
      'cust1',
      {
        receiptId: 'r2',
        paidAt: PAID_AT,
        allocations: [{ orderId: 'o2', amount: 10 }],
        receiptFile: {
          url: 'https://firebasestorage.googleapis.com/x',
          storagePath: 'tenants/c1/receipts/r2/file.jpg',
          contentType: 'image/jpeg',
        },
      },
      CONSULTANT,
    );
    const o2 = read('companies/c1/orders/o2');
    expect(o2.transactions[0].receiptDocumentId).toBe('receipt_r2_0');
    expect(o2.documents[0]).toMatchObject({ id: 'receipt_r2_0', type: 'receipt', linkedTransactionId: 'r2_0' });
  });

  const cases: Array<[string, Record<string, unknown>, string]> = [
    ['OS de outro cliente', { allocations: [{ orderId: 'o6', amount: 10 }] }, 'ORDER_NOT_OF_CUSTOMER'],
    ['orçamento', { allocations: [{ orderId: 'o3', amount: 10 }] }, 'ORDER_NOT_PAYABLE'],
    ['OS cancelada', { allocations: [{ orderId: 'o4', amount: 10 }] }, 'ORDER_NOT_PAYABLE'],
    ['acima do aberto da OS', { allocations: [{ orderId: 'o2', amount: 150.01 }] }, 'VALUE_EXCEEDS_BALANCE'],
    ['OS já paga', { allocations: [{ orderId: 'o5', amount: 1 }] }, 'VALUE_EXCEEDS_BALANCE'],
    ['OS que não existe (ou de outra empresa)', { allocations: [{ orderId: 'nope', amount: 1 }] }, 'ORDER_NOT_FOUND'],
    ['OS repetida', { allocations: [{ orderId: 'o1', amount: 1 }, { orderId: 'o1', amount: 1 }] }, 'INVALID_VALUE'],
    ['valor zero', { allocations: [{ orderId: 'o1', amount: 0 }] }, 'INVALID_VALUE'],
    ['data no futuro', { paidAt: '2099-01-01T00:00:00.000Z' }, 'INVALID_PAID_AT'],
    [
      'comprovante fora da pasta do recebimento',
      { receiptFile: { url: 'https://x.com/a', storagePath: 'tenants/c2/receipts/r9/a.jpg', contentType: 'image/jpeg' } },
      'INVALID_FILE',
    ],
  ];

  it.each(cases)('recusa: %s (nada é gravado)', async (_label, override, code) => {
    await expect(
      registerCustomerReceipt(
        'c1',
        'cust1',
        { receiptId: 'r9', paidAt: PAID_AT, allocations: [{ orderId: 'o1', amount: 10 }], ...override } as any,
        CONSULTANT,
      ),
    ).rejects.toMatchObject({ code });
    expect(read('companies/c1/receipts/r9')).toBeUndefined();
    expect(read('companies/c1/orders/o1').transactions).toHaveLength(0);
  });

  it('outra empresa não enxerga as OS desta', async () => {
    await expect(
      registerCustomerReceipt('c2', 'cust1', { receiptId: 'r9', paidAt: PAID_AT, allocations: [{ orderId: 'o1', amount: 10 }] }, CONSULTANT),
    ).rejects.toMatchObject({ code: 'ORDER_NOT_FOUND' });
  });

  it('mesmo id de recebimento duas vezes não lança de novo', async () => {
    const input = { receiptId: 'r1', paidAt: PAID_AT, allocations: [{ orderId: 'o1', amount: 10 }] };
    await registerCustomerReceipt('c1', 'cust1', input, CONSULTANT);
    await expect(registerCustomerReceipt('c1', 'cust1', input, CONSULTANT)).rejects.toMatchObject({ code: 'RECEIPT_EXISTS' });
    expect(read('companies/c1/orders/o1').paidAmount).toBe(10);
  });
});
