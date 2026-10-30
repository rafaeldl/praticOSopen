/**
 * Backfill order payment status
 * Orders without a usable `payment` ('unpaid' or 'paid') stay out of
 * "Falta receber": the Financeiro query is `payment == 'unpaid'`. This sets
 * `paid`/`payment` from the order total and paidAmount on active orders whose
 * `payment` is missing, null or the legacy 'partial'.
 *
 * Quotes, canceled orders and orders already 'paid' or 'unpaid' are skipped.
 * `paymentSyncedAt` keeps the order trigger from issuing a nota automatically
 * for an order that turns 'paid' here. Amounts and updatedAt are not touched.
 *
 * Dry run by default; review the list before applying.
 *
 * Usage (from firebase/functions, with GOOGLE_APPLICATION_CREDENTIALS set):
 *   npx ts-node scripts/backfill-order-payment-status.ts
 *   npx ts-node scripts/backfill-order-payment-status.ts --company=<companyId>
 *   npx ts-node scripts/backfill-order-payment-status.ts --apply
 */

import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const APPLY = process.argv.includes('--apply');
const COMPANY = process.argv.find((a) => a.startsWith('--company='))?.split('=')[1];
const BATCH_SIZE = 400;

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

async function backfillCompany(company: FirebaseFirestore.DocumentSnapshot): Promise<{ orders: number; open: number }> {
  const snap = await db.collection(`companies/${company.id}/orders`).get();
  const now = new Date().toISOString();
  let batch = db.batch();
  let pending = 0;
  let orders = 0;
  let open = 0;

  for (const doc of snap.docs) {
    const order = doc.data();
    if (order.status === 'quote' || order.status === 'canceled') continue;
    if (order.payment === 'paid' || order.payment === 'unpaid') continue;

    const total = Number(order.total ?? 0);
    const paidAmount = roundMoney(Number(order.paidAmount ?? 0));
    const paid = total > 0 && paidAmount >= roundMoney(total);
    const payment = paid ? 'paid' : 'unpaid';
    const missing = paid ? 0 : roundMoney(total - paidAmount);
    orders += 1;
    open += missing;
    console.log(`  OS ${order.number ?? doc.id}: payment ${order.payment ?? 'none'} → ${payment}, missing ${missing}`);

    if (!APPLY) continue;
    batch.update(doc.ref, { paid, payment, paymentSyncedAt: now });
    pending += 1;
    if (pending === BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { orders, open: roundMoney(open) };
}

async function main() {
  console.log(`\nBackfill order payment status ${APPLY ? '(APPLY)' : '(DRY RUN)'}\n`);
  const companies = COMPANY
    ? [await db.collection('companies').doc(COMPANY).get()]
    : (await db.collection('companies').get()).docs;

  let orders = 0;
  let open = 0;
  for (const company of companies) {
    if (!company.exists) continue;
    const result = await backfillCompany(company);
    if (result.orders === 0) continue;
    console.log(`${company.data()?.name ?? company.id} (${company.id}): ${result.orders} OS, ${result.open} to receive\n`);
    orders += result.orders;
    open += result.open;
  }
  console.log(`Total: ${orders} OS, ${roundMoney(open)} to receive`);
  if (!APPLY) console.log('Nothing written. Run with --apply to save.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
