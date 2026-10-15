/**
 * NFS-e (nota fiscal de serviço) through the company's Asaas account.
 * See docs/NFSE_ASAAS.md.
 *
 * - One invoice per order by default; several orders of the same customer in
 *   one invoice when the user picks them ("uma nota com várias OS").
 * - The invoice is "avulsa" (tied to the Asaas customer, not to a payment):
 *   the nota belongs to the order, whatever way it was paid.
 * - Only the services of the order go into the nota (products are not NFS-e).
 *   Value rule (see `invoiceValueOfOrder`): services total minus the order
 *   discount in proportion to the services share of the items.
 * - companies/{cid}/invoices/{id} is written only here and by the webhook.
 *   One active invoice per order is guaranteed by the lock docs
 *   companies/{cid}/private/nfse/orders/{orderId} (server-only), read and
 *   written in the same transaction as the new invoice.
 */

import { db } from '../firestore.service';
import { Customer, Order, UserAggr } from '../../models/types';
import {
  AsaasCreateInvoiceInput,
  AsaasInvoice,
  CreateInvoiceInput,
  InvoiceOrderPart,
  InvoiceStatus,
  NfseInvoice,
  NfseServiceSettings,
  PaymentSettingsDoc,
} from '../../models/asaas.types';
import { AsaasApiError } from './asaas-client';
import { getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError } from './errors';
import { getPaymentSettings } from './connection.service';
import { findOrCreateAsaasCustomer, resolveTaxId, roundMoney, todayInSaoPaulo, addDays } from './charge.service';

export const MAX_INVOICE_ORDERS = 50;
/** Tag of the invoice externalReference `{companyId}:nf:{invoiceId}`. */
export const INVOICE_REF_TAG = 'nf';
/** A 'creating' invoice older than this never reached Asaas (crash) and stops blocking. */
const STALE_CREATING_MS = 15 * 60 * 1000;
const MAX_DESCRIPTION = 2000;
const MAX_OBSERVATIONS = 500;
/** Furthest future date accepted for the issue date. */
const MAX_FUTURE_DAYS = 60;
export const DEFAULT_DESCRIPTION_TEMPLATE = '{servicos}';

/** Statuses that no longer count as "the order has a nota". */
const INACTIVE_STATUSES: InvoiceStatus[] = ['canceled', 'error'];
/** Statuses the user can ask to cancel. */
const CANCELABLE_STATUSES: InvoiceStatus[] = ['scheduled', 'authorized', 'cancellationDenied'];

function companyRef(companyId: string) {
  return db.collection('companies').doc(companyId);
}

export function invoicesRef(companyId: string) {
  return companyRef(companyId).collection('invoices');
}

export function nfseSettingsRef(companyId: string) {
  return companyRef(companyId).collection('settings').doc('nfse');
}

function orderLockRef(companyId: string, orderId: string) {
  return companyRef(companyId).collection('private').doc('nfse').collection('orders').doc(orderId);
}

export function invoiceExternalReference(companyId: string, invoiceId: string): string {
  return `${companyId}:${INVOICE_REF_TAG}:${invoiceId}`;
}

export function parseInvoiceReference(ref?: string | null): { companyId: string; invoiceId: string } | null {
  if (!ref) return null;
  const parts = ref.split(':');
  if (parts.length !== 3 || parts.some((p) => !p) || parts[1] !== INVOICE_REF_TAG) return null;
  return { companyId: parts[0], invoiceId: parts[2] };
}

// ----------------------------------------------------------------------------
// Value rule
// ----------------------------------------------------------------------------

export interface OrderInvoiceValue {
  servicesTotal: number;
  productsTotal: number;
  discount: number;
  /** Services total minus the services share of the discount. */
  value: number;
}

