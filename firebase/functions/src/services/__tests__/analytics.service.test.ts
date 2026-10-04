const mockGet = jest.fn();

jest.mock('../firestore.service', () => ({
  getTenantCollection: jest.fn(() => ({
    get: mockGet,
    where: jest.fn(() => ({ get: mockGet })),
  })),
  runTransaction: jest.fn(),
}));

import { calculateRevenue, getPendingItems } from '../analytics.service';
import { Order } from '../../models/types';

function docs(orders: Partial<Order>[]) {
  return { docs: orders.map((o, i) => ({ id: `o${i}`, data: () => o })) };
}

describe('analytics.service — saldo sem desconto duplo', () => {
  beforeEach(() => jest.clearAllMocks());

  it('getPendingItems: saldo = total - paidAmount', async () => {
    mockGet.mockResolvedValue(
      docs([
        { number: 1, status: 'done', paid: false, total: 90, discount: 10, paidAmount: 30, createdAt: '2026-10-01T10:00:00.000Z' },
        { number: 2, status: 'done', paid: false, total: 90, discount: 10, paidAmount: 90, createdAt: '2026-10-01T10:00:00.000Z' },
      ])
    );

    const pending = await getPendingItems('comp1');

    expect(pending.unpaid).toHaveLength(1);
    expect(pending.unpaid[0]).toMatchObject({ number: 1, remainingBalance: 60 });
  });

  it('calculateRevenue: unpaid = soma do saldo de cada OS confirmada', () => {
    const revenue = calculateRevenue([
      { status: 'done', total: 90, discount: 10, paidAmount: 30 },
      { status: 'approved', total: 50, discount: 0, paidAmount: 60 },
      { status: 'quote', total: 1000, discount: 0, paidAmount: 0 },
    ] as Order[]);

    expect(revenue).toEqual({ total: 140, paid: 90, unpaid: 60, discount: 10 });
  });
});
