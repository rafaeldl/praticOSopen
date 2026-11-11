/**
 * Clientes of a big company (a workshop with thousands of orders left
 * "approved" without payment). Who sees every order reads only the customers:
 * the numbers the server keeps on each one (customer-aggregates.service.ts) are
 * the ones of the whole orders (countsByCustomer and the customer screen's
 * customerOwed over every document). Consultant and technician still read
 * their orders, in pages with only the fields they add up.
 *
 * Before, the list kept every open order whole, twice (open and money open):
 * ~3.000 of them took the `api` past its 256 MiB.
 */
jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, queryLog, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { customerDirectory } from '../app-directory.service';
import { recountCustomer } from '../customer-aggregates.service';
import { countsByCustomer, customerOwed, OPEN_STATUSES, type SummaryOrder } from '../customer-summary';

const ORDERS = 2600; // more than two pages of 1.000
const CUSTOMERS = 300;
const NOW = new Date('2026-11-06T12:00:00Z');
const ZONE = 'America/Sao_Paulo';
const STATUSES = ['quote', 'approved', 'approved', 'progress', 'done', 'done', 'canceled'];
const PAYMENTS = ['unpaid', 'partial', 'paid', null, undefined];
/** What the list must never read: the heavy part of an order. */
const HEAVY = ['photos', 'services', 'products', 'transactions', 'keywords', 'observation'];

function seedCompany() {
  seed('companies/c1', { name: 'Oficina Fictícia' });
  for (let c = 0; c < CUSTOMERS; c++) {
    seed(`companies/c1/customers/cust${c}`, { name: `Cliente ${c}`, phone: '+5511999990000', keywords: ['x'] });
  }
  for (let i = 0; i < ORDERS; i++) {
    const total = 100 + (i % 13) * 7.35;
    const payment = PAYMENTS[i % PAYMENTS.length];
    seed(`companies/c1/orders/o${String(i).padStart(5, '0')}`, {
      status: STATUSES[i % STATUSES.length],
      customer: { id: i % 50 === 0 ? undefined : `cust${i % CUSTOMERS}`, name: 'Cliente' },
      total,
      paidAmount: i % 3 === 0 ? 0 : Math.round(total * 0.3 * 100) / 100,
      ...(payment === undefined ? {} : { payment }),
      dueDate: new Date(Date.UTC(2026, 9, 1) + (i % 60) * 86400e3).toISOString(),
      createdBy: { id: i % 4 === 0 ? 'tech1' : 'owner1' },
      assignedTo: { id: i % 5 === 0 ? 'tech1' : 'owner1' },
      photos: [{ url: 'https://example.com/p.jpg' }],
      services: [{ description: 'Troca de óleo', value: 50 }],
      products: [{ description: 'Filtro', value: 20 }],
      transactions: [],
      keywords: ['a', 'b'],
      observation: 'Texto longo',
    });
  }
}

/** The rule as before: every whole order, filtered in memory like the queries. */
function expected(scope: { all: boolean; userId: string; assigned: boolean }) {
  const orders = list('companies/c1/orders').map((d) => d.data as unknown as SummaryOrder & { createdBy: { id: string }; assignedTo: { id: string } });
  const inScope = orders.filter((o) => scope.all || o.createdBy.id === scope.userId || (scope.assigned && o.assignedTo.id === scope.userId));
  const counts = countsByCustomer(inScope.filter((o) => (OPEN_STATUSES as readonly unknown[]).includes(o.status)), NOW, ZONE);
  // The customer screen's sum over every order of the customer.
  const owed = new Map<string, number>();
  for (let c = 0; c < CUSTOMERS; c++) owed.set(`cust${c}`, customerOwed(orders.filter((o) => o.customer?.id === `cust${c}`)));
  return { counts, owed };
}

beforeEach(async () => {
  resetFakeDb();
  seedCompany();
  // What the order triggers (or the backfill) leave on each customer.
  for (let c = 0; c < CUSTOMERS; c++) await recountCustomer('c1', `cust${c}`, ZONE);
  queryLog.length = 0;
});

describe('Clientes de uma empresa grande', () => {
  it('soma por cliente igual à regra sobre as OS inteiras (Em aberto, atrasadas e Falta receber)', async () => {
    const scope = { all: true, userId: 'owner1', assigned: false };
    const { customers, truncated } = await customerDirectory('c1', scope, { zone: ZONE, withOwed: true, now: NOW });
    const want = expected(scope);
    expect(truncated).toBe(false);
    expect(customers).toHaveLength(CUSTOMERS);
    for (const c of customers) {
      expect([c.id, c.open, c.late, c.owed]).toEqual([
        c.id, want.counts.get(c.id)?.open ?? 0, want.counts.get(c.id)?.late ?? 0, want.owed.get(c.id) ?? 0,
      ]);
    }
    // The fixture really exercises the numbers.
    expect(customers.filter((c) => c.open > 0).length).toBeGreaterThan(100);
    expect(customers.filter((c) => (c.owed ?? 0) > 0).length).toBeGreaterThan(100);
  });

  it('técnico: conta só as OS dele (criadas ou atribuídas), sem repetir a que é as duas', async () => {
    const scope = { all: false, userId: 'tech1', assigned: true };
    const { customers } = await customerDirectory('c1', scope, { zone: ZONE, withOwed: false, now: NOW });
    const want = expected(scope);
    for (const c of customers) {
      expect([c.id, c.open, c.late, c.owed]).toEqual([c.id, want.counts.get(c.id)?.open ?? 0, want.counts.get(c.id)?.late ?? 0, null]);
    }
  });

  it('quem vê tudo não lê nenhuma OS', async () => {
    await customerDirectory('c1', { all: true, userId: 'owner1', assigned: false }, { zone: ZONE, withOwed: true, now: NOW });
    expect(queryLog.filter((q) => q.path === 'companies/c1/orders')).toEqual([]);
    expect(queryLog.filter((q) => q.path === 'companies/c1/customers')).toHaveLength(1);
  });

  it('técnico lê as OS dele em páginas de no máximo 1.000, só com os campos da conta', async () => {
    seed('companies/c1/orders/zzz-extra', { status: 'approved', customer: { id: 'cust1' }, createdBy: { id: 'tech1' } });
    for (let i = 0; i < 1200; i++) {
      seed(`companies/c1/orders/t${String(i).padStart(5, '0')}`, { status: 'approved', customer: { id: 'cust2' }, createdBy: { id: 'tech1' }, photos: [] });
    }
    await customerDirectory('c1', { all: false, userId: 'tech1', assigned: true }, { zone: ZONE, withOwed: false, now: NOW });
    const orderReads = queryLog.filter((q) => q.path === 'companies/c1/orders');
    expect(orderReads.length).toBeGreaterThan(2); // paged, not one read of everything
    for (const read of orderReads) {
      expect(read.docs).toBeLessThanOrEqual(1000);
      expect(read.fields).toBeDefined();
      expect(read.fields!.filter((f) => HEAVY.includes(f.split('.')[0]))).toEqual([]);
    }
    const customerReads = queryLog.filter((q) => q.path === 'companies/c1/customers');
    expect(customerReads.every((q) => q.fields && !q.fields.includes('keywords'))).toBe(true);
  });
});
