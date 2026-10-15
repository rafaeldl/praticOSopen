/**
 * One Asaas charge for several orders of the same customer ("Mandar
 * cobrança" from "Receber de João").
 *
 * Asaas has no line items and no partial payment of a charge, so the
 * charge is a single Asaas payment (value = total) and the split lives here:
 * companies/{cid}/customerCharges/{chargeId} keeps which orders it covers and
 * how much goes to each one (`allocations`, oldest first, same rule as the
 * app's `allocatePayment`). Written only by the server; the webhook spreads
 * the payment over the orders from it (customer-charge-payment.service.ts).
 *
 * The customer never has two payable charges for the same debt: creating one
 * cancels the open single-order charges of the covered orders and the
 * previous open multi-order charge of the customer, and a single-order charge
 * is refused while the order is covered by an open multi-order charge.
 */

import { db } from '../firestore.service';
import { calculateRemainingBalance } from '../order.service';
import type { Customer, Order, UserAggr } from '../../models/types';
import type {
  AsaasCreatePaymentInput,
  ChargeStatus,
  CreateCustomerChargeInput,
  CustomerCharge,
  OrderCharge,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError } from './errors';
import { getPaymentSettings } from './connection.service';
import {
  OPEN_STATUSES,
  cancelCharge,
  findOrCreateAsaasCustomer,
  hasPaidInstallments,
  isCancelable,
  isOpen,
  listCharges,
  resolveTaxId,
  validateInput,
} from './charge.service';
import { allocateOldestFirst, OpenBalance, totalOpen } from '../../utils/payment-allocation';

export const CUSTOMER_CHARGES = 'customerCharges';
export const CUSTOMER_CHARGE_REF_TAG = 'cc';
export const MAX_CHARGE_ORDERS = 50;
const MAX_DESCRIPTION = 500;

/** Server-only fields, never returned to the app. */
const SERVER_ONLY_FIELDS = ['appliedTransactions', 'refundedAsaasPaymentIds', 'settlingOutsideAt', 'adjustingUntil'] as const;

export function customerChargesRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection(CUSTOMER_CHARGES);
}

export function customerChargeRef(companyId: string, chargeId: string) {
  return customerChargesRef(companyId).doc(chargeId);
}

/** `{companyId}:cc:{chargeId}`: a short id of ours, never the list of orders. */
export function customerChargeExternalReference(companyId: string, chargeId: string): string {
  return `${companyId}:${CUSTOMER_CHARGE_REF_TAG}:${chargeId}`;
}

/** Charge without the server-only bookkeeping fields. */
export function publicCustomerCharge(charge: CustomerCharge): CustomerCharge {
  const copy = { ...charge } as Record<string, unknown>;
  for (const key of SERVER_ONLY_FIELDS) delete copy[key];
  return copy as unknown as CustomerCharge;
}

function isOrderPayable(order: Pick<Order, 'status'>): boolean {
  return order.status !== 'quote' && order.status !== 'canceled';
}

/**
 * "OS 182, 190, 201 - Oficina" within Asaas' 500 characters; when the list is
 * too long it ends with "e mais N".
 */
export function describeCustomerCharge(numbers: Array<number | null | undefined>, companyName: string): string {
  const labels = numbers.map((n) => (n === null || n === undefined || `${n}` === '' ? '?' : `${n}`));
  const suffix = companyName ? ` - ${companyName}` : '';
  for (let shown = labels.length; shown >= 1; shown--) {
    const rest = labels.length - shown;
    const list = labels.slice(0, shown).join(', ');
    const text = `OS ${list}${rest > 0 ? ` e mais ${rest}` : ''}${suffix}`;
    if (text.length <= MAX_DESCRIPTION) return text;
  }
  return `OS${suffix}`.slice(0, MAX_DESCRIPTION);
}

/** Open (pending/overdue) multi-order charges of a customer. One equality filter: no composite index. */
export async function listOpenCustomerCharges(companyId: string, customerId: string): Promise<CustomerCharge[]> {
  const snapshot = await customerChargesRef(companyId).where('customer.id', '==', customerId).get();
  return snapshot.docs
    .map((doc) => ({ ...(doc.data() as CustomerCharge), id: doc.id }))
    .filter((charge) => OPEN_STATUSES.includes(charge.status));
}

