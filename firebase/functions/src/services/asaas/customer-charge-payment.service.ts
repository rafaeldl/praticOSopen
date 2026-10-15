/**
 * Bookkeeping of a multi-order charge (CustomerCharge) paid through Asaas.
 *
 * One Asaas payment is spread over the covered orders oldest first, each
 * capped at what the order owes at that moment (`spreadPaymentOverOpen`: the
 * stored share first, then what is left to orders still owing; interest,
 * fine or overpayment beyond that goes to the last order and is logged). In
 * one transaction:
 *
 * - each order gets a regular `payment` transaction
 *   `asaas_<paymentId>_<n>` (the `asaas_` prefix keeps it locked in the app
 *   like any Asaas payment) with `receiptGroupId` = the receipt id;
 * - a Receipt `companies/{cid}/receipts/asaas_<paymentId>` (createdBy Asaas)
 *   so the "Recebimento" screen and the recibo PDF work as for a manual one;
 * - the charge records the payment (`paidAsaasPaymentIds`) and a copy of
 *   every transaction (`appliedTransactions`, used by the repair trigger).
 *
 * A charge the server settled itself (`paidOutside`/`settlingOutsideAt`, see
 * outside-payment.service.ts) is never booked: the money was already
 * registered by hand on the orders.
 */
import { db, FieldValue } from '../firestore.service';
import { applyPaymentTransaction, calculateRemainingBalance } from '../order.service';
import type { Order, PaymentTransaction } from '../../models/types';
import type {
  AsaasPaymentEvent,
  CustomerCharge,
  CustomerChargeAppliedTransaction,
} from '../../models/asaas.types';
import { spreadPaymentOverOpen } from '../../utils/payment-allocation';
import { customerChargeRef } from './customer-charge.service';
import {
  ASAAS_ACTOR,
  ASAAS_TRANSACTION_PREFIX,
  buildAsaasTransaction,
  computePaymentFields,
  isOurOutsideSettlement,
  OrderPaymentState,
  orderRef,
} from './order-payment.service';

