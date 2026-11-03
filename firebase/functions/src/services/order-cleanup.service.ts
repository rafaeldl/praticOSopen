/**
 * Cleanup after an order is deleted straight in Firestore (the app deletes
 * with the client SDK; DELETE /v1/app/orders/:id already cleans up itself,
 * see order-delete.service.ts, and running this again there is harmless).
 *
 * Only what lives inside the order's own folder goes: its comments,
 * checklists (with their items) and photos subcollections, and the Storage
 * files under `tenants/{companyId}/orders/{orderId}/`. Charges stay: they are
 * Asaas records the webhook may still update.
 */
import { db, storage } from './firestore.service';
import { orderFilesPrefix } from './payment-input';

const SUBCOLLECTIONS = ['comments', 'forms', 'photos'];

/** A single path segment: no slash and not `.`/`..`. */
function isSegment(id: string): boolean {
  return typeof id === 'string' && id.length > 0 && !id.includes('/') && id !== '.' && id !== '..';
}

export async function cleanupDeletedOrder(companyId: string, orderId: string): Promise<void> {
  if (!isSegment(companyId) || !isSegment(orderId)) return;

  const ref = db.collection('companies').doc(companyId).collection('orders').doc(orderId);
  // Same id written again (e.g. a contract order regenerated): keep it all.
  if ((await ref.get()).exists) return;

  for (const name of SUBCOLLECTIONS) {
    await db.recursiveDelete(ref.collection(name));
  }
  await storage.bucket().deleteFiles({ prefix: orderFilesPrefix(companyId, orderId) });
}
