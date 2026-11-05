/**
 * Issuing and canceling notas directly in the national system (issue #563,
 * spec §5.2–5.5 and §5.7). Every function here runs in the nfseApi (the only
 * account that opens certificates).
 *
 * Numbering and idempotency (§5.3):
 * - The DPS number comes from companies/{cid}/private/nfse/emitters/{id}.nextDpsNumber,
 *   reserved in the same transaction that creates the `creating` invoice and
 *   locks its orders. The DPS id is deterministic (city + CNPJ + series + number).
 * - No clear answer (timeout, 5xx, network): the invoice stays `creating`.
 *   `reconcileDirectInvoice` asks GET /dps/{id}: it exists → saved as issued;
 *   it does not → the SAME DPS (same number) is sent again. A number is never
 *   skipped nor repeated.
 * - A refusal (the government answered with errors) leaves the invoice in
 *   `error` with its code; that number belongs to the refused DPS and is not reused.
 *
 * Logs carry codes and ids only: never the XML, the certificate or customer data.
 */

import { db, storage } from '../firestore.service';
import { refreshDanfse } from './danfse.service';
import type { Customer, UserAggr } from '../../models/types';
import type { NfseInvoice } from '../../models/asaas.types';
import type {
  CustomerFiscalFields,
  FiscalAddress,
  FiscalEmitter,
  FiscalEmitterPrivate,
  NfseCancelReason,
  NfseRecipient,
} from '../../models/nfse-direct.types';
import { fiscalEmitterAggr } from '../../models/nfse-direct.types';
import { loadInvoiceOrders, type LoadedOrders } from '../asaas/invoice.service';
import { todayInSaoPaulo } from '../asaas/charge.service';
import { loadCertificate, type UsableCertificate } from './certificate-vault.service';
import { getNfseServerConfig, type NfseServerConfig } from './config';
import { complementaryInfo, describeOrdersForNota } from './description';
import { brasiliaTimestamps, buildCancelEvent, buildDps, dpsId, layoutFor } from './dps';
import { NfseServiceError } from './errors';
import type { DpsInput } from './layouts/types';
import { explainRefusal, refusalLog, type Refusal } from './refusals';
import { leafOf, signXml } from './signature';
import { SefinClient, SefinUnavailableError, type IssueResult, type Transport } from './sefin-client';
import { emitterTotals, meiWarning, type MeiWarning, type TotalsInvoice } from './totals';

/** A `creating` nota older than this is checked with the government. */
export const RECONCILE_AFTER_MS = 3 * 60 * 1000;
const MAX_DESCRIPTION = 2000;

type DirectInvoice = NfseInvoice & { refusal?: Refusal | null };
type CustomerDoc = Customer & CustomerFiscalFields & { id: string };

// ----------------------------------------------------------------------------
// Paths
// ----------------------------------------------------------------------------

const companyRef = (companyId: string) => db.collection('companies').doc(companyId);
const invoicesRef = (companyId: string) => companyRef(companyId).collection('invoices');
const emittersRef = (companyId: string) => companyRef(companyId).collection('fiscalEmitters');
const privateNfse = (companyId: string) => companyRef(companyId).collection('private').doc('nfse');
const emitterPrivateRef = (companyId: string, emitterId: string) => privateNfse(companyId).collection('emitters').doc(emitterId);
const orderLockRef = (companyId: string, orderId: string) => privateNfse(companyId).collection('orders').doc(orderId);
/** What the DPS was built from, to send the same one again (server only). */
const dpsSnapshotRef = (companyId: string, invoiceId: string) => privateNfse(companyId).collection('dps').doc(invoiceId);

export const nfseXmlPath = (companyId: string, invoiceId: string) => `tenants/${companyId}/invoices/${invoiceId}/nfse.xml`;
const cancelXmlPath = (companyId: string, invoiceId: string) => `tenants/${companyId}/invoices/${invoiceId}/cancelamento.xml`;