/** Receipt written for an Asaas payment of a multi-order charge. */
export function asaasReceiptId(asaasPaymentId: string): string {
  return `${ASAAS_TRANSACTION_PREFIX}${asaasPaymentId}`.replace(/\//g, '_');
}

/** Transaction of the n-th order share of an Asaas payment. */
export function asaasShareTransactionId(asaasPaymentId: string, index: number): string {
  return `${ASAAS_TRANSACTION_PREFIX}${asaasPaymentId}_${index}`;
}

/** Whether `transactionId` is an order share of `asaasPaymentId`. */
export function isShareOfPayment(transactionId: string | undefined, asaasPaymentId: string): boolean {
  return !!transactionId && transactionId.startsWith(`${ASAAS_TRANSACTION_PREFIX}${asaasPaymentId}_`);
}

function receiptRef(companyId: string, receiptId: string) {
  return db.collection('companies').doc(companyId).collection('receipts').doc(receiptId);
}

export async function applyCustomerChargePayment(
  companyId: string,
  chargeId: string,
  payment: AsaasPaymentEvent,
): Promise<{ applied: boolean; orderIds: string[] }> {
  const cRef = customerChargeRef(companyId, chargeId);

  return db.runTransaction(async (tx) => {
    const chargeSnap = await tx.get(cRef);
    if (!chargeSnap.exists) return { applied: false, orderIds: [] };
    const charge = { ...(chargeSnap.data() as CustomerCharge), id: chargeSnap.id };

    const orderSnaps = await Promise.all(charge.allocations.map((a) => tx.get(orderRef(companyId, a.orderId))));
    const now = new Date();

    if ((charge.refundedAsaasPaymentIds ?? []).includes(payment.id)) return { applied: false, orderIds: [] };
    if ((charge.paidAsaasPaymentIds ?? []).includes(payment.id)) return { applied: false, orderIds: [] };

    // Settled by us with receiveInCash: the money is already on the orders.
    if (isOurOutsideSettlement(charge, payment)) {
      if (charge.status !== 'paid' || !charge.paidOutside || charge.settlingOutsideAt) {
        tx.update(cRef, {
          status: 'paid',
          paidOutside: true,
          paidAt: charge.paidAt ?? now.toISOString(),
          settlingOutsideAt: FieldValue.delete(),
          settlingOutsideValue: FieldValue.delete(),
        });
      }
      console.log('[AsaasPayment] customer charge settled outside Asaas; not booked', { companyId, chargeId });
      return { applied: false, orderIds: [] };
    }

    const receiptId = asaasReceiptId(payment.id);
    // Split by what each order owes now (the stored allocations can be stale).
    const open = orderSnaps.map((snap) => {
      if (!snap.exists) return null;
      const order = snap.data() as Order;
      return order.status === 'quote' || order.status === 'canceled' ? 0 : calculateRemainingBalance(order);
    });
    const { shares, excess } = spreadPaymentOverOpen(charge.allocations, open, Number(payment.value) || 0);
    if (excess > 0) {
      console.log('[AsaasPayment] customer charge paid beyond what the orders owe; extra on the last order', {
        companyId, chargeId, asaasPaymentId: payment.id, excess,
      });
    }
    const applied: CustomerChargeAppliedTransaction[] = [];
    const receiptAllocations: Array<Record<string, unknown>> = [];
    const bookedOrderIds: string[] = [];
    let totalCents = 0;

    shares.forEach((share, index) => {
      if (share.amount <= 0) return;
      const snap = orderSnaps[index];
      if (!snap.exists) {
        console.error('[AsaasPayment] ALERT order of customer charge not found; share not booked', {
          companyId, chargeId, orderId: share.orderId,
        });
        return;
      }
      const order = snap.data() as Order;
      const transaction: PaymentTransaction = {
        ...buildAsaasTransaction({ ...payment, value: share.amount }, { mode: 'single' }, now),
        id: asaasShareTransactionId(payment.id, index),
        receiptGroupId: receiptId,
        paidAt: now.toISOString(),
      };
      if (!(order.transactions ?? []).some((t) => t.id === transaction.id)) {
        const result = applyPaymentTransaction(order, transaction);
        tx.update(snap.ref as FirebaseFirestore.DocumentReference, {
          transactions: result.transactions,
          paidAmount: result.paidAmount,
          paid: result.paid,
          payment: result.payment,
          updatedAt: now.toISOString(),
          updatedBy: { ...ASAAS_ACTOR },
        });
        bookedOrderIds.push(share.orderId);
      }
      applied.push({ orderId: share.orderId, asaasPaymentId: payment.id, transaction });
      receiptAllocations.push({
        orderId: share.orderId,
        orderNumber: share.orderNumber ?? order.number ?? null,
        amount: share.amount,
        transactionId: transaction.id,
      });
      totalCents += Math.round(share.amount * 100);
    });

    tx.set(receiptRef(companyId, receiptId), {
      id: receiptId,
      company: { id: companyId },
      customer: charge.customer,
      amount: totalCents / 100,
      paidAt: now.toISOString(),
      allocations: receiptAllocations,
      status: 'active',
      source: 'asaas',
      asaasPaymentId: payment.id,
      customerChargeId: chargeId,
      createdAt: now.toISOString(),
      createdBy: { ...ASAAS_ACTOR },
      updatedAt: now.toISOString(),
      updatedBy: { ...ASAAS_ACTOR },
    });

    const chargeUpdate: Record<string, unknown> = {
      paidAsaasPaymentIds: [...(charge.paidAsaasPaymentIds ?? []), payment.id],
      appliedTransactions: [...(charge.appliedTransactions ?? []), ...applied],
      receiptId,
    };
    if (charge.status !== 'refunded') {
      chargeUpdate.status = 'paid';
      chargeUpdate.paidAt = now.toISOString();
    }
    tx.update(cRef, chargeUpdate);

    return { applied: bookedOrderIds.length > 0, orderIds: bookedOrderIds };
  });
}

const brlFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

/**
 * Refund (or deletion after payment) of a multi-order charge payment: takes
 * every share out of its order, cancels the Asaas receipt and marks the
 * charge refunded. A refund of a payment never booked only records the id,
 * so a late CONFIRMED/RECEIVED is never booked.
 */
export async function revertCustomerChargePayment(
  companyId: string,
  chargeId: string,
  asaasPaymentId: string,
): Promise<{ reverted: boolean }> {
  const cRef = customerChargeRef(companyId, chargeId);

  return db.runTransaction(async (tx) => {
    const chargeSnap = await tx.get(cRef);
    if (!chargeSnap.exists) return { reverted: false };
    const charge = { ...(chargeSnap.data() as CustomerCharge), id: chargeSnap.id };
    const refundedIds = charge.refundedAsaasPaymentIds ?? [];
    if (refundedIds.includes(asaasPaymentId)) return { reverted: false };

    const applied = charge.appliedTransactions ?? [];
    const orderIds = [...new Set(charge.allocations.map((a) => a.orderId))];
    const orderSnaps = await Promise.all(orderIds.map((id) => tx.get(orderRef(companyId, id))));
    const receiptId = asaasReceiptId(asaasPaymentId);
    const rRef = receiptRef(companyId, receiptId);
    const receiptSnap = await tx.get(rRef);

    const paidIds = charge.paidAsaasPaymentIds ?? [];
    if (!paidIds.includes(asaasPaymentId)) {
      tx.update(cRef, { refundedAsaasPaymentIds: [...refundedIds, asaasPaymentId] });
      return { reverted: false };
    }

    const now = new Date();
    orderSnaps.forEach((snap) => {
      if (!snap.exists) return;
      const order = snap.data() as OrderPaymentState;
      const current = order.transactions ?? [];
      const removed = current.filter((t) => isShareOfPayment(t.id, asaasPaymentId));
      if (removed.length === 0) return;
      const fields = computePaymentFields(
        order,
        current.filter((t) => !isShareOfPayment(t.id, asaasPaymentId)),
      );
      const ref = snap.ref as FirebaseFirestore.DocumentReference;
      tx.update(ref, { ...fields, updatedAt: now.toISOString(), updatedBy: { ...ASAAS_ACTOR } });
      const amount = removed.reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
      tx.set(ref.collection('comments').doc(), {
        text: `Pagamento estornado no Asaas: ${brlFormatter.format(amount)} (cobrança de várias OS). O saldo da OS foi recalculado.`,
        authorType: 'internal',
        author: { name: 'Asaas' },
        source: 'asaas',
        isInternal: true,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    if (receiptSnap.exists) {
      tx.update(rRef, { status: 'canceled', updatedAt: now.toISOString(), updatedBy: { ...ASAAS_ACTOR } });
    }
    tx.update(cRef, {
      status: 'refunded',
      paidAsaasPaymentIds: paidIds.filter((id) => id !== asaasPaymentId),
      appliedTransactions: applied.filter((t) => t.asaasPaymentId !== asaasPaymentId),
      refundedAsaasPaymentIds: [...refundedIds, asaasPaymentId],
    });
    return { reverted: true };
  });
}

/**
 * PAYMENT_RECEIVED_IN_CASH_UNDONE: the "received in cash" was undone on
 * Asaas. When the server had settled the charge itself (`paidOutside`), it is
 * open again (pending, or overdue after the due date). A cash receipt that
 * had been booked (marked in the Asaas panel) is left as it is and logged:
 * the money was registered on the orders and a person must decide.
 */
export function reopenAfterCashUndone<T extends { status: string; paidOutside?: boolean; dueDate: string }>(
  charge: T,
  today: string,
): Record<string, unknown> | null {
  if (!charge.paidOutside || charge.status !== 'paid') return null;
  return {
    status: charge.dueDate < today ? 'overdue' : 'pending',
    paidOutside: false,
    paidAt: FieldValue.delete(),
  };
}
