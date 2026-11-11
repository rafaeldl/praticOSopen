jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { customerChanged, dateMillis, touchCustomerOfOrder, touchCustomerOnWrite } from '../customer-activity.service';

const CUSTOMER = 'companies/c1/customers/k1';
const AT = '2026-11-09T12:00:00.000Z';
const SECONDS_LATER = '2026-11-09T12:00:30.000Z';
const LATER = '2026-11-09T15:00:00.000Z';

describe('customer-activity.service', () => {
  beforeEach(() => resetFakeDb());

  it('OS nova ou alterada grava a data no cliente dela, sem mexer no resto', async () => {
    seed(CUSTOMER, { name: 'Ana', phone: '1199' });
    await touchCustomerOfOrder('c1', { customer: { id: 'k1', name: 'Ana' }, status: 'quote' }, AT);
    expect(read(CUSTOMER)).toEqual({ name: 'Ana', phone: '1199', lastActivityAt: AT });
  });

  it('OS sem cliente ou com cliente apagado não grava nada', async () => {
    await touchCustomerOfOrder('c1', { status: 'quote' }, AT);
    await touchCustomerOfOrder('c1', { customer: { id: 'k1' } }, AT);
    expect(read(CUSTOMER)).toBeUndefined();
  });

  it('evento atrasado não troca uma data mais nova', async () => {
    seed(CUSTOMER, { name: 'Ana', lastActivityAt: LATER });
    await touchCustomerOfOrder('c1', { customer: { id: 'k1' } }, AT);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(LATER);
  });

  it('várias mudanças seguidas na OS gravam uma vez só (menos de um minuto)', async () => {
    seed(CUSTOMER, { name: 'Ana', lastActivityAt: AT });
    await touchCustomerOfOrder('c1', { customer: { id: 'k1' } }, SECONDS_LATER);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(AT);
    await touchCustomerOfOrder('c1', { customer: { id: 'k1' } }, LATER);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(LATER);
  });

  it('data antiga em outro formato (Timestamp, texto sem fuso) é comparada', async () => {
    expect(dateMillis({ seconds: 10, nanoseconds: 0 })).toBe(10_000);
    expect(dateMillis({ toMillis: () => 5 })).toBe(5);
    expect(dateMillis('2026-11-09T12:00:00.000Z')).toBe(Date.parse(AT));
    expect(dateMillis('não é data')).toBeNull();
    expect(dateMillis(null)).toBeNull();
  });

  it('cliente criado grava a data', async () => {
    seed(CUSTOMER, { name: 'Ana' });
    await touchCustomerOnWrite('c1', 'k1', undefined, { name: 'Ana' }, AT);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(AT);
  });

  it('cadastro editado grava a data', async () => {
    seed(CUSTOMER, { name: 'Ana Souza', lastActivityAt: AT });
    await touchCustomerOnWrite('c1', 'k1', { name: 'Ana', lastActivityAt: AT }, { name: 'Ana Souza', lastActivityAt: AT }, LATER);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(LATER);
  });

  it('a gravação só da data não dispara de novo (sem laço)', async () => {
    seed(CUSTOMER, { name: 'Ana', lastActivityAt: AT });
    await touchCustomerOnWrite('c1', 'k1', { name: 'Ana' }, { name: 'Ana', lastActivityAt: AT }, LATER);
    expect(read(CUSTOMER)!.lastActivityAt).toBe(AT);
  });

  it('cliente apagado não grava nada', async () => {
    await touchCustomerOnWrite('c1', 'k1', { name: 'Ana' }, undefined, AT);
    expect(read(CUSTOMER)).toBeUndefined();
  });

  it('customerChanged ignora a ordem das chaves e só a data', () => {
    expect(customerChanged({ a: 1, b: { x: 1, y: 2 } }, { b: { y: 2, x: 1 }, a: 1, lastActivityAt: AT })).toBe(false);
    expect(customerChanged({ a: 1 }, { a: 2 })).toBe(true);
  });
});