/**
 * Value of the nota for one order, mirroring the app's order total
 * (OrderStore.updateTotal): services sum `value`, products `total` or
 * `value * quantity`, items without a price count as zero. The order discount
 * applies to the whole order, so the nota takes the services share of it:
 *   value = services - discount * services / (services + products)
 * rounded to cents. Example: services 300, products 100, discount 40 →
 * 300 - 40 * 0.75 = 270.
 */
export function invoiceValueOfOrder(order: Pick<Order, 'services' | 'products' | 'discount'>): OrderInvoiceValue {
  const servicesTotal = roundMoney(
    (order.services ?? []).reduce((sum, s) => sum + (Number(s?.value) || 0), 0),
  );
  const productsTotal = roundMoney(
    (order.products ?? []).reduce((sum, p) => {
      const line = p as unknown as { value?: number; quantity?: number; total?: number };
      if (line?.value === undefined || line?.value === null) return sum;
      const total = line.total ?? (Number(line.value) || 0) * (line.quantity ?? 1);
      return sum + (Number(total) || 0);
    }, 0),
  );
  const gross = servicesTotal + productsTotal;
  const discount = Math.min(Math.max(Number(order.discount) || 0, 0), Math.max(gross, 0));
  const share = gross > 0 ? servicesTotal / gross : 0;
  const value = Math.max(roundMoney(servicesTotal - discount * share), 0);
  return { servicesTotal, productsTotal, discount: roundMoney(discount), value };
}

function serviceLine(service: NonNullable<Order['services']>[number]): string {
  const name = (service?.service?.name || '').trim();
  const description = (service?.description || '').trim();
  if (name && description && description !== name) return `${name} - ${description}`;
  return name || description;
}

/** Service names of the orders: one line per order when there are several. */
export function describeServices(orders: Array<Pick<Order, 'number' | 'services'>>): string {
  const linesOf = (order: Pick<Order, 'services'>) =>
    (order.services ?? []).map(serviceLine).filter((line) => line.length > 0).join('; ');
  if (orders.length === 1) return linesOf(orders[0]);
  return orders
    .map((order) => {
      const lines = linesOf(order);
      return order.number !== undefined && order.number !== null ? `OS ${order.number}: ${lines}` : lines;
    })
    .join('\n');
}

/** "OS 182" / "OS 182, 190" (capped so it fits the observations field). */
export function describeOrderNumbers(numbers: Array<number | null | undefined>): string {
  const known = numbers.filter((n): n is number => n !== undefined && n !== null);
  if (known.length === 0) return '';
  let text = `OS ${known[0]}`;
  for (let i = 1; i < known.length; i++) {
    const next = `${text}, ${known[i]}`;
    if (next.length > MAX_OBSERVATIONS - 20) return `${text} e mais ${known.length - i}`;
    text = next;
  }
  return text;
}

export function applyDescriptionTemplate(template: string | undefined, services: string, orderNumbers: string): string {
  const base = (template || DEFAULT_DESCRIPTION_TEMPLATE).trim() || DEFAULT_DESCRIPTION_TEMPLATE;
  return base.replace(/\{servicos\}/g, services).replace(/\{os\}/g, orderNumbers).trim().slice(0, MAX_DESCRIPTION);
}

// ----------------------------------------------------------------------------
// Status rules
// ----------------------------------------------------------------------------

const ASAAS_STATUS: Record<string, InvoiceStatus> = {
  SCHEDULED: 'scheduled',
  SYNCHRONIZED: 'synchronized',
  AUTHORIZED: 'authorized',
  PROCESSING_CANCELLATION: 'processingCancellation',
  CANCELED: 'canceled',
  CANCELLATION_DENIED: 'cancellationDenied',
  ERROR: 'error',
};

const EVENT_STATUS: Record<string, InvoiceStatus> = {
  INVOICE_CREATED: 'scheduled',
  INVOICE_SYNCHRONIZED: 'synchronized',
  INVOICE_AUTHORIZED: 'authorized',
  INVOICE_PROCESSING_CANCELLATION: 'processingCancellation',
  INVOICE_CANCELED: 'canceled',
  INVOICE_CANCELLATION_DENIED: 'cancellationDenied',
  INVOICE_ERROR: 'error',
};

