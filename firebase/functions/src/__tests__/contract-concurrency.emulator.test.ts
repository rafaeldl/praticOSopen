/**
 * Recurring contracts with real Firestore transactions (emulator): the job,
 * the route and a retry running together, and old app versions that still
 * generate on their own (lib/mobx/order_store.dart generateOrderFromContract:
 * read the contract query, `add` the order with a random id, then save the
 * whole template; no transaction).
 *
 * `appGenerate` below is that sequence step by step, with the network round
 * trip of each step as a parameter. The tests prove what happens in every
 * interleaving and measure the window in which both generate.
 *
 * Run with the emulator: `npm run test:rules` (or test:contracts). Skipped
 * without FIRESTORE_EMULATOR_HOST.
 */

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeEmulator = emulatorHost ? describe : describe.skip;

describeEmulator('contracts: job, route and old app at the same time', () => {
  /* eslint-disable @typescript-eslint/no-require-imports */
  const { db } = require('../services/firestore.service') as typeof import('../services/firestore.service');
  const { generateDueOrders } = require('../services/contract.service') as typeof import('../services/contract.service');
  const { advanceContract, buildContractOrder, instantOfWall, parseContractDate, shouldGenerate, wallClockOf } =
    require('../services/contract-generation') as typeof import('../services/contract-generation');
  /* eslint-enable @typescript-eslint/no-require-imports */

  type Json = Record<string, any>;
  const NOW = instantOfWall(parseContractDate('2026-11-03T02:00:00.000')!);
  const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
  let seq = 0;

  jest.setTimeout(120_000);

  async function seedCompany(): Promise<string> {
    const companyId = `race${Date.now()}_${seq++}`;
    await db.collection('companies').doc(companyId).set({ name: 'Clima', country: 'BR', useContracts: true });
    await db.collection('companies').doc(companyId).collection('orders').doc('t1').set({
      number: 7,
      isContract: true,
      createdBy: { id: 'u1', name: 'Ana' },
      customer: { id: 'cust1', name: 'Sol' },
      services: [{ service: { id: 's1', name: 'Limpeza' }, description: 'Limpeza', value: 100 }],
      contract: {
        frequency: 'monthly', interval: 1, startDate: '2026-10-03T09:00:00.000',
        nextDueDate: '2026-11-03T00:00:00.000', generatedCount: 0, autoGenerate: true, active: true,
      },
    });
    return companyId;
  }

  const orders = (companyId: string) => db.collection('companies').doc(companyId).collection('orders');
  async function generatedCount(companyId: string): Promise<number> {
    const snap = await orders(companyId).where('contract.parentOrderId', '==', 't1').get();
    return snap.size;
  }
  async function templateContract(companyId: string): Promise<Json> {
    return ((await orders(companyId).doc('t1').get()).data() as Json).contract;
  }

  interface AppHooks {
    /** Round trip of each Firestore call, ms. */
    rtt?: number;
    /** Snapshot read earlier (a cached query result): skips the read. */
    cached?: Json;
    afterRead?: () => Promise<void>;
    afterAdd?: () => Promise<void>;
  }

  /** The app's generateOrderFromContract, step by step. Returns whether it generated. */
  async function appGenerate(companyId: string, hooks: AppHooks = {}): Promise<{ generated: boolean; readAt: number; wroteAt: number }> {
    const rtt = hooks.rtt ?? 0;
    const start = Date.now();
    let template = hooks.cached;
    if (!template) {
      await sleep(rtt);
      template = (await orders(companyId).doc('t1').get()).data() as Json;
    }
    const readAt = Date.now() - start;
    await hooks.afterRead?.();
    const now = wallClockOf(NOW);
    if (!shouldGenerate(template.contract, now)) return { generated: false, readAt, wroteAt: readAt };
    await sleep(rtt);
    await orders(companyId).add(buildContractOrder(template, 't1', { id: companyId }, now));
    await hooks.afterAdd?.();
    // updateItem: the whole template, merged, with the contract the app computed.
    const contract = { ...template.contract, ...advanceContract(template.contract, now) };
    await sleep(rtt);
    await orders(companyId).doc('t1').set({ ...template, contract }, { merge: true });
    return { generated: true, readAt, wroteAt: Date.now() - start };
  }

  const serverGenerate = (companyId: string) => generateDueOrders(companyId, { now: NOW });

  it('job, route and retries at the same time: one order', async () => {
    const companyId = await seedCompany();
    const results = await Promise.all(Array.from({ length: 20 }, () => serverGenerate(companyId)));
    expect(results.reduce((sum, r) => sum + r.generated, 0)).toBe(1);
    expect(await generatedCount(companyId)).toBe(1);
    expect((await templateContract(companyId)).generatedCount).toBe(1);
  });

  it('the app generated first: the job finds the contract advanced and does nothing', async () => {
    const companyId = await seedCompany();
    await appGenerate(companyId);
    expect((await serverGenerate(companyId)).generated).toBe(0);
    expect(await generatedCount(companyId)).toBe(1);
  });

  it('the job generated first and the app reads fresh data: the app does nothing', async () => {
    const companyId = await seedCompany();
    await serverGenerate(companyId);
    expect((await appGenerate(companyId)).generated).toBe(false);
    expect(await generatedCount(companyId)).toBe(1);
  });

  it('the job commits between the app read and the app writes: two orders', async () => {
    const companyId = await seedCompany();
    await appGenerate(companyId, { afterRead: async () => void (await serverGenerate(companyId)) });
    expect(await generatedCount(companyId)).toBe(2);
    // The app's full save wins: same next due date, but the count lost one.
    expect(await templateContract(companyId)).toMatchObject({ nextDueDate: '2026-12-03T00:00:00.000', generatedCount: 1 });
    // Nothing else is generated afterwards.
    expect((await serverGenerate(companyId)).generated).toBe(0);
  });

  it('the job commits between the app add and the template save: two orders', async () => {
    const companyId = await seedCompany();
    await appGenerate(companyId, { afterAdd: async () => void (await serverGenerate(companyId)) });
    expect(await generatedCount(companyId)).toBe(2);
  });

  it('the app reads a cached query result from before the job: two orders, hours later', async () => {
    // The app reads `streamContractOrders(...).first`. With offline persistence a
    // listener raises the cached result first when it has documents
    // (QueryListener::ShouldRaiseInitialEvent, wait_for_sync_when_online false).
    const companyId = await seedCompany();
    const cached = (await orders(companyId).doc('t1').get()).data() as Json;
    await serverGenerate(companyId); // the night job
    await appGenerate(companyId, { cached }); // the morning open, offline cache first
    expect(await generatedCount(companyId)).toBe(2);
  });

  it('measures the window: the job duplicates only when it commits between the app read and the app save', async () => {
    const rows: string[] = [];
    for (const rtt of [0, 150]) {
      const duplicatedAt: number[] = [];
      const offsets = rtt === 0 ? [-40, -20, -10, -5, 0, 5, 10, 20, 40] : [-300, -150, -50, 0, 100, 200, 300, 400, 500, 700, 900];
      let window = { read: 0, wrote: 0 };
      for (const offset of offsets) {
        const companyId = await seedCompany();
        // offset = when the job starts, relative to the app opening (negative: before).
        const app = sleep(Math.max(0, -offset)).then(() => appGenerate(companyId, { rtt }));
        const job = sleep(Math.max(0, offset)).then(() => serverGenerate(companyId));
        const [appResult] = await Promise.all([app, job]);
        if (appResult.generated) window = { read: appResult.readAt, wrote: appResult.wroteAt };
        if ((await generatedCount(companyId)) > 1) duplicatedAt.push(offset);
      }
      rows.push(
        `rtt=${rtt}ms app read at ${window.read}ms, saved the template at ${window.wrote}ms; ` +
          `duplicate when the job started at ${duplicatedAt.join(', ') || 'none'} ms`,
      );
      // Only when the job's commit lands inside the app's read → save span: the
      // job starts at most one transaction before the app reads, and before it saves.
      for (const offset of duplicatedAt) {
        expect(offset).toBeLessThanOrEqual(window.wrote);
        expect(offset).toBeGreaterThanOrEqual(-100);
      }
      if (rtt > 0) expect(duplicatedAt.length).toBeGreaterThan(0);
    }
    console.log(`[contracts race]\n${rows.join('\n')}`);
  });
});
