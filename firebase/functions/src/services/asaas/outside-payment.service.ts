/**
 * Money received outside Asaas while a payment link is open ("dar baixa").
 *
 * Runs from the order trigger (`onOrderUpdatedAsaas`) whenever an order's
 * transactions, total or status change, so it also covers payments the app
 * registered offline (they reach the server when the phone syncs). An
 * explicit call from the app would miss those and need the connection at
 * the moment of receiving.
 *
 * For every open charge covering the order (single-order `charges` in mode
 * `single`, and multi-order `customerCharges`), the amount still owed through
 * the link is recomputed from the orders (each share capped at what is open
 * on its order; quotes and canceled orders owe nothing):
 *
 * - nothing left and money was registered on the orders since the link was
 *   created → `POST /payments/{id}/receiveInCash` with that money (at most
 *   the charge value, notifyCustomer false) and the charge becomes `paid` +
 *   `paidOutside`; the PAYMENT_RECEIVED webhook that follows (status
 *   RECEIVED_IN_CASH) is recognized by `settlingOutsideAt`/`paidOutside` and
 *   books nothing (also while the outcome of the call is unknown);
 * - nothing left but no money came in (discount, total lowered, order
 *   canceled) → the link is canceled: nothing was received in cash;
 * - less than the link → `PUT /payments/{id}` with the remaining value (the
 *   link stays the same); multi-order allocations are updated. If Asaas
 *   refuses the new value (e.g. below its minimum), the link is canceled so
 *   the customer can never pay more than is owed;
 * - same or more → nothing.
 *
 * Installment plans can't be lowered or received in cash: one with nothing
 * paid yet is canceled once the orders owe less than it (a plan with a paid
 * installment is left alone). A quote owes nothing, so its link is canceled
 * like any link with nothing left to charge.
 *
 * Concurrency: a short lease (`adjustingUntil`) on the charge. An invocation
 * that finds the lease taken bumps `dirtyCount` and returns; the holder
 * recomputes until nothing changes and, before releasing, runs again if the
 * charge was marked dirty after its last read (bounded rounds).
 *
 * An unknown receiveInCash outcome (timeout, network, 5xx) keeps
 * `settlingOutsideAt`: the RECEIVED_IN_CASH webhook is not booked, and the
 * payment status is confirmed on Asaas (GET) right away or in the next
 * reconciliation before deciding anything else.
 */
import { db, FieldValue } from '../firestore.service';
import { calculateRemainingBalance } from '../order.service';
import type { Order } from '../../models/types';
import type { CustomerCharge, CustomerChargeAllocation, OrderCharge } from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { getAsaasCredentialProvider } from './credential-provider';
import { OPEN_STATUSES, cancelInAsaas, hasPaidInstallments, listCharges } from './charge.service';
import {
  customerChargeRef,
  describeCustomerCharge,
  listOpenCustomerChargesForOrder,
} from './customer-charge.service';
import { ASAAS_TRANSACTION_PREFIX, chargeRef, orderRef } from './order-payment.service';
import { fromCents, toCents } from '../../utils/payment-allocation';

const LEASE_MS = 60 * 1000;
const brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const MAX_ROUNDS = 5;

export type OutsideDecision =
  | { action: 'none' }
  | { action: 'receiveInCash'; value: number }
  | { action: 'update'; value: number }
  | { action: 'cancel' };

/**
 * What to do with an open link of `chargeValue` when `stillOwed` is what is
 * still owed through it (already capped by the caller) and `paidOutside` is
 * what was registered as received on the covered orders (outside Asaas)
 * since the link was created.
 *
 * - still owes all of it → nothing;
 * - owes nothing and money came in → receiveInCash (the money received,
 *   at most the charge value);
 * - owes nothing and no money came in (discount, total lowered, order
 *   canceled) → cancel the link: nothing was received in cash;
 * - owes part of it → lower the link to what is still owed.
 */
export function decideOutsideAction(chargeValue: number, stillOwed: number, paidOutside: number): OutsideDecision {
  const charge = toCents(chargeValue);
  const owed = Math.max(0, toCents(stillOwed));
  if (owed >= charge) return { action: 'none' };
  if (owed > 0) return { action: 'update', value: fromCents(owed) };
  const paid = Math.min(charge, Math.max(0, toCents(paidOutside)));
  if (paid === 0) return { action: 'cancel' };
  return { action: 'receiveInCash', value: fromCents(paid) };
}