/** Our status for an Asaas invoice (its `status`, else the event name). */
export function mapInvoiceStatus(asaasStatus?: string | null, eventName?: string): InvoiceStatus | null {
  if (asaasStatus && ASAAS_STATUS[asaasStatus]) return ASAAS_STATUS[asaasStatus];
  if (eventName && EVENT_STATUS[eventName]) return EVENT_STATUS[eventName];
  return null;
}

const RANK: Record<InvoiceStatus, number> = {
  creating: 0,
  scheduled: 1,
  synchronized: 2,
  error: 2,
  authorized: 3,
  processingCancellation: 4,
  cancellationDenied: 4,
  canceled: 5,
};

/**
 * Whether `to` may replace `from`. Status only moves forward (late or
 * repeated events never undo an issued or canceled nota); 'canceled' is
 * final; 'error' may move anywhere (the nota was fixed and rescheduled on Asaas).
 */
export function canMoveInvoiceStatus(from: InvoiceStatus, to: InvoiceStatus): boolean {
  if (from === to) return true;
  if (from === 'canceled') return false;
  if (from === 'error') return true;
  return RANK[to] >= RANK[from];
}

export function isActiveInvoice(invoice: Pick<NfseInvoice, 'status' | 'createdAt'>, now: number = Date.now()): boolean {
  if (INACTIVE_STATUSES.includes(invoice.status)) return false;
  if (invoice.status === 'creating') {
    const created = Date.parse(invoice.createdAt || '');
    if (Number.isFinite(created) && now - created > STALE_CREATING_MS) return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// Preconditions and order loading
// ----------------------------------------------------------------------------

/** NFS-e is available: server flag on and Asaas connected. */
export async function assertNfseEnabled(companyId: string): Promise<PaymentSettingsDoc> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.nfseEnabled) {
    throw new AsaasServiceError('NFSE_NOT_ENABLED', 'NFS-e is not enabled for this company');
  }
  if (!settings.asaasConnected) {
    throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
  }
  return settings;
}

export async function getNfseServiceSettings(companyId: string): Promise<NfseServiceSettings | null> {
  const snap = await nfseSettingsRef(companyId).get();
  return snap.exists ? (snap.data() as NfseServiceSettings) : null;
}

interface LoadedOrders {
  orders: Order[];
  parts: Array<InvoiceOrderPart & OrderInvoiceValue>;
  customerId: string;
  customerName: string | null;
  value: number;
}

function uniqueIds(ids: string[]): string[] {
  return [...new Set(ids)];
}

/** Loads the orders, checks they can go into one nota and computes the value. */
export async function loadInvoiceOrders(
  companyId: string,
  orderIds: string[],
  expectedCustomerId?: string,
): Promise<LoadedOrders> {
  const ids = uniqueIds(orderIds);
  if (ids.length === 0 || ids.length > MAX_INVOICE_ORDERS) {
    throw new AsaasServiceError('ORDER_NOT_FOUND', 'Pick between 1 and 50 orders');
  }
  const snaps = await Promise.all(ids.map((id) => companyRef(companyId).collection('orders').doc(id).get()));
  const orders = snaps.map((snap) => {
    if (!snap.exists) throw new AsaasServiceError('ORDER_NOT_FOUND', 'Order not found');
    return { ...(snap.data() as Order), id: snap.id };
  });

  const customerId = expectedCustomerId ?? orders[0].customer?.id;
  if (!customerId) throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order has no customer');
  for (const order of orders) {
    if (order.customer?.id !== customerId) {
      throw new AsaasServiceError('ORDER_NOT_OF_CUSTOMER', 'All orders must belong to the same customer');
    }
    if (order.status === 'quote' || order.status === 'canceled') {
      throw new AsaasServiceError('NFSE_ORDER_NOT_ALLOWED', 'Quotes and canceled orders cannot have a nota');
    }
  }

  // Oldest first, so the description reads in order.
  orders.sort((a, b) => (Number(a.number) || 0) - (Number(b.number) || 0));
  const parts = orders.map((order) => {
    const computed = invoiceValueOfOrder(order);
    if (computed.value <= 0) {
      throw new AsaasServiceError('NO_SERVICES', 'The order has no service value for a nota');
    }
    return { orderId: order.id, orderNumber: order.number ?? null, ...computed };
  });
  const value = roundMoney(parts.reduce((sum, p) => sum + p.value, 0));
  return { orders, parts, customerId, customerName: orders[0].customer?.name ?? null, value };
}

