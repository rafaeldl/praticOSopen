/**
 * Asaas webhook event handling (POST /webhooks/asaas/:companyId).
 *
 * - Idempotency: every handled event id is stored in
 *   companies/{cid}/private/asaas/events/{eventId} (TTL on expiresAt, 30 days).
 *   The id is only recorded after processing succeeded, so an event whose
 *   processing throws leaves no marker and is retried by Asaas; every handler
 *   below is idempotent on its own (concurrent redeliveries are safe).
 * - Events that can never succeed (unknown charge, other company, unhandled
 *   event name) are recorded and acknowledged, otherwise the SEQUENTIALLY
 *   queue of the company gets stuck and Asaas interrupts it.
 * - Never logs the payload (customer data): only ids and the event name.
 */
import { db, Timestamp } from '../firestore.service';
import { notifyAsaasPaymentReceived } from '../notification.service';
import { applyAsaasPayment, chargeRef, revertAsaasPayment } from './order-payment.service';
import { CUSTOMER_CHARGE_REF_TAG, customerChargeRef } from './customer-charge.service';
import {
  applyCustomerChargePayment,
  reopenAfterCashUndone,
  revertCustomerChargePayment,
} from './customer-charge-payment.service';
import { applyInvoiceEvent } from './invoice.service';
import type {
  AsaasPaymentEvent,
  AsaasWebhookEvent,
  AsaasWebhookEventName,
  ChargeStatus,
  CustomerCharge,
  OrderCharge,
} from '../../models/asaas.types';

const EVENT_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const HANDLED_EVENTS: ReadonlySet<string> = new Set<AsaasWebhookEventName>([
  'PAYMENT_RECEIVED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_OVERDUE',
  'PAYMENT_REFUNDED',
  'PAYMENT_DELETED',
  'PAYMENT_RECEIVED_IN_CASH_UNDONE',
  'PAYMENT_PARTIALLY_REFUNDED',
]);

/** NFS-e events (docs/NFSE_ASAAS.md); INVOICE_UPDATED carries the current status too. */
const INVOICE_EVENTS: ReadonlySet<string> = new Set<AsaasWebhookEventName>([
  'INVOICE_CREATED',
  'INVOICE_UPDATED',
  'INVOICE_SYNCHRONIZED',
  'INVOICE_AUTHORIZED',
  'INVOICE_PROCESSING_CANCELLATION',
  'INVOICE_CANCELED',
  'INVOICE_CANCELLATION_DENIED',
  'INVOICE_ERROR',
]);

interface ChargeTarget {
  orderId: string;
  chargeId: string;
}

/**
 * Single-order charge reference `{companyId}:{orderId}:{chargeId}`. A
 * multi-order reference (`{companyId}:cc:{chargeId}`) is not one.
 */
export function parseExternalReference(
  ref?: string | null,
): { companyId: string; orderId: string; chargeId: string } | null {
  if (!ref) return null;
  const parts = ref.split(':');
  if (parts.length !== 3 || parts.some((part) => !part)) return null;
  const [companyId, orderId, chargeId] = parts;
  if (orderId === CUSTOMER_CHARGE_REF_TAG) return null;
  return { companyId, orderId, chargeId };
}

/** Multi-order charge reference `{companyId}:cc:{chargeId}`. */
export function parseCustomerChargeReference(
  ref?: string | null,
): { companyId: string; chargeId: string } | null {
  if (!ref) return null;
  const parts = ref.split(':');
  if (parts.length !== 3 || parts.some((part) => !part) || parts[1] !== CUSTOMER_CHARGE_REF_TAG) return null;
  return { companyId: parts[0], chargeId: parts[2] };
}

function eventsCollection(companyId: string) {
  return db.collection('companies').doc(companyId).collection('private').doc('asaas').collection('events');
}

