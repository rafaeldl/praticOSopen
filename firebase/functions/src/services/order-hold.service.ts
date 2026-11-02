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