/** Active invoice ids covering each order (via the lock docs). */
async function activeInvoicesOf(companyId: string, orderIds: string[]): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  for (const orderId of orderIds) {
    const lock = await orderLockRef(companyId, orderId).get();
    const invoiceId = lock.data()?.invoiceId as string | undefined;
    if (!invoiceId) continue;
    const invoice = await invoicesRef(companyId).doc(invoiceId).get();
    if (invoice.exists && isActiveInvoice(invoice.data() as NfseInvoice)) result[orderId] = invoiceId;
  }
  return result;
}

function validEffectiveDate(input: string | undefined): string {
  const today = todayInSaoPaulo();
  const date = input ?? today;
  const isCalendar = /^\d{4}-\d{2}-\d{2}$/.test(date) && addDays(date, 0) === date;
  if (!isCalendar || date < today || date > addDays(today, MAX_FUTURE_DAYS)) {
    throw new AsaasServiceError('INVALID_EFFECTIVE_DATE', 'effectiveDate must be between today and 60 days ahead');
  }
  return date;
}

// ----------------------------------------------------------------------------
// Preview
// ----------------------------------------------------------------------------

export interface InvoicePreview {
  value: number;
  orders: Array<InvoiceOrderPart & OrderInvoiceValue>;
  hasProducts: boolean;
  serviceDescription: string;
  observations: string;
  effectiveDate: string;
  customer: { id: string; name: string | null; hasTaxId: boolean };
  /** Orders that already have an active nota (orderId → invoiceId). */
  invoicedOrders: Record<string, string>;
  municipalServiceName: string;
}

export async function previewInvoice(
  companyId: string,
  orderIds: string[],
  expectedCustomerId?: string,
): Promise<InvoicePreview> {
  await assertNfseEnabled(companyId);
  const service = await getNfseServiceSettings(companyId);
  if (!service) throw new AsaasServiceError('NFSE_NOT_READY', 'Set up the nota service first');

  const loaded = await loadInvoiceOrders(companyId, orderIds, expectedCustomerId);
  const customerSnap = await companyRef(companyId).collection('customers').doc(loaded.customerId).get();
  const customer = customerSnap.data() as Customer | undefined;
  const numbers = describeOrderNumbers(loaded.orders.map((o) => o.number));
  return {
    value: loaded.value,
    orders: loaded.parts,
    hasProducts: loaded.parts.some((p) => p.productsTotal > 0),
    serviceDescription: applyDescriptionTemplate(service.descriptionTemplate, describeServices(loaded.orders), numbers),
    observations: numbers,
    effectiveDate: todayInSaoPaulo(),
    customer: {
      id: loaded.customerId,
      name: customer?.name ?? loaded.customerName,
      hasTaxId: !!customer?.taxId,
    },
    invoicedOrders: await activeInvoicesOf(companyId, loaded.orders.map((o) => o.id)),
    municipalServiceName: service.municipalServiceName,
  };
}

// ----------------------------------------------------------------------------
// Create
// ----------------------------------------------------------------------------