/** Open amount of an order for the link: quotes and canceled orders owe nothing. */
export function openForLink(order: Pick<Order, 'status' | 'total' | 'paidAmount'> | undefined): number {
  if (!order || order.status === 'quote' || order.status === 'canceled') return 0;
  return calculateRemainingBalance(order);
}

/** An ISO string that ends with 'Z' or an offset ('+02:00', '-0300'). */
const ZONED_ISO = /(?:[zZ]|[+-]\d{2}:?\d{2})$/;

/**
 * The app writes `createdAt` as the phone's local time without a zone
 * ('2026-10-29T17:39:47.433185'); Date.parse would read it as UTC here and
 * put a payment made right after the link three hours before it. Such
 * strings are read as Brazil time (UTC-3, no daylight saving since 2019).
 */
export function parseTransactionTime(value: string): number {
  const trimmed = value.trim();
  if (ZONED_ISO.test(trimmed)) return Date.parse(trimmed);
  const withTime = /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? `${trimmed}T00:00:00` : trimmed;
  return Date.parse(`${withTime}-03:00`);
}

function toMillis(value: unknown): number {
  if (!value) return NaN;
  if (typeof value === 'string') return parseTransactionTime(value);
  if (value instanceof Date) return value.getTime();
  const maybe = value as { toMillis?: () => number; toDate?: () => Date };
  if (typeof maybe.toMillis === 'function') return maybe.toMillis();
  if (typeof maybe.toDate === 'function') return maybe.toDate().getTime();
  return NaN;
}

/**
 * Money registered on the order outside Asaas since `sinceIso`: `payment`
 * transactions that are not Asaas ones (`asaas_` prefix), by registration
 * time (`createdAt`; an offline payment keeps the time it was registered).
 */
export function paidOutsideSince(order: Pick<Order, 'transactions'> | undefined, sinceIso: string): number {
  const since = Date.parse(sinceIso);
  const cents = (order?.transactions ?? [])
    .filter((t) => t.type === 'payment' && !t.id?.startsWith(ASAAS_TRANSACTION_PREFIX))
    .filter((t) => {
      const at = toMillis(t.createdAt);
      return Number.isFinite(since) && Number.isFinite(at) && at >= since;
    })
    .reduce((sum, t) => sum + toCents(t.amount), 0);
  return fromCents(cents);
}

/** Allocations of a multi-order charge capped at what each order still owes. */
export function capAllocations(
  allocations: CustomerChargeAllocation[],
  openByOrder: Map<string, number>,
): CustomerChargeAllocation[] {
  return allocations.map((a) => ({
    ...a,
    amount: fromCents(Math.min(toCents(a.amount), toCents(openByOrder.get(a.orderId) ?? 0))),
  }));
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Takes the lease. When another invocation holds it, marks the charge dirty
 * (`dirtyCount`) so the holder runs again before releasing: a write that
 * landed after the holder's last read is never left unreconciled.
 */
async function claimLease(ref: FirebaseFirestore.DocumentReference): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const data = snap.data() as { status: string; adjustingUntil?: string; dirtyCount?: number };
    if (!OPEN_STATUSES.includes(data.status as OrderCharge['status'])) return false;
    const now = Date.now();
    if (data.adjustingUntil && Date.parse(data.adjustingUntil) > now) {
      tx.update(ref, { dirtyCount: (data.dirtyCount ?? 0) + 1, dirtyAt: new Date(now).toISOString() });
      return false;
    }
    tx.update(ref, { adjustingUntil: new Date(now + LEASE_MS).toISOString() });
    return true;
  });
}

/**
 * Releases the lease unless the charge was marked dirty after the holder read
 * it (`seenDirty`) and is still open. Returns false when it must run again.
 */
async function releaseLeaseIfClean(ref: FirebaseFirestore.DocumentReference, seenDirty: number): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return true;
    const data = snap.data() as { status: string; dirtyCount?: number };
    const open = OPEN_STATUSES.includes(data.status as OrderCharge['status']);
    if (open && (data.dirtyCount ?? 0) !== seenDirty) return false;
    tx.update(ref, { adjustingUntil: FieldValue.delete() });
    return true;
  });
}

async function releaseLease(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  const snap = await ref.get();
  if (snap.exists) await ref.update({ adjustingUntil: FieldValue.delete() });
}

/** One reconciliation pass: `again` asks for another pass; `dirty` is the `dirtyCount` it read. */
type PassResult = { again: boolean; dirty: number };

/**
 * Runs `pass` under the lease until nothing is left to do and no other
 * invocation marked the charge dirty meanwhile (at most MAX_ROUNDS passes).
 */
