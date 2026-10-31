/**
 * `completedAt` (UTC ISO): when the order became `done`. Only the server
 * writes it, here, from the order triggers, so every path that changes the
 * status (app, API, bot, MCP) is covered. The app reads it but never sends it,
 * and old app versions save with `set(merge)` of the fields they know, which
 * keeps it. Orders that were already done have no date and are left alone.
 *
 * Trigger events can repeat and arrive out of order, so each write first
 * checks the order as it is now: an event that no longer applies does nothing.
 */
import { db, FieldValue } from './firestore.service';

interface OrderStatusSnapshot {
  status?: string | null;
}

function orderRef(companyId: string, orderId: string) {
  return db.collection('companies').doc(companyId).collection('orders').doc(orderId);
}

async function stamp(companyId: string, orderId: string, at: string): Promise<void> {
  const ref = orderRef(companyId, orderId);
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (data?.status !== 'done') return;
    // A late event of an earlier completion never replaces a newer date.
    if (data.completedAt && new Date(data.completedAt).getTime() >= new Date(at).getTime()) return;
    tx.update(ref, { completedAt: at });
  });
}

async function clear(companyId: string, orderId: string): Promise<void> {
  const ref = orderRef(companyId, orderId);
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (!data || data.status === 'done' || data.completedAt === undefined) return;
    tx.update(ref, { completedAt: FieldValue.delete() });
  });
}

/** Order created already done (new order with that status, API, bot). */
export async function stampCompletedAtOnCreate(
  companyId: string,
  orderId: string,
  created: OrderStatusSnapshot | undefined,
  at: string,
): Promise<void> {
  if (created?.status === 'done') await stamp(companyId, orderId, at);
}

/**
 * Became done: stamps [at], also when it is done again after being reopened.
 * Left done: clears the date. Any other update does nothing, so the write
 * here does not loop through the trigger.
 */
export async function syncCompletedAt(
  companyId: string,
  orderId: string,
  before: OrderStatusSnapshot | undefined,
  after: OrderStatusSnapshot | undefined,
  at: string,
): Promise<void> {
  const wasDone = before?.status === 'done';
  const isDone = after?.status === 'done';
  if (isDone && !wasDone) await stamp(companyId, orderId, at);
  if (wasDone && !isDone) await clear(companyId, orderId);
}
