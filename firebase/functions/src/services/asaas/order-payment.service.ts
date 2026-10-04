/**
 * Order payment bookkeeping for Asaas charges.
 *
 * Every Asaas payment confirmed for an order charge becomes one
 * PaymentTransaction on the order (`id = asaas_<paymentId>`, type `payment`,
 * never a new type: old app versions decode it with $enumDecode). The charge
 * document is the source of truth: `paidAsaasPaymentIds` lists the payments
 * already booked and `appliedTransactions` keeps a copy of each booked
 * transaction so the repair trigger can restore one that an old app version
 * overwrote.
 *
 * Payment status follows the app convention: `paid` | `unpaid` ("partial" is
 * computed in memory by the app). Remaining balance = total - paidAmount.
 */
import { db, FieldValue } from '../firestore.service';
import { applyPaymentTransaction, roundMoney } from '../order.service';
import type { Order, PaymentTransaction, UserAggr } from '../../models/types';
import type { AsaasPaymentEvent, OrderCharge } from '../../models/asaas.types';

export const ASAAS_TRANSACTION_PREFIX = 'asaas_';
export const ASAAS_ACTOR: UserAggr = { id: 'asaas', name: 'Asaas' };

export interface OrderPaymentState {
  total?: number;
  paidAmount?: number;
  transactions?: PaymentTransaction[];
}

export interface OrderPaymentFields {
  transactions: PaymentTransaction[];
  paidAmount: number;
  paid: boolean;
  payment: 'paid' | 'unpaid';
}

const BILLING_TYPE_LABELS: Record<string, string> = {
  PIX: 'Pix',
  BOLETO: 'Boleto',
  CREDIT_CARD: 'Cartão',
  DEBIT_CARD: 'Cartão',
};

export function orderRef(companyId: string, orderId: string) {
  return db.collection('companies').doc(companyId).collection('orders').doc(orderId);
}

export function chargeRef(companyId: string, orderId: string, chargeId: string) {
  return orderRef(companyId, orderId).collection('charges').doc(chargeId);
}

export function asaasTransactionId(asaasPaymentId: string): string {
  return `${ASAAS_TRANSACTION_PREFIX}${asaasPaymentId}`;
}

/** 'Asaas • Pix' | 'Asaas • Boleto' | 'Asaas • Cartão' (+ ' n/N' for card installments). */
export function describeAsaasPayment(
  payment: AsaasPaymentEvent,
  charge: Pick<OrderCharge, 'mode' | 'installmentCount'>,
  fallbackInstallmentNumber?: number,
): string {
  const label = BILLING_TYPE_LABELS[payment.billingType];
  let description = label ? `Asaas • ${label}` : 'Asaas';
  const installmentNumber = payment.installmentNumber ?? fallbackInstallmentNumber;
  if (charge.mode === 'cardInstallments' && charge.installmentCount && installmentNumber) {
    description += ` ${installmentNumber}/${charge.installmentCount}`;
  }
  return description;
}

/** The order transaction for an Asaas payment (gross `value`, what the customer paid). */
export function buildAsaasTransaction(
  payment: AsaasPaymentEvent,
  charge: Pick<OrderCharge, 'mode' | 'installmentCount'>,
  now: Date,
  fallbackInstallmentNumber?: number,
): PaymentTransaction {
  return {
    id: asaasTransactionId(payment.id),
    type: 'payment',
    amount: roundMoney(Number(payment.value) || 0),
    description: describeAsaasPayment(payment, charge, fallbackInstallmentNumber),
    createdAt: now.toISOString(),
    createdBy: { ...ASAAS_ACTOR },
  };
}

function sumPayments(transactions: PaymentTransaction[]): number {
  return transactions
    .filter((t) => t.type === 'payment')
    .reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
}

/**
 * Recomputes paidAmount/paid/payment for a new transaction list (used when
 * transactions are removed or restored). Any paidAmount the previous state had
 * beyond its payment transactions (legacy orders paid before transactions
 * existed) is preserved.
 */
export function computePaymentFields(
  previous: OrderPaymentState,
  nextTransactions: PaymentTransaction[],
): OrderPaymentFields {
  const untracked = Math.max(0, roundMoney((previous.paidAmount ?? 0) - sumPayments(previous.transactions ?? [])));
  const paidAmount = roundMoney(sumPayments(nextTransactions) + untracked);
  const total = Number(previous.total ?? 0);
  const paid = total > 0 && paidAmount >= total;
  return { transactions: nextTransactions, paidAmount, paid, payment: paid ? 'paid' : 'unpaid' };
}

function expectedPaymentCount(charge: OrderCharge, ids: { companyId: string; orderId: string; chargeId: string }): number {
  if (charge.mode === 'cardInstallments' && !charge.installmentCount) {
    console.warn('[AsaasPayment] cardInstallments charge without installmentCount', ids);
  }
  return Math.max(1, charge.installmentCount ?? 1);
}