// ----------------------------------------------------------------------------
// Dependencies (tests replace them)
// ----------------------------------------------------------------------------

export interface IssueDeps {
  now: () => Date;
  loadCertificate: (companyId: string, emitterId: string) => Promise<UsableCertificate>;
  config: () => Promise<NfseServerConfig>;
  /** Transport of the government client; tests answer with recorded fixtures. */
  transport?: Transport;
  saveFile: (path: string, contents: string, contentType: string) => Promise<void>;
  /** Makes the PDF after issuing or canceling (best effort; tests replace it). */
  refreshPdf: (companyId: string, invoiceId: string) => Promise<void>;
}

export function defaultIssueDeps(): IssueDeps {
  return {
    now: () => new Date(),
    loadCertificate: (companyId, emitterId) => loadCertificate(companyId, emitterId),
    config: getNfseServerConfig,
    saveFile: async (path, contents, contentType) => {
      await storage.bucket().file(path).save(contents, { contentType, resumable: false });
    },
    refreshPdf: (companyId, invoiceId) => refreshDanfse(companyId, invoiceId),
  };
}

function withDeps(override?: Partial<IssueDeps>): IssueDeps {
  return { ...defaultIssueDeps(), ...override };
}

// ----------------------------------------------------------------------------
// Rules
// ----------------------------------------------------------------------------

const INACTIVE = ['error', 'canceled'];

export function isActiveDirectInvoice(invoice: Pick<NfseInvoice, 'status' | 'conflict'>): boolean {
  return !INACTIVE.includes(invoice.status) && invoice.conflict !== true;
}

export async function assertDirectEnabled(companyId: string): Promise<void> {
  const settings = (await companyRef(companyId).collection('settings').doc('payments').get()).data();
  if (settings?.nfseDirectEnabled !== true) {
    throw new NfseServiceError('NFSE_DIRECT_NOT_ENABLED', 'NFS-e direct is not enabled for this company');
  }
}

/** Why the emitter cannot issue now, or null when it can. */
export function emitterProblem(emitter: Partial<FiscalEmitter>, today: string): string | null {
  const cert = emitter.certificate;
  if (!cert || cert.status !== 'active') return 'certificate';
  if (cert.notAfter && cert.notAfter.slice(0, 10) < today) return 'certificateExpired';
  if (!emitter.enabledInCity) return 'notEnabledInCity';
  if (!emitter.cityCode || !/^\d{7}$/.test(emitter.cityCode)) return 'city';
  if (!emitter.service?.nationalCode) return 'service';
  if (!emitter.dpsSeries) return 'series';
  if (emitter.regime !== 'mei' && emitter.regime !== 'simples') return 'regime';
  return null;
}

/**
 * Emitter of a nota (decision 3): the one asked for, else the last used for
 * this customer, else the company's default, else the only one.
 */
export async function chooseEmitter(
  companyId: string,
  customer: Pick<CustomerFiscalFields, 'lastEmitterId'> | null,
  requestedId?: string | null,
): Promise<FiscalEmitter> {
  const read = async (id: string | null | undefined) => {
    if (!id) return null;
    const snap = await emittersRef(companyId).doc(id).get();
    return snap.exists ? ({ ...(snap.data() as FiscalEmitter), id: snap.id } as FiscalEmitter) : null;
  };
  if (requestedId) {
    const emitter = await read(requestedId);
    if (!emitter) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    return emitter;
  }
  const settings = (await companyRef(companyId).collection('settings').doc('nfse').get()).data();
  const marked = (await read(customer?.lastEmitterId)) ?? (await read(settings?.defaultEmitterId as string | undefined));
  if (marked) return marked;
  const all = await emittersRef(companyId).limit(2).get();
  if (all.size === 1) return { ...(all.docs[0].data() as FiscalEmitter), id: all.docs[0].id };
  throw new NfseServiceError('EMITTER_NOT_FOUND', 'Pick the emitter of the nota');
}

