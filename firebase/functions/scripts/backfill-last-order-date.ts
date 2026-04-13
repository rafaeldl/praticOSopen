/**
 * Backfill lastOrderDate Script
 * Sets the `lastOrderDate` field on all company documents based on their most recent order.
 *
 * Usage (production - uses default credentials):
 *   npx ts-node scripts/backfill-last-order-date.ts
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npx ts-node scripts/backfill-last-order-date.ts
 *
 * Dry run (no writes):
 *   npx ts-node scripts/backfill-last-order-date.ts --dry-run
 */

import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');

async function backfillLastOrderDate() {
  console.log(`\n🔄 Backfill lastOrderDate ${DRY_RUN ? '(DRY RUN)' : ''}\n`);

  const companiesSnap = await db.collection('companies').get();
  console.log(`Found ${companiesSnap.size} companies\n`);

  let updated = 0;
  let skipped = 0;
  let noOrders = 0;
  let errors = 0;

  for (const companyDoc of companiesSnap.docs) {
    try {
      const companyData = companyDoc.data();
      const companyName = companyData.name || companyDoc.id;

      // Get most recent order
      const ordersSnap = await db
        .collection(`companies/${companyDoc.id}/orders`)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

      if (ordersSnap.empty) {
        noOrders++;
        continue;
      }

      const latestOrder = ordersSnap.docs[0].data();
      const lastOrderDate = latestOrder.createdAt;

      if (!lastOrderDate) {
        console.log(`  ⚠ ${companyName}: latest order has no createdAt`);
        skipped++;
        continue;
      }

      // Check if already has lastOrderDate and is up-to-date
      if (companyData.lastOrderDate) {
        const existing = companyData.lastOrderDate.toDate
          ? companyData.lastOrderDate.toDate()
          : new Date(companyData.lastOrderDate);
        const newDate = lastOrderDate.toDate
          ? lastOrderDate.toDate()
          : new Date(lastOrderDate);

        if (existing >= newDate) {
          skipped++;
          continue;
        }
      }

      if (!DRY_RUN) {
        await companyDoc.ref.update({ lastOrderDate });
      }

      console.log(`  ✅ ${companyName}: lastOrderDate set`);
      updated++;
    } catch (err: any) {
      console.error(`  ❌ ${companyDoc.id}: ${err.message}`);
      errors++;
    }
  }

  console.log(`\n📊 Results:`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped (already up-to-date): ${skipped}`);
  console.log(`  No orders: ${noOrders}`);
  console.log(`  Errors: ${errors}`);
  console.log(`  Total: ${companiesSnap.size}\n`);
}

backfillLastOrderDate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
