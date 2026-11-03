/**
 * contract.service over the in-memory Firestore: idempotency, several nights
 * in a row, dates at the end of the month, missed days, useContracts, the
 * creator scope of the route and the job switch. Real concurrency (Firestore
 * transactions and the old app racing) is in
 * __tests__/contract-concurrency.emulator.test.ts.
 */
import { Server } from 'http';
import express, { NextFunction, Request, Response } from 'express';
import request from 'supertest';

jest.mock('../firestore.service', () => {
  const fake = jest.requireActual('../../__tests__/helpers/fake-firestore');
  return {
    ...fake.firestoreServiceMock,
    runTransaction: (fn: (tx: unknown) => Promise<unknown>) => fake.fakeDb.runTransaction(fn),
  };
});

import { list, read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import {
  generateAllDueOrders,
  generateDueOrders,
  generateForTemplate,
  isContractsJobEnabled,
} from '../contract.service';
import { contractOrderId, instantOfWall, parseContractDate } from '../contract-generation';
import contractsRouter from '../../routes/v1/contracts.routes';

const at = (wall: string) => instantOfWall(parseContractDate(wall)!);
const COMPANY = { name: 'Clima Bom', country: 'BR', useContracts: true };

function template(contract: Record<string, unknown>, extra: Record<string, unknown> = {}) {
  return {
    number: 7,
    isContract: true,
    createdBy: { id: 'u1', name: 'Ana' },
    customer: { id: 'cust1', name: 'Condomínio Sol' },
    services: [{ service: { id: 's1', name: 'Limpeza' }, description: 'Limpeza', value: 100 }],
    contract: {
      frequency: 'monthly',
      interval: 1,
      startDate: '2026-10-03T09:00:00.000',
      nextDueDate: '2026-11-03T00:00:00.000',
      generatedCount: 0,
      autoGenerate: true,
      active: true,
      ...contract,
    },
    ...extra,
  };
}

const generated = (companyId = 'c1') =>
  list(`companies/${companyId}/orders`).filter((o) => o.data.contract && (o.data.contract as any).parentOrderId);
const contractOf = (id: string, companyId = 'c1') => (read(`companies/${companyId}/orders/${id}`) as any).contract;

beforeEach(() => {
  resetFakeDb();
  seed('companies/c1', COMPANY);
});

describe('generateDueOrders', () => {
  it('a second run at the same time generates nothing more', async () => {
    seed('companies/c1/orders/t1', template({}));
    const first = await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    const second = await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    expect(first.generated).toBe(1);
    expect(second.generated).toBe(0);
    expect(generated()).toHaveLength(1);
  });

  it('a daily contract run by the job every night makes one order per night', async () => {
    seed('companies/c1/orders/t1', template({ frequency: 'daily', nextDueDate: '2026-11-03T00:00:00.000' }));
    // The job passes its scheduled time: exactly 24h apart, so the next due date
    // (now + 1 day) is reached on the next run, not skipped to the one after.
    for (let day = 3; day <= 9; day++) {
      await generateDueOrders('c1', { now: at(`2026-11-${String(day).padStart(2, '0')}T02:00:00.000`) });
    }
    expect(generated()).toHaveLength(7);
    expect(contractOf('t1')).toMatchObject({ generatedCount: 7, nextDueDate: '2026-11-10T02:00:00.000' });
  });

  it('a daily contract run a few seconds late is still due the next night', async () => {
    seed('companies/c1/orders/t1', template({ frequency: 'daily', nextDueDate: '2026-11-03T00:00:00.000' }));
    await generateDueOrders('c1', { now: at('2026-11-03T02:00:07.000') });
    // An earlier start the next night (02:00:00) is before 02:00:07 + 1 day.
    await generateDueOrders('c1', { now: at('2026-11-04T02:00:00.000') });
    expect(generated()).toHaveLength(1);
    // So the job must use its scheduled time, never the real start time.
  });

  it('end of month: 31 January, then 3 March, then 3 April', async () => {
    seed('companies/c1/orders/t1', template({ nextDueDate: '2027-01-31T00:00:00.000' }));
    for (const day of ['2027-01-31', '2027-02-28', '2027-03-03', '2027-04-02', '2027-04-03']) {
      await generateDueOrders('c1', { now: at(`${day}T02:00:00.000`) });
    }
    expect(generated()).toHaveLength(3);
    expect(contractOf('t1').nextDueDate).toBe('2027-05-03T00:00:00.000');
  });

  it('three months without anyone generating: one order, next due date from today', async () => {
    seed('companies/c1/orders/t1', template({ nextDueDate: '2026-08-03T00:00:00.000', generatedCount: 4 }));
    await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    await generateDueOrders('c1', { now: at('2026-11-04T02:00:00.000') });
    expect(generated()).toHaveLength(1);
    expect(contractOf('t1')).toMatchObject({ generatedCount: 5, nextDueDate: '2026-12-03T00:00:00.000' });
  });

  it('does nothing when the company has recurring contracts off', async () => {
    seed('companies/c1', { ...COMPANY, useContracts: false });
    seed('companies/c1/orders/t1', template({}));
    const result = await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    expect(result).toMatchObject({ contractsOn: false, generated: 0 });
    expect(generated()).toHaveLength(0);
  });

  it('scoped to a creator, skips the contracts of others', async () => {
    seed('companies/c1/orders/mine', template({}, { createdBy: { id: 'tech1', name: 'Téc' } }));
    seed('companies/c1/orders/other', template({}));
    const result = await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000'), createdById: 'tech1' });
    expect(result.generated).toBe(1);
    expect(generated().map((o) => (o.data.contract as any).parentOrderId)).toEqual(['mine']);
  });

  it('a template rewound by a stale full save does not generate the same due date twice', async () => {
    const original = template({});
    seed('companies/c1/orders/t1', original);
    await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    // The app saves the whole template from a screen opened before the generation.
    seed('companies/c1/orders/t1', original);
    const second = await generateDueOrders('c1', { now: at('2026-11-03T10:00:00.000') });
    expect(second).toMatchObject({ generated: 0, alreadyGenerated: 1 });
    expect(generated()).toHaveLength(1);
    expect(contractOf('t1').nextDueDate).toBe('2026-12-03T00:00:00.000');
  });

  it('a template turned off between the query and the transaction is not generated', async () => {
    seed('companies/c1/orders/t1', template({ active: false }));
    const outcome = await generateForTemplate('c1', 't1', { id: 'c1' }, at('2026-11-03T02:00:00.000'));
    expect(outcome.outcome).toBe('not_due');
  });

  it('the order id is the template plus the due date', async () => {
    seed('companies/c1/orders/t1', template({}));
    await generateDueOrders('c1', { now: at('2026-11-03T02:00:00.000') });
    expect(generated()[0].id).toBe(contractOrderId('t1', '2026-11-03T00:00:00.000'));
    // The same instant written with an offset gives the same id.
    expect(contractOrderId('t1', '2026-11-03T03:00:00.000Z')).toBe(generated()[0].id);
  });
});

describe('generateAllDueOrders and the job switch', () => {
  it('runs every company with useContracts and skips the others', async () => {
    seed('companies/c2', { ...COMPANY, useContracts: false });
    seed('companies/c1/orders/t1', template({}));
    seed('companies/c2/orders/t1', template({}));
    const totals = await generateAllDueOrders(at('2026-11-03T02:00:00.000'));
    expect(totals).toMatchObject({ companies: 1, generated: 1, errors: 0 });
    expect(generated('c2')).toHaveLength(0);
  });

  it('is off without config/contracts.jobEnabled', async () => {
    expect(await isContractsJobEnabled()).toBe(false);
    seed('config/contracts', { jobEnabled: true });
    expect(await isContractsJobEnabled()).toBe(true);
  });
});

describe('POST /generate-due', () => {
  let server: Server;
  beforeAll((done) => {
    const app = express();
    app.use(express.json());
    app.use((req: Request, _res: Response, next: NextFunction) => {
      Object.assign(req, {
        userContext: { companyId: 'c1', userId: req.header('x-test-user') ?? 'u1', role: req.header('x-test-role') },
      });
      next();
    });
    app.use('/contracts', contractsRouter);
    server = app.listen(0, '127.0.0.1', done);
  });
  afterAll((done) => {
    server.close(done);
  });
  const post = (role: string, user = 'u1') =>
    request(server).post('/contracts/generate-due').set('x-test-role', role).set('x-test-user', user).send({});

  it('the manager cannot (no createOrder), like the app', async () => {
    seed('companies/c1/orders/t1', template({ nextDueDate: '2020-01-01T00:00:00.000' }));
    const res = await post('manager');
    expect(res.status).toBe(403);
    expect(generated()).toHaveLength(0);
  });

  it('admin generates every due contract and a repeat generates nothing', async () => {
    seed('companies/c1/orders/t1', template({ nextDueDate: '2020-01-01T00:00:00.000' }));
    const first = await post('admin');
    const again = await post('admin');
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ contractsOn: true, generated: 1 });
    expect(first.body.data.orders).toEqual([{ templateId: 't1', orderId: generated()[0].id }]);
    expect(again.body.data.generated).toBe(0);
  });

  it('a technician generates only from contracts they created', async () => {
    seed('companies/c1/orders/t1', template({ nextDueDate: '2020-01-01T00:00:00.000' }));
    const res = await post('technician', 'tech1');
    expect(res.body.data.generated).toBe(0);
  });
});