async function readCustomer(companyId: string, id: string | null | undefined): Promise<CustomerDoc | null> {
  if (!id) return null;
  const snap = await companyRef(companyId).collection('customers').doc(id).get();
  return snap.exists ? ({ ...(snap.data() as CustomerDoc), id: snap.id } as CustomerDoc) : null;
}

/** Data typed in the sheet for a recipient that lacks it. */
export interface RecipientInput {
  /** Send to another customer only in this nota. */
  customerId?: string | null;
  taxId?: string | null;
  legalName?: string | null;
  address?: FiscalAddress | null;
  email?: string | null;
}

const clean = (v: string | null | undefined) => (typeof v === 'string' && v.trim() ? v.trim() : null);
const onlyDigits = (v: string | null | undefined) => (v ?? '').replace(/\D/g, '');

/**
 * The recipient (§4.6): "Nota fiscal para" of the order's customer, else the
 * customer itself; the sheet may point to another customer or type data.
 * Typed data fills the customer only where it is empty, like today.
 */
export async function resolveRecipient(
  companyId: string,
  orderCustomer: CustomerDoc,
  input: RecipientInput | null | undefined,
): Promise<{ recipient: NfseRecipient; customer: CustomerDoc | null }> {
  const target =
    (input?.customerId ? await readCustomer(companyId, input.customerId) : null) ??
    (orderCustomer.invoiceRecipient?.id ? await readCustomer(companyId, orderCustomer.invoiceRecipient.id) : null) ??
    orderCustomer;

  const taxId = onlyDigits(clean(target.taxId) ?? input?.taxId);
  if (taxId.length !== 11 && taxId.length !== 14) {
    throw new NfseServiceError('RECIPIENT_TAX_ID_REQUIRED', 'The recipient needs a CPF or CNPJ');
  }
  const recipient: NfseRecipient = {
    customerId: target.id,
    taxId,
    legalName: clean(target.legalName) ?? clean(input?.legalName) ?? clean(target.name) ?? '',
    address: target.fiscalAddress ?? input?.address ?? null,
    email: clean(target.invoiceEmail) ?? clean(target.email) ?? clean(input?.email),
  };
  if (!recipient.legalName) throw new NfseServiceError('RECIPIENT_TAX_ID_REQUIRED', 'The recipient needs a name');

  // Fill only what is empty on the customer (never overwrite what someone typed).
  const fill: Record<string, unknown> = {};
  if (!clean(target.taxId) && input?.taxId) fill.taxId = taxId;
  if (!clean(target.legalName) && clean(input?.legalName)) fill.legalName = clean(input?.legalName);
  if (!target.fiscalAddress && input?.address) fill.fiscalAddress = input.address;
  if (!clean(target.invoiceEmail) && !clean(target.email) && clean(input?.email)) fill.invoiceEmail = clean(input?.email);
  if (Object.keys(fill).length > 0) {
    await companyRef(companyId).collection('customers').doc(target.id).set(fill, { merge: true });
  }
  return { recipient, customer: target };
}

// ----------------------------------------------------------------------------
// Preview (what the sheet shows)
// ----------------------------------------------------------------------------

export interface DirectPreviewInput {
  orderIds: string[];
  emitterId?: string | null;
}

export interface DirectPreview {
  value: number;
  orders: LoadedOrders['parts'];
  hasProducts: boolean;
  description: string;
  complementaryInfo: string;
  emitter: { id: string; legalName: string; taxId: string; regime: string | undefined; problem: string | null };
  emitters: Array<{ id: string; legalName: string; taxId: string; regime: string | undefined; problem: string | null }>;
  recipient: { customerId: string; legalName: string | null; taxId: string | null; viaInvoiceRecipient: boolean };
  missing: Array<'taxId' | 'address' | 'email'>;
  meiWarning: MeiWarning;
  invoicedOrders: Record<string, string>;
}