/**
 * Books an Asaas payment on the order inside a transaction.
 *
 * `applied` means "money was booked on the order in this call" (the webhook
 * uses it to send the push). Returns { applied: false } without writing when
 * the order/charge no longer exists, the payment was already booked, or it was
 * refunded on this charge (refunded money is never booked again).
 *
 * Charge status: a `refunded` charge keeps its status. A `canceled` charge that
 * still receives a payment is booked and marked paid: real money arrived.
 */
export async function applyAsaasPayment(
  companyId: string,
  orderId: string,
  chargeId: string,
  payment: AsaasPaymentEvent,
): Promise<{ applied: boolean }> {
  const oRef = orderRef(companyId, orderId);
  const cRef = chargeRef(companyId, orderId, chargeId);

  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(oRef);
    const chargeSnap = await tx.get(cRef);
    if (!orderSnap.exists || !chargeSnap.exists) {
      console.warn('[AsaasPayment] order or charge not found', { companyId, orderId, chargeId });
      return { applied: false };
    }

    const order = orderSnap.data() as Order;
    const charge = chargeSnap.data() as OrderCharge;
    const paidIds = charge.paidAsaasPaymentIds ?? [];
    if (paidIds.includes(payment.id)) return { applied: false };
    if ((charge.refundedAsaasPaymentIds ?? []).includes(payment.id)) return { applied: false };

    const now = new Date();
    const transaction = buildAsaasTransaction(payment, charge, now, paidIds.length + 1);
    const alreadyOnOrder = (order.transactions ?? []).some((t) => t.id === transaction.id);

    if (alreadyOnOrder) {
      console.warn('[AsaasPayment] transaction already on order; reconciling charge only', {
        companyId, orderId, chargeId, asaasPaymentId: payment.id,
      });
    } else {
      const result = applyPaymentTransaction(order, transaction);
      tx.update(oRef, {
        transactions: result.transactions,
        paidAmount: result.paidAmount,
        paid: result.paid,
        payment: result.payment,
        updatedAt: now.toISOString(),
        updatedBy: { ...ASAAS_ACTOR },
      });
    }

    const nextPaidIds = [...paidIds, payment.id];
    const chargeUpdate: Record<string, unknown> = {
      paidAsaasPaymentIds: nextPaidIds,
      appliedTransactions: [
        ...(charge.appliedTransactions ?? []).filter((t) => t.id !== transaction.id),
        transaction,
      ],
    };
    if (charge.status !== 'refunded' && nextPaidIds.length >= expectedPaymentCount(charge, { companyId, orderId, chargeId })) {
      chargeUpdate.status = 'paid';
      chargeUpdate.paidAt = now.toISOString();
    }
    tx.update(cRef, chargeUpdate);

    return { applied: !alreadyOnOrder };
  });
}

const brlFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

/**
 * Reverts a refunded Asaas payment inside a transaction: removes
 * `asaas_<id>` from the order, recomputes the payment fields, moves the id
 * from `paidAsaasPaymentIds` to `refundedAsaasPaymentIds` (so a redelivered
 * CONFIRMED/RECEIVED is never booked again), marks the charge `refunded` and
 * adds an internal audit comment to the order history (same pattern as the
 * magic-link approve/reject/rating comments).
 *
 * Returns { reverted: false } without writing when the order/charge no longer
 * exists or the payment was already reverted. A refund for a payment never
 * booked returns { reverted: false } but still records the id in
 * `refundedAsaasPaymentIds` (no status change, no order write, no comment).
 */
export async function revertAsaasPayment(
  companyId: string,
  orderId: string,
  chargeId: string,
  asaasPaymentId: string,
): Promise<{ reverted: boolean }> {
  const oRef = orderRef(companyId, orderId);
  const cRef = chargeRef(companyId, orderId, chargeId);
  const transactionId = asaasTransactionId(asaasPaymentId);

  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(oRef);
    const chargeSnap = await tx.get(cRef);
    if (!orderSnap.exists || !chargeSnap.exists) {
      console.warn('[AsaasPayment] order or charge not found on refund', { companyId, orderId, chargeId });
      return { reverted: false };
    }

    const order = orderSnap.data() as OrderPaymentState;
    const charge = chargeSnap.data() as OrderCharge;
    const refundedIds = charge.refundedAsaasPaymentIds ?? [];
    if (refundedIds.includes(asaasPaymentId)) return { reverted: false };

    const current = order.transactions ?? [];
    const paidIds = charge.paidAsaasPaymentIds ?? [];
    const applied = charge.appliedTransactions ?? [];
    const onOrder = current.find((t) => t.id === transactionId);
    if (!onOrder && !paidIds.includes(asaasPaymentId)) {
      // Refund for a payment never booked here: remember it so a late
      // CONFIRMED/RECEIVED for the same id is never booked.
      tx.update(cRef, { refundedAsaasPaymentIds: [...refundedIds, asaasPaymentId] });
      return { reverted: false };
    }

    const now = new Date();
    if (onOrder) {
      const fields = computePaymentFields(order, current.filter((t) => t.id !== transactionId));
      tx.update(oRef, { ...fields, updatedAt: now.toISOString(), updatedBy: { ...ASAAS_ACTOR } });
    }
    tx.update(cRef, {
      status: 'refunded',
      paidAsaasPaymentIds: paidIds.filter((id) => id !== asaasPaymentId),
      appliedTransactions: applied.filter((t) => t.id !== transactionId),
      refundedAsaasPaymentIds: [...refundedIds, asaasPaymentId],
    });

    const removed = onOrder ?? applied.find((t) => t.id === transactionId);
    const detail = removed
      ? `: ${brlFormatter.format(Number(removed.amount) || 0)} (${removed.description ?? 'Asaas'})`
      : '';
    tx.set(oRef.collection('comments').doc(), {
      text: `Pagamento estornado no Asaas${detail}. O saldo da OS foi recalculado.`,
      authorType: 'internal',
      author: { name: 'Asaas' },
      source: 'asaas',
      isInternal: true,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { reverted: true };
  });
}

