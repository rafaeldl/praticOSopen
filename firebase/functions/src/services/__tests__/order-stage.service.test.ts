jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../asaas/charge.service', () => ({ handleOrderStatusChange: jest.fn(async () => undefined) }));
jest.mock('../asaas/outside-payment.service', () => ({ reconcileOutsidePayments: jest.fn(async () => undefined) }));
jest.mock('../asaas/invoice.service', () => ({ autoIssueInvoice: jest.fn(async () => undefined) }));

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { handleOrderUpdatedAsaas } from '../asaas/order-trigger.service';
import { workStagesOf } from '../order-stage.service';

const ORDER_PATH = 'companies/c1/orders/o1';
const STAGE = { id: 'paint', rank: 1, since: '2026-11-01T12:00:00.000Z' };

describe('order-stage.service', () => {
  beforeEach(() => resetFakeDb());

  it.each(['approved', 'canceled', 'quote'])('OS com etapa que vira %s perde a etapa, sem mexer no resto', async (status) => {
    seed(ORDER_PATH, { status, total: 100, stage: STAGE });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress', stage: STAGE }, { status, stage: STAGE });
    expect(read(ORDER_PATH)).toEqual({ status, total: 100 });
  });

  it('em andamento a etapa fica; evento atrasado não tira a etapa', async () => {
    seed(ORDER_PATH, { status: 'progress', stage: STAGE });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress', stage: STAGE }, { status: 'done', stage: STAGE });
    expect(read(ORDER_PATH)!.stage).toEqual(STAGE);
  });

  it('lê só as etapas com id e nome', () => {
    expect(workStagesOf({ workStages: [{ id: 'a', name: ' Pintura ', keywords: ['pint', 3] }, { id: '', name: 'X' }, { id: 'b' }, null] })).toEqual([
      { id: 'a', name: 'Pintura', keywords: ['pint'] },
    ]);
    expect(workStagesOf({})).toEqual([]);
    expect(workStagesOf(undefined)).toEqual([]);
  });
});