export async function previewDirectInvoice(companyId: string, input: DirectPreviewInput, override?: Partial<IssueDeps>): Promise<DirectPreview> {
  const deps = withDeps(override);
  await assertDirectEnabled(companyId);
  const loaded = await loadInvoiceOrders(companyId, input.orderIds);
  const customer = await readCustomer(companyId, loaded.customerId);
  if (!customer) throw new NfseServiceError('RECIPIENT_TAX_ID_REQUIRED', 'Order customer not found');
  const emitter = await chooseEmitter(companyId, customer, input.emitterId);
  const today = todayInSaoPaulo(deps.now());
  const config = await deps.config();

  const target = customer.invoiceRecipient?.id ? (await readCustomer(companyId, customer.invoiceRecipient.id)) ?? customer : customer;
  const missing: DirectPreview['missing'] = [];
  const taxId = onlyDigits(target.taxId);
  if (taxId.length !== 11 && taxId.length !== 14) missing.push('taxId');
  if (!target.fiscalAddress) missing.push('address');
  if (!clean(target.invoiceEmail) && !clean(target.email)) missing.push('email');

  const all = await emittersRef(companyId).get();
  const summary = (e: FiscalEmitter) => ({
    id: e.id,
    legalName: e.legalName,
    taxId: e.taxId,
    regime: e.regime,
    problem: emitterProblem(e, today),
  });
  const invoicedOrders: Record<string, string> = {};
  for (const orderId of loaded.orders.map((o) => o.id)) {
    const invoiceId = (await orderLockRef(companyId, orderId).get()).data()?.invoiceId as string | undefined;
    if (!invoiceId) continue;
    const invoice = (await invoicesRef(companyId).doc(invoiceId).get()).data() as NfseInvoice | undefined;
    if (invoice && isActiveDirectInvoice(invoice)) invoicedOrders[orderId] = invoiceId;
  }

  return {
    value: loaded.value,
    orders: loaded.parts,
    hasProducts: loaded.parts.some((p) => p.productsTotal > 0),
    description: describeOrdersForNota(loaded.orders, emitter.descriptionStyle).slice(0, MAX_DESCRIPTION),
    complementaryInfo: complementaryInfo(loaded.orders.map((o) => o.number)),
    emitter: summary(emitter),
    emitters: all.docs.map((d) => summary({ ...(d.data() as FiscalEmitter), id: d.id })),
    recipient: {
      customerId: target.id,
      legalName: clean(target.legalName) ?? clean(target.name),
      taxId: taxId || null,
      viaInvoiceRecipient: target.id !== customer.id,
    },
    missing,
    meiWarning: meiWarning(emitter.regime, emitter.totals, loaded.value, today, config.meiAnnualLimit),
    invoicedOrders,
  };
}

// ----------------------------------------------------------------------------
// Issue
// ----------------------------------------------------------------------------

export interface IssueDirectInput {
  orderIds: string[];
  emitterId?: string | null;
  /** Edited in the sheet; only for this nota. */
  description?: string | null;
  recipient?: RecipientInput | null;
}

export interface IssueOptions {
  auto?: boolean;
}

/**
 * Issues one nota for [input.orderIds] (one customer). Resolves with the
 * invoice: `authorized` (the usual: ~0.5 s), or `creating` when the
 * government gave no clear answer (the reconcile finishes it). A refusal
 * throws NFSE_REFUSED with the plain-words refusal in `details`.
 */
