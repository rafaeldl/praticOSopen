/**
 * Backfill order payment status and lastPaymentAt
 *
 * 1. Orders without a usable `payment` ('unpaid' or 'paid') stay out of
 *    "Falta receber": the Financeiro query is `payment == 'unpaid'`. This sets
 *    `paid`/`payment` from the order total and paidAmount on active orders
 *    whose `payment` is missing, null or the legacy 'partial'.
 * 2. "Recebido em {mês}" finds orders paid in a month by `lastPaymentAt`, kept
 *    by the order trigger: this fills it on orders paid before it existed.
 *
 * Quotes, canceled orders and orders already 'paid' or 'unpaid' keep their
 * status. So do orders that may already be paid but have no amount to tell
 * (`paid: true`, or transactions without paidAmount): they are only listed.
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
import { latestPaymentAt } from '../src/utils/payment-time';

admin.initializeApp();

const db = admin.firestore();
const APPLY = process.argv.includes('--apply');
const COMPANY = process.argv.find((a) => a.startsWith('--company='))?.split('=')[1];
const BATCH_SIZE = 400;

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

async function backfillCompany(company: FirebaseFirestore.DocumentSnapshot): Promise<{ orders: number; open: number; stamped: number; unclear: number }> {
  const snap = await db.collection(`companies/${company.id}/orders`).get();
  const now = new Date().toISOString();
  let batch = db.batch();
  let pending = 0;
  let orders = 0;
  let open = 0;
  let stamped = 0;
  let unclear = 0;

  async function write(ref: FirebaseFirestore.DocumentReference, data: Record<string, unknown>) {
    batch.update(ref, data);
    pending += 1;
    if (pending === BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  for (const doc of snap.docs) {
    const order = doc.data();
    const lastPaymentAt = latestPaymentAt(order.transactions);
    if (lastPaymentAt && !order.lastPaymentAt) {
      stamped += 1;
      if (APPLY) await write(doc.ref, { lastPaymentAt });
    }

    if (order.status === 'quote' || order.status === 'canceled') continue;
    if (order.payment === 'paid' || order.payment === 'unpaid') continue;

    const hasPayments = (order.transactions ?? []).some((t: { type?: string }) => t.type === 'payment');
    if (order.paid === true || (order.paidAmount == null && hasPayments)) {
      unclear += 1;
      console.log(`  OS ${order.number ?? doc.id}: left as is, may already be paid (paid: ${order.paid}, paidAmount: ${order.paidAmount})`);
      continue;
    }

    const total = Number(order.total ?? 0);
    const paidAmount = roundMoney(Number(order.paidAmount ?? 0));
    const paid = total > 0 && paidAmount >= roundMoney(total);
    const payment = paid ? 'paid' : 'unpaid';
    const missing = paid ? 0 : roundMoney(total - paidAmount);
    orders += 1;
    open += missing;
    console.log(`  OS ${order.number ?? doc.id}: payment ${order.payment ?? 'none'} → ${payment}, missing ${missing}`);

    if (APPLY) await write(doc.ref, { paid, payment, paymentSyncedAt: now });
  }
  if (pending > 0) await batch.commit();
  return { orders, open: roundMoney(open), stamped, unclear };
}

async function main() {
  console.log(`\nBackfill order payment status ${APPLY ? '(APPLY)' : '(DRY RUN)'}\n`);
  const companies = COMPANY
    ? [await db.collection('companies').doc(COMPANY).get()]
    : (await db.collection('companies').get()).docs;

  let orders = 0;
  let open = 0;
  let stamped = 0;
  let unclear = 0;
  for (const company of companies) {
    if (!company.exists) continue;
    const result = await backfillCompany(company);
    stamped += result.stamped;
    unclear += result.unclear;
    if (result.orders === 0) continue;
    console.log(`${company.data()?.name ?? company.id} (${company.id}): ${result.orders} OS, ${result.open} to receive\n`);
    orders += result.orders;
    open += result.open;
  }
  console.log(`Total: ${orders} OS, ${roundMoney(open)} to receive`);
  console.log(`lastPaymentAt: ${stamped} OS. Left as is, may already be paid: ${unclear} OS`);
  if (!APPLY) console.log('Nothing written. Run with --apply to save.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