/** Firestore doc ids cannot contain '/'. Asaas ids look like 'evt_<hex>&<n>'. */
function eventDocId(eventId: string): string {
  return eventId.replace(/\//g, '_');
}

function chargeMatchesPayment(charge: OrderCharge, payment: AsaasPaymentEvent): boolean {
  return (
    charge.asaasPaymentId === payment.id ||
    (!!charge.asaasInstallmentId && charge.asaasInstallmentId === payment.installment)
  );
}

async function resolveCharge(
  companyId: string,
  eventName: string,
  payment: AsaasPaymentEvent,
): Promise<ChargeTarget | null> {
  const parsed = parseExternalReference(payment.externalReference);
  if (parsed) {
    if (parsed.companyId !== companyId) {
      console.warn('[AsaasWebhook] externalReference belongs to another company', { companyId, event: eventName });
      return null;
    }
    const snap = await chargeRef(companyId, parsed.orderId, parsed.chargeId).get();
    if (!snap.exists) {
      // Our own reference points to a charge that is gone: data inconsistency, alert.
      console.error('[AsaasWebhook] ALERT referenced charge not found', {
        companyId,
        orderId: parsed.orderId,
        chargeId: parsed.chargeId,
        paymentId: payment.id,
        event: eventName,
      });
      return null;
    }
    if (!chargeMatchesPayment(snap.data() as OrderCharge, payment)) {
      console.warn('[AsaasWebhook] payment does not belong to the referenced charge', {
        companyId,
        chargeId: parsed.chargeId,
        paymentId: payment.id,
        event: eventName,
      });
      return null;
    }
    return { orderId: parsed.orderId, chargeId: parsed.chargeId };
  }

  if (payment.installment) {
    const snap = await db
      .collectionGroup('charges')
      .where('asaasInstallmentId', '==', payment.installment)
      .limit(10)
      .get();
    // Path: companies/{cid}/orders/{oid}/charges/{chargeId}
    for (const doc of snap.docs) {
      const parts = doc.ref.path.split('/');
      if (parts.length === 6 && parts[0] === 'companies' && parts[1] === companyId && parts[2] === 'orders') {
        return { orderId: parts[3], chargeId: parts[5] };
      }
    }
  }

  console.warn('[AsaasWebhook] charge not found, event acknowledged', {
    companyId,
    paymentId: payment.id,
    event: eventName,
  });
  return null;
}

/**
 * Moves the charge to `to` only when its current status is in `from`.
 * `keepIfPaymentsBooked`: a cancel never applies to a charge that already has
 * booked payments (partially paid installment plan keeps its status).
 */
async function updateChargeStatus(
  companyId: string,
  target: ChargeTarget,
  from: ChargeStatus[],
  to: ChargeStatus,
  keepIfPaymentsBooked = false,
): Promise<boolean> {
  const ref = chargeRef(companyId, target.orderId, target.chargeId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const charge = snap.data() as OrderCharge;
    if (!from.includes(charge.status)) return false;
    if (keepIfPaymentsBooked && (charge.paidAsaasPaymentIds ?? []).length > 0) return false;
    tx.update(ref, { status: to });
    return true;
  });
}

async function processPaymentEvent(
  companyId: string,
  name: AsaasWebhookEventName,
  payment: AsaasPaymentEvent,
  target: ChargeTarget,
): Promise<void> {
  switch (name) {
    case 'PAYMENT_RECEIVED':
    case 'PAYMENT_CONFIRMED': {
      const { applied } = await applyAsaasPayment(companyId, target.orderId, target.chargeId, payment);
      if (applied) await notifyAsaasPaymentReceived(companyId, target.orderId, Number(payment.value) || 0);
      return;
    }
    case 'PAYMENT_OVERDUE':
      await updateChargeStatus(companyId, target, ['pending'], 'overdue');
      return;
    case 'PAYMENT_REFUNDED':
      await revertAsaasPayment(companyId, target.orderId, target.chargeId, payment.id);
      return;
    case 'PAYMENT_DELETED':
      await updateChargeStatus(companyId, target, ['pending', 'overdue'], 'canceled', true);
      return;
    case 'PAYMENT_RECEIVED_IN_CASH_UNDONE':
      await reopenCharge(companyId, chargeRef(companyId, target.orderId, target.chargeId), payment);
      return;
    case 'PAYMENT_PARTIALLY_REFUNDED':
      logPartialRefund(companyId, target.chargeId, payment);
      return;
  }
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * PAYMENT_RECEIVED_IN_CASH_UNDONE: a charge the server settled itself
 * (paidOutside) is open again. A booked cash receipt (marked in the Asaas
 * panel) is left as it is and logged for a person to decide.
 */
async function reopenCharge(
  companyId: string,
  ref: FirebaseFirestore.DocumentReference,
  payment: AsaasPaymentEvent,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const charge = snap.data() as OrderCharge | CustomerCharge;
    const update = reopenAfterCashUndone(charge, today());
    if (update) {
      tx.update(ref, update);
      return;
    }
    if ((charge.paidAsaasPaymentIds ?? []).includes(payment.id)) {
      console.error('[AsaasWebhook] ALERT cash receipt undone on a booked payment; left as is', {
        companyId, chargeId: snap.id, paymentId: payment.id,
      });
    }
  });
}

/**
 * PAYMENT_PARTIALLY_REFUNDED: most of the money stays with the company and
 * Asaas has no line to take out of a specific order, so nothing changes on
 * the orders; it is logged for a person to register by hand.
 */
