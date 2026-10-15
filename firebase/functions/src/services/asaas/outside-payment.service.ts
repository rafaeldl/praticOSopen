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
 *   books nothing;
 * - nothing left but no money came in (discount, total lowered, order
 *   canceled) → the link is canceled: nothing was received in cash;
 * - less than the link → `PUT /payments/{id}` with the remaining value (the
 *   link stays the same); multi-order allocations are updated. If Asaas
 *   refuses the new value (e.g. below its minimum), the link is canceled so
 *   the customer can never pay more than is owed;
 * - same or more → nothing.
 *
 * Installment plans are left alone (a part of them may be paid already).
 *
 * Concurrency: a short lease (`adjustingUntil`) on the charge; the holder
 * recomputes until nothing changes, so an invocation that finds the lease
 * taken can return.
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
const MAX_ROUNDS = 3;

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

function toMillis(value: unknown): number {
  if (!value) return NaN;
  if (typeof value === 'string') return Date.parse(value);
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

async function claimLease(ref: FirebaseFirestore.DocumentReference): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const data = snap.data() as { status: string; adjustingUntil?: string };
    if (!OPEN_STATUSES.includes(data.status as OrderCharge['status'])) return false;
    const now = Date.now();
    if (data.adjustingUntil && Date.parse(data.adjustingUntil) > now) return false;
    tx.update(ref, { adjustingUntil: new Date(now + LEASE_MS).toISOString() });
    return true;
  });
}

async function releaseLease(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  const snap = await ref.get();
  if (snap.exists) await ref.update({ adjustingUntil: FieldValue.delete() });
}

/** receiveInCash for the whole charge; marks it paid outside. */
async function settleOutside(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  asaasPaymentId: string,
  value: number,
): Promise<void> {
  await ref.update({ settlingOutsideAt: new Date().toISOString() });
  try {
    await client.receiveInCash(asaasPaymentId, { paymentDate: todayIso(), value, notifyCustomer: false });
  } catch (error) {
    await ref.update({ settlingOutsideAt: FieldValue.delete() });
    throw error;
  }
  await ref.update({
    status: 'paid',
    paidOutside: true,
    paidAt: new Date().toISOString(),
    settlingOutsideAt: FieldValue.delete(),
  });
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

/** Cancels the link (nothing was received): Asaas first, then our doc. */
async function cancelLink(
  client: AsaasClient,
  ref: FirebaseFirestore.DocumentReference,
  charge: Pick<OrderCharge, 'asaasPaymentId' | 'asaasInstallmentId'>,
): Promise<void> {
  await cancelInAsaas(client, charge);
  await ref.update({ status: 'canceled' });
}

async function reconcileOrderCharge(
  client: () => Promise<AsaasClient>,
  companyId: string,
  orderId: string,
  chargeId: string,
): Promise<void> {
  const ref = chargeRef(companyId, orderId, chargeId) as unknown as FirebaseFirestore.DocumentReference;
  if (!(await claimLease(ref))) return;
  try {
    for (let round = 0; round < MAX_ROUNDS; round++) {
      const [chargeSnap, orderSnap] = await Promise.all([ref.get(), orderRef(companyId, orderId).get()]);
      if (!chargeSnap.exists) return;
      const charge = chargeSnap.data() as OrderCharge;
      if (!OPEN_STATUSES.includes(charge.status) || charge.mode !== 'single' || hasPaidInstallments(charge)) return;
      const order = orderSnap.exists ? (orderSnap.data() as Order) : undefined;
      // A quote/canceled order: its charges are canceled by handleOrderStatusChange.
      if (!order || order.status === 'quote' || order.status === 'canceled') return;
      const owed = Math.min(charge.value, openForLink(order));
      const decision = decideOutsideAction(charge.value, owed, paidOutsideSince(order, charge.createdAt));
      if (decision.action === 'none') return;
      const asaas = await client();
      if (decision.action === 'cancel') {
        await cancelLink(asaas, ref, charge);
        console.log('[AsaasOutside] nothing left to charge; link canceled', { companyId, orderId, chargeId });
        return;
      }
      if (decision.action === 'receiveInCash') {
        await settleOutside(asaas, ref, charge.asaasPaymentId, decision.value);
        console.log('[AsaasOutside] charge settled outside Asaas', { companyId, orderId, chargeId });
        return;
      }
      if (!(await updateValue(asaas, ref, charge, { value: decision.value }, {}))) return;
      console.log('[AsaasOutside] charge value lowered', { companyId, orderId, chargeId });
    }
  } finally {
    await releaseLease(ref);
  }
}

async function reconcileCustomerCharge(
  client: () => Promise<AsaasClient>,
  companyId: string,
  chargeId: string,
): Promise<void> {
  const ref = customerChargeRef(companyId, chargeId) as unknown as FirebaseFirestore.DocumentReference;
  if (!(await claimLease(ref))) return;
  try {
    for (let round = 0; round < MAX_ROUNDS; round++) {
      const chargeSnap = await ref.get();
      if (!chargeSnap.exists) return;
      const charge = { ...(chargeSnap.data() as CustomerCharge), id: chargeSnap.id };
      if (!OPEN_STATUSES.includes(charge.status) || (charge.paidAsaasPaymentIds ?? []).length > 0) return;

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
      if (decision.action === 'none') return;
      const asaas = await client();
      if (decision.action === 'cancel') {
        await cancelLink(asaas, ref, { asaasPaymentId: charge.asaasPaymentId });
        console.log('[AsaasOutside] nothing left to charge; customer link canceled', { companyId, chargeId });
        return;
      }
      if (decision.action === 'receiveInCash') {
        await settleOutside(asaas, ref, charge.asaasPaymentId, decision.value);
        console.log('[AsaasOutside] customer charge settled outside Asaas', { companyId, chargeId });
        return;
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
      if (!updated) return;
      console.log('[AsaasOutside] customer charge value lowered', { companyId, chargeId });
    }
  } finally {
    await releaseLease(ref);
  }
}

/**
 * Brings every open link covering `orderId` in line with what the orders
 * still owe. The caller checks that the company has Asaas connected.
 */
export async function reconcileOutsidePayments(companyId: string, orderId: string): Promise<void> {
  let cached: AsaasClient | null = null;
  const client = async () => (cached ??= await getAsaasCredentialProvider().getClient(companyId));

  const singles = (await listCharges(companyId, orderId)).filter(
    (c) => OPEN_STATUSES.includes(c.status) && c.mode === 'single',
  );
  const customerCharges = await listOpenCustomerChargesForOrder(companyId, orderId);

  const failures: unknown[] = [];
  for (const charge of singles) {
    await reconcileOrderCharge(client, companyId, orderId, charge.id).catch((e) => failures.push(e));
  }
  for (const charge of customerCharges) {
    await reconcileCustomerCharge(client, companyId, charge.id).catch((e) => failures.push(e));
  }
  if (failures.length > 0) throw failures[0];
}