export async function issueDirectInvoice(
  companyId: string,
  input: IssueDirectInput,
  user: UserAggr,
  options: IssueOptions = {},
  override?: Partial<IssueDeps>,
): Promise<DirectInvoice> {
  const deps = withDeps(override);
  await assertDirectEnabled(companyId);
  const now = deps.now();
  const today = todayInSaoPaulo(now);

  const loaded = await loadInvoiceOrders(companyId, input.orderIds);
  const orderIds = loaded.orders.map((o) => o.id);
  const customer = await readCustomer(companyId, loaded.customerId);
  if (!customer) throw new NfseServiceError('RECIPIENT_TAX_ID_REQUIRED', 'Order customer not found');

  const emitter = await chooseEmitter(companyId, customer, input.emitterId);
  const problem = emitterProblem(emitter, today);
  if (problem) {
    throw new NfseServiceError(problem === 'certificateExpired' ? 'CERT_EXPIRED' : 'EMITTER_NOT_READY', `Emitter cannot issue (${problem})`, {
      problem,
      emitterId: emitter.id,
    });
  }
  const { recipient } = await resolveRecipient(companyId, customer, input.recipient);

  // Stale `creating` notas of these orders are settled first, so the lock check sees the truth.
  for (const orderId of orderIds) {
    const invoiceId = (await orderLockRef(companyId, orderId).get()).data()?.invoiceId as string | undefined;
    if (invoiceId) await reconcileDirectInvoice(companyId, invoiceId, deps).catch(() => undefined);
  }

  const description =
    (input.description ?? '').trim().slice(0, MAX_DESCRIPTION) ||
    describeOrdersForNota(loaded.orders, emitter.descriptionStyle).slice(0, MAX_DESCRIPTION);
  const info = complementaryInfo(loaded.orders.map((o) => o.number));
  const config = await deps.config();
  const series = String(emitter.dpsSeries);

  const invoiceRef = invoicesRef(companyId).doc();
  const createdAt = now.toISOString();
  const base = {
    id: invoiceRef.id,
    status: 'creating' as const,
    provider: 'direct' as const,
    source: 'praticos' as const,
    emitter: fiscalEmitterAggr(emitter),
    recipient,
    customer: { id: customer.id, name: customer.name || null },
    orderIds,
    orders: loaded.parts.map((p) => ({ orderId: p.orderId, orderNumber: p.orderNumber, value: p.value })),
    value: loaded.value,
    serviceDescription: description,
    observations: info,
    effectiveDate: today,
    municipalServiceName: emitter.service?.name ?? '',
    createdBy: { id: user.id, name: user.name },
    createdAt,
    ...(options.auto ? { auto: true } : {}),
  };

  // 1. Reserve the DPS number and the orders in one transaction.
  const reserved = await db.runTransaction(async (tx) => {
    const counterRef = emitterPrivateRef(companyId, emitter.id);
    const counter = (await tx.get(counterRef)).data() as Partial<FiscalEmitterPrivate> | undefined;
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    const lockedIds = locks.map((lock) => lock.data()?.invoiceId as string | undefined);
    const existing = await Promise.all(lockedIds.map((id) => (id ? tx.get(invoicesRef(companyId).doc(id)) : Promise.resolve(null))));
    for (const snap of existing) {
      if (snap?.exists && isActiveDirectInvoice(snap.data() as NfseInvoice)) {
        throw new NfseServiceError('ORDER_HAS_INVOICE', 'An order already has an active nota');
      }
    }
    const number = Math.max(1, Math.floor(Number(counter?.nextDpsNumber) || 1));
    const id = dpsId(emitter.cityCode, emitter.taxId, series, number);
    const invoice = { ...base, dps: { id, series, number } };
    tx.set(counterRef, { nextDpsNumber: number + 1, updatedAt: createdAt }, { merge: true });
    tx.set(invoiceRef, invoice as unknown as Record<string, unknown>);
    for (const orderId of orderIds) tx.set(orderLockRef(companyId, orderId), { invoiceId: invoiceRef.id, updatedAt: createdAt });
    const snapshot: Omit<DpsInput, 'issuedAt' | 'competenceDate' | 'environment' | 'appVersion'> = {
      series,
      number,
      emitter: {
        taxId: emitter.taxId,
        cityCode: emitter.cityCode,
        municipalRegistration: emitter.municipalRegistration ?? null,
        regime: emitter.regime,
        simplesOption: emitter.simplesOption ?? null,
      },
      recipient: { taxId: recipient.taxId, legalName: recipient.legalName, address: recipient.address ?? null, email: recipient.email ?? null },
      service: {
        nationalCode: emitter.service!.nationalCode,
        municipalCode: emitter.service?.municipalCode ?? null,
        nbs: emitter.service?.nbs ?? null,
        description,
      },
      value: loaded.value,
      simplesTaxRate: emitter.service?.simplesTaxRate ?? null,
      complementaryInfo: info,
    };
    tx.set(dpsSnapshotRef(companyId, invoiceRef.id), { emitterId: emitter.id, dps: snapshot, createdAt });
    return invoice;
  });

  // 2. Sign and send.
  return sendDps(companyId, emitter.id, invoiceRef.id, reserved as DirectInvoice, config, deps, customer.id);
}

