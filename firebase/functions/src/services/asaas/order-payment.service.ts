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
 * Asaas transactions also carry the optional `billingType` and `receiptUrl`
 * (Asaas `transactionReceiptUrl`, https on asaas.com only). Both are additive:
 * old app versions ignore them, and payloads without them still book.
 *
 * Payment status follows the app convention: `paid` | `unpaid` ("partial" is
 * computed in memory by the app). Remaining balance = total - paidAmount.
 */
import { db, FieldValue } from '../firestore.service';
import { applyPaymentTransaction, paymentStatusFields, roundMoney } from '../order.service';
import type { Order, PaymentTransaction, UserAggr } from '../../models/types';
import type { AsaasPaymentEvent, CustomerCharge, OrderCharge } from '../../models/asaas.types';

export const ASAAS_TRANSACTION_PREFIX = 'asaas_';
export const ASAAS_ACTOR: UserAggr = { id: 'asaas', name: 'Asaas' };

export interface OrderPaymentState {
  /** Order status: quotes and canceled orders have no payment status. */
  status?: string | null;
  total?: number;
  paidAmount?: number;
  transactions?: PaymentTransaction[];
}

export interface OrderPaymentFields {
  transactions: PaymentTransaction[];
  paidAmount: number;
  paid: boolean;
  /** null for quotes and canceled orders (same rule as the app). */
  payment: 'paid' | 'unpaid' | null;
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

/**
 * A payment Asaas reports as received in cash (`receiveInCash`, ours or one
 * marked in the Asaas panel).
 */
export function isCashReceipt(payment: Pick<AsaasPaymentEvent, 'status'>): boolean {
  return payment.status === 'RECEIVED_IN_CASH';
}

/**
 * The webhook of our own `receiveInCash` (outside-payment.service.ts): the
 * money is already on the order(s), so it is never booked. A real Pix/card
 * payment that raced it is booked (the customer did pay twice).
 */
export function isOurOutsideSettlement(
  charge: { paidOutside?: boolean; settlingOutsideAt?: string },
  payment: Pick<AsaasPaymentEvent, 'status'>,
): boolean {
  return (!!charge.paidOutside || !!charge.settlingOutsideAt) && isCashReceipt(payment);
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

const BILLING_TYPE_PATTERN = /^[A-Z_]{1,32}$/;

/** Asaas billing type to store on the transaction, or undefined when missing/unexpected. */
export function sanitizeBillingType(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const billingType = value.trim().toUpperCase();
  return BILLING_TYPE_PATTERN.test(billingType) ? billingType : undefined;
}

/**
 * Receipt URL to store on the transaction: only https links on an Asaas
 * domain (asaas.com and its subdomains, e.g. sandbox.asaas.com). Anything else
 * (missing, malformed, other host) is dropped, so the app never opens a link
 * that did not come from Asaas.
 */
export function sanitizeReceiptUrl(value: unknown): string | undefined {
  if (typeof value !== 'string' || value.length > 2048) return undefined;
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    return undefined;
  }
  if (url.protocol !== 'https:') return undefined;
  const host = url.hostname.toLowerCase();
  if (host !== 'asaas.com' && !host.endsWith('.asaas.com')) return undefined;
  return url.toString();
}

/**
 * Optional Asaas details of a payment (`receiptUrl`, `billingType`). Keys are
 * left out when there is no valid value: Firestore rejects undefined and old
 * payloads (no `transactionReceiptUrl`) keep working.
 */
export function asaasPaymentDetails(payment: AsaasPaymentEvent): Pick<PaymentTransaction, 'receiptUrl' | 'billingType'> {
  const details: Pick<PaymentTransaction, 'receiptUrl' | 'billingType'> = {};
  const billingType = sanitizeBillingType(payment.billingType);
  if (billingType) details.billingType = billingType;
  const receiptUrl = sanitizeReceiptUrl(payment.transactionReceiptUrl);
  if (receiptUrl) details.receiptUrl = receiptUrl;
  return details;
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
    ...asaasPaymentDetails(payment),
  };
}

/**
 * Copies `receiptUrl`/`billingType` from `source` into `target` when `target`
 * lacks them. Returns the merged transaction, or null when nothing changes
 * (an existing value is never overwritten).
 */
