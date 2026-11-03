/**
 * Payment changes of one order beyond adding money (which is
 * order.service `addPayment`): remove a payment or discount, mark as fully
 * paid, undo all payments, attach or remove a payment's proof.
 *
 * Same rules as the app (OrderPaymentMath.removeTransaction, resetPayments,
 * markAsFullyPaid, setReceipt; contract payment-transactions.json), plus two
 * locks the app enforces on the screen:
 * - an Asaas payment (`asaas_*`) only goes away with a refund in Asaas;
 * - a share of a customer receipt (`receiptGroupId`) is undone with the
 *   receipt as a whole (customer-receipt.service `cancelCustomerReceipt`).
 *
 * Every write runs in a transaction over the fresh order; a proof file that
 * belonged only to the removed payment is deleted from Storage after commit.
 */
import { v4 as uuidv4 } from 'uuid';
import { getTenantCollection, runTransaction, storage } from './firestore.service';
import {
  calculateRemainingBalance,
  computeOrderTotal,
  OrderWriteOptions,
  paymentStatusFields,
  readOrderForWrite,
  receiptDocument,
} from './order.service';
import { findTransactionIndex } from './order-items';
import { OrderRuleError } from './order-errors';
import { ASAAS_TRANSACTION_PREFIX } from './asaas/order-payment.service';
import { isInsideFolder, isSharedReceiptPath, orderFilesPrefix, ReceiptFileInput, validatePaidAt, validateReceiptFile } from './payment-input';
import { roundMoney } from '../utils/money';
import type { Order, OrderDocument, PaymentTransaction, UserAggr } from '../models/types';

/** Payment fields written by these operations (plus discount/total and audit). */
export interface PaymentState {
  transactions: PaymentTransaction[];
  paidAmount: number;
  discount: number;
  total: number;
  paid: boolean;
  payment: 'paid' | 'unpaid' | null;
}

export function isAsaasTransaction(transaction: Pick<PaymentTransaction, 'id'>): boolean {
  return typeof transaction.id === 'string' && transaction.id.startsWith(ASAAS_TRANSACTION_PREFIX);
}

function withStatus(order: Order, state: Omit<PaymentState, 'paid' | 'payment'>): PaymentState {
  return { ...state, ...paymentStatusFields(order.status, state.total, state.paidAmount) };
}

/**
 * Removes the transaction at [index] (pure). Payment: paidAmount goes down,
 * never below 0. Discount: discount goes down and the total is recomputed
 * from the items. Refuses Asaas payments and shares of a customer receipt.
 */
export function removeTransactionAt(order: Order, index: number): PaymentState {
  const transactions = [...(order.transactions ?? [])];
  const target = transactions[index];
  if (!target) throw new OrderRuleError('TRANSACTION_NOT_FOUND', 404, 'Transaction not found');
  if (isAsaasTransaction(target)) {
    throw new OrderRuleError('ASAAS_LOCKED', 409, 'An Asaas payment is undone with a refund in Asaas');
  }
  if (target.receiptGroupId) {
    throw new OrderRuleError('RECEIPT_SHARE', 409, 'Part of a customer receipt: undo the receipt instead');
  }
  transactions.splice(index, 1);
  let paidAmount = roundMoney(Number(order.paidAmount) || 0);
  let discount = roundMoney(Number(order.discount) || 0);
  let total = Number(order.total) || 0;
  if (target.type === 'payment') {
    paidAmount = Math.max(0, roundMoney(paidAmount - target.amount));
  } else {
    discount = Math.max(0, roundMoney(discount - target.amount));
    total = computeOrderTotal({ services: order.services, products: order.products, discount });
  }
  return withStatus(order, { transactions, paidAmount, discount, total });
}

/** Removes every manual payment and discount; Asaas payments stay (OrderPaymentMath.resetPayments). */
export function resetPaymentsOf(order: Order): PaymentState {
  const transactions = (order.transactions ?? []).filter(isAsaasTransaction);
  const paidAmount = roundMoney(transactions.filter((t) => t.type === 'payment').reduce((sum, t) => sum + (Number(t.amount) || 0), 0));
  const total = computeOrderTotal({ services: order.services, products: order.products, discount: 0 });
  return withStatus(order, { transactions, paidAmount, discount: 0, total });
}

/** Removes every discount (transactions and a discount set without one); total from the items. */
export function removeDiscountsOf(order: Order): PaymentState {
  const transactions = (order.transactions ?? []).filter((t) => t.type !== 'discount');
  const total = computeOrderTotal({ services: order.services, products: order.products, discount: 0 });
  return withStatus(order, {
    transactions, paidAmount: roundMoney(Number(order.paidAmount) || 0), discount: 0, total,
  });
}