async function sendDps(
  companyId: string,
  emitterId: string,
  invoiceId: string,
  invoice: DirectInvoice,
  config: NfseServerConfig,
  deps: IssueDeps,
  orderCustomerId?: string,
): Promise<DirectInvoice> {
  const snapshot = (await dpsSnapshotRef(companyId, invoiceId).get()).data() as { dps: Omit<DpsInput, 'issuedAt' | 'competenceDate' | 'environment' | 'appVersion'> };
  const cert = await deps.loadCertificate(companyId, emitterId);
  const client = new SefinClient({ environment: config.environment, keyPem: cert.keyPem, chainPem: cert.chainPem, transport: deps.transport });
  const stamp = brasiliaTimestamps(deps.now());
  const input: DpsInput = { ...snapshot.dps, ...stamp, environment: config.environment, appVersion: config.appVersion };
  const { id, xml } = buildDps(input, layoutFor(config.environment, config.layoutByEnvironment, input.competenceDate));
  if (id !== invoice.dps?.id) throw new Error('DPS id changed between reservation and send');
  const signed = signXml(xml, cert.keyPem, leafOf(cert.chainPem), 'infDPS', 'DPS');

  let result: IssueResult;
  try {
    result = await client.issue(signed);
  } catch (error) {
    if (error instanceof SefinUnavailableError) {
      console.warn(`[nfse] issue of invoice ${invoiceId} of company ${companyId} unknown (${error.status ?? 'no answer'}); kept creating`);
      await invoicesRef(companyId).doc(invoiceId).update({ lastAttemptAt: deps.now().toISOString() });
      return { ...invoice, status: 'creating' };
    }
    throw error;
  }
  return applyIssueResult(companyId, emitterId, invoiceId, invoice, result, deps, orderCustomerId);
}

async function applyIssueResult(
  companyId: string,
  emitterId: string,
  invoiceId: string,
  invoice: DirectInvoice,
  result: IssueResult,
  deps: IssueDeps,
  orderCustomerId?: string,
): Promise<DirectInvoice> {
  const at = deps.now().toISOString();
  if (result.kind === 'refused') {
    const refusal = explainRefusal(result.errors, result.status);
    console.warn(`[nfse] invoice ${invoiceId} of company ${companyId} refused (${refusalLog(result.errors)})`);
    const update = {
      status: 'error' as const,
      errorCode: refusal.code,
      refusal,
      statusDescription: refusal.govText,
      updatedAt: at,
    };
    await invoicesRef(companyId).doc(invoiceId).update(update);
    await releaseLocks(companyId, invoiceId, invoice.orderIds);
    throw new NfseServiceError('NFSE_REFUSED', 'The government refused the nota', { refusal, invoiceId });
  }

  const xmlPath = nfseXmlPath(companyId, invoiceId);
  await deps.saveFile(xmlPath, result.nfseXml, 'application/xml');
  const update = {
    status: 'authorized' as const,
    accessKey: result.accessKey,
    number: result.number,
    xmlPath,
    authorizedAt: at,
    updatedAt: at,
    errorCode: null,
    refusal: null,
  };
  await invoicesRef(companyId).doc(invoiceId).update(update);
  console.log(`[nfse] invoice ${invoiceId} of company ${companyId} issued (nº ${result.number ?? '?'})`);
  // Decision 3: the issue sheet marks this emitter first for this customer next time.
  const customerId = orderCustomerId ?? invoice.customer?.id;
  if (customerId) {
    await companyRef(companyId).collection('customers').doc(customerId).set({ lastEmitterId: emitterId }, { merge: true }).catch(() => undefined);
  }
  await recalcEmitterTotals(companyId, emitterId, deps).catch((error) => {
    console.error(`[nfse] totals of emitter ${emitterId} not updated`, (error as Error)?.name);
  });
  await deps.refreshPdf(companyId, invoiceId);
  return { ...invoice, ...update } as DirectInvoice;
}