async function withLease(ref: FirebaseFirestore.DocumentReference, pass: () => Promise<PassResult>): Promise<void> {
  if (!(await claimLease(ref))) return;
  let released = false;
  try {
    for (let round = 0; round < MAX_ROUNDS; round++) {
      const { again, dirty } = await pass();
      if (again) continue;
      if (await releaseLeaseIfClean(ref, dirty)) {
        released = true;
        return;
      }
    }
    console.warn('[AsaasOutside] reconciliation stopped after max rounds', { chargeId: ref.id });
  } finally {
    if (!released) await releaseLease(ref);
  }
}

const SETTLE_FLAGS = { settlingOutsideAt: FieldValue.delete(), settlingOutsideValue: FieldValue.delete() };

async function markPaidOutside(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  await ref.update({ status: 'paid', paidOutside: true, paidAt: new Date().toISOString(), ...SETTLE_FLAGS });
}

/** Asaas answered and refused (4xx): nothing was received in cash. Timeouts, network errors and 5xx are unknown. */
function isDefinitiveRejection(error: unknown): boolean {
  return error instanceof AsaasApiError && error.status >= 400 && error.status < 500 && error.status !== 408;
}

/**
 * A receiveInCash whose outcome is unknown (`settlingOutsideAt` kept): asks
 * Asaas for the payment status.
 * - RECEIVED_IN_CASH → it went through: the charge is paid outside;
 * - PENDING/OVERDUE → it did not: the flag is cleared (`cleared`), the caller
 *   may decide again;
 * - anything else (paid through Asaas, deleted, refunded) → the flag is
 *   cleared and the webhook books/cancels as usual (`other`).
 * Throws (flag kept) when Asaas cannot be reached.
 */
async function confirmPendingSettlement(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  asaasPaymentId: string,
): Promise<'settled' | 'cleared' | 'other'> {
  const payment = await client.getPayment(asaasPaymentId);
  if (payment.status === 'RECEIVED_IN_CASH') {
    await markPaidOutside(ref);
    console.log('[AsaasOutside] pending cash receipt confirmed on Asaas', { chargeId: ref.id });
    return 'settled';
  }
  await ref.update(SETTLE_FLAGS);
  if (!payment.deleted && (payment.status === 'PENDING' || payment.status === 'OVERDUE')) return 'cleared';
  return 'other';
}

/**
 * receiveInCash for the whole charge; marks it paid outside. The flag
 * (`settlingOutsideAt` + `settlingOutsideValue`) is set before the call and
 * only cleared when Asaas definitely refused it (4xx): after a timeout,
 * network error or 5xx Asaas may have received it, and its RECEIVED_IN_CASH
 * webhook must not be booked as an Asaas payment. The status is then checked
 * right away and, if Asaas cannot be reached, in the next reconciliation.
 */
async function settleOutside(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  asaasPaymentId: string,
  value: number,
): Promise<void> {
  await ref.update({ settlingOutsideAt: new Date().toISOString(), settlingOutsideValue: value });
  try {
    await client.receiveInCash(asaasPaymentId, { paymentDate: todayIso(), value, notifyCustomer: false });
  } catch (error) {
    if (isDefinitiveRejection(error)) {
      await ref.update(SETTLE_FLAGS);
      throw error;
    }
    console.warn('[AsaasOutside] receiveInCash outcome unknown; checking the payment', { chargeId: ref.id });
    const outcome = await confirmPendingSettlement(client, ref, asaasPaymentId).catch(() => null);
    if (outcome === 'settled') return;
    throw error;
  }
  await markPaidOutside(ref);
}

/**
 * PUT the new value. When Asaas refuses it (400, e.g. below its minimum),
 * the link is canceled instead: it must never charge more than is owed.
 * Returns false when the link was canceled.
 */
async function updateValue(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  charge: Pick<OrderCharge, 'asaasPaymentId' | 'asaasInstallmentId'>,
  input: { value: number; description?: string },
  extra: Record<string, unknown>,
): Promise<boolean> {
  try {
    await client.updatePayment(charge.asaasPaymentId, input);
  } catch (error) {
    if (error instanceof AsaasApiError && error.status === 400) {
      console.warn('[AsaasOutside] Asaas refused the new value; canceling the link', { chargeId: ref.id });
      await cancelLink(client, ref, charge);
      return false;
    }
    throw error;
  }
  await ref.update({ value: input.value, ...extra });
  return true;
}

