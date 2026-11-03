/**
 * Runs docs/web-app/contract-cases/*.json against the real server code: pure
 * functions, services over the in-memory Firestore, and the v1 orders router
 * where the rule lives in the route (who receives, what leaves the server).
 *
 * A case wants `divergesIn.functions` merged over `correct ?? expect`. An entry
 * in `divergesIn.functions` is what the server does today: when the server is
 * fixed the test fails on purpose, and the entry goes away (same idea as `gap`
 * in rbac/firestore-matrix.ts). See docs/web-app/business-rules-map.md.
 */
import { readdirSync, readFileSync } from 'fs';
import { Server } from 'http';
import * as path from 'path';
import express, { Express, NextFunction, Request, Response } from 'express';
import request from 'supertest';

jest.mock('../services/firestore.service', () => {
  const fake = jest.requireActual('./helpers/fake-firestore');
  return {
    ...fake.firestoreServiceMock,
    getNextOrderNumber: async () => 1,
    createDocument: async (collection: { add(data: unknown): Promise<{ id: string }> }, data: unknown) =>
      (await collection.add(data)).id,
    runTransaction: (fn: (tx: unknown) => Promise<unknown>) => fake.fakeDb.runTransaction(fn),
  };
});

import { list, read, resetFakeDb, seed } from './helpers/fake-firestore';
import {
  canChangeOrderStatus,
  canEditOrderMainFields,
  canSeeOrder,
  roleHasPermission,
} from '../middleware/app-permission.middleware';
import ordersRouter from '../routes/v1/orders.routes';
import { syncPaymentStatusWithTotal } from '../services/asaas/order-payment.service';
import { reportOf, summarizeOrders } from '../services/app-finance.service';
import * as catalogService from '../services/catalog.service';
import { canReceiveForCustomer, registerCustomerReceipt } from '../services/customer-receipt.service';
import * as orderService from '../services/order.service';
import { dialCodeOf, getFormatContext, normalizePhone } from '../utils/format.utils';
import { allocateOldestFirst, totalOpen } from '../utils/payment-allocation';
import { locateLines } from '../services/order-items';
import { markFullyPaid, removeTransactionAt, resetPaymentsOf } from '../services/order-finance.service';
import { OrderRuleError } from '../services/order-errors';
import { isValidCnpj, isValidCpf, isValidTaxId, normalizeTaxId } from '../utils/tax-id.utils';

const LANG = 'functions';
const LANGUAGES = ['dart', 'functions', 'web'];
const USER = { id: 'me', name: 'Me' };
const STATUSES = ['quote', 'approved', 'progress', 'done', 'canceled'] as const;

/** Every file this runner reads. A new file naming `functions` in `runsIn` must be added here. */
const COVERED = [
  'currency.json',
  'finance-summary.json',
  'order-delete.json',
  'order-items.json',
  'order-permissions.json',
  'order-receive.json',
  'order-totals.json',
  'overdue.json',
  'payment-status.json',
  'payment-transactions.json',
  'phone.json',
  'receipts.json',
  'round-money.json',
  'status-transitions.json',
  'tax-id.json',
  'visibility.json',
];

const dir = path.join(__dirname, '../../../../docs/web-app/contract-cases');
const files = readdirSync(dir).filter((name) => name.endsWith('.json')).sort();
const file = (name: string): any => JSON.parse(readFileSync(path.join(dir, name), 'utf8'));
const cases = (name: string): any[] => file(name).cases;

/** What this language must do today. */
const want = (c: any): any => ({ ...(c.correct ?? c.expect), ...c.divergesIn?.[LANG] });
const pick = (from: any, like: any): any =>
  Object.fromEntries(Object.keys(like).filter((key) => key in from).map((key) => [key, from[key]]));

const orderPath = (id = 'o1') => `companies/c1/orders/${id}`;
const unpriced = (doc: any): number =>
  [...(doc.services ?? []), ...(doc.products ?? [])].filter((line) => line.value === null || line.value === undefined).length;

function asCatalogItem(id: string) {
  return { id, name: id, photo: null } as any;
}

function seedOrder(given: any): void {
  seed(orderPath(), {
    number: 1,
    status: given.status,
    total: given.total,
    discount: given.discount,
    paidAmount: given.paidAmount,
    payment: given.payment,
    paid: given.payment === 'paid',
    services: given.services.map((s: any) => ({ service: asCatalogItem('s'), value: s.value ?? null })),
    products: given.products.map((p: any) => ({
      product: asCatalogItem('p'),
      value: p.value ?? null,
      quantity: p.quantity,
      ...(p.total === undefined ? {} : { total: p.total }),
    })),
  });
}

