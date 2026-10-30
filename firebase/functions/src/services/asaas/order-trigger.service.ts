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
 * - `transactions` or `total` changed, or the order became a quote/canceled, and the company has Asaas
 *   connected → `reconcileOutsidePayments` (money received outside Asaas
 *   while a link is open: settle or lower the link, outside-payment.service);
 * - `total` changed (and `transactions` did not) → `syncPaymentStatusWithTotal`
 *   (every company: `paid`/`payment` follow the new total);
 * - the order became paid (`payment` → 'paid', unless only the total changed:
 *   no money came in) or done (`status` → 'done') → `autoIssueInvoice`, which
 *   issues the nota when the company chose that moment (settings/nfse.autoIssue);
 * - anything else returns without reading Firestore.
 *
 * Both branches run independently; if one fails the other still runs and the
 * first error is rethrown so the failure shows up in the function logs.
 */
import { handleOrderStatusChange } from './charge.service';
import { getPaymentSettings } from './connection.service';
import {
  OrderPaymentState,
  repairAsaasTransactions,
  syncPaymentStatusWithTotal,
  transactionsChanged,
} from './order-payment.service';
import { reconcileOutsidePayments } from './outside-payment.service';
import { autoIssueInvoice } from './invoice.service';

export type OrderUpdateSnapshot = OrderPaymentState & {
  status?: string;
  payment?: string | null;
  /** Stamped by `syncPaymentStatusWithTotal`. */
  paymentSyncedAt?: string;
};

/** Repair first (it can change paidAmount), then bring open links in line. */
async function paymentsChangedIfConnected(companyId: string, orderId: string, repair: boolean): Promise<void> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) return;
  if (repair) await repairAsaasTransactions(companyId, orderId);
  await reconcileOutsidePayments(companyId, orderId);
}

export async function handleOrderUpdatedAsaas(
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
  const repair = transactionsChanged(before, after);
  // Only what changes the amount owed: total, or the order leaving the
  // payable states (quote/canceled owe nothing). Other status moves read nothing.
  const owesNothing = (status?: string) => status === 'quote' || status === 'canceled';
  const totalChanged = Number(before?.total ?? 0) !== Number(after.total ?? 0);
  const owedChanged =
    totalChanged ||
    (owesNothing(after.status) && !owesNothing(before?.status));
  if (repair || owedChanged) {
    tasks.push(paymentsChangedIfConnected(companyId, orderId, repair));
  }
  // Items edited after a payment: `paid`/`payment` follow the new total
  // (every company; the app's save never writes them).
  if (totalChanged && !repair) {
    tasks.push(syncPaymentStatusWithTotal(companyId, orderId).then(() => undefined));
  }
  const syncedFromTotal = !!after.paymentSyncedAt && after.paymentSyncedAt !== before?.paymentSyncedAt;
  if (after.payment === 'paid' && before?.payment !== 'paid' && !syncedFromTotal) {
    tasks.push(autoIssueInvoice(companyId, orderId, 'paid'));
  }
  if (after.status === 'done' && before?.status !== 'done') {
    tasks.push(autoIssueInvoice(companyId, orderId, 'completed'));
  }
  if (tasks.length === 0) return;

  const results = await Promise.allSettled(tasks);
  const failure = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failure) throw failure.reason;
}