/** Applies the Asaas invoice fields to our doc, respecting the status rules. */
export function invoiceUpdateFrom(
  current: NfseInvoice,
  asaas: AsaasInvoice,
  eventName?: string,
): Partial<NfseInvoice> | null {
  const status = mapInvoiceStatus(asaas.status, eventName) ?? current.status;
  if (!canMoveInvoiceStatus(current.status, status)) return null;
  const now = new Date().toISOString();
  const update: Partial<NfseInvoice> = { status, updatedAt: now };
  if (asaas.id && !current.asaasInvoiceId) update.asaasInvoiceId = asaas.id;
  if (asaas.pdfUrl) update.pdfUrl = asaas.pdfUrl;
  if (asaas.xmlUrl) update.xmlUrl = asaas.xmlUrl;
  if (asaas.number) update.number = asaas.number;
  if (asaas.validationCode) update.validationCode = asaas.validationCode;
  update.statusDescription = status === 'error' || status === 'cancellationDenied' ? asaas.statusDescription ?? null : null;
  if (status === 'authorized' && !current.authorizedAt) update.authorizedAt = now;
  if (status === 'canceled' && !current.canceledAt) update.canceledAt = now;
  return update;
}

/** Writes the Asaas state to the invoice doc in a transaction (never moves the status back). */
export async function syncInvoice(
  companyId: string,
  invoiceId: string,
  asaas: AsaasInvoice,
  eventName?: string,
): Promise<{ before: NfseInvoice; after: NfseInvoice } | null> {
  const ref = invoicesRef(companyId).doc(invoiceId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const before = { ...(snap.data() as NfseInvoice), id: snap.id };
    if (before.asaasInvoiceId && asaas.id && before.asaasInvoiceId !== asaas.id) return null;
    const update = invoiceUpdateFrom(before, asaas, eventName);
    if (!update) return { before, after: before };
    tx.update(ref, update as Record<string, unknown>);
    return { before, after: { ...before, ...update } as NfseInvoice };
  });
}

async function releaseLocks(companyId: string, invoiceId: string, orderIds: string[]): Promise<void> {
  await db.runTransaction(async (tx) => {
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    locks.forEach((lock, i) => {
      if (lock.data()?.invoiceId === invoiceId) tx.delete(orderLockRef(companyId, orderIds[i]));
    });
    tx.delete(invoicesRef(companyId).doc(invoiceId));
  });
}

