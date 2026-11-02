jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../asaas/charge.service', () => ({ handleOrderStatusChange: jest.fn(async () => undefined) }));
jest.mock('../asaas/outside-payment.service', () => ({ reconcileOutsidePayments: jest.fn(async () => undefined) }));
jest.mock('../asaas/invoice.service', () => ({ autoIssueInvoice: jest.fn(async () => undefined) }));

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { handleOrderUpdatedAsaas } from '../asaas/order-trigger.service';

const ORDER_PATH = 'companies/c1/orders/o1';
const HOLD = { reason: 'part', since: '2026-11-01T12:00:00.000Z' };

describe('order-hold.service', () => {
  beforeEach(() => resetFakeDb());

  it.each(['done', 'canceled', 'quote'])('OS parada que vira %s perde a marca, sem mexer no resto', async (status) => {
    seed(ORDER_PATH, { status, total: 100, onHold: HOLD });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress', onHold: HOLD }, { status, onHold: HOLD });
    expect(read(ORDER_PATH)).toEqual({ status, total: 100, ...(status === 'done' ? { completedAt: expect.any(String) } : {}) });
  });

  it('entre aprovada e em andamento a marca fica', async () => {
    seed(ORDER_PATH, { status: 'progress', onHold: HOLD });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'approved', onHold: HOLD }, { status: 'progress', onHold: HOLD });
    expect(read(ORDER_PATH)!.onHold).toEqual(HOLD);
  });

  it('evento atrasado não tira a marca de OS que voltou a andar', async () => {
    seed(ORDER_PATH, { status: 'progress', onHold: HOLD });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress', onHold: HOLD }, { status: 'canceled', onHold: HOLD });
    expect(read(ORDER_PATH)!.onHold).toEqual(HOLD);
  });

  it('OS sem marca não lê nem grava nada', async () => {
    seed(ORDER_PATH, { status: 'canceled', total: 100 });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'canceled', total: 100 }, { status: 'canceled', total: 100 });
    expect(read(ORDER_PATH)).toEqual({ status: 'canceled', total: 100 });
  });
});
