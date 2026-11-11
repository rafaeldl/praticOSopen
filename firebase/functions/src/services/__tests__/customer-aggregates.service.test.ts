jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { aggregatesOf, customersOfOrderWrite, recountCustomer, recountCustomersOfOrder } from '../customer-aggregates.service';
import { customerChanged } from '../customer-activity.service';

const ZONE = 'America/Sao_Paulo';
const ANA = 'companies/c1/customers/ana';
const BIA = 'companies/c1/customers/bia';

function order(id: string, data: Record<string, unknown>) {
  seed(`companies/c1/orders/${id}`, data);
  return data;
}

describe('customer-aggregates.service', () => {
  beforeEach(() => {
    resetFakeDb();
    seed('companies/c1', { name: 'Oficina', country: 'BR' });
    seed(ANA, { name: 'Ana' });
    seed(BIA, { name: 'Bia' });
  });

  it('conta as em aberto, soma o que falta receber e guarda os dias prometidos em ordem', () => {
    const result = aggregatesOf([
      { status: 'quote', dueDate: '2026-11-20' },
      { status: 'approved', dueDate: '2026-11-05T10:00:00.000Z', total: 300, paidAmount: 100, payment: 'partial' },
      { status: 'progress' },
      { status: 'done', total: 200, paidAmount: 50, payment: 'partial', dueDate: '2026-01-01' },
      { status: 'done', total: 90, payment: 'paid' },
      { status: 'canceled', total: 500, dueDate: '2026-01-01' },
    ], ZONE);
    expect(result).toEqual({
      openOrders: 3,
      owed: 350, // done with balance (150) + running with a down payment (200)
      openDueDates: ['2026-11-05T10:00:00.000Z', '2026-11-20T03:00:00.000Z'],
    });
  });

  it('OS nova grava os números no cliente dela', async () => {
    const created = order('o1', { status: 'approved', customer: { id: 'ana' }, total: 100, paidAmount: 40, dueDate: '2026-11-10' });
    await recountCustomersOfOrder('c1', undefined, created);
    expect(read(ANA)).toMatchObject({ name: 'Ana', openOrders: 1, owed: 60, openDueDates: ['2026-11-10T03:00:00.000Z'] });
  });

  it('OS trocada de cliente recalcula o antigo e o novo', async () => {
    order('o1', { status: 'approved', customer: { id: 'ana' } });
    await recountCustomer('c1', 'ana');
    expect(read(ANA)?.openOrders).toBe(1);

    const before = { status: 'approved', customer: { id: 'ana' } };
    const after = order('o1', { status: 'approved', customer: { id: 'bia' } });
    await recountCustomersOfOrder('c1', before, after);
    expect(read(ANA)).toMatchObject({ openOrders: 0, owed: 0, openDueDates: [] });
    expect(read(BIA)).toMatchObject({ openOrders: 1 });
  });

  it('OS apagada sai da conta do cliente', async () => {
    const data = order('o1', { status: 'progress', customer: { id: 'ana' }, dueDate: '2026-11-01' });
    await recountCustomer('c1', 'ana');
    resetFakeDb();
    seed('companies/c1', { country: 'BR' });
    seed(ANA, { name: 'Ana', openOrders: 1, owed: 0, openDueDates: ['2026-11-01T03:00:00.000Z'] });
    await recountCustomersOfOrder('c1', data, undefined);
    expect(read(ANA)).toMatchObject({ openOrders: 0, openDueDates: [] });
  });

  it('não escreve quando nada mudou e ignora cliente apagado', async () => {
    order('o1', { status: 'quote', customer: { id: 'ana' } });
    await recountCustomer('c1', 'ana');
    const first = read(ANA);
    await recountCustomer('c1', 'ana');
    expect(read(ANA)).toEqual(first);
    await expect(recountCustomer('c1', 'ghost')).resolves.toBeNull();
    expect(read('companies/c1/customers/ghost')).toBeUndefined();
  });

  it('só recalcula quando muda algo que entra na conta', () => {
    const base = { status: 'approved', customer: { id: 'ana', name: 'Ana' }, total: 100, services: [] };
    expect(customersOfOrderWrite(base, { ...base, services: [{ value: 1 }] })).toEqual([]);
    expect(customersOfOrderWrite(base, { ...base, customer: { id: 'ana', name: 'Ana Souza' } })).toEqual([]);
    expect(customersOfOrderWrite(base, { ...base, paidAmount: 10 })).toEqual(['ana']);
    expect(customersOfOrderWrite(base, { ...base, customer: { id: 'bia' } })).toEqual(['ana', 'bia']);
    expect(customersOfOrderWrite(undefined, base)).toEqual(['ana']);
    expect(customersOfOrderWrite(base, undefined)).toEqual(['ana']);
    expect(customersOfOrderWrite({ status: 'quote' }, undefined)).toEqual([]);
  });

  it('gravar os números não conta como atividade do cliente (sem laço com o gatilho)', () => {
    const before = { name: 'Ana', openOrders: 1, owed: 10, openDueDates: [] };
    expect(customerChanged(before, { ...before, openOrders: 2, owed: 0, openDueDates: ['2026-11-01T03:00:00.000Z'] })).toBe(false);
    expect(customerChanged(before, { ...before, name: 'Ana Souza' })).toBe(true);
  });
});