/** The real router behind what bearerAuth and resolveCompanyContext would set. */
function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    Object.assign(req, {
      auth: { companyId: 'c1' },
      userContext: { companyId: 'c1', userId: USER.id, userName: USER.name, role: req.header('x-test-role') },
    });
    next();
  });
  app.use('/orders', ordersRouter);
  return app;
}

/**
 * One server on the IPv4 loopback for the whole file. `request(app)` opens a
 * port per call on every interface, and a local service already on that port
 * of 127.0.0.1 can answer instead.
 */
let server: Server;
const get = (role: string, url: string) => request(server).get(url).set('x-test-role', role);
const post = (role: string, url: string, body: object) => request(server).post(url).set('x-test-role', role).send(body);
const del = (role: string, url: string) => request(server).delete(url).set('x-test-role', role);

function reqAs(role: string) {
  return { userContext: { companyId: 'c1', userId: USER.id, role } } as any;
}

const creatorOf = (isCreator: boolean) => ({ createdBy: { id: isCreator ? USER.id : 'someone-else', name: 'X' } });

beforeAll((done) => {
  server = buildApp().listen(0, '127.0.0.1', done);
});

afterAll((done) => {
  server.close(done);
});

beforeEach(() => {
  resetFakeDb();
  jest.spyOn(catalogService, 'getService').mockImplementation(async (_c, id) => asCatalogItem(id));
  jest.spyOn(catalogService, 'getProduct').mockImplementation(async (_c, id) => asCatalogItem(id));
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('contract files', () => {
  it('this runner reads every file that names it in runsIn', () => {
    expect(files.filter((name) => file(name).runsIn.includes(LANG))).toEqual(COVERED);
  });

  it.each(files)('%s is well formed', (name) => {
    const all = cases(name);
    expect(new Set(all.map((c) => c.id)).size).toBe(all.length);
    for (const c of all) {
      const diverges = c.divergesIn ?? {};
      expect(['correct' in c && 'expect' in c, c.id]).toEqual([false, c.id]);
      expect(['correct' in c || 'expect' in c, c.id]).toEqual([true, c.id]);
      if ('correct' in c) expect([Object.keys(diverges).length > 0, c.id]).toEqual([true, c.id]);
      for (const [lang, today] of Object.entries<any>(diverges)) {
        expect(LANGUAGES).toContain(lang);
        const { offline, ...values } = today;
        const decision = c.correct ?? c.expect;
        const differs = Object.entries(values).some(([key, value]) => JSON.stringify(value) !== JSON.stringify(decision[key]));
        expect([differs || offline !== undefined, c.id]).toEqual([true, c.id]);
      }
    }
  });
});

describe('order-totals', () => {
  for (const c of cases('order-totals.json')) {
    it(c.id, async () => {
      const { services, products, discount } = c.given;
      await orderService.createOrder(
        'c1',
        {
          customerId: 'cust1',
          customer: { id: 'cust1', name: 'Ana' },
          services: services.map((s: any) => ({ serviceId: 's', value: s.value ?? undefined })),
          products: products.map((p: any) => ({ productId: 'p', quantity: p.quantity, value: p.value ?? undefined, total: p.total })),
        },
        USER,
        { id: 'c1', name: 'C' } as any,
      );
      const created = list('companies/c1/orders')[0].data as any;
      const total = discount > 0
        ? orderService.applyPaymentTransaction(created, {
          id: 't', type: 'discount', amount: discount, createdAt: '2026-01-01T00:00:00.000Z', createdBy: USER,
        } as never).total
        : created.total;
      const expected = want(c);
      expect({ total, unpricedCount: unpriced(created) })
        .toEqual({ total: expected.total, unpricedCount: expected.unpricedCount });
    });
  }
});

describe('round-money', () => {
  for (const c of cases('round-money.json')) {
    it(c.id, () => {
      expect(orderService.roundMoney(c.given.value)).toBe(want(c).rounded);
    });
  }
});

describe('payment-status', () => {
  for (const c of cases('payment-status.json')) {
    it(c.id, () => {
      const { status, total, paidAmount } = c.given;
      expect({
        ...orderService.paymentStatusFields(status, total, paidAmount),
        remaining: orderService.calculateRemainingBalance({ total, paidAmount }),
      }).toEqual(want(c));
    });
  }
});

describe('payment-transactions', () => {
  const ERRORS: Record<string, string> = { ASAAS_LOCKED: 'asaasLocked', PAYMENT_EXCEEDS_BALANCE: 'exceedsBalance' };
  const build = (amount: number): any => ({ id: 'new', type: 'payment', amount, createdAt: 'x', createdBy: USER });
  const run: Record<string, (order: any, op: any) => any> = {
    addPayment: (order, op) => {
      // POST /:id/payments checks the balance before applying the payment.
      orderService.assertPaymentWithinBalance(order, op.amount);
      return orderService.applyPaymentTransaction(order, { ...build(op.amount), type: 'payment' });
    },
    addDiscount: (order, op) => orderService.applyPaymentTransaction(order, { ...build(op.amount), type: 'discount' }),
    removeTransaction: (order, op) =>
      removeTransactionAt(order, (order.transactions ?? []).findIndex((t: any) => t.id === op.transactionId)),
    resetPayments: (order) => resetPaymentsOf(order),
    markAsFullyPaid: (order) => markFullyPaid(order, build),
  };

  for (const c of cases('payment-transactions.json')) {
    it(c.id, () => {
      const expected = want(c);
      let result: any;
      try {
        result = run[c.given.op.kind](c.given.order, c.given.op);
      } catch (error) {
        if (!(error instanceof OrderRuleError)) throw error;
        expect({ error: ERRORS[error.code] ?? error.code }).toEqual(expected);
        return;
      }
      const { total, discount, paidAmount, payment, paid, transactions } = result;
      const got: any = { total, discount, paidAmount, payment, paid, remaining: orderService.calculateRemainingBalance({ total, paidAmount }) };
      if ('transactionIds' in expected) got.transactionIds = transactions.map((t: any) => t.id);
      if ('transactionCount' in expected) got.transactionCount = transactions.length;
      expect(got).toEqual(expected);
    });
  }
});

describe('order-items', () => {
  /** Id of the n-th line of a kind, as GET /orders/:id gives it to a client. */
  const itemIdOf = (kind: string, index: number) =>
    locateLines(read(orderPath()) as any).filter((line) => line.kind === kind)[index].itemId;
  const edit = (kind: string, op: any) => {
    const { index, ...patch } = op;
    delete patch.kind;
    return orderService.updateOrderItem('c1', 'o1', itemIdOf(kind, index), patch, USER);
  };
  const run: Record<string, (op: any) => Promise<unknown>> = {
    addService: (op) => orderService.addOrderService('c1', 'o1', 's', op.value ?? undefined, undefined, USER),
    addProduct: (op) => orderService.addOrderProduct('c1', 'o1', 'p', op.quantity, op.value ?? undefined, undefined, USER, { total: op.total }),
    editService: (op) => edit('service', op),
    editProduct: (op) => edit('product', op),
    removeService: (op) => orderService.removeServiceFromOrder('c1', 1, op.index, USER),
    removeProduct: (op) => orderService.removeProductFromOrder('c1', 1, op.index, USER),
  };

  for (const c of cases('order-items.json').filter((item) => item.given.op.kind in run)) {
    it(c.id, async () => {
      seedOrder(c.given.order);
      await run[c.given.op.kind](c.given.op);
      await syncPaymentStatusWithTotal('c1', 'o1');
      const doc = read(orderPath()) as any;
      expect({
        total: doc.total,
        payment: doc.payment ?? null,
        paid: doc.paid,
        remaining: orderService.calculateRemainingBalance(doc),
        unpricedCount: unpriced(doc),
      }).toEqual(want(c));
    });
  }
});

describe('status-transitions', () => {
  const doc = file('status-transitions.json');
  for (const c of doc.cases) {
    it(c.id, () => {
      const { role, isCreator, from } = c.given;
      const allowed: string[] = want(c).allowed;
      for (const to of STATUSES) {
        const order = { status: from, ...creatorOf(isCreator) } as any;
        expect([to, canChangeOrderStatus(reqAs(role), order, to)])
          .toEqual([to, to === from ? doc.sameStatus[LANG] && canSeeOrder(reqAs(role), order) : allowed.includes(to)]);
      }
    });
  }
});

describe('order-permissions (the checks the server has)', () => {
  for (const c of cases('order-permissions.json')) {
    it(c.id, () => {
      const { role, isCreator, status } = c.given;
      const req = reqAs(role);
      const order = { status, ...creatorOf(isCreator) } as any;
      const canAccess = canSeeOrder(req, order);
      const server = {
        canAccess,
        canEdit: canAccess && roleHasPermission(role, 'editOrder', undefined),
        canExecute: canAccess && roleHasPermission(role, 'executeOrder', undefined),
        canAssign: canAccess && roleHasPermission(role, 'assignOrder', undefined),
        canEditMainFields: canEditOrderMainFields(req, order),
      };
      expect(server).toEqual(pick(want(c), server));
    });
  }
});

describe('order-receive', () => {
  for (const c of cases('order-receive.json')) {
    it(c.id, async () => {
      const { role, isCreator, status, useFinancial } = c.given;
      seed('companies/c1', { useFinancial });
      seed(orderPath(), { status, total: 100, discount: 0, paidAmount: 0, transactions: [], ...creatorOf(isCreator) });
      const receive = (await post(role, '/orders/o1/payments', { amount: 1 })).status;
      const discount = (await post(role, '/orders/o1/discounts', { amount: 1 })).status;
      expect([200, 403]).toContain(receive);
      expect([200, 403]).toContain(discount);
      expect({ canReceive: receive === 200, canDiscount: discount === 200 }).toEqual(want(c));
    });
  }
});

describe('visibility', () => {
  const ORDER = {
    number: 1,
    status: 'quote',
    total: 150,
    discount: 10,
    paidAmount: 20,
    services: [{ service: { id: 's', name: 's', value: 80 }, value: 100 }],
    products: [{ product: { id: 'p', name: 'p', value: 20 }, value: 30, quantity: 2, total: 60 }],
    createdBy: { id: USER.id, name: USER.name },
  };
  const has = (value: unknown) => value !== undefined;

  async function moneyFields(route: string, role: string): Promise<string[]> {
    if (route === 'listOrders') {
      jest.spyOn(orderService, 'listOrders').mockResolvedValue({ data: [{ ...ORDER, id: 'o1' }], total: 1, hasMore: false } as never);
      const res = await get(role, '/orders');
      return res.status === 200 && has(res.body.data[0].total) ? ['total'] : [];
    }
    if (route === 'getOrder') {
      const { data } = (await get(role, '/orders/o1')).body;
      const [service, product] = [data.services[0], data.products[0]];
      const present: Array<[string, unknown]> = [
        ['total', data.total],
        ['discount', data.discount],
        ['paidAmount', data.paidAmount],
        ['remainingBalance', data.remainingBalance],
        ['services[].value', service.value],
        ['services[].service.value', service.service.value],
        ['products[].value', product.value],
        ['products[].product.value', product.product.value],
        ['products[].total', product.total],
      ];
      return present.filter(([, value]) => has(value)).map(([name]) => name);
    }
    const res = route === 'addService'
      ? await post(role, '/orders/o1/services', { serviceId: 's' })
      : await post(role, '/orders/o1/products', { productId: 'p', quantity: 1 });
    expect(res.status).toBe(200);
    return has(res.body.data.newTotal) ? ['newTotal'] : [];
  }

  for (const c of cases('visibility.json')) {
    it(c.id, async () => {
      const { route, role, useFinancial } = c.given;
      seed('companies/c1', { useFinancial });
      seed(orderPath(), ORDER);
      expect(roleHasPermission(role, 'viewPrices', useFinancial)).toBe(want(c).showPrices);
      expect(await moneyFields(route, role)).toEqual(want(c).fields);
    });
  }
});

describe('overdue', () => {
  afterEach(() => jest.useRealTimers());

  for (const c of cases('overdue.json')) {
    it(c.id, async () => {
      const { status, dueDate, now } = c.given;
      seed(orderPath(), { status, dueDate });
      jest.useFakeTimers({ now: new Date(now) });
      const found = await orderService.getOverdueOrders('c1');
      expect(found.length === 1).toBe(want(c).overdue);
    });
  }
});

describe('currency', () => {
  for (const c of cases('currency.json')) {
    it(c.id, () => {
      const { currency, locale } = getFormatContext(c.given.country ?? undefined);
      expect({ currency, locale }).toEqual(want(c));
    });
  }
});

describe('phone (normalize, the only one the server has)', () => {
  for (const c of cases('phone.json').filter((item) => item.given.kind === 'normalize')) {
    it(c.id, () => {
      expect(normalizePhone(c.given.raw, dialCodeOf(c.given.country)).replace(/\D/g, '')).toBe(want(c).number);
    });
  }
});

describe('order-delete', () => {
  for (const c of cases('order-delete.json')) {
    it(c.id, async () => {
      const { role, isCreator, status, hasMoney } = c.given;
      seed(orderPath(), {
        status, total: 100, paidAmount: hasMoney ? 10 : 0, transactions: [], ...creatorOf(isCreator),
      });
      const res = await del(role, '/orders/o1');
      expect([200, 403]).toContain(res.status);
      expect({ allowed: res.status === 200 }).toEqual(want(c));
      expect(read(orderPath()) === undefined).toBe(res.status === 200);
    });
  }
});

describe('tax-id (all but format, which the server does not have)', () => {
  const valid: Record<string, (value: string) => boolean> = { cpf: isValidCpf, cnpj: isValidCnpj, taxId: isValidTaxId };

  for (const c of cases('tax-id.json').filter((item) => item.given.kind !== 'format')) {
    it(c.id, () => {
      const { kind, value } = c.given;
      if (kind === 'normalize') expect(normalizeTaxId(value)).toBe(want(c).result);
      else expect(valid[kind](value)).toBe(want(c).valid);
    });
  }
});

describe('receipts', () => {
  const ERRORS: Record<string, string> = { ORDER_NOT_PAYABLE: 'notPayable', VALUE_EXCEEDS_BALANCE: 'exceedsBalance' };

  for (const c of cases('receipts.json')) {
    it(c.id, async () => {
      const { given } = c;
      const expected = want(c);
      if (given.kind === 'allocate') {
        const allocations = allocateOldestFirst(given.balances, given.amount)
          .map(({ orderId, amount }) => ({ orderId, amount }));
        expect({ allocations, totalOpen: totalOpen(given.balances) }).toEqual(expected);
      } else if (given.kind === 'canReceive') {
        expect(canReceiveForCustomer(given.role, given.useFinancial)).toBe(expected.allowed);
      } else {
        for (const { id, status, total, paidAmount } of given.orders) {
          seed(orderPath(id), { status, total, paidAmount, transactions: [], customer: { id: 'cust1', name: 'Ana' } });
        }
        const outcome = await registerCustomerReceipt(
          'c1',
          'cust1',
          { receiptId: 'r1', paidAt: '2026-01-01T00:00:00.000Z', allocations: given.allocations },
          USER,
        ).catch((error) => ({ error: ERRORS[error.code] ?? error }));
        if (expected.error) {
          expect(outcome).toEqual({ error: expected.error });
          return;
        }
        expect({
          error: null,
          amount: (outcome as { amount: number }).amount,
          orders: given.orders.map(({ id }: { id: string }) => {
            const { payment, paid, paidAmount } = read(orderPath(id)) as any;
            return { id, payment, paid, paidAmount };
          }),
        }).toEqual(expected);
      }
    });
  }
});

describe('finance-summary', () => {
  for (const c of cases('finance-summary.json')) {
    it(c.id, () => {
      const { op, zone, from, to, orders, customer, payment } = c.given;
      const expected = want(c);
      if (op === 'summary') {
        const s = summarizeOrders(orders, { from, to, zone });
        const facts = {
          received: s.received.total,
          sold: s.sold.total,
          receivable: s.receivable.total,
          owed: s.receivable.owed,
          depositOwed: s.receivable.depositOwed,
          receivableCustomers: s.receivable.customers,
          progress: s.progress.total,
          receivedIds: s.received.orders.map((o) => o.id),
          soldIds: s.sold.orders.map((o) => o.id),
          depositIds: s.receivable.deposits.map((o) => o.id),
          progressIds: s.progress.orders.map((o) => o.id),
          debtorKeys: s.receivable.debtors.map((d) => d.key),
        };
        expect(pick(facts, expected)).toEqual(expected);
      } else {
        const r = reportOf(orders, { from, to, zone, customer, payment });
        const facts = {
          revenue: r.revenue,
          paid: r.paid,
          remaining: r.remaining,
          count: r.count,
          paidCount: r.paidCount,
          orderIds: r.orders.map((o) => o.id),
          customerIds: r.customers.map((x) => x.id),
          compositionServices: r.composition.services,
          compositionProducts: r.composition.products,
          serviceNames: r.services.map((x) => x.name),
          productNames: r.products.map((x) => x.name),
        };
        expect(pick(facts, expected)).toEqual(expected);
      }
    });
  }
});