export function mergeAsaasDetails(
  target: PaymentTransaction,
  source: Pick<PaymentTransaction, 'receiptUrl' | 'billingType'>,
): PaymentTransaction | null {
  const merged: PaymentTransaction = { ...target };
  let changed = false;
  if (!target.receiptUrl && source.receiptUrl) {
    merged.receiptUrl = source.receiptUrl;
    changed = true;
  }
  if (!target.billingType && source.billingType) {
    merged.billingType = source.billingType;
    changed = true;
  }
  return changed ? merged : null;
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
  const { paid, payment } = paymentStatusFields(previous.status, Number(previous.total ?? 0), paidAmount);
  return { transactions: nextTransactions, paidAmount, paid, payment };
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
    if ((charge.refundedAsaasPaymentIds ?? []).includes(payment.id)) return { applied: false };
    if (paidIds.includes(payment.id)) {
      // Already booked (e.g. card CONFIRMED, then RECEIVED with the receipt):
      // only fill in receipt/billing type that the first event did not carry.
      backfillAsaasDetails(tx, oRef, cRef, order, charge, payment);
      return { applied: false };
    }

    const now = new Date();
    // Settled by us with receiveInCash (paid outside Asaas): the money is
    // already on the order, never book it a second time.
    if (isOurOutsideSettlement(charge, payment)) {
      if (charge.status !== 'paid' || !charge.paidOutside) {
        tx.update(cRef, { status: 'paid', paidOutside: true, paidAt: charge.paidAt ?? now.toISOString() });
      }
      console.log('[AsaasPayment] charge settled outside Asaas; not booked', { companyId, orderId, chargeId });
      return { applied: false };
    }

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

/**
 * Adds `receiptUrl`/`billingType` of an already booked payment to the order
 * transaction and to the charge copy when they are missing. Never touches
 * amounts or status, never overwrites a stored value and writes nothing when
 * there is nothing new (redeliveries stay no-ops).
 */
function backfillAsaasDetails(
  tx: FirebaseFirestore.Transaction,
  oRef: FirebaseFirestore.DocumentReference,
  cRef: FirebaseFirestore.DocumentReference,
  order: Order,
  charge: OrderCharge,
  payment: AsaasPaymentEvent,
): void {
  const details = asaasPaymentDetails(payment);
  if (!details.receiptUrl && !details.billingType) return;
  const transactionId = asaasTransactionId(payment.id);

  const transactions = order.transactions ?? [];
  const orderIndex = transactions.findIndex((t) => t.id === transactionId);
  const orderMerged = orderIndex >= 0 ? mergeAsaasDetails(transactions[orderIndex], details) : null;
  if (orderMerged) {
    const next = [...transactions];
    next[orderIndex] = orderMerged;
    tx.update(oRef, { transactions: next });
  }

  const applied = charge.appliedTransactions ?? [];
  const appliedIndex = applied.findIndex((t) => t.id === transactionId);
  const appliedMerged = appliedIndex >= 0 ? mergeAsaasDetails(applied[appliedIndex], details) : null;
  if (appliedMerged) {
    const next = [...applied];
    next[appliedIndex] = appliedMerged;
    tx.update(cRef, { appliedTransactions: next });
  }
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
 *    Any `asaas_<id>` on the order whose id is in a charge's
 *    `refundedAsaasPaymentIds` (brought back by a stale copy) is removed.
 * 2. Otherwise (and only when the order has `paidAmount`) recomputes `paidAmount`/`paid`/`payment` from the transactions
 *    and the order total (`computePaymentFields`) and fixes them when they
 *    disagree (the app increments `paidAmount` atomically but writes the status
 *    computed from its local state, which can miss a concurrent Asaas payment).
 *    Quotes and canceled orders keep `payment: null, paid: false` (same rule
 *    as the app), so a canceled order is never flipped to paid.
 *
 * 3. Puts back `receiptUrl`/`billingType` on booked Asaas transactions when an
 *    old app version (model without these keys) saved the order without them,
 *    copying them from the charge's `appliedTransactions`.
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

    // Multi-order charges covering this order (customer-charge-payment.service).
    const customerChargesSnap = await tx.get(
      db.collection('companies').doc(companyId).collection('customerCharges').where('orderIds', 'array-contains', orderId),
    );

    const order = orderSnap.data() as OrderPaymentState & { paid?: unknown; payment?: unknown };
    const charges = chargesSnap.docs.map((doc) => ({ id: doc.id, charge: doc.data() as OrderCharge }));
    const customerCharges = customerChargesSnap.docs.map((doc) => ({ id: doc.id, charge: doc.data() as CustomerCharge }));

    // A stale copy saved by an old app can bring back a refunded payment.
    const refundedTransactionIds = new Set(
      charges.flatMap(({ charge }) => (charge.refundedAsaasPaymentIds ?? []).map(asaasTransactionId)),
    );
    const refundedSharePrefixes = customerCharges.flatMap(({ charge }) =>
      (charge.refundedAsaasPaymentIds ?? []).map((id) => `${asaasTransactionId(id)}_`),
    );
    const isRefunded = (id: string | undefined) =>
      !!id && (refundedTransactionIds.has(id) || refundedSharePrefixes.some((prefix) => id.startsWith(prefix)));
    const original = order.transactions ?? [];
    const current = original.filter((t) => !isRefunded(t.id));
    const removed = original.length - current.length;
    const present = new Set(current.map((t) => t.id));
    const missing: PaymentTransaction[] = [];

    for (const { id: chargeId, charge } of charges) {
      const refunded = new Set(charge.refundedAsaasPaymentIds ?? []);
      const applied = charge.appliedTransactions ?? [];
      for (const paymentId of charge.paidAsaasPaymentIds ?? []) {
        const transactionId = asaasTransactionId(paymentId);
        if (refunded.has(paymentId) || present.has(transactionId)) continue;
        const copy = applied.find((t) => t.id === transactionId);
        if (!copy) {
          console.warn('[AsaasPayment] booked payment without applied copy; cannot repair', {
            companyId, orderId, chargeId, asaasPaymentId: paymentId,
          });
          continue;
        }
        missing.push(copy);
        present.add(transactionId);
      }
    }

    // Shares of multi-order charge payments booked on this order.
    for (const { charge } of customerCharges) {
      const paid = new Set(charge.paidAsaasPaymentIds ?? []);
      for (const entry of charge.appliedTransactions ?? []) {
        if (entry.orderId !== orderId || !paid.has(entry.asaasPaymentId)) continue;
        if (present.has(entry.transaction.id)) continue;
        missing.push(entry.transaction);
        present.add(entry.transaction.id);
      }
    }

    // An old app version (model without receiptUrl/billingType) drops these
    // keys when it saves the order: put them back from the charge copy.
    const appliedById = new Map<string, PaymentTransaction>();
    for (const { charge } of charges) {
      for (const copy of charge.appliedTransactions ?? []) appliedById.set(copy.id, copy);
    }
    for (const { charge } of customerCharges) {
      for (const entry of charge.appliedTransactions ?? []) {
        if (entry.orderId === orderId) appliedById.set(entry.transaction.id, entry.transaction);
      }
    }
    let enriched = 0;
    const kept = current.map((t) => {
      const copy = t.id?.startsWith(ASAAS_TRANSACTION_PREFIX) ? appliedById.get(t.id) : undefined;
      const merged = copy ? mergeAsaasDetails(t, copy) : null;
      if (!merged) return t;
      enriched += 1;
      return merged;
    });

    const repaired = missing.length + removed;
    if (repaired > 0) {
      const fields = computePaymentFields(order, [...kept, ...missing]);
      tx.update(oRef, { ...fields, updatedAt: new Date().toISOString(), updatedBy: { ...ASAAS_ACTOR } });
      console.log('[AsaasPayment] repaired order transactions', {
        companyId, orderId, restored: missing.length, removedRefunded: removed,
      });
      return { repaired };
    }

    // Details-only restore: amounts are unchanged, so keep the app's
    // updatedAt/updatedBy (same as the status-only fix below).
    const update: Record<string, unknown> = {};
    if (enriched > 0) {
      update.transactions = kept;
      console.log('[AsaasPayment] restored Asaas payment details', { companyId, orderId, enriched });
    }

    // Legacy orders (payment set, no paidAmount; the app falls back to total)
    // are never downgraded by the status-only fix.
    if (order.paidAmount !== undefined && order.paidAmount !== null) {
      const fields = computePaymentFields(order, current);
      const storedPaidAmount = roundMoney(Number(order.paidAmount) || 0);
      if (
        storedPaidAmount !== fields.paidAmount ||
        (order.paid === true) !== fields.paid ||
        (order.payment ?? null) !== fields.payment
      ) {
        update.paidAmount = fields.paidAmount;
        update.paid = fields.paid;
        update.payment = fields.payment;
        console.log('[AsaasPayment] fixed order payment fields', { companyId, orderId });
      }
    }
    if (Object.keys(update).length > 0) tx.update(oRef, update);
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
