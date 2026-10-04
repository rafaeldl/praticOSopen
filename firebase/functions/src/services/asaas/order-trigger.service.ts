/**
 * Body of the single Asaas trigger on `companies/{companyId}/orders/{orderId}`
 * updates (`onOrderUpdatedAsaas` in index.ts). Kept here so the branching is
 * testable without the Functions runtime:
 *
 * - status changed to `canceled` → cancel open Asaas charges
 *   (`handleOrderStatusChange`, which checks the connection itself);
 * - `transactions` changed and the company has Asaas connected →
 *   `repairAsaasTransactions` (restores Asaas payments overwritten by old app
 *   versions and fixes an inconsistent paid/payment status);
 * - anything else returns without reading Firestore.
 *
 * Both branches run independently; if one fails the other still runs and the
 * first error is rethrown so the failure shows up in the function logs.
 */
import { handleOrderStatusChange } from './charge.service';
import { getPaymentSettings } from './connection.service';
import { OrderPaymentState, repairAsaasTransactions, transactionsChanged } from './order-payment.service';

export type OrderUpdateSnapshot = OrderPaymentState & { status?: string };

async function repairIfConnected(companyId: string, orderId: string): Promise<void> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) return;
  await repairAsaasTransactions(companyId, orderId);
}

export async function runAsaasOrderUpdate(
  companyId: string,
  orderId: string,
  before: OrderUpdateSnapshot | undefined,
  after: OrderUpdateSnapshot | undefined,
): Promise<void> {
  if (!after) return;

  const tasks: Promise<void>[] = [];
  if (after.status === 'canceled' && before?.status !== 'canceled') {
    tasks.push(handleOrderStatusChange(companyId, orderId, before?.status, after.status));
  }
  if (transactionsChanged(before, after)) {
    tasks.push(repairIfConnected(companyId, orderId));
  }
  if (tasks.length === 0) return;

  const results = await Promise.allSettled(tasks);
  const failure = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failure) throw failure.reason;
}