/** Open multi-order charges covering an order. */
export async function listOpenCustomerChargesForOrder(companyId: string, orderId: string): Promise<CustomerCharge[]> {
  const snapshot = await customerChargesRef(companyId).where('orderIds', 'array-contains', orderId).get();
  return snapshot.docs
    .map((doc) => ({ ...(doc.data() as CustomerCharge), id: doc.id }))
    .filter((charge) => OPEN_STATUSES.includes(charge.status));
}

async function deleteAsaasPayment(client: AsaasClient, asaasPaymentId: string): Promise<void> {
  try {
    await client.deletePayment(asaasPaymentId);
  } catch (error) {
    if (error instanceof AsaasApiError && error.status === 404) return;
    throw error;
  }
}

/**
 * Cancels on Asaas, then marks the doc canceled only if it is still open (a
 * status written meanwhile by the webhook is never overwritten).
 */
export async function cancelCustomerChargeDoc(
  client: AsaasClient,
  companyId: string,
  charge: CustomerCharge,
): Promise<CustomerCharge> {
  await deleteAsaasPayment(client, charge.asaasPaymentId);
  const ref = customerChargeRef(companyId, charge.id);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return { ...charge, status: 'canceled' as ChargeStatus };
    const current = { ...(snapshot.data() as CustomerCharge), id: snapshot.id };
    if (!OPEN_STATUSES.includes(current.status) || (current.paidAsaasPaymentIds ?? []).length > 0) return current;
    tx.update(ref, { status: 'canceled' });
    return { ...current, status: 'canceled' as ChargeStatus };
  });
}

interface CoveredOrder {
  order: Order & { id: string };
  open: number;
}

async function readCoveredOrders(companyId: string, customerId: string, orderIds: string[]): Promise<CoveredOrder[]> {
  const orders = db.collection('companies').doc(companyId).collection('orders');
  const snapshots = await Promise.all(orderIds.map((id) => orders.doc(id).get()));
  return snapshots.map((snap) => {
    if (!snap.exists) throw new AsaasServiceError('ORDER_NOT_FOUND', 'Order not found');
    const order = { ...(snap.data() as Order), id: snap.id };
    if (order.customer?.id !== customerId) {
      throw new AsaasServiceError('ORDER_NOT_OF_CUSTOMER', 'Order belongs to another customer');
    }
    if (!isOrderPayable(order)) {
      throw new AsaasServiceError('ORDER_NOT_PAYABLE', 'Quotes and canceled orders cannot be charged');
    }
    return { order, open: calculateRemainingBalance(order) };
  });
}

