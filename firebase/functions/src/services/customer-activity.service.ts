/**
 * `lastActivityAt` (UTC ISO) on the customer: the last time something happened
 * with them, so the customer list can show the most recent first. Only the
 * server writes it, from the triggers, so every path is covered (app, web,
 * API, bot, MCP and old app versions, which save with `set(merge)` and keep it):
 * - the customer was created or edited;
 * - one of their orders was created or changed (status, items, payment...).
 *
 * Trigger events can repeat and arrive out of order, so a write never puts an
 * older date over a newer one. Orders change many times in a row while being
 * edited, so a date less than THROTTLE_MS old is kept instead of rewritten.
 * Writing the date fires the customer trigger again, which sees that only the
 * date changed and stops there.
 */
import { db } from './firestore.service';

export const ACTIVITY_FIELD = 'lastActivityAt';
export const THROTTLE_MS = 60_000;

type Data = Record<string, unknown> | undefined;

/** Milliseconds of a stored date: ISO string, Firestore Timestamp, Date or epoch. */
export function dateMillis(value: unknown): number | null {
  if (value == null || value === '') return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const ms = new Date(value).getTime();
    return Number.isNaN(ms) ? null : ms;
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value.getTime();
  const stamp = value as { toMillis?: () => number; seconds?: number; _seconds?: number };
  if (typeof stamp.toMillis === 'function') return stamp.toMillis();
  const seconds = stamp.seconds ?? stamp._seconds;
  return typeof seconds === 'number' ? seconds * 1000 : null;
}

/** Customer id of an order (`customer.id`), when it is a valid document id. */
export function orderCustomerId(order: Data): string | null {
  const id = (order?.customer as { id?: unknown } | undefined)?.id;
  return typeof id === 'string' && id.length > 0 && !id.includes('/') ? id : null;
}

function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b));
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${stable(item)}`).join(',')}}`;
  }
  return JSON.stringify(value) ?? 'undefined';
}

/** Whether a customer write is real activity (created or edited), not just the date the server wrote. */
export function customerChanged(before: Data, after: Data): boolean {
  if (!after) return false;
  if (!before) return true;
  const strip = (data: Record<string, unknown>) => {
    const copy = { ...data };
    delete copy[ACTIVITY_FIELD];
    return copy;
  };
  return stable(strip(before)) !== stable(strip(after));
}

/** Sets the customer's date to [at] unless it is gone or already has a newer (or very recent) one. */
export async function touchCustomer(companyId: string, customerId: string, at: string): Promise<void> {
  const atMs = dateMillis(at);
  if (atMs == null) return;
  const ref = db.collection('companies').doc(companyId).collection('customers').doc(customerId);
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return;
    const current = dateMillis(snapshot.data()?.[ACTIVITY_FIELD]);
    if (current != null && current >= atMs - THROTTLE_MS) return;
    tx.update(ref, { [ACTIVITY_FIELD]: new Date(atMs).toISOString() });
  });
}

/** Order created or changed: its customer (the new one, if it was moved) had activity. */
export async function touchCustomerOfOrder(companyId: string, order: Data, at: string): Promise<void> {
  const customerId = orderCustomerId(order);
  if (customerId) await touchCustomer(companyId, customerId, at);
}

/** Customer created or edited (not just the date written here). */
export async function touchCustomerOnWrite(companyId: string, customerId: string, before: Data, after: Data, at: string): Promise<void> {
  if (customerChanged(before, after)) await touchCustomer(companyId, customerId, at);
}
