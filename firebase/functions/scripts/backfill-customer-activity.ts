/**
 * Backfill `lastActivityAt` on every customer (services/customer-activity.service.ts):
 * the most recent of the customer's own createdAt/updatedAt and the createdAt/
 * updatedAt of their orders. Never puts an older date over a newer one, so it
 * can run again. Run it after the triggers are deployed.
 *
 * Usage (production - uses default credentials):
 *   npx ts-node scripts/backfill-customer-activity.ts --dry-run
 *   npx ts-node scripts/backfill-customer-activity.ts
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npx ts-node scripts/backfill-customer-activity.ts
 *
 * One company only: --company=<companyId>
 */

import * as admin from 'firebase-admin';
import { dateMillis } from '../src/services/customer-activity.service';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');
const ONLY = process.argv.find((arg) => arg.startsWith('--company='))?.split('=')[1];

const latest = (...values: unknown[]) =>
  values.map(dateMillis).reduce<number | null>((max, ms) => (ms != null && (max == null || ms > max) ? ms : max), null);

async function backfillCompany(companyId: string): Promise<{ updated: number; skipped: number }> {
  const company = db.collection('companies').doc(companyId);
  const [customers, orders] = await Promise.all([
    company.collection('customers').get(),
    company.collection('orders').select('customer.id', 'createdAt', 'updatedAt').get(),
  ]);

  const fromOrders = new Map<string, number>();
  for (const order of orders.docs) {
    const data = order.data();
    const customerId = data.customer?.id;
    if (typeof customerId !== 'string') continue;
    const ms = latest(data.createdAt, data.updatedAt, fromOrders.get(customerId));
    if (ms != null) fromOrders.set(customerId, ms);
  }

  let updated = 0;
  let skipped = 0;
  let batch = db.batch();
  let pending = 0;
  for (const customer of customers.docs) {
    const data = customer.data();
    const ms = latest(data.createdAt, data.updatedAt, fromOrders.get(customer.id));
    const current = dateMillis(data.lastActivityAt);
    if (ms == null || (current != null && current >= ms)) {
      skipped++;
      continue;
    }
    updated++;
    if (DRY_RUN) continue;
    batch.update(customer.ref, { lastActivityAt: new Date(ms).toISOString() });
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { updated, skipped };
}

async function main() {
  console.log(`\nBackfill customer lastActivityAt ${DRY_RUN ? '(DRY RUN)' : ''}\n`);
  const companyIds = ONLY ? [ONLY] : (await db.collection('companies').select().get()).docs.map((doc) => doc.id);
  let updated = 0;
  let skipped = 0;
  let errors = 0;
  for (const companyId of companyIds) {
    try {
      const result = await backfillCompany(companyId);
      updated += result.updated;
      skipped += result.skipped;
      if (result.updated) console.log(`  ${companyId}: ${result.updated} customers`);
    } catch (err) {
      console.error(`  ${companyId}: ${(err as Error).message}`);
      errors++;
    }
  }
  console.log(`\nCompanies: ${companyIds.length}  Updated: ${updated}  Skipped: ${skipped}  Errors: ${errors}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
