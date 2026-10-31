jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../asaas/charge.service', () => ({ handleOrderStatusChange: jest.fn(async () => undefined) }));
jest.mock('../asaas/outside-payment.service', () => ({ reconcileOutsidePayments: jest.fn(async () => undefined) }));
jest.mock('../asaas/invoice.service', () => ({ autoIssueInvoice: jest.fn(async () => undefined) }));

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { handleOrderUpdatedAsaas } from '../asaas/order-trigger.service';
import { stampCompletedAtOnCreate } from '../order-completion.service';

const ORDER_PATH = 'companies/c1/orders/o1';
const AT = '2026-10-31T15:00:00.000Z';
const LATER = '2026-11-02T09:00:00.000Z';

describe('order-completion.service', () => {
  beforeEach(() => resetFakeDb());

  it('OS concluída grava completedAt com a hora do evento, sem mexer nos outros campos', async () => {
    seed(ORDER_PATH, { status: 'done', total: 100, updatedAt: 'antes' });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress' }, { status: 'done' }, AT);
    expect(read(ORDER_PATH)).toEqual({ status: 'done', total: 100, updatedAt: 'antes', completedAt: AT });
  });

  it('reabrir limpa, e concluir de novo grava a nova data', async () => {
    seed(ORDER_PATH, { status: 'progress', completedAt: AT });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done', completedAt: AT }, { status: 'progress', completedAt: AT }, LATER);
    expect(read(ORDER_PATH)).not.toHaveProperty('completedAt');

    seed(ORDER_PATH, { status: 'done' });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress' }, { status: 'done' }, LATER);
    expect(read(ORDER_PATH)!.completedAt).toBe(LATER);
  });

  it('cancelar OS concluída também limpa', async () => {
    seed(ORDER_PATH, { status: 'canceled', completedAt: AT });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done' }, { status: 'canceled' }, LATER);
    expect(read(ORDER_PATH)).not.toHaveProperty('completedAt');
  });

  it('OS antiga já concluída, sem data, não ganha data em outras mudanças', async () => {
    seed(ORDER_PATH, { status: 'done', total: 200 });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done', total: 100 }, { status: 'done', total: 200 }, LATER);
    expect(read(ORDER_PATH)).not.toHaveProperty('completedAt');
  });

  it('outra mudança na OS concluída não mexe na data', async () => {
    seed(ORDER_PATH, { status: 'done', completedAt: AT, total: 200 });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done', completedAt: AT }, { status: 'done', completedAt: AT, total: 200 }, LATER);
    expect(read(ORDER_PATH)!.completedAt).toBe(AT);
  });

  it('evento atrasado de conclusão não grava em OS que já foi reaberta', async () => {
    seed(ORDER_PATH, { status: 'progress' });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress' }, { status: 'done' }, AT);
    expect(read(ORDER_PATH)).not.toHaveProperty('completedAt');
  });

  it('evento atrasado de reabertura não limpa OS que já foi concluída de novo', async () => {
    seed(ORDER_PATH, { status: 'done', completedAt: LATER });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done' }, { status: 'progress' }, LATER);
    expect(read(ORDER_PATH)!.completedAt).toBe(LATER);
  });

  it('evento atrasado de uma conclusão anterior não troca a data mais nova', async () => {
    seed(ORDER_PATH, { status: 'done', completedAt: LATER });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'progress' }, { status: 'done' }, AT);
    expect(read(ORDER_PATH)!.completedAt).toBe(LATER);
  });

  it('a própria gravação não dispara outra (sem loop)', async () => {
    seed(ORDER_PATH, { status: 'done', completedAt: AT });
    await handleOrderUpdatedAsaas('c1', 'o1', { status: 'done' }, { status: 'done', completedAt: AT }, LATER);
    expect(read(ORDER_PATH)!.completedAt).toBe(AT);
  });

  it('OS criada já concluída grava a data; criada em outro status, não', async () => {
    seed(ORDER_PATH, { status: 'done' });
    await stampCompletedAtOnCreate('c1', 'o1', { status: 'done' }, AT);
    expect(read(ORDER_PATH)!.completedAt).toBe(AT);

    seed(ORDER_PATH, { status: 'quote' });
    await stampCompletedAtOnCreate('c1', 'o1', { status: 'quote' }, AT);
    expect(read(ORDER_PATH)).not.toHaveProperty('completedAt');
  });
});
