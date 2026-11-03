/**
 * Runs docs/web-app/contract-cases/contract-generation.json against the real
 * server code: the job/route path (contract.service over the in-memory
 * Firestore) and the pure rules. The Dart side is
 * test/contract/contract_generation_cases_test.dart (OrderContract and
 * lib/utils/contract_generation.dart, PR #513). File listed in COVERED of
 * contract-cases.test.ts.
 */
import { readFileSync } from 'fs';
import * as path from 'path';

jest.mock('../services/firestore.service', () => {
  const fake = jest.requireActual('./helpers/fake-firestore');
  return {
    ...fake.firestoreServiceMock,
    runTransaction: (fn: (tx: unknown) => Promise<unknown>) => fake.fakeDb.runTransaction(fn),
  };
});

import { list, read, resetFakeDb, seed } from './helpers/fake-firestore';
import { generateDueOrders } from '../services/contract.service';
import {
  contractOrderId,
  instantOfWall,
  isContractDue,
  parseContractDate,
  shouldGenerate,
} from '../services/contract-generation';

const LANG = 'functions';
const doc = JSON.parse(
  readFileSync(path.join(__dirname, '../../../../docs/web-app/contract-cases/contract-generation.json'), 'utf8'),
);
const want = (c: any): any => ({ ...(c.correct ?? c.expect), ...c.divergesIn?.[LANG] });
const pick = (from: any, like: any): any => Object.fromEntries(Object.keys(like).map((key) => [key, from[key]]));

const TEMPLATE = `companies/c1/orders/${doc.templateId}`;

beforeEach(() => resetFakeDb());

describe('contract-generation', () => {
  it('runs in functions', () => {
    expect(doc.runsIn).toContain(LANG);
  });

  describe('order id', () => {
    for (const c of doc.idCases) {
      it(c.id, () => {
        expect(contractOrderId(c.templateId, c.due)).toBe(c.orderId);
      });
    }
  });

  for (const c of doc.cases) {
    it(c.id, async () => {
      const expected = want(c);
      const contract = { ...doc.contract, ...c.given.contract };
      const template = { ...doc.template, ...c.given.template, contract };
      const now = parseContractDate(c.given.now)!;

      expect(isContractDue(contract, now)).toBe(expected.due);
      expect(shouldGenerate(contract, now)).toBe(expected.generates);

      seed(`companies/c1`, { ...doc.company, useContracts: true });
      seed(TEMPLATE, template);
      const result = await generateDueOrders('c1', { now: instantOfWall(now) });

      const created = list('companies/c1/orders').filter((o) => o.id !== doc.templateId);
      expect(result.generated).toBe(expected.generates ? 1 : 0);
      expect(created).toHaveLength(expected.generates ? 1 : 0);
      if (!expected.generates) {
        expect(read(TEMPLATE)).toEqual(template);
        return;
      }

      const [order] = created;
      expect(order.id).toBe(contractOrderId(doc.templateId, contract.nextDueDate));
      if (expected.orderId) expect(order.id).toBe(expected.orderId);
      expect(order.data.createdAt).toBe(c.given.now);
      expect(order.data.updatedAt).toBe(c.given.now);
      if (expected.order) expect(pick(order.data, expected.order)).toEqual(expected.order);

      const after = (read(TEMPLATE) as any).contract;
      expect(after.lastGeneratedDate).toBe(c.given.now);
      expect(pick(after, expected.contract)).toEqual(expected.contract);
    });
  }
});