async function releaseLocks(companyId: string, invoiceId: string, orderIds: string[]): Promise<void> {
  await db.runTransaction(async (tx) => {
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    locks.forEach((lock, i) => {
      if (lock.data()?.invoiceId === invoiceId) tx.delete(orderLockRef(companyId, orderIds[i]));
    });
  });
}

// ----------------------------------------------------------------------------
// Reconcile (no clear answer before)
// ----------------------------------------------------------------------------

/**
 * Settles a `creating` direct nota older than 3 minutes (or any, when
 * [force]): asks the government whether the DPS became a nota; if it did,
 * saves it; if not, sends the same DPS again. Returns the invoice as it ends.
 */
export async function reconcileDirectInvoice(
  companyId: string,
  invoiceId: string,
  override?: Partial<IssueDeps>,
  force = false,
): Promise<DirectInvoice | null> {
  const deps = withDeps(override);
  const snap = await invoicesRef(companyId).doc(invoiceId).get();
  if (!snap.exists) return null;
  const invoice = { ...(snap.data() as DirectInvoice), id: snap.id };
  if (invoice.provider !== 'direct' || invoice.status !== 'creating' || !invoice.dps || !invoice.emitter) return invoice;
  const last = Date.parse((invoice as { lastAttemptAt?: string }).lastAttemptAt ?? invoice.createdAt);
  if (!force && deps.now().getTime() - last < RECONCILE_AFTER_MS) return invoice;

  const config = await deps.config();
  const cert = await deps.loadCertificate(companyId, invoice.emitter.id);
  const client = new SefinClient({ environment: config.environment, keyPem: cert.keyPem, chainPem: cert.chainPem, transport: deps.transport });
  let accessKey: string | null;
  try {
    accessKey = await client.accessKeyOfDps(invoice.dps.id);
  } catch (error) {
    if (error instanceof SefinUnavailableError) return invoice;
    throw error;
  }
  if (accessKey) {
    const xml = await client.nfseXml(accessKey).catch(() => null);
    if (!xml) return invoice;
    const number = xml.match(/<nNFSe>([^<]+)<\/nNFSe>/)?.[1] ?? null;
    return applyIssueResult(companyId, invoice.emitter.id, invoiceId, invoice, { kind: 'issued', accessKey, nfseXml: xml, number, alerts: [] }, deps);
  }
  // The DPS never arrived: the same one (same number) goes again.
  return sendDps(companyId, invoice.emitter.id, invoiceId, invoice, config, deps).catch((error) => {
    if (error instanceof NfseServiceError && error.code === 'NFSE_REFUSED') return null;
    throw error;
  });
}

/** Daily/periodic check of every stale `creating` direct nota of a company. */
export async function reconcileStaleDirectInvoices(companyId: string, override?: Partial<IssueDeps>): Promise<number> {
  const deps = withDeps(override);
  const creating = await invoicesRef(companyId).where('status', '==', 'creating').get();
  let settled = 0;
  for (const doc of creating.docs) {
    if ((doc.data() as NfseInvoice).provider !== 'direct') continue;
    const after = await reconcileDirectInvoice(companyId, doc.id, deps).catch(() => null);
    if (after && after.status !== 'creating') settled++;
  }
  return settled;
}

// ----------------------------------------------------------------------------
// Cancel
// ----------------------------------------------------------------------------