/**
 * Books the remaining balance as a payment (when > 0) and forces "paid", as
 * the app does (markAsFullyPaid: an order of value 0 can be marked paid).
 * Quotes and canceled orders keep no payment status (D2).
 */
export function markFullyPaid(order: Order, build: (remaining: number) => PaymentTransaction): PaymentState & { added: PaymentTransaction | null } {
  const remaining = calculateRemainingBalance(order);
  const added = remaining > 0 ? build(remaining) : null;
  const transactions = added ? [...(order.transactions ?? []), added] : [...(order.transactions ?? [])];
  const paidAmount = roundMoney((Number(order.paidAmount) || 0) + (added?.amount ?? 0));
  const total = Number(order.total) || 0;
  const noStatus = order.status === 'quote' || order.status === 'canceled';
  return {
    transactions, paidAmount, discount: Number(order.discount) || 0, total,
    paid: !noStatus, payment: noStatus ? null : 'paid', added,
  };
}

function orderRef(companyId: string, orderId: string) {
  return getTenantCollection(companyId, 'orders').doc(orderId) as unknown as FirebaseFirestore.DocumentReference;
}

/**
 * Documents that went with [removed] (its proof), and the Storage files that
 * are only theirs: a proof file is deleted only from the folder of its own
 * payment (`{orderFolder}payments/{transactionId}/`, where the app uploads it).
 */
function documentsWithout(
  orderFolder: string,
  order: Order,
  removed: PaymentTransaction[],
): { documents: OrderDocument[]; files: string[] } {
  const ids = new Set(removed.map((t) => t.id));
  const byDocId = new Map(removed.filter((t) => t.receiptDocumentId).map((t) => [t.receiptDocumentId as string, t.id]));
  const current = order.documents ?? [];
  const documents = current.filter((d) => !(d.linkedTransactionId && ids.has(d.linkedTransactionId)) && !byDocId.has(d.id));
  const files: string[] = [];
  for (const d of current) {
    if (documents.includes(d) || !d.storagePath || isSharedReceiptPath(d.storagePath)) continue;
    const transactionId = d.linkedTransactionId && ids.has(d.linkedTransactionId) ? d.linkedTransactionId : byDocId.get(d.id);
    if (transactionId && isInsideFolder(`${orderFolder}payments/${transactionId}/`, d.storagePath)) {
      files.push(d.storagePath);
    } else {
      console.warn(`[OrderFinance] kept a proof file outside its payment folder: order=${order.id ?? ''}`);
    }
  }
  return { documents, files };
}

/**
 * Deletes the proof files of an order. The paths come from the order's
 * `documents`, which members can write, so only files inside this order's own
 * folder are deleted; any other path is skipped and logged.
 */
async function deleteFiles(companyId: string, orderId: string, paths: string[]): Promise<void> {
  const prefix = orderFilesPrefix(companyId, orderId);
  for (const path of paths) {
    if (!isInsideFolder(prefix, path)) {
      console.warn(`[OrderFinance] skipped a file outside the order folder: company=${companyId} order=${orderId}`);
      continue;
    }
    try {
      await storage.bucket().file(path).delete();
    } catch (error) {
      console.warn('[OrderFinance] could not delete a receipt file', (error as Error).name);
    }
  }
}

interface FinanceResult {
  order: Order;
}

/**
 * Runs [change] on the fresh order and writes the payment fields it returns
 * (plus documents when they changed). Files to drop are deleted after commit.
 */
async function writePayments(
  companyId: string,
  orderId: string,
  actor: UserAggr,
  options: OrderWriteOptions,
  change: (order: Order, now: string) => {
    state: Partial<PaymentState> & Record<string, unknown>;
    /** Transactions removed: their proof documents go too. */
    removed?: PaymentTransaction[];
    /** Storage files to delete after commit. */
    files?: string[];
  },
): Promise<FinanceResult | null> {
  const ref = orderRef(companyId, orderId);
  let files: string[] = [];
  const result = await runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;
    const now = new Date().toISOString();
    const { state, removed = [], files: extra = [] } = change(order, now);
    const update: Record<string, unknown> = { ...state, updatedAt: now, updatedBy: actor };
    files = [...extra];
    if (removed.length > 0) {
      const cleaned = documentsWithout(orderFilesPrefix(companyId, orderId), order, removed);
      if (cleaned.documents.length !== (order.documents ?? []).length) update.documents = cleaned.documents;
      files.push(...cleaned.files);
    }
    tx.update(ref, update);
    return { order: { ...order, ...update } as Order };
  });
  if (result) await deleteFiles(companyId, orderId, files);
  return result;
}

