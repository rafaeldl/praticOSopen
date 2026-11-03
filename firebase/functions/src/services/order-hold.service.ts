/**
 * `onHold`: the "parada" mark of an order, valid only while it is `approved`
 * or `progress`. The app removes it when it changes the status; this covers
 * every other path (API, bot, MCP, old app versions), which change the status
 * without knowing the mark.
 *
 * Trigger events can repeat and arrive out of order, so the write first checks
 * the order as it is now: an event that no longer applies does nothing.
 */
import { db, FieldValue } from './firestore.service';
import { OrderWriteOptions, readOrderForWrite } from './order.service';
import { OrderRuleError } from './order-errors';
import type { Order, OrderHold, UserAggr } from '../models/types';

const HOLD_STATUSES = ['approved', 'progress'];

interface OrderHoldSnapshot {
  status?: string | null;
  onHold?: unknown;
}

export function holdNoLongerApplies(order: OrderHoldSnapshot | undefined): boolean {
  return !!order?.onHold && !HOLD_STATUSES.includes(order.status ?? '');
}

/** The write does not loop: without `onHold` the trigger has nothing to do. */
export async function clearOrderHold(companyId: string, orderId: string): Promise<void> {
  const ref = db.collection('companies').doc(companyId).collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (!holdNoLongerApplies(data)) return;
    tx.update(ref, { onHold: FieldValue.delete() });
  });
}

// ----------------------------------------------------------------------------
// Mark and resume through the API (POST/DELETE /v1/app/orders/:id/hold)
// ----------------------------------------------------------------------------

export type OrderHoldReason = 'part' | 'customer' | 'authorization' | 'other';

/** Same words as the app's internal comment (orderHoldLogMarked / orderHoldLogResumed). */
const REASON_LABELS: Record<OrderHoldReason, string> = {
  part: 'Esperando peça',
  customer: 'Esperando cliente',
  authorization: 'Esperando autorização',
  other: 'Outro motivo',
};

function resumedText(since: string | undefined, now: Date): string {
  const start = since ? new Date(since) : now;
  const day = (d: Date) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const days = Number.isNaN(start.getTime()) ? 0 : Math.max(0, Math.round((day(now) - day(start)) / 86_400_000));
  if (days === 0) return 'Retomada no mesmo dia';
  return days === 1 ? 'Retomada depois de 1 dia parada' : `Retomada depois de ${days} dias parada`;
}

function internalComment(text: string, actor: UserAggr) {
  return {
    text,
    authorType: 'internal',
    author: { name: actor.name, userId: actor.id },
    source: 'api',
    isInternal: true,
    createdAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Marks the order "parada" (or changes the reason) and writes the internal
 * comment, in one transaction. Only `approved` or `progress` (409 otherwise).
 */
export async function setOrderHold(
  companyId: string,
  orderId: string,
  input: { reason: OrderHoldReason; note?: string },
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<Order | null> {
  const ref = db.collection('companies').doc(companyId).collection('orders').doc(orderId);
  return db.runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;
    if (!HOLD_STATUSES.includes(order.status ?? '')) {
      throw new OrderRuleError('HOLD_NOT_ALLOWED', 409, 'Only approved or in-progress orders can be on hold');
    }
    const now = new Date().toISOString();
    const note = input.note?.trim();
    const onHold: OrderHold = { reason: input.reason, ...(note ? { note } : {}), since: now };
    const update = { onHold, updatedAt: now, updatedBy: actor };
    tx.update(ref, update);
    const label = REASON_LABELS[input.reason];
    tx.set(ref.collection('comments').doc(), internalComment(`Marcada como parada: ${note ? `${label}. ${note}` : label}`, actor));
    return { ...order, ...update } as Order;
  });
}

/** Removes the mark, in any status; without a mark nothing is written. */
export async function removeOrderHold(
  companyId: string,
  orderId: string,
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<Order | null> {
  const ref = db.collection('companies').doc(companyId).collection('orders').doc(orderId);
  return db.runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;
    if (!order.onHold) return order;
    const now = new Date();
    tx.update(ref, { onHold: FieldValue.delete(), updatedAt: now.toISOString(), updatedBy: actor });
    if (HOLD_STATUSES.includes(order.status ?? '')) {
      tx.set(ref.collection('comments').doc(), internalComment(resumedText(order.onHold.since, now), actor));
    }
    const rest = { ...order, updatedAt: now.toISOString(), updatedBy: actor } as Order;
    delete rest.onHold;
    return rest;
  });
}
