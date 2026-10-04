/**
 * Order charges (cobranças da OS) on the company's Asaas account.
 * companies/{cid}/orders/{oid}/charges/{chargeId} is written only here and by
 * the webhook; it is the source of truth for Asaas payments of the order.
 */

import { db } from '../firestore.service';
import { calculateRemainingBalance } from '../order.service';
import { Customer, Order, UserAggr } from '../../models/types';
import {
  AsaasConnectionDoc,
  AsaasCreatePaymentInput,
  ChargeStatus,
  CreateChargeInput,
  OrderCharge,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { asaasConnectionRef, getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError } from './errors';
import { getPaymentSettings } from './connection.service';
import { isValidTaxId, normalizeTaxId } from '../../utils/tax-id.utils';

const OPEN_STATUSES: ChargeStatus[] = ['pending', 'overdue'];
const TIME_ZONE = 'America/Sao_Paulo';
const DEFAULT_DUE_DAYS = 3;
const MIN_INSTALLMENTS = 2;
const MAX_INSTALLMENTS = 12;
const CENT_TOLERANCE = 0.005;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function companyRef(companyId: string) {
  return db.collection('companies').doc(companyId);
}

function orderRef(companyId: string, orderId: string) {
  return companyRef(companyId).collection('orders').doc(orderId);
}

export function chargesRef(companyId: string, orderId: string) {
  return orderRef(companyId, orderId).collection('charges');
}

function customerRef(companyId: string, customerId: string) {
  return companyRef(companyId).collection('customers').doc(customerId);
}

function asaasCustomerMapRef(companyId: string, customerId: string) {
  return companyRef(companyId)
    .collection('private')
    .doc('asaas')
    .collection('customers')
    .doc(customerId);
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

/** YYYY-MM-DD of `now` in America/Sao_Paulo */
export function todayInSaoPaulo(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/** Calendar arithmetic on a YYYY-MM-DD string (no time zone involved). */
export function addDays(date: string, days: number): string {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

/** Default due date: today + 3 days in America/Sao_Paulo */
export function defaultDueDate(now: Date = new Date()): string {
  return addDays(todayInSaoPaulo(now), DEFAULT_DUE_DAYS);
}

/** YYYY-MM-DD that is a real calendar date (rejects 2026-02-30, 2026-13-01). */
function isCalendarDate(value: string): boolean {
  return DATE_PATTERN.test(value) && addDays(value, 0) === value;
}

function isOpen(charge: Pick<OrderCharge, 'status'>): boolean {
  return OPEN_STATUSES.includes(charge.status);
}

/** An installment plan with any paid installment must not be canceled (mirrors the webhook rule). */
function hasPaidInstallments(charge: Pick<OrderCharge, 'paidAsaasPaymentIds'>): boolean {
  return (charge.paidAsaasPaymentIds?.length ?? 0) > 0;
}

/** Open and with nothing paid yet: safe to cancel on Asaas and mark canceled. */
function isCancelable(charge: OrderCharge): boolean {
  return isOpen(charge) && !hasPaidInstallments(charge);
}

async function cancelInAsaas(client: AsaasClient, charge: OrderCharge): Promise<void> {
  try {
    if (charge.asaasInstallmentId) {
      await client.deleteInstallment(charge.asaasInstallmentId);
    } else {
      await client.deletePayment(charge.asaasPaymentId);
    }
  } catch (error) {
    // Already removed on Asaas: treat as canceled.
    if (error instanceof AsaasApiError && error.status === 404) return;
    throw error;
  }
}

async function listCharges(companyId: string, orderId: string): Promise<OrderCharge[]> {
  const snapshot = await chargesRef(companyId, orderId).get();
  return snapshot.docs.map((doc) => ({ ...(doc.data() as OrderCharge), id: doc.id }));
}

/**
 * Cancels on Asaas, then marks the doc canceled only if it is still open, so a
 * status written meanwhile by the webhook (paid/refunded) is never overwritten.
 */
async function cancelCharge(
  client: AsaasClient,
  companyId: string,
  orderId: string,
  charge: OrderCharge,
): Promise<OrderCharge> {
  await cancelInAsaas(client, charge);
  const ref = chargesRef(companyId, orderId).doc(charge.id);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return { ...charge, status: 'canceled' as ChargeStatus };
    const current = { ...(snapshot.data() as OrderCharge), id: snapshot.id };
    if (!isCancelable(current)) return current;
    tx.update(ref, { status: 'canceled' });
    return { ...current, status: 'canceled' as ChargeStatus };
  });
}

/**
 * CPF/CNPJ for the charge, normalized. A tax id sent in the request is
 * validated and saved on the customer; otherwise the customer's stored one is used.
 */
async function resolveTaxId(
  companyId: string,
  customer: Customer,
  inputTaxId: string | undefined,
): Promise<string> {
  const fromInput = normalizeTaxId(inputTaxId);
  if (fromInput) {
    if (!isValidTaxId(fromInput)) {
      throw new AsaasServiceError('INVALID_TAX_ID', 'Invalid CPF/CNPJ');
    }
    if (customer.taxId !== fromInput) {
      await customerRef(companyId, customer.id).update({ taxId: fromInput });
    }
    return fromInput;
  }

  const stored = normalizeTaxId(customer.taxId);
  if (!stored) {
    throw new AsaasServiceError('TAX_ID_REQUIRED', 'Customer CPF/CNPJ is required');
  }
  if (!isValidTaxId(stored)) {
    throw new AsaasServiceError('INVALID_TAX_ID', 'Invalid CPF/CNPJ');
  }
  return stored;
}

/** companies/{cid}/private/asaas/customers/{customerId} */
interface AsaasCustomerMapEntry {
  asaasCustomerId: string;
  environment?: AsaasConnectionDoc['environment'];
  walletId?: string;
}

type AccountIdentity = Pick<AsaasConnectionDoc, 'environment' | 'walletId'>;

async function currentAccount(companyId: string): Promise<Partial<AccountIdentity>> {
  const snapshot = await asaasConnectionRef(companyId).get();
  const connection = snapshot.data() as AsaasConnectionDoc | undefined;
  return { environment: connection?.environment, walletId: connection?.walletId };
}

/**
 * A mapped Asaas customer belongs to the account it was created on. Entries
 * from another environment/wallet (reconnect to a different account) or
 * legacy entries without environment are not reused.
 */
function mapEntryMatches(entry: Partial<AsaasCustomerMapEntry> | undefined, account: Partial<AccountIdentity>): boolean {
  if (!entry?.asaasCustomerId || !entry.environment || !account.environment) return false;
  if (entry.environment !== account.environment) return false;
  if (entry.walletId && account.walletId && entry.walletId !== account.walletId) return false;
  return true;
}

async function findOrCreateAsaasCustomer(
  client: AsaasClient,
  companyId: string,
  customer: Customer,
  taxId: string,
): Promise<string> {
  const mapRef = asaasCustomerMapRef(companyId, customer.id);
  const [mapped, account] = await Promise.all([mapRef.get(), currentAccount(companyId)]);
  const entry = mapped.data() as Partial<AsaasCustomerMapEntry> | undefined;
  if (mapEntryMatches(entry, account)) return entry!.asaasCustomerId as string;

  const existing = await client.findCustomerByExternalReference(customer.id);
  let asaasCustomerId = existing?.id;

  if (!asaasCustomerId) {
    const email = customer.email && EMAIL_PATTERN.test(customer.email) ? customer.email : undefined;
    const created = await client.createCustomer({
      name: customer.name,
      cpfCnpj: taxId,
      ...(email ? { email } : {}),
      externalReference: customer.id,
      notificationDisabled: true,
    });
    asaasCustomerId = created.id;
  }

  const newEntry: AsaasCustomerMapEntry = { asaasCustomerId };
  if (account.environment) newEntry.environment = account.environment;
  if (account.walletId) newEntry.walletId = account.walletId;
  await mapRef.set(newEntry);
  return asaasCustomerId;
}

interface ValidatedInput {
  value: number;
  dueDate: string;
  installmentCount?: number;
}

function validateInput(input: CreateChargeInput, remaining: number): ValidatedInput {
  const rawValue = typeof input.value === 'number' ? input.value : NaN;
  const value = roundMoney(rawValue);
  if (!Number.isFinite(value) || value <= 0) {
    throw new AsaasServiceError('INVALID_VALUE', 'Value must be greater than zero');
  }
  if (value > remaining + CENT_TOLERANCE) {
    throw new AsaasServiceError('INVALID_VALUE', 'Value exceeds the order remaining balance');
  }

  let installmentCount: number | undefined;
  if (input.mode === 'cardInstallments') {
    const count = input.installmentCount;
    if (
      typeof count !== 'number' ||
      !Number.isInteger(count) ||
      count < MIN_INSTALLMENTS ||
      count > MAX_INSTALLMENTS
    ) {
      throw new AsaasServiceError('INVALID_INSTALLMENT_COUNT', 'installmentCount must be between 2 and 12');
    }
    installmentCount = count;
  }

  const dueDate = input.dueDate ?? defaultDueDate();
  if (typeof dueDate !== 'string' || !isCalendarDate(dueDate) || dueDate < todayInSaoPaulo()) {
    throw new AsaasServiceError('INVALID_DUE_DATE', 'dueDate must be today or later (YYYY-MM-DD)');
  }
  return { value, dueDate, installmentCount };
}

export async function createOrderCharge(
  companyId: string,
  orderId: string,
  input: CreateChargeInput,
  user: UserAggr,
): Promise<OrderCharge> {
  // 1. Connection and order state
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) {
    throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
  }

  const orderSnap = await orderRef(companyId, orderId).get();
  if (!orderSnap.exists) {
    throw new AsaasServiceError('ORDER_NOT_FOUND', 'Order not found');
  }
  const order = { ...(orderSnap.data() as Order), id: orderSnap.id };
  if (order.status === 'canceled') {
    throw new AsaasServiceError('ORDER_CANCELED', 'Order is canceled');
  }

  // 2. Value, installments and due date (remaining = total - paidAmount; total is net of discount)
  const { value, dueDate, installmentCount } = validateInput(input, calculateRemainingBalance(order));

  // 3. Customer and CPF/CNPJ (read from the Customer document, not the order aggregate)
  const customerId = order.customer?.id;
  if (!customerId) {
    throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order has no customer');
  }
  const customerSnap = await customerRef(companyId, customerId).get();
  if (!customerSnap.exists) {
    throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order customer not found');
  }
  const customer = { ...(customerSnap.data() as Customer), id: customerSnap.id };
  if (!customer.name) customer.name = order.customer?.name || '';
  const taxId = await resolveTaxId(companyId, customer, input.customerTaxId);

  const client = await getAsaasCredentialProvider().getClient(companyId);

  const openCharges = (await listCharges(companyId, orderId)).filter(isOpen);
  if (openCharges.some(hasPaidInstallments)) {
    // Remaining installments are still being collected: a new charge could bill twice.
    throw new AsaasServiceError(
      'INSTALLMENTS_IN_PROGRESS',
      'The order has an installment plan with paid installments; it cannot be replaced',
    );
  }

  // 4. Asaas customer, before touching the open charge: a customer/tax id
  // rejection by Asaas must not leave the order without its open charge.
  const asaasCustomerId = await findOrCreateAsaasCustomer(client, companyId, customer, taxId);

  // 5. One open charge per order: cancel the previous ones.
  for (const charge of openCharges) {
    await cancelCharge(client, companyId, orderId, charge);
  }

  // 6. Asaas payment
  const companySnap = await companyRef(companyId).get();
  const companyName = (companySnap.data()?.name as string | undefined) || '';
  const chargeDoc = chargesRef(companyId, orderId).doc();

  const paymentInput: AsaasCreatePaymentInput = {
    customer: asaasCustomerId,
    billingType: input.mode === 'cardInstallments' ? 'CREDIT_CARD' : 'UNDEFINED',
    dueDate,
    description: `OS #${order.number ?? ''} - ${companyName}`,
    externalReference: `${companyId}:${orderId}:${chargeDoc.id}`,
  };
  if (input.mode === 'cardInstallments') {
    paymentInput.installmentCount = installmentCount;
    paymentInput.totalValue = value;
  } else {
    paymentInput.value = value;
  }

  const payment = await client.createPayment(paymentInput);

  // 7. Charge document
  const charge: OrderCharge = {
    id: chargeDoc.id,
    asaasPaymentId: payment.id,
    mode: input.mode === 'cardInstallments' ? 'cardInstallments' : 'single',
    value,
    dueDate,
    status: 'pending',
    invoiceUrl: payment.invoiceUrl,
    paidAsaasPaymentIds: [],
    createdBy: { id: user.id, name: user.name },
    createdAt: new Date().toISOString(),
  };
  if (input.mode === 'cardInstallments') {
    charge.installmentCount = installmentCount;
    if (payment.installment) charge.asaasInstallmentId = payment.installment;
  }

  try {
    await chargeDoc.set(charge);
  } catch (error) {
    // Do not leave an orphan charge on Asaas.
    await cancelInAsaas(client, charge).catch(() => {
      console.error(`[Asaas] Could not cancel orphan charge ${charge.id} of order ${orderId}`);
    });
    throw error;
  }

  console.log(`[Asaas] Charge ${charge.id} created for order ${orderId} of company ${companyId}`);
  return charge;
}

export async function cancelOrderCharge(
  companyId: string,
  orderId: string,
  chargeId: string,
): Promise<OrderCharge> {
  const snapshot = await chargesRef(companyId, orderId).doc(chargeId).get();
  if (!snapshot.exists) {
    throw new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found');
  }
  const charge = { ...(snapshot.data() as OrderCharge), id: snapshot.id };
  if (!isOpen(charge)) {
    throw new AsaasServiceError('CHARGE_NOT_OPEN', 'Only pending or overdue charges can be canceled');
  }
  if (hasPaidInstallments(charge)) {
    throw new AsaasServiceError(
      'INSTALLMENTS_IN_PROGRESS',
      'An installment plan with paid installments cannot be canceled',
    );
  }

  const client = await getAsaasCredentialProvider().getClient(companyId);
  return cancelCharge(client, companyId, orderId, charge);
}

/**
 * Cancels every pending/overdue charge of the order, skipping installment
 * plans with paid installments. Logs failures, never throws per charge.
 */
export async function cancelOpenChargesForOrder(companyId: string, orderId: string): Promise<void> {
  const openCharges = (await listCharges(companyId, orderId)).filter(isCancelable);
  if (openCharges.length === 0) return;

  const client = await getAsaasCredentialProvider().getClient(companyId);
  for (const charge of openCharges) {
    try {
      await cancelCharge(client, companyId, orderId, charge);
    } catch (error) {
      const status = error instanceof AsaasApiError ? error.status : 'unknown';
      console.error(`[Asaas] Failed to cancel charge ${charge.id} of order ${orderId} (status ${status})`);
    }
  }
}

/** Open charge (most recent) or, when none, the most recently paid one. */
export async function getOpenOrLatestPaidCharge(
  companyId: string,
  orderId: string,
): Promise<OrderCharge | null> {
  const charges = await listCharges(companyId, orderId);
  const newestFirst = (a: OrderCharge, b: OrderCharge) =>
    (b.paidAt || b.createdAt || '').localeCompare(a.paidAt || a.createdAt || '');

  const open = charges.filter(isOpen).sort(newestFirst);
  if (open.length > 0) return open[0];

  const paid = charges.filter((c) => c.status === 'paid').sort(newestFirst);
  return paid[0] ?? null;
}

/**
 * Firestore trigger handler: when an order changes to 'canceled' and the
 * company has Asaas connected, cancel its open charges on Asaas.
 */
export async function handleOrderStatusChange(
  companyId: string,
  orderId: string,
  beforeStatus: string | undefined,
  afterStatus: string | undefined,
): Promise<void> {
  if (afterStatus !== 'canceled' || beforeStatus === 'canceled') return;
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) return;
  await cancelOpenChargesForOrder(companyId, orderId);
}