export async function createCustomerCharge(
  companyId: string,
  customerId: string,
  input: CreateCustomerChargeInput,
  user: UserAggr,
): Promise<CustomerCharge> {
  // 1. Connection, customer and orders (all of this customer, payable).
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) {
    throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
  }

  const orderIds = [...new Set(input.orderIds ?? [])];
  if (orderIds.length === 0 || orderIds.length > MAX_CHARGE_ORDERS) {
    throw new AsaasServiceError('INVALID_VALUE', `Choose between 1 and ${MAX_CHARGE_ORDERS} orders`);
  }

  const customerSnap = await db.collection('companies').doc(companyId).collection('customers').doc(customerId).get();
  if (!customerSnap.exists) throw new AsaasServiceError('CUSTOMER_NOT_FOUND', 'Customer not found');
  const customer = { ...(customerSnap.data() as Customer), id: customerSnap.id };

  const covered = await readCoveredOrders(companyId, customerId, orderIds);
  if (!customer.name) customer.name = covered[0]?.order.customer?.name || '';

  // 2. Value (<= what the chosen orders owe) and due date; split oldest first
  // in the order the app sent (its `Debtor.orders` order).
  const balances: OpenBalance[] = covered.map(({ order, open }) => ({
    orderId: order.id,
    orderNumber: order.number ?? null,
    open,
  }));
  const { value, dueDate } = validateInput(
    { value: input.value, mode: 'single', dueDate: input.dueDate },
    totalOpen(balances),
  );
  const allocations = allocateOldestFirst(balances, value);

  // 3. CPF/CNPJ and Asaas client.
  const taxId = await resolveTaxId(companyId, customer, input.customerTaxId);
  const client = await getAsaasCredentialProvider().getClient(companyId);

  // 4. What has to be canceled once the new charge exists.
  const coveredIds = allocations.map((a) => a.orderId);
  const singleCharges: Array<{ orderId: string; charge: OrderCharge }> = [];
  for (const orderId of coveredIds) {
    const open = (await listCharges(companyId, orderId)).filter(isOpen);
    if (open.some(hasPaidInstallments)) {
      throw new AsaasServiceError(
        'INSTALLMENTS_IN_PROGRESS',
        'An order has an installment plan with paid installments; it cannot be replaced',
      );
    }
    for (const charge of open.filter(isCancelable)) singleCharges.push({ orderId, charge });
  }
  const previousCustomerCharges = await listOpenCustomerCharges(companyId, customerId);

  // 5. Asaas payment. Previous charges are canceled only after the new one
  // exists, so an Asaas rejection never kills a link already shared; the new
  // link is only shared after this call returns, so the customer never holds
  // two payable charges for the same debt.
  const asaasCustomerId = await findOrCreateAsaasCustomer(client, companyId, customer, taxId);
  const companySnap = await db.collection('companies').doc(companyId).get();
  const companyName = (companySnap.data()?.name as string | undefined) || '';
  const chargeDoc = customerChargesRef(companyId).doc();

  const paymentInput: AsaasCreatePaymentInput = {
    customer: asaasCustomerId,
    billingType: 'UNDEFINED',
    dueDate,
    value,
    description: describeCustomerCharge(allocations.map((a) => a.orderNumber), companyName),
    externalReference: customerChargeExternalReference(companyId, chargeDoc.id),
  };
  const payment = await client.createPayment(paymentInput);

  // 6. Charge document.
  const charge: CustomerCharge = {
    id: chargeDoc.id,
    customer: { id: customerId, name: customer.name || null },
    asaasPaymentId: payment.id,
    value,
    dueDate,
    status: 'pending',
    invoiceUrl: payment.invoiceUrl,
    orderIds: coveredIds,
    allocations: allocations.map((a) => ({ orderId: a.orderId, orderNumber: a.orderNumber ?? null, amount: a.amount })),
    paidAsaasPaymentIds: [],
    createdBy: { id: user.id, name: user.name },
    createdAt: new Date().toISOString(),
  };
  try {
    await chargeDoc.set(charge);
  } catch (error) {
    await deleteAsaasPayment(client, payment.id).catch(() => {
      console.error(`[Asaas] Could not cancel orphan customer charge ${charge.id}`);
    });
    throw error;
  }

  // 7. Cancel what the new charge replaces; roll back if anything cannot be canceled.
  try {
    for (const { orderId, charge: previous } of singleCharges) {
      await cancelCharge(client, companyId, orderId, previous);
    }
    for (const previous of previousCustomerCharges) {
      await cancelCustomerChargeDoc(client, companyId, previous);
    }
  } catch (error) {
    console.error(`[Asaas] Could not cancel a replaced charge; rolling back customer charge ${charge.id}`);
    await cancelCustomerChargeDoc(client, companyId, charge).catch(() => {
      console.error(`[Asaas] Could not roll back customer charge ${charge.id}`);
    });
    throw error;
  }

  console.log(`[Asaas] Customer charge ${charge.id} created for ${coveredIds.length} orders of company ${companyId}`);
  return charge;
}

export async function cancelCustomerCharge(
  companyId: string,
  customerId: string,
  chargeId: string,
): Promise<CustomerCharge> {
  const snapshot = await customerChargeRef(companyId, chargeId).get();
  if (!snapshot.exists) throw new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found');
  const charge = { ...(snapshot.data() as CustomerCharge), id: snapshot.id };
  if (charge.customer?.id !== customerId) throw new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found');
  if (!OPEN_STATUSES.includes(charge.status)) {
    throw new AsaasServiceError('CHARGE_NOT_OPEN', 'Only pending or overdue charges can be canceled');
  }
  const client = await getAsaasCredentialProvider().getClient(companyId);
  return publicCustomerCharge(await cancelCustomerChargeDoc(client, companyId, charge));
}

/** Refuses a single-order charge while the order is covered by an open multi-order charge. */
export async function assertNoOpenCustomerCharge(companyId: string, orderId: string): Promise<void> {
  const open = await listOpenCustomerChargesForOrder(companyId, orderId);
  if (open.length > 0) {
    throw new AsaasServiceError(
      'CUSTOMER_CHARGE_OPEN',
      'The order is covered by an open charge of several orders; cancel it first',
    );
  }
}