function logPartialRefund(companyId: string, chargeId: string, payment: AsaasPaymentEvent): void {
  console.warn('[AsaasWebhook] partial refund not booked; register it by hand', {
    companyId, chargeId, paymentId: payment.id,
  });
}

async function processCustomerChargeEvent(
  companyId: string,
  name: AsaasWebhookEventName,
  payment: AsaasPaymentEvent,
  chargeId: string,
): Promise<void> {
  const ref = customerChargeRef(companyId, chargeId);
  switch (name) {
    case 'PAYMENT_RECEIVED':
    case 'PAYMENT_CONFIRMED': {
      const { orderIds } = await applyCustomerChargePayment(companyId, chargeId, payment);
      if (orderIds.length > 0) {
        await notifyAsaasPaymentReceived(companyId, orderIds[0], Number(payment.value) || 0);
      }
      return;
    }
    case 'PAYMENT_OVERDUE':
    case 'PAYMENT_DELETED': {
      const from: ChargeStatus[] = name === 'PAYMENT_OVERDUE' ? ['pending'] : ['pending', 'overdue'];
      const to: ChargeStatus = name === 'PAYMENT_OVERDUE' ? 'overdue' : 'canceled';
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const charge = snap.data() as CustomerCharge;
        if (!from.includes(charge.status) || (charge.paidAsaasPaymentIds ?? []).length > 0) return;
        tx.update(ref, { status: to });
      });
      return;
    }
    case 'PAYMENT_REFUNDED':
      await revertCustomerChargePayment(companyId, chargeId, payment.id);
      return;
    case 'PAYMENT_RECEIVED_IN_CASH_UNDONE':
      await reopenCharge(companyId, ref, payment);
      return;
    case 'PAYMENT_PARTIALLY_REFUNDED':
      logPartialRefund(companyId, chargeId, payment);
      return;
  }
}

/** The multi-order charge an event refers to, or null (acknowledged). */
async function resolveCustomerCharge(
  companyId: string,
  eventName: string,
  payment: AsaasPaymentEvent,
): Promise<string | null> {
  const parsed = parseCustomerChargeReference(payment.externalReference);
  if (!parsed) return null;
  if (parsed.companyId !== companyId) {
    console.warn('[AsaasWebhook] externalReference belongs to another company', { companyId, event: eventName });
    return null;
  }
  const snap = await customerChargeRef(companyId, parsed.chargeId).get();
  if (!snap.exists) {
    console.error('[AsaasWebhook] ALERT referenced customer charge not found', {
      companyId, chargeId: parsed.chargeId, paymentId: payment.id, event: eventName,
    });
    return null;
  }
  if ((snap.data() as CustomerCharge).asaasPaymentId !== payment.id) {
    console.warn('[AsaasWebhook] payment does not belong to the referenced customer charge', {
      companyId, chargeId: parsed.chargeId, paymentId: payment.id, event: eventName,
    });
    return null;
  }
  return parsed.chargeId;
}

export async function handleAsaasEvent(companyId: string, event: AsaasWebhookEvent): Promise<void> {
  const eventRef = event.id ? eventsCollection(companyId).doc(eventDocId(event.id)) : null;
  if (!eventRef) {
    // No id to deduplicate on: process anyway (handlers are idempotent), record nothing.
    console.warn('[AsaasWebhook] event without id', { companyId, event: event.event });
  } else if ((await eventRef.get()).exists) {
    console.log('[AsaasWebhook] duplicate event skipped', { companyId, eventId: event.id, event: event.event });
    return;
  }

  const payment = event.payment;
  if (event.invoice?.id && INVOICE_EVENTS.has(event.event)) {
    await applyInvoiceEvent(companyId, event.event, event.invoice);
  } else if (payment?.id && HANDLED_EVENTS.has(event.event)) {
    const name = event.event as AsaasWebhookEventName;
    if (parseCustomerChargeReference(payment.externalReference)) {
      const chargeId = await resolveCustomerCharge(companyId, event.event, payment);
      if (chargeId) await processCustomerChargeEvent(companyId, name, payment, chargeId);
    } else {
      const target = await resolveCharge(companyId, event.event, payment);
      if (target) await processPaymentEvent(companyId, name, payment, target);
    }
  }

  // Only reached when processing did not throw: a failure leaves no marker.
  if (!eventRef) return;
  const now = new Date();
  await eventRef.set({
    processedAt: now.toISOString(),
    expiresAt: Timestamp.fromDate(new Date(now.getTime() + EVENT_TTL_MS)),
  });
}