export async function createInvoice(
  companyId: string,
  input: CreateInvoiceInput,
  user: UserAggr,
  expectedCustomerId?: string,
): Promise<NfseInvoice> {
  await assertNfseEnabled(companyId);
  const service = await getNfseServiceSettings(companyId);
  if (!service) throw new AsaasServiceError('NFSE_NOT_READY', 'Set up the nota service first');

  const effectiveDate = validEffectiveDate(input.effectiveDate);
  const loaded = await loadInvoiceOrders(companyId, input.orderIds, expectedCustomerId);
  const orderIds = loaded.orders.map((o) => o.id);

  const customerSnap = await companyRef(companyId).collection('customers').doc(loaded.customerId).get();
  if (!customerSnap.exists) throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order customer not found');
  const customer = { ...(customerSnap.data() as Customer), id: customerSnap.id };
  if (!customer.name) customer.name = loaded.customerName || '';
  const taxId = await resolveTaxId(companyId, customer, input.customerTaxId);

  const client = await getAsaasCredentialProvider().getClient(companyId);
  const asaasCustomerId = await findOrCreateAsaasCustomer(client, companyId, customer, taxId);

  const numbers = describeOrderNumbers(loaded.orders.map((o) => o.number));
  const serviceDescription =
    (input.serviceDescription || '').trim().slice(0, MAX_DESCRIPTION) ||
    applyDescriptionTemplate(service.descriptionTemplate, describeServices(loaded.orders), numbers);

  // 1. Reserve the orders: one active nota per order.
  const invoiceRef = invoicesRef(companyId).doc();
  const now = new Date().toISOString();
  const invoice: NfseInvoice = {
    id: invoiceRef.id,
    status: 'creating',
    customer: { id: customer.id, name: customer.name || null },
    orderIds,
    orders: loaded.parts.map((p) => ({ orderId: p.orderId, orderNumber: p.orderNumber, value: p.value })),
    value: loaded.value,
    serviceDescription,
    observations: numbers,
    effectiveDate,
    municipalServiceName: service.municipalServiceName,
    createdBy: { id: user.id, name: user.name },
    createdAt: now,
  };
  await db.runTransaction(async (tx) => {
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    const lockedIds = locks.map((lock) => lock.data()?.invoiceId as string | undefined);
    const existing = await Promise.all(
      lockedIds.map((id) => (id ? tx.get(invoicesRef(companyId).doc(id)) : Promise.resolve(null))),
    );
    for (const snap of existing) {
      if (snap?.exists && isActiveInvoice(snap.data() as NfseInvoice)) {
        throw new AsaasServiceError('ORDER_HAS_INVOICE', 'An order already has an active nota');
      }
    }
    tx.set(invoiceRef, invoice as unknown as Record<string, unknown>);
    for (const id of orderIds) tx.set(orderLockRef(companyId, id), { invoiceId: invoiceRef.id, updatedAt: now });
  });

  // 2. Schedule it on Asaas (avulsa: tied to the customer, not to a payment).
  const payload: AsaasCreateInvoiceInput = {
    customer: asaasCustomerId,
    serviceDescription,
    observations: numbers,
    externalReference: invoiceExternalReference(companyId, invoiceRef.id),
    value: loaded.value,
    deductions: 0,
    effectiveDate,
    municipalServiceName: service.municipalServiceName,
    taxes: service.taxes,
  };
  // Asaas: send the id OR the code, never both.
  if (service.municipalServiceId) payload.municipalServiceId = service.municipalServiceId;
  else payload.municipalServiceCode = service.municipalServiceCode ?? null;

  let created: AsaasInvoice;
  try {
    created = await client.createInvoice(payload);
  } catch (error) {
    await releaseLocks(companyId, invoiceRef.id, orderIds).catch(() => {
      console.error(`[NFS-e] Could not release invoice ${invoiceRef.id} of company ${companyId}`);
    });
    throw error;
  }

  let result = (await syncInvoice(companyId, invoiceRef.id, created))?.after ?? invoice;

  // 3. Issue now when the date is today (otherwise Asaas issues it on the date).
  if (effectiveDate === todayInSaoPaulo() && created.status === 'SCHEDULED') {
    try {
      const authorized = await client.authorizeInvoice(created.id);
      result = (await syncInvoice(companyId, invoiceRef.id, authorized))?.after ?? result;
    } catch (error) {
      const status = error instanceof AsaasApiError ? error.status : 'unknown';
      console.warn(`[NFS-e] authorize of invoice ${invoiceRef.id} failed (status ${status}); left scheduled`);
    }
  }

  console.log(`[NFS-e] Invoice ${invoiceRef.id} created for ${orderIds.length} order(s) of company ${companyId}`);
  return { ...result, id: invoiceRef.id };
}

// ----------------------------------------------------------------------------
// Cancel
// ----------------------------------------------------------------------------