/**
 * Cancels the link (nothing was received): Asaas first, then our doc, only
 * while it is still open with nothing booked (a webhook that landed in
 * between keeps its paid/refunded status).
 */
async function cancelLink(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  charge: Pick<OrderCharge, 'asaasPaymentId' | 'asaasInstallmentId'>,
): Promise<void> {
  await cancelInAsaas(client, charge);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const current = snap.data() as Pick<OrderCharge, 'status' | 'paidAsaasPaymentIds'>;
    if (!OPEN_STATUSES.includes(current.status) || hasPaidInstallments(current)) return;
    tx.update(ref, { status: 'canceled' });
  });
}

/** Installment payments Asaas already took (the webhook may still be on its way). */
const TAKEN_STATUSES = new Set(['CONFIRMED', 'RECEIVED', 'RECEIVED_IN_CASH']);

/**
 * Cancels an installment plan the order no longer owes in full, unless the
 * customer already paid it on Asaas (card confirmed, webhook not booked
 * yet): then nothing is done and the webhook books it. Leaves an internal
 * comment on the order so the technician knows to send a new link.
 */
async function cancelInstallmentPlan(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  charge: OrderCharge,
  ids: { companyId: string; orderId: string; chargeId: string },
  stillOwed: number,
): Promise<void> {
  if (charge.asaasInstallmentId) {
    const payments = await client.listInstallmentPayments(charge.asaasInstallmentId);
    if (payments.some((p) => TAKEN_STATUSES.has(p.status))) {
      console.warn('[AsaasOutside] installment plan already paid on Asaas; not canceled', ids);
      return;
    }
  }
  await cancelLink(client, ref, charge);
  const owed = fromCents(Math.max(0, toCents(stillOwed)));
  const text = owed > 0
    ? `Parcelamento no cartão de ${brl.format(charge.value)} cancelado: a OS passou a dever ${brl.format(owed)}. Mande um link novo.`
    : `Parcelamento no cartão de ${brl.format(charge.value)} cancelado: a OS não deve mais nada.`;
  await orderRef(ids.companyId, ids.orderId).collection('comments').doc().set({
    text,
    authorType: 'internal',
    author: { name: 'Asaas' },
    source: 'asaas',
    isInternal: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log('[AsaasOutside] order owes less than the installment plan; link canceled', ids);
}

async function reconcileOrderCharge(
  client: () => Promise<AsaasClient>,
  companyId: string,
  orderId: string,
  chargeId: string,
): Promise<void> {
  const ref = chargeRef(companyId, orderId, chargeId) as unknown as FirebaseFirestore.DocumentReference;
  await withLease(ref, async () => {
    const [chargeSnap, orderSnap] = await Promise.all([ref.get(), orderRef(companyId, orderId).get()]);
    if (!chargeSnap.exists) return { again: false, dirty: 0 };
    const charge = chargeSnap.data() as OrderCharge;
    const stop = { again: false, dirty: charge.dirtyCount ?? 0 };
    if (!OPEN_STATUSES.includes(charge.status) || hasPaidInstallments(charge)) return stop;
    const order = orderSnap.exists ? (orderSnap.data() as Order) : undefined;
    // A canceled order: its charges are canceled by handleOrderStatusChange.
    // A quote owes nothing (openForLink): its link is canceled below.
    if (!order || order.status === 'canceled') return stop;
    if (charge.mode !== 'single') {
      // An installment plan can't be lowered or received in cash: once the
      // order owes less than the plan (paid by hand, total lowered, back to
      // quote), the link is canceled, or the customer could pay it all again.
      const open = openForLink(order);
      if (toCents(open) >= toCents(charge.value)) return stop;
      await cancelInstallmentPlan(await client(), ref, charge, { companyId, orderId, chargeId }, open);
      return stop;
    }
    if (order.status === 'quote') {
      // A quote owes nothing: its link is canceled, never received in cash.
      await cancelLink(await client(), ref, charge);
      console.log('[AsaasOutside] order back to quote; link canceled', { companyId, orderId, chargeId });
      return stop;
    }
    if (charge.settlingOutsideAt) {
      if ((await confirmPendingSettlement(await client(), ref, charge.asaasPaymentId)) !== 'cleared') return stop;
    }
    const owed = Math.min(charge.value, openForLink(order));
    const decision = decideOutsideAction(charge.value, owed, paidOutsideSince(order, charge.createdAt));
    if (decision.action === 'none') return stop;
    const asaas = await client();
    if (decision.action === 'cancel') {
      await cancelLink(asaas, ref, charge);
      console.log('[AsaasOutside] nothing left to charge; link canceled', { companyId, orderId, chargeId });
      return stop;
    }
    if (decision.action === 'receiveInCash') {
      await settleOutside(asaas, ref, charge.asaasPaymentId, decision.value);
      console.log('[AsaasOutside] charge settled outside Asaas', { companyId, orderId, chargeId });
      return stop;
    }
    if (!(await updateValue(asaas, ref, charge, { value: decision.value }, {}))) return stop;
    console.log('[AsaasOutside] charge value lowered', { companyId, orderId, chargeId });
    return { ...stop, again: true };
  });
}

async function reconcileCustomerCharge(
  client: () => Promise<AsaasClient>,
  companyId: string,
  chargeId: string,
): Promise<void> {
  const ref = customerChargeRef(companyId, chargeId) as unknown as FirebaseFirestore.DocumentReference;
  await withLease(ref, async () => {
    const chargeSnap = await ref.get();
    if (!chargeSnap.exists) return { again: false, dirty: 0 };
    const charge = { ...(chargeSnap.data() as CustomerCharge), id: chargeSnap.id };
    const stop = { again: false, dirty: charge.dirtyCount ?? 0 };
    if (!OPEN_STATUSES.includes(charge.status) || (charge.paidAsaasPaymentIds ?? []).length > 0) return stop;
    if (charge.settlingOutsideAt) {
      if ((await confirmPendingSettlement(await client(), ref, charge.asaasPaymentId)) !== 'cleared') return stop;
    }

    const orderSnaps = await Promise.all(charge.allocations.map((a) => orderRef(companyId, a.orderId).get()));
    const openByOrder = new Map<string, number>();
    let paidCents = 0;
    orderSnaps.forEach((snap, i) => {
      const order = snap.exists ? (snap.data() as Order) : undefined;
      openByOrder.set(charge.allocations[i].orderId, openForLink(order));
      paidCents += toCents(paidOutsideSince(order, charge.createdAt));
    });
    const capped = capAllocations(charge.allocations, openByOrder);
    const owed = fromCents(capped.reduce((sum, a) => sum + toCents(a.amount), 0));
    const decision = decideOutsideAction(charge.value, owed, fromCents(paidCents));
    if (decision.action === 'none') return stop;
    const asaas = await client();
    if (decision.action === 'cancel') {
      await cancelLink(asaas, ref, { asaasPaymentId: charge.asaasPaymentId });
      console.log('[AsaasOutside] nothing left to charge; customer link canceled', { companyId, chargeId });
      return stop;
    }
    if (decision.action === 'receiveInCash') {
      await settleOutside(asaas, ref, charge.asaasPaymentId, decision.value);
      console.log('[AsaasOutside] customer charge settled outside Asaas', { companyId, chargeId });
      return stop;
    }
    const kept = capped.filter((a) => a.amount > 0);
    const companySnap = await db.collection('companies').doc(companyId).get();
    const description = describeCustomerCharge(
      kept.map((a) => a.orderNumber),
      (companySnap.data()?.name as string | undefined) || '',
    );
    const updated = await updateValue(
      asaas,
      ref,
      { asaasPaymentId: charge.asaasPaymentId },
      { value: decision.value, description },
      { allocations: kept, orderIds: kept.map((a) => a.orderId) },
    );
    if (!updated) return stop;
    console.log('[AsaasOutside] customer charge value lowered', { companyId, chargeId });
    return { ...stop, again: true };
  });
}

/**
 * Brings every open link covering `orderId` in line with what the orders
 * still owe. The caller checks that the company has Asaas connected.
 */
export async function reconcileOutsidePayments(companyId: string, orderId: string): Promise<void> {
  let cached: AsaasClient | null = null;
  const client = async () => (cached ??= await getAsaasCredentialProvider().getClient(companyId));

  const orderCharges = (await listCharges(companyId, orderId)).filter((c) => OPEN_STATUSES.includes(c.status));
  const customerCharges = await listOpenCustomerChargesForOrder(companyId, orderId);

  const failures: unknown[] = [];
  for (const charge of orderCharges) {
    await reconcileOrderCharge(client, companyId, orderId, charge.id).catch((e) => failures.push(e));
  }
  for (const charge of customerCharges) {
    await reconcileCustomerCharge(client, companyId, charge.id).catch((e) => failures.push(e));
  }
  if (failures.length > 0) throw failures[0];
}
