/**
 * DELETE /v1/app/orders/:id: removes an order with everything under it.
 *
 * Who: `canDeleteOrder` (contract order-delete.json, same as firestore.rules).
 * Before deleting, what could still move money or a nota is settled:
 * - an active nota fiscal → refused (ORDER_HAS_INVOICE): cancel it first;
 * - an open charge of several orders → refused (CUSTOMER_CHARGE_OPEN): it
 *   covers other orders, so the user decides;
 * - an installment plan with paid installments → refused (INSTALLMENTS_IN_PROGRESS);
 * - the permission is checked again on the fresh order (money may have
 *   arrived) right before anything is canceled, so a refusal never leaves the
 *   order without its charge;
 * - an open charge of this order → canceled in Asaas; when one stays open the
 *   order is kept (ASAAS_UNAVAILABLE), so money never lands on a missing order.
 * Then, in a transaction over the fresh order (checked once more), the
 * document goes; its subcollections (comments, forms, photos, charges),
 * Storage files and share links follow.
 */
import { db, getTenantCollection, runTransaction, storage } from './firestore.service';
import { readOrderForWrite } from './order.service';
import { orderFilesPrefix } from './payment-input';
import { AsaasServiceError } from './asaas/errors';
import { getPaymentSettings } from './asaas/connection.service';
import { cancelOpenChargesForOrder, hasPaidInstallments, isCancelable, isOpen, listCharges } from './asaas/charge.service';
import { assertNoOpenCustomerCharge } from './asaas/customer-charge.service';
import { invoicesRef, isActiveInvoice } from './asaas/invoice.service';
import { getTokensForOrder, revokeShareToken } from './share-token.service';
import type { NfseInvoice } from '../models/asaas.types';
import type { Order } from '../models/types';

async function assertNoActiveInvoice(companyId: string, orderId: string): Promise<void> {
  const snapshot = await invoicesRef(companyId).where('orderIds', 'array-contains', orderId).get();
  if (snapshot.docs.some((doc) => isActiveInvoice(doc.data() as NfseInvoice))) {
    throw new AsaasServiceError('ORDER_HAS_INVOICE', 'The order has an active nota: cancel it first');
  }
}

/** Open charges of the order; refuses an installment plan already being paid. */
async function openChargesOf(companyId: string, orderId: string) {
  const open = (await listCharges(companyId, orderId)).filter(isOpen);
  if (open.some(hasPaidInstallments)) {
    throw new AsaasServiceError('INSTALLMENTS_IN_PROGRESS', 'An installment plan with paid installments cannot be canceled');
  }
  return open;
}

async function cancelOpenCharges(companyId: string, orderId: string): Promise<void> {
  // Without Asaas connected nothing can be canceled there and no webhook arrives.
  if (!(await getPaymentSettings(companyId)).asaasConnected) return;
  await cancelOpenChargesForOrder(companyId, orderId);
  const stillOpen = (await listCharges(companyId, orderId)).filter(isCancelable);
  if (stillOpen.length > 0) {
    throw new AsaasServiceError('ASAAS_UNAVAILABLE', 'Could not cancel the open charge of the order');
  }
}

async function afterDelete(step: string, fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch (error) {
    console.warn(`[OrderDelete] ${step} failed after the order was deleted`, (error as Error).name);
  }
}

/** Deletes the order. False when it does not exist; `guard` throws to refuse. */
export async function deleteOrder(
  companyId: string,
  orderId: string,
  guard: (order: Order) => void,
): Promise<boolean> {
  const ref = getTenantCollection(companyId, 'orders').doc(orderId) as unknown as FirebaseFirestore.DocumentReference;
  const current = await ref.get();
  if (!current.exists) return false;
  guard({ ...(current.data() as Order), id: orderId });

  await assertNoActiveInvoice(companyId, orderId);
  await assertNoOpenCustomerCharge(companyId, orderId);
  const open = await openChargesOf(companyId, orderId);

  if (open.length > 0) {
    // Final check on the fresh order before canceling anything in Asaas.
    const exists = await runTransaction(async (tx) => !!(await readOrderForWrite(tx, ref, { guard })));
    if (!exists) return false;
    await cancelOpenCharges(companyId, orderId);
  }

  const deleted = await runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, { guard });
    if (!order) return false;
    tx.delete(ref);
    return true;
  });
  if (!deleted) return false;

  await afterDelete('subcollections', () => db.recursiveDelete(ref));
  await afterDelete('files', () => storage.bucket().deleteFiles({ prefix: orderFilesPrefix(companyId, orderId) }));
  await afterDelete('share links', async () => {
    for (const token of await getTokensForOrder(orderId, companyId)) await revokeShareToken(token.token);
  });
  return true;
}