export async function cancelInvoice(
  companyId: string,
  invoiceId: string,
  onlyOnAsaas = false,
): Promise<NfseInvoice> {
  await assertNfseEnabled(companyId);
  const snap = await invoicesRef(companyId).doc(invoiceId).get();
  if (!snap.exists) throw new AsaasServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
  const invoice = { ...(snap.data() as NfseInvoice), id: snap.id };
  if (!CANCELABLE_STATUSES.includes(invoice.status) || !invoice.asaasInvoiceId) {
    throw new AsaasServiceError('INVOICE_NOT_CANCELABLE', 'This nota cannot be canceled now');
  }

  const client = await getAsaasCredentialProvider().getClient(companyId);
  // An issued nota is canceled at the city; some cities do not allow it through the API.
  if (invoice.status !== 'scheduled' && !onlyOnAsaas) {
    const options = await client.getMunicipalOptions().catch(() => null);
    if (options && options.supportsCancellation === false) {
      throw new AsaasServiceError('CANCEL_NOT_SUPPORTED', 'The city does not cancel notas through the integration');
    }
  }

  const canceled = await client.cancelInvoice(invoice.asaasInvoiceId, onlyOnAsaas);
  const result = await syncInvoice(companyId, invoiceId, canceled);
  return { ...(result?.after ?? invoice), id: invoiceId };
}

// ----------------------------------------------------------------------------
// Order documents (the PDF of an issued nota appears among the OS files)
// ----------------------------------------------------------------------------

export function invoiceDocumentId(invoiceId: string): string {
  return `nfse_${invoiceId}`;
}

/** Adds (authorized) or removes (canceled) the nota PDF on each order. Idempotent. */
export async function syncOrderDocuments(companyId: string, invoice: NfseInvoice): Promise<void> {
  const docId = invoiceDocumentId(invoice.id);
  const attach = invoice.status === 'authorized' && !!invoice.pdfUrl;
  const detach = invoice.status === 'canceled';
  if (!attach && !detach) return;

  for (const orderId of invoice.orderIds) {
    const ref = companyRef(companyId).collection('orders').doc(orderId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const documents = ((snap.data() as { documents?: Array<{ id?: string }> }).documents ?? []) as Array<
        Record<string, unknown>
      >;
      const has = documents.some((d) => d.id === docId);
      if (attach && !has) {
        const number = invoice.number ? ` ${invoice.number}` : '';
        tx.update(ref, {
          documents: [
            ...documents,
            {
              id: docId,
              url: invoice.pdfUrl,
              storagePath: null,
              fileName: `Nota fiscal${number}.pdf`,
              contentType: 'application/pdf',
              type: 'invoice',
              description: invoice.number ? `NFS-e ${invoice.number}` : 'NFS-e',
              createdAt: new Date().toISOString(),
              createdBy: { id: 'system', name: 'PraticOS' },
            },
          ],
        });
      } else if (detach && has) {
        tx.update(ref, { documents: documents.filter((d) => d.id !== docId) });
      }
    });
  }
}

/** Webhook entry: INVOICE_* event for this company. Acknowledged when unknown. */
export async function applyInvoiceEvent(companyId: string, eventName: string, asaas: AsaasInvoice): Promise<void> {
  let invoiceId: string | null = null;
  const parsed = parseInvoiceReference(asaas.externalReference);
  if (parsed) {
    if (parsed.companyId !== companyId) {
      console.warn('[AsaasWebhook] invoice reference belongs to another company', { companyId, event: eventName });
      return;
    }
    invoiceId = parsed.invoiceId;
  } else if (asaas.id) {
    const found = await invoicesRef(companyId).where('asaasInvoiceId', '==', asaas.id).limit(1).get();
    invoiceId = found.docs[0]?.id ?? null;
  }
  if (!invoiceId) {
    // Nota issued outside PraticOS (Asaas panel, payment-linked): not ours.
    console.log('[AsaasWebhook] invoice not from PraticOS, acknowledged', { companyId, event: eventName });
    return;
  }

  const result = await syncInvoice(companyId, invoiceId, asaas, eventName);
  if (!result) {
    console.warn('[AsaasWebhook] invoice not found or other Asaas id, acknowledged', {
      companyId, invoiceId, event: eventName,
    });
    return;
  }
  await syncOrderDocuments(companyId, { ...result.after, id: invoiceId });
}