/** DELETE /:id/payments/:transactionId and /:id/discounts/:transactionId. */
export async function removeOrderTransaction(
  companyId: string,
  orderId: string,
  transactionId: string,
  type: PaymentTransaction['type'],
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<FinanceResult | null> {
  return writePayments(companyId, orderId, actor, options, (order) => {
    const index = findTransactionIndex(order.transactions, transactionId);
    const target = order.transactions?.[index];
    if (!target || target.type !== type) throw new OrderRuleError('TRANSACTION_NOT_FOUND', 404, 'Transaction not found');
    return { state: { ...removeTransactionAt(order, index) }, removed: [target] };
  });
}

/** POST /:id/payments/reset: refuses while the order holds a share of a customer receipt. */
export async function resetOrderPayments(
  companyId: string,
  orderId: string,
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<FinanceResult | null> {
  return writePayments(companyId, orderId, actor, options, (order) => {
    if ((order.transactions ?? []).some((t) => t.receiptGroupId)) {
      throw new OrderRuleError('RECEIPT_SHARE', 409, 'Part of a customer receipt: undo the receipt instead');
    }
    const removed = (order.transactions ?? []).filter((t) => !isAsaasTransaction(t));
    return { state: { ...resetPaymentsOf(order) }, removed };
  });
}

/** DELETE /:id/discounts: every discount, also one set without a transaction. */
export async function removeOrderDiscounts(
  companyId: string,
  orderId: string,
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<FinanceResult | null> {
  return writePayments(companyId, orderId, actor, options, (order) => ({ state: { ...removeDiscountsOf(order) } }));
}

export interface MarkPaidInput {
  description?: string;
  paidAt?: string;
  paymentMethod?: string;
}

/**
 * POST /:id/payments/mark-paid. When nothing was left to receive no money
 * came in, so `paymentSyncedAt` tells the order trigger not to issue a nota.
 */
export async function markOrderPaid(
  companyId: string,
  orderId: string,
  input: MarkPaidInput,
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<(FinanceResult & { transactionId: string | null }) | null> {
  const paidAt = input.paidAt ? validatePaidAt(input.paidAt) : undefined;
  let transactionId: string | null = null;
  const result = await writePayments(companyId, orderId, actor, options, (order, now) => {
    if (input.paidAt) validatePaidAt(input.paidAt, order.createdAt);
    const { added, ...state } = markFullyPaid(order, (remaining) => ({
      id: uuidv4(),
      type: 'payment',
      amount: remaining,
      description: input.description ?? 'Pagamento total',
      createdAt: now,
      createdBy: actor,
      ...(paidAt ? { paidAt } : {}),
      ...(input.paymentMethod ? { paymentMethod: input.paymentMethod } : {}),
    }));
    transactionId = added?.id ?? null;
    const changedWithoutMoney = !added && (order.payment ?? null) !== state.payment;
    return { state: { ...state, ...(changedWithoutMoney ? { paymentSyncedAt: now } : {}) } };
  });
  return result ? { ...result, transactionId } : null;
}

/**
 * PUT/DELETE /:id/payments/:transactionId/receipt. [file] null removes the
 * proof (and its file, unless it is a customer receipt's shared file).
 */
export async function setTransactionReceipt(
  companyId: string,
  orderId: string,
  transactionId: string,
  file: ReceiptFileInput | null,
  actor: UserAggr,
  options: OrderWriteOptions = {},
): Promise<FinanceResult | null> {
  if (file) validateReceiptFile(orderFilesPrefix(companyId, orderId), file);
  return writePayments(companyId, orderId, actor, options, (order, now) => {
    const transactions = [...(order.transactions ?? [])];
    const index = findTransactionIndex(transactions, transactionId);
    const target = transactions[index];
    if (!target || target.type !== 'payment') throw new OrderRuleError('TRANSACTION_NOT_FOUND', 404, 'Transaction not found');
    if (isAsaasTransaction(target)) throw new OrderRuleError('ASAAS_LOCKED', 409, 'An Asaas payment has the receipt of Asaas');
    if (target.receiptGroupId) throw new OrderRuleError('RECEIPT_SHARE', 409, 'The proof belongs to the customer receipt');
    const { documents, files } = documentsWithout(orderFilesPrefix(companyId, orderId), order, [target]);
    const next: PaymentTransaction = { ...target, id: target.id || uuidv4() };
    delete next.receiptDocumentId;
    const kept = [...documents];
    if (file) {
      const document = receiptDocument(file, next.id, actor, now);
      next.receiptDocumentId = document.id;
      kept.push(document);
    }
    transactions[index] = next;
    // The old proof file goes away when replaced or removed, after commit.
    return { state: { transactions, documents: kept }, files };
  });
}