export async function cancelDirectInvoice(
  companyId: string,
  invoiceId: string,
  reason: NfseCancelReason,
  user: UserAggr,
  override?: Partial<IssueDeps>,
): Promise<DirectInvoice> {
  const deps = withDeps(override);
  await assertDirectEnabled(companyId);
  const snap = await invoicesRef(companyId).doc(invoiceId).get();
  if (!snap.exists) throw new NfseServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
  const invoice = { ...(snap.data() as DirectInvoice), id: snap.id };
  if (invoice.provider !== 'direct' || !invoice.emitter || !invoice.accessKey) {
    throw new NfseServiceError('INVOICE_NOT_CANCELABLE', 'Only issued direct notas can be canceled here');
  }
  if (invoice.status !== 'authorized' && invoice.status !== 'cancellationDenied') {
    throw new NfseServiceError('INVOICE_NOT_CANCELABLE', 'The nota is not issued');
  }

  const config = await deps.config();
  const cert = await deps.loadCertificate(companyId, invoice.emitter.id);
  const client = new SefinClient({ environment: config.environment, keyPem: cert.keyPem, chainPem: cert.chainPem, transport: deps.transport });
  const { issuedAt } = brasiliaTimestamps(deps.now());
  const event = buildCancelEvent({
    environment: config.environment,
    appVersion: config.appVersion,
    accessKey: invoice.accessKey,
    authorTaxId: invoice.emitter.taxId,
    reason,
    issuedAt,
  });
  const signed = signXml(event.xml, cert.keyPem, leafOf(cert.chainPem), 'infPedReg', 'pedRegEvento');

  let result;
  try {
    result = await client.registerEvent(invoice.accessKey, signed);
  } catch (error) {
    if (error instanceof SefinUnavailableError) {
      throw new NfseServiceError('SEFIN_UNAVAILABLE', 'The government did not answer; try again');
    }
    throw error;
  }
  const at = deps.now().toISOString();
  if (result.kind === 'refused') {
    const refusal = explainRefusal(result.errors, result.status);
    console.warn(`[nfse] cancel of invoice ${invoiceId} of company ${companyId} refused (${refusalLog(result.errors)})`);
    await invoicesRef(companyId).doc(invoiceId).update({ status: 'cancellationDenied', refusal, updatedAt: at });
    // Deadline and rule are the city's: the portal may still accept it.
    throw new NfseServiceError('CANCEL_REFUSED', 'The government refused the cancellation', { refusal, usePortal: true });
  }

  await deps.saveFile(cancelXmlPath(companyId, invoiceId), result.eventXml, 'application/xml');
  const update = {
    status: 'canceled' as const,
    cancelReason: reason,
    canceledAt: at,
    canceledBy: { id: user.id, name: user.name },
    updatedAt: at,
  };
  await invoicesRef(companyId).doc(invoiceId).update(update);
  await releaseLocks(companyId, invoiceId, invoice.orderIds ?? []);
  await recalcEmitterTotals(companyId, invoice.emitter.id, deps).catch(() => undefined);
  // The PDF now needs the "CANCELADA" watermark (NT 008, item 2.5.1).
  await deps.refreshPdf(companyId, invoiceId);
  console.log(`[nfse] invoice ${invoiceId} of company ${companyId} canceled`);
  return { ...invoice, ...update };
}

// ----------------------------------------------------------------------------
// Totals
// ----------------------------------------------------------------------------

/** Recomputes `totals` of the emitter from its notas of the year (any source). */
export async function recalcEmitterTotals(companyId: string, emitterId: string, override?: Partial<IssueDeps>): Promise<void> {
  const deps = withDeps(override);
  const today = todayInSaoPaulo(deps.now());
  const snap = await invoicesRef(companyId)
    .where('emitter.id', '==', emitterId)
    .where('effectiveDate', '>=', `${today.slice(0, 4)}-01-01`)
    .get();
  const invoices = snap.docs.map((d) => d.data() as TotalsInvoice);
  await emittersRef(companyId).doc(emitterId).set({ totals: emitterTotals(invoices, today) }, { merge: true });
}