/**
 * Self-heals an order's payment fields after any change to `transactions`:
 *
 * 1. Puts back every booked Asaas transaction that is missing from the order
 *    (an old app version saved a stale copy of the whole order). Charges are
 *    the source of truth: `paidAsaasPaymentIds` + the copy in
 *    `appliedTransactions`. Ids in `refundedAsaasPaymentIds` are never re-added.
 * 2. Otherwise recomputes `paidAmount`/`paid`/`payment` from the transactions
 *    and the order total (`computePaymentFields`) and fixes them when they
 *    disagree (the app increments `paidAmount` atomically but writes the status
 *    computed from its local state, which can miss a concurrent Asaas payment).
 *
 * Writes only when something actually changes, so the trigger that calls it
 * does not loop. A status-only fix keeps the app's updatedAt/updatedBy.
 */
export async function repairAsaasTransactions(
  companyId: string,
  orderId: string,
): Promise<{ repaired: number }> {
  const oRef = orderRef(companyId, orderId);
  const chargesRef = oRef.collection('charges');

  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(oRef);
    if (!orderSnap.exists) return { repaired: 0 };
    const chargesSnap = await tx.get(chargesRef);

    const order = orderSnap.data() as OrderPaymentState & { paid?: unknown; payment?: unknown };
    const current = order.transactions ?? [];
    const present = new Set(current.map((t) => t.id));
    const missing: PaymentTransaction[] = [];

    for (const doc of chargesSnap.docs) {
      const charge = doc.data() as OrderCharge;
      const refunded = new Set(charge.refundedAsaasPaymentIds ?? []);
      const applied = charge.appliedTransactions ?? [];
      for (const paymentId of charge.paidAsaasPaymentIds ?? []) {
        const transactionId = asaasTransactionId(paymentId);
        if (refunded.has(paymentId) || present.has(transactionId)) continue;
        const copy = applied.find((t) => t.id === transactionId);
        if (!copy) {
          console.warn('[AsaasPayment] booked payment without applied copy; cannot repair', {
            companyId, orderId, chargeId: doc.id, asaasPaymentId: paymentId,
          });
          continue;
        }
        missing.push(copy);
        present.add(transactionId);
      }
    }

    if (missing.length > 0) {
      const fields = computePaymentFields(order, [...current, ...missing]);
      tx.update(oRef, { ...fields, updatedAt: new Date().toISOString(), updatedBy: { ...ASAAS_ACTOR } });
      console.log('[AsaasPayment] repaired order transactions', { companyId, orderId, repaired: missing.length });
      return { repaired: missing.length };
    }

    const fields = computePaymentFields(order, current);
    const storedPaidAmount = roundMoney(Number(order.paidAmount) || 0);
    if (
      storedPaidAmount !== fields.paidAmount ||
      (order.paid === true) !== fields.paid ||
      (order.payment ?? 'unpaid') !== fields.payment
    ) {
      tx.update(oRef, { paidAmount: fields.paidAmount, paid: fields.paid, payment: fields.payment });
      console.log('[AsaasPayment] fixed order payment fields', { companyId, orderId });
    }
    return { repaired: 0 };
  });
}

/** Deep comparison of `transactions` (key order inside each transaction is ignored). */
export function transactionsChanged(
  before: OrderPaymentState | undefined,
  after: OrderPaymentState | undefined,
): boolean {
  return stableJson(before?.transactions ?? []) !== stableJson(after?.transactions ?? []);
}

function stableJson(value: unknown): string {
  return JSON.stringify(value, (_key, v) =>
    v && typeof v === 'object' && !Array.isArray(v)
      ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, (v as Record<string, unknown>)[k]]))
      : v,
  );
}
