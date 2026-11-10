/**
 * Backfill the Clientes list numbers on every customer
 * (services/customer-aggregates.service.ts): `openOrders`, `owed` and
 * `openDueDates`, counted from all the customer's orders with the same rule as
 * the order triggers. Writes only what changed, so it can run again (and fixes
 * a count left old by two changes at the same instant). Run it right after the
 * triggers are deployed: until then the list shows no badge and no "Falta receber".
 *
 * Usage (production - uses default credentials):
 *   npx ts-node scripts/backfill-customer-aggregates.ts --dry-run
 *   npx ts-node scripts/backfill-customer-aggregates.ts
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npx ts-node scripts/backfill-customer-aggregates.ts
 *
 * One company only: --company=<companyId>
 */

import * as admin from 'firebase-admin';
import { AGGREGATE_FIELDS, aggregatesOf } from '../src/services/customer-aggregates.service';
import type { SummaryOrder } from '../src/services/customer-summary';
import { companyZone } from '../src/utils/company-zone';

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');
const ONLY = process.argv.find((arg) => arg.startsWith('--company='))?.split('=')[1];

const same = (a: unknown, b: unknown) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

async function backfillCompany(companyId: string): Promise<{ updated: number; skipped: number }> {
  const company = db.collection('companies').doc(companyId);
  const [companyDoc, customers, orders] = await Promise.all([
    company.get(),
    company.collection('customers').select(...AGGREGATE_FIELDS).get(),
    company.collection('orders').select('customer.id', 'status', 'dueDate', 'total', 'paidAmount', 'payment').get(),
  ]);
  const zone = companyZone(companyDoc.data()?.country as string | undefined);

  const byCustomer = new Map<string, SummaryOrder[]>();
  for (const order of orders.docs) {
    const data = order.data() as SummaryOrder;
    const customerId = data.customer?.id;
    if (typeof customerId !== 'string' || !customerId) continue;
    const list = byCustomer.get(customerId) ?? [];
    list.push(data);
    byCustomer.set(customerId, list);
  }

  let updated = 0;
  let skipped = 0;
  let batch = db.batch();
  let pending = 0;
  for (const customer of customers.docs) {
    const current = customer.data();
    const next = aggregatesOf(byCustomer.get(customer.id) ?? [], zone);
    if (AGGREGATE_FIELDS.every((field) => same(current[field], next[field]))) {
      skipped++;
      continue;
    }
    updated++;
    if (DRY_RUN) continue;
    batch.update(customer.ref, { ...next });
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
  console.log(`\nBackfill customer list numbers ${DRY_RUN ? '(DRY RUN)' : ''}\n`);
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
