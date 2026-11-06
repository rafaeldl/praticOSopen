/**
 * Import of the notas already issued, the daily reading and the links between
 * notas and orders (issue #569, spec §4.3, §4.7 and §5.6). Runs in the nfseApi:
 * reading the ADN uses the emitter's certificate.
 *
 * Flow:
 * 1. `startImport` (right after the certificate is sent) reads the mailbox
 *    from NSU 0, 50 at a time, for at most ~45 s per call; the app calls
 *    `continueImport` until the batch leaves `reading`. Notas the CNPJ issued
 *    become invoices `source: 'external'` (id `ext-{chave}`, XML in Storage);
 *    cancel events cancel them; notas received get a minimal server-only
 *    record. Nothing about customers or orders changes yet.
 * 2. With the mailbox read, the proposal (import-proposal.ts) goes to
 *    `nfseImports/{batchId}` (`proposed`).
 * 3. `applyImport` ("Importar") fills only what is empty, creates the new
 *    customers, points stores to their CNPJ, links the sure notas to their
 *    orders (locking them) and records everything it did.
 * 4. `undoImport` ("Desfazer importação", 30 days) reverts what is still as
 *    the import left it. The notas stay in the history.
 * 5. `syncEmitterMailbox` (daily) reads from `lastNsu`: notas made on the
 *    portal or elsewhere, cancellations and received notas.
 *
 * Logs carry ids and counts only: never names, CNPJs or the XML.
 */

import type { DocumentData, Query } from 'firebase-admin/firestore';
import { db, FieldValue, storage } from '../firestore.service';
import type { Customer, Order, UserAggr } from '../../models/types';
import { toDate } from '../../models/types';
import type { NfseInvoice } from '../../models/asaas.types';
import type { CustomerFiscalFields, FiscalEmitter, FiscalEmitterPrivate } from '../../models/nfse-direct.types';
import { fiscalEmitterAggr } from '../../models/nfse-direct.types';
import { invoiceValueOfOrder } from '../asaas/invoice.service';
import { todayInSaoPaulo } from '../asaas/charge.service';
import { generateSearchKeywords } from '../../utils/search.utils';
import { loadCertificate, type UsableCertificate } from './certificate-vault.service';
import { getNfseServerConfig, type NfseServerConfig } from './config';
import { NfseServiceError } from './errors';
import { fetchDfePage, parseEvent, parseNfse, type DfeDocument, type ParsedNfse } from './adn-reader';
import {
  buildProposal,
  fillsFor,
  proposeEmitter,
  rankOrdersForNota,
  type ImportCustomer,
  type ImportNota,
  type ImportOrder,
  type ImportProposal,
  type ProposedGroup,
} from './import-proposal';
import { cityUsesNationalIssuer, issRateOf, lookupCnc, lookupCnpj, type CncInfo, type CnpjInfo } from './registry.service';
import { SefinClient, SefinUnavailableError, type Transport } from './sefin-client';
import { emitterTotals, type TotalsInvoice } from './totals';

/** "Desfazer importação" is offered for this long after applying. */
export const UNDO_DAYS = 30;
/** Time spent reading the mailbox per call (the function times out at 120 s). */
export const READ_BUDGET_MS = 45_000;

const SYSTEM_USER: UserAggr = { id: 'system', name: 'PraticOS' };

// ----------------------------------------------------------------------------
// Paths
// ----------------------------------------------------------------------------

const companyRef = (cid: string) => db.collection('companies').doc(cid);
const invoicesRef = (cid: string) => companyRef(cid).collection('invoices');
const customersRef = (cid: string) => companyRef(cid).collection('customers');
const ordersRef = (cid: string) => companyRef(cid).collection('orders');
const emittersRef = (cid: string) => companyRef(cid).collection('fiscalEmitters');
const importsRef = (cid: string) => companyRef(cid).collection('nfseImports');
const privateNfse = (cid: string) => companyRef(cid).collection('private').doc('nfse');
const emitterPrivateRef = (cid: string, emitterId: string) => privateNfse(cid).collection('emitters').doc(emitterId);
const receivedRef = (cid: string, emitterId: string) => emitterPrivateRef(cid, emitterId).collection('received');
/** A cancel event read before its nota: applied when the nota arrives. */
const pendingCancelRef = (cid: string, emitterId: string, key: string) => emitterPrivateRef(cid, emitterId).collection('canceledKeys').doc(key);
const orderLockRef = (cid: string, orderId: string) => privateNfse(cid).collection('orders').doc(orderId);

/** Documents per page when a whole collection is read (see scanFields). */
export const SCAN_PAGE_SIZE = 300;

/**
 * Reads a query page by page and only the given fields. A workshop with years
 * of orders (photos, checklists, history) took the nfseApi past 512 MiB when
 * every order came whole at once; here each page is dropped before the next.
 * `fields` empty reads the ids only.
 */
export async function scanFields(query: Query, fields: string[], visit: (id: string, data: DocumentData) => void, pageSize = SCAN_PAGE_SIZE): Promise<void> {
  const base = query.select(...fields).orderBy('__name__').limit(pageSize);
  let page = await base.get();
  for (;;) {
    for (const d of page.docs) visit(d.id, d.data());
    if (page.size < pageSize) return;
    page = await base.startAfter(page.docs[page.size - 1]).get();
  }
}

export const externalInvoiceId = (accessKey: string) => `ext-${accessKey}`;
const xmlPathOf = (cid: string, invoiceId: string) => `tenants/${cid}/invoices/${invoiceId}/nfse.xml`;

// ----------------------------------------------------------------------------
// Dependencies (tests replace them)
// ----------------------------------------------------------------------------

export interface ImportDeps {
  now: () => Date;
  /** Wall clock for the reading budget. */
  clock: () => number;
  budgetMs: number;
  loadCertificate: (companyId: string, emitterId: string) => Promise<UsableCertificate>;
  config: () => Promise<NfseServerConfig>;
  transport?: Transport;
  saveFile: (path: string, contents: string, contentType: string) => Promise<void>;
  lookupCnpj: (taxId: string) => Promise<CnpjInfo | null>;
  lookupCnc: (client: SefinClient, cityCode: string, taxId: string) => Promise<CncInfo | null>;
  cityUsesNationalIssuer: (client: SefinClient, cityCode: string) => Promise<boolean>;
  issRate: (client: SefinClient, cityCode: string, nationalCode: string, municipalCode: string | null | undefined, date: string) => Promise<number | null>;
}

export function defaultImportDeps(): ImportDeps {
  return {
    now: () => new Date(),
    clock: () => Date.now(),
    budgetMs: READ_BUDGET_MS,
    loadCertificate: (cid, emitterId) => loadCertificate(cid, emitterId, undefined, { purpose: 'import' }),
    config: getNfseServerConfig,
    saveFile: async (path, contents, contentType) => {
      await storage.bucket().file(path).save(contents, { contentType, resumable: false });
    },
    lookupCnpj: (taxId) => lookupCnpj(taxId),
    lookupCnc,
    cityUsesNationalIssuer,
    issRate: issRateOf,
  };
}

const withDeps = (override?: Partial<ImportDeps>): ImportDeps => ({ ...defaultImportDeps(), ...override });

async function assertEnabled(cid: string): Promise<void> {
  const settings = (await companyRef(cid).collection('settings').doc('payments').get()).data();
  if (settings?.nfseDirectEnabled !== true) {
    throw new NfseServiceError('NFSE_DIRECT_NOT_ENABLED', 'NFS-e direct is not enabled for this company');
  }
}

async function readEmitter(cid: string, emitterId: string): Promise<FiscalEmitter> {
  const snap = await emittersRef(cid).doc(emitterId).get();
  if (!snap.exists) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
  return { ...(snap.data() as FiscalEmitter), id: snap.id };
}

async function clientFor(cid: string, emitter: FiscalEmitter, deps: ImportDeps): Promise<SefinClient> {
  const config = await deps.config();
  const cert = await deps.loadCertificate(cid, emitter.id);
  return new SefinClient({ environment: config.environment, keyPem: cert.keyPem, chainPem: cert.chainPem, transport: deps.transport });
}

const NETWORK_CODES = new Set(['ECONNRESET', 'ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND', 'EAI_AGAIN', 'EPIPE', 'ENETUNREACH', 'EHOSTUNREACH', 'ECONNABORTED']);

/** No clear answer from the government (timeout, network, 5xx): worth trying again. */
export function isGovernmentUnavailable(error: unknown): boolean {
  if (error instanceof SefinUnavailableError) return true;
  const e = error as { code?: unknown; message?: unknown } | null;
  if (typeof e?.code === 'string' && NETWORK_CODES.has(e.code)) return true;
  return e?.message === 'timeout';
}

/** What failed, for the log: name, code and message, without long digit runs (CPF/CNPJ, access keys). */
export function describeError(error: unknown): string {
  const e = error as { name?: unknown; code?: unknown; status?: unknown; message?: unknown } | null;
  const code = e?.code ?? e?.status;
  const message = String(e?.message ?? error ?? '').replace(/\d{11,}/g, '…').slice(0, 300);
  return `${String(e?.name ?? 'Error')}${code !== undefined && code !== null ? ` ${String(code)}` : ''}: ${message}`;
}

const clean = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);
const digits = (v: string | null | undefined) => (v ?? '').replace(/[^0-9A-Za-z]/g, '').toUpperCase();
const isActive = (invoice: Pick<NfseInvoice, 'status' | 'conflict'>) => !['error', 'canceled'].includes(invoice.status) && invoice.conflict !== true;

// ----------------------------------------------------------------------------
// Reading the mailbox
// ----------------------------------------------------------------------------

/** What the import needs of an external nota besides the invoice fields. */
export interface ExternalInfo {
  appVersion: string | null;
  regime: string | null;
  simplesOption: number | null;
  simplesTaxRate: number | null;
  municipalRegistration: string | null;
  cityCode: string | null;
  cityName: string | null;
  nationalCode: string | null;
  municipalCode: string | null;
  nbs: string | null;
  serviceName: string | null;
  issRate: number | null;
}

export interface ReadResult {
  done: boolean;
  documents: number;
  created: string[];
  lastNsu: number;
}

interface ReadOptions {
  importBatchId?: string | null;
  /** Daily sync: a new nota goes to the only customer with its CPF/CNPJ. */
  linkCustomers?: boolean;
}

/** Reads the emitter's mailbox from its `lastNsu`, within the time budget. */
export async function readMailbox(
  cid: string,
  emitter: FiscalEmitter,
  client: SefinClient,
  deps: ImportDeps,
  options: ReadOptions = {},
): Promise<ReadResult> {
  const privateRef = emitterPrivateRef(cid, emitter.id);
  let last = Math.max(0, Number(((await privateRef.get()).data() as Partial<FiscalEmitterPrivate> | undefined)?.lastNsu) || 0);
  const deadline = deps.clock() + deps.budgetMs;
  const created: string[] = [];
  let documents = 0;
  let done = false;
  while (deps.clock() < deadline) {
    const page = await fetchDfePage(client, emitter.taxId, last);
    const fresh = page.documents.filter((d) => d.nsu > last);
    for (const doc of fresh) {
      const id = await processDocument(cid, emitter, doc, deps, options);
      if (id) created.push(id);
    }
    documents += fresh.length;
    if (fresh.length > 0) {
      last = fresh[fresh.length - 1].nsu;
      await privateRef.set({ lastNsu: last, lastReadAt: deps.now().toISOString() }, { merge: true });
    }
    if (page.done || fresh.length === 0) {
      done = true;
      break;
    }
  }
  if (done) await privateRef.set({ lastReadAt: deps.now().toISOString() }, { merge: true });
  return { done, documents, created, lastNsu: last };
}

async function processDocument(cid: string, emitter: FiscalEmitter, doc: DfeDocument, deps: ImportDeps, options: ReadOptions): Promise<string | null> {
  if (doc.kind === 'event') {
    const event = parseEvent(doc.xml);
    if (event?.cancels) await applyCancelEvent(cid, emitter, event.accessKey, event.processedAt ?? deps.now().toISOString());
    return null;
  }
  if (doc.kind !== 'nfse') return null;
  const nota = parseNfse(doc.xml);
  if (!nota) return null;
  if (digits(nota.emitter.taxId) === digits(emitter.taxId)) return saveIssued(cid, emitter, nota, doc.xml, deps, options);
  if (nota.recipient && digits(nota.recipient.taxId) === digits(emitter.taxId)) await saveReceived(cid, emitter, nota, doc.nsu, deps);
  return null;
}

async function findInvoiceByKey(cid: string, accessKey: string) {
  const ext = await invoicesRef(cid).doc(externalInvoiceId(accessKey)).get();
  if (ext.exists) return ext;
  const found = await invoicesRef(cid).where('accessKey', '==', accessKey).limit(1).get();
  return found.empty ? null : found.docs[0];
}

async function saveIssued(cid: string, emitter: FiscalEmitter, nota: ParsedNfse, xml: string, deps: ImportDeps, options: ReadOptions): Promise<string | null> {
  // A nota the PraticOS issued (or one already read) is not created again.
  if (await findInvoiceByKey(cid, nota.accessKey)) return null;
  const id = externalInvoiceId(nota.accessKey);
  const pending = await pendingCancelRef(cid, emitter.id, nota.accessKey).get();
  const xmlPath = xmlPathOf(cid, id);
  await deps.saveFile(xmlPath, xml, 'application/xml');
  const at = deps.now().toISOString();
  const processedAt = nota.processedAt ? new Date(nota.processedAt).toISOString() : at;

  let customer: { id: string; name: string | null } | null = null;
  if (options.linkCustomers && nota.recipient) {
    const same = await customersRef(cid).where('taxId', '==', digits(nota.recipient.taxId)).limit(2).get();
    if (same.size === 1) customer = { id: same.docs[0].id, name: (same.docs[0].data().name as string) ?? null };
  }
  const external: ExternalInfo = {
    appVersion: nota.appVersion,
    regime: nota.regime,
    simplesOption: nota.simplesOption,
    simplesTaxRate: nota.simplesTaxRate,
    municipalRegistration: nota.emitter.municipalRegistration,
    cityCode: nota.emitter.address?.cityCode ?? null,
    cityName: nota.cityName,
    nationalCode: nota.service.nationalCode,
    municipalCode: nota.service.municipalCode,
    nbs: nota.service.nbs,
    serviceName: nota.service.name,
    issRate: nota.service.issRate,
  };
  const invoice = {
    id,
    status: pending.exists ? 'canceled' : 'authorized',
    provider: 'direct',
    source: 'external',
    emitter: fiscalEmitterAggr({ ...emitter, regime: emitter.regime ?? nota.regime ?? undefined }),
    recipient: nota.recipient
      ? {
          customerId: customer?.id ?? null,
          taxId: digits(nota.recipient.taxId),
          legalName: nota.recipient.name ?? '',
          address: nota.recipient.address,
          email: nota.recipient.email,
        }
      : null,
    customer,
    orderIds: [],
    orders: [],
    value: nota.value,
    serviceDescription: nota.service.description,
    observations: nota.complementaryInfo ?? '',
    effectiveDate: nota.competenceDate ?? processedAt.slice(0, 10),
    municipalServiceName: nota.service.name ?? '',
    number: nota.number,
    accessKey: nota.accessKey,
    dps: nota.dpsId ? { id: nota.dpsId, series: nota.series ?? '', number: nota.dpsNumber ?? 0 } : null,
    xmlPath,
    external,
    importBatchId: options.importBatchId ?? null,
    createdBy: SYSTEM_USER,
    createdAt: processedAt,
    authorizedAt: processedAt,
    readAt: at,
    ...(pending.exists ? { canceledAt: (pending.data()?.at as string) ?? at } : {}),
  };
  await invoicesRef(cid).doc(id).set(invoice);
  if (pending.exists) await pendingCancelRef(cid, emitter.id, nota.accessKey).delete();
  return id;
}

async function saveReceived(cid: string, emitter: FiscalEmitter, nota: ParsedNfse, nsu: number, deps: ImportDeps) {
  // Minimal record for the later "notas recebidas → despesas" (spec §2, A). Server only.
  const pending = await pendingCancelRef(cid, emitter.id, nota.accessKey).get();
  await receivedRef(cid, emitter.id).doc(String(nsu)).set({
    nsu,
    accessKey: nota.accessKey,
    providerTaxId: digits(nota.emitter.taxId),
    providerName: nota.emitter.name ?? null,
    value: nota.value,
    date: nota.competenceDate,
    status: pending.exists ? 'canceled' : 'issued',
    readAt: deps.now().toISOString(),
  });
  if (pending.exists) await pendingCancelRef(cid, emitter.id, nota.accessKey).delete();
}

async function releaseLocks(cid: string, invoiceId: string, orderIds: string[]) {
  for (const orderId of orderIds) {
    const lock = await orderLockRef(cid, orderId).get();
    if (lock.data()?.invoiceId === invoiceId) await orderLockRef(cid, orderId).delete();
  }
}

/** A nota canceled on the portal (or anywhere): our invoice follows, its orders are free again. */
async function applyCancelEvent(cid: string, emitter: FiscalEmitter, accessKey: string, at: string) {
  const invoice = await findInvoiceByKey(cid, accessKey);
  if (invoice) {
    const data = invoice.data() as NfseInvoice;
    if (data.status === 'canceled') return;
    await invoice.ref.set({ status: 'canceled', canceledAt: new Date(at).toISOString(), canceledOutside: true, updatedAt: new Date().toISOString() }, { merge: true });
    await releaseLocks(cid, invoice.id, data.orderIds ?? []);
    return;
  }
  const received = await receivedRef(cid, emitter.id).where('accessKey', '==', accessKey).limit(1).get();
  if (!received.empty) {
    await received.docs[0].ref.set({ status: 'canceled' }, { merge: true });
    return;
  }
  await pendingCancelRef(cid, emitter.id, accessKey).set({ at });
}

async function recalcTotals(cid: string, emitterId: string, deps: ImportDeps) {
  const today = todayInSaoPaulo(deps.now());
  const snap = await invoicesRef(cid)
    .where('emitter.id', '==', emitterId)
    .where('effectiveDate', '>=', `${today.slice(0, 4)}-01-01`)
    .select('status', 'value', 'effectiveDate')
    .get();
  await emittersRef(cid).doc(emitterId).set({ totals: emitterTotals(snap.docs.map((d) => d.data() as TotalsInvoice), today) }, { merge: true });
}

// ----------------------------------------------------------------------------
// Import: read, propose
// ----------------------------------------------------------------------------

export interface ImportBatchDoc {
  id: string;
  emitterId: string;
  status: 'reading' | 'proposed' | 'applied' | 'undone' | 'failed';
  createdAt: string;
  createdBy: UserAggr;
  read: { documents: number; lastNsu: number };
  proposal?: ImportProposal | null;
  /** CNC: enabled to issue in the city (null when the lookup failed). */
  enabledInCity?: boolean | null;
  proposedAt?: string | null;
  answers?: ImportAnswers | null;
  applied?: AppliedRecord | null;
  appliedAt?: string | null;
  appliedBy?: UserAggr | null;
  expiresAt?: string | null;
  undoneAt?: string | null;
  undoneBy?: UserAggr | null;
  undo?: { customersDeleted: number; customersKept: number } | null;
  updatedAt?: string;
}

/** Starts (or continues) the import of the emitter's notas. Owner and admin (route). */
export async function startImport(cid: string, emitterId: string, user: UserAggr, override?: Partial<ImportDeps>): Promise<ImportBatchDoc> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const emitter = await readEmitter(cid, emitterId);
  if (emitter.certificate?.status !== 'active') throw new NfseServiceError('CERT_NOT_FOUND', 'Emitter has no certificate');
  const open = await importsRef(cid).where('emitterId', '==', emitterId).get();
  const running = open.docs.find((d) => ['reading', 'proposed'].includes(d.data().status as string));
  if (running) return continueImport(cid, running.id, override);

  const ref = importsRef(cid).doc();
  const batch: ImportBatchDoc = {
    id: ref.id,
    emitterId,
    status: 'reading',
    createdAt: deps.now().toISOString(),
    createdBy: user,
    read: { documents: 0, lastNsu: 0 },
  };
  await ref.set(batch as unknown as Record<string, unknown>);
  console.log(`[nfse-import] batch ${ref.id} of company ${cid} started`);
  return continueImport(cid, ref.id, override);
}

async function readBatch(cid: string, batchId: string): Promise<ImportBatchDoc> {
  const snap = await importsRef(cid).doc(batchId).get();
  if (!snap.exists) throw new NfseServiceError('IMPORT_NOT_FOUND', 'Import not found');
  return { ...(snap.data() as ImportBatchDoc), id: snap.id };
}

/** Reads more of the mailbox; with it all read, builds the proposal. */
export async function continueImport(cid: string, batchId: string, override?: Partial<ImportDeps>): Promise<ImportBatchDoc> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const batch = await readBatch(cid, batchId);
  if (batch.status !== 'reading') return batch;
  const emitter = await readEmitter(cid, batch.emitterId);
  const client = await clientFor(cid, emitter, deps);
  const ref = importsRef(cid).doc(batchId);
  let result: ReadResult;
  try {
    result = await readMailbox(cid, emitter, client, deps, { importBatchId: batchId });
  } catch (error) {
    // What was read stays: the next call goes on from the last NSU saved.
    if (isGovernmentUnavailable(error)) {
      console.warn(`[nfse-import] batch ${batchId} of company ${cid} paused, government unavailable (${describeError(error)})`);
      throw new NfseServiceError('SEFIN_UNAVAILABLE', 'The government did not answer; try again');
    }
    console.error(`[nfse-import] batch ${batchId} of company ${cid} failed (${describeError(error)})`);
    throw new NfseServiceError('IMPORT_FAILED', 'The notas could not be imported');
  }
  const read = { documents: (batch.read?.documents ?? 0) + result.documents, lastNsu: result.lastNsu };
  if (!result.done) {
    await ref.set({ read, updatedAt: deps.now().toISOString() }, { merge: true });
    return { ...batch, read };
  }
  await recalcTotals(cid, emitter.id, deps).catch(() => undefined);
  const { proposal, enabledInCity } = await prepareProposal(cid, emitter, client, deps);
  const update = { read, status: 'proposed' as const, proposal, enabledInCity, proposedAt: deps.now().toISOString(), updatedAt: deps.now().toISOString() };
  await ref.set(update, { merge: true });
  console.log(`[nfse-import] batch ${batchId} of company ${cid} proposed (${proposal.counts.notas} notas, ${proposal.counts.customers} customers)`);
  return { ...batch, ...update };
}

function notaOf(doc: { id: string; data: () => unknown }): ImportNota {
  const inv = doc.data() as NfseInvoice & { external?: ExternalInfo; dps?: { series?: string } };
  const ext = inv.external;
  return {
    invoiceId: doc.id,
    canceled: inv.status === 'canceled',
    date: inv.effectiveDate ?? null,
    value: Number(inv.value) || 0,
    recipient: inv.recipient
      ? { taxId: inv.recipient.taxId, legalName: inv.recipient.legalName || null, address: inv.recipient.address ?? null, email: inv.recipient.email ?? null }
      : null,
    series: inv.dps?.series ?? null,
    description: inv.serviceDescription ?? '',
    service: {
      nationalCode: ext?.nationalCode ?? null,
      municipalCode: ext?.municipalCode ?? null,
      nbs: ext?.nbs ?? null,
      name: ext?.serviceName ?? null,
      issRate: ext?.issRate ?? null,
    },
    regime: ext?.regime === 'mei' || ext?.regime === 'simples' ? ext.regime : null,
    simplesOption: ext?.simplesOption ?? null,
    simplesTaxRate: ext?.simplesTaxRate ?? null,
    municipalRegistration: ext?.municipalRegistration ?? null,
    cityCode: ext?.cityCode ?? null,
    cityName: ext?.cityName ?? null,
    linked: (inv.orderIds ?? []).length > 0,
  };
}

function orderDate(order: Order): string | null {
  const done = order.completedAt ? new Date(order.completedAt) : null;
  const date = done && !Number.isNaN(done.getTime()) ? done : toDate(order.createdAt);
  return date ? todayInSaoPaulo(date) : null;
}

/** Orders and customers of the company in the shape the proposal reads. */
async function loadCompanyData(cid: string): Promise<{ customers: ImportCustomer[]; orders: ImportOrder[] }> {
  const locked = new Set<string>();
  await scanFields(privateNfse(cid).collection('orders'), [], (id) => locked.add(id));
  const customers: ImportCustomer[] = [];
  await scanFields(customersRef(cid), CUSTOMER_FIELDS, (id, data) => {
    const c = data as Customer & CustomerFiscalFields;
    customers.push({
      id,
      name: c.name ?? '',
      taxId: c.taxId ?? null,
      legalName: c.legalName ?? null,
      fiscalAddress: c.fiscalAddress ?? null,
      invoiceEmail: c.invoiceEmail ?? null,
      email: c.email ?? null,
      invoiceRecipient: c.invoiceRecipient ?? null,
    });
  });
  const orders: ImportOrder[] = [];
  await scanFields(ordersRef(cid), ORDER_FIELDS, (id, data) => {
    const o = data as Order;
    if (o.status === 'quote' || o.status === 'canceled') return;
    orders.push({
      id,
      number: typeof o.number === 'number' ? o.number : null,
      customerId: o.customer?.id ?? null,
      customerName: o.customer?.name ?? null,
      value: invoiceValueOfOrder(o).value,
      date: orderDate(o),
      done: o.status === 'done',
      locked: locked.has(id),
    });
  });
  return { customers, orders };
}

/** What the proposal reads of each customer, order and imported nota. */
const CUSTOMER_FIELDS = ['name', 'taxId', 'legalName', 'fiscalAddress', 'invoiceEmail', 'email', 'invoiceRecipient'];
const ORDER_FIELDS = ['status', 'number', 'customer.id', 'customer.name', 'services', 'products', 'discount', 'completedAt', 'createdAt'];
const NOTA_FIELDS = ['source', 'status', 'effectiveDate', 'value', 'recipient', 'dps.series', 'serviceDescription', 'external', 'orderIds'];

async function prepareProposal(cid: string, emitter: FiscalEmitter, client: SefinClient, deps: ImportDeps): Promise<{ proposal: ImportProposal; enabledInCity: boolean | null }> {
  const notas: ImportNota[] = [];
  await scanFields(invoicesRef(cid).where('emitter.id', '==', emitter.id), NOTA_FIELDS, (id, data) => {
    if ((data as NfseInvoice).source === 'external') notas.push(notaOf({ id, data: () => data }));
  });
  const { customers, orders } = await loadCompanyData(cid);
  // Customers and order links come from every nota; the emitter data (service, regime,
  // description style, series) only from the recent ones (3 months or the 10 newest).
  const proposal = buildProposal({ emitter, notas, customers, orders });
  proposal.emitter = proposeEmitter(emitter, recentNotas(notas).notas);
  const fill = proposal.emitter.fill;
  const today = todayInSaoPaulo(deps.now());

  // A CNPJ without notas: regime and city from the public CNPJ data.
  if ((!emitter.regime && !fill.regime) || (!emitter.cityCode && !fill.cityCode)) {
    const info = await deps.lookupCnpj(emitter.taxId).catch(() => null);
    if (info) {
      if (!emitter.regime && !fill.regime && info.regime) fill.regime = info.regime;
      if (!emitter.cityCode && !fill.cityCode && info.cityCode) fill.cityCode = info.cityCode;
      if (!emitter.cityName && !fill.cityName && info.cityName) fill.cityName = info.cityName;
    }
  }
  const cityCode = emitter.cityCode || fill.cityCode;
  let enabledInCity: boolean | null = null;
  if (cityCode) {
    const cnc = await deps.lookupCnc(client, cityCode, emitter.taxId).catch(() => null);
    if (cnc) {
      enabledInCity = cnc.enabledInCity;
      // The CNC decides the IM (E0116 × E0120): only send what it has.
      if (!emitter.municipalRegistration) {
        if (cnc.municipalRegistration) fill.municipalRegistration = cnc.municipalRegistration;
        else delete fill.municipalRegistration;
      }
    } else {
      const adherent = await deps.cityUsesNationalIssuer(client, cityCode).catch(() => null);
      // Without the CNC, recent notas on the national issuer are enough evidence.
      if (adherent === false) enabledInCity = false;
      else if (notas.some((n) => !n.canceled && n.date && n.date >= addDays(today, -90))) enabledInCity = true;
    }
    if (fill.service && !(fill.service.issRate > 0)) {
      const rate = await deps.issRate(client, cityCode, fill.service.nationalCode, fill.service.municipalCode, today).catch(() => null);
      if (rate !== null) fill.service.issRate = rate;
    }
  }
  proposal.emitter.view = {
    ...proposal.emitter.view,
    regime: emitter.regime ?? fill.regime ?? null,
    municipalRegistration: emitter.municipalRegistration ?? fill.municipalRegistration ?? null,
    service: emitter.service ?? fill.service ?? null,
  };
  return { proposal, enabledInCity };
}

/** The emitter data comes from the notas of the 3 months before the newest one... */
export const RECENT_NOTA_DAYS = 90;
/** ...or, when they are fewer, the 10 newest. */
export const RECENT_NOTA_MIN = 10;

/** The recent notas (3 months from the newest, at least the 10 newest) and the date they start. */
export function recentNotas(notas: ImportNota[]): { notas: ImportNota[]; since: string | null } {
  const dated = notas.filter((n) => n.date).sort((a, b) => (a.date! < b.date! ? 1 : a.date! > b.date! ? -1 : 0));
  if (dated.length === 0) return { notas, since: null };
  const window = addDays(dated[0].date!, -RECENT_NOTA_DAYS);
  const tenth = dated[Math.min(RECENT_NOTA_MIN, dated.length) - 1].date!;
  const since = tenth < window ? tenth : window;
  return { notas: notas.filter((n) => !n.date || n.date >= since), since };
}

function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

// ----------------------------------------------------------------------------
// Apply ("Importar")
// ----------------------------------------------------------------------------

export interface ImportAnswers {
  /** "Este é o mesmo cliente?" per group key: true = yes; false or absent = create another. */
  sameCustomer?: Record<string, boolean>;
  /** "Emitir sozinha" turned on for these customers (nothing comes on by itself). */
  autoIssueCustomerIds?: string[];
}

export interface AppliedRecord {
  createdCustomerIds: string[];
  filled: Array<{ customerId: string; values: Record<string, unknown> }>;
  recipients: Array<{ customerId: string; targetId: string }>;
  invoiceCustomers: Array<{ invoiceId: string; customerId: string }>;
  links: Array<{ invoiceId: string; orderId: string }>;
  autoIssue: string[];
  emitterFields: string[];
  defaultEmitter: boolean;
}

function groupData(g: ProposedGroup) {
  return { taxId: g.taxId, legalName: g.legalName, address: g.address, email: g.email };
}

/** Links one nota to one order in a transaction; false when the order already has an active nota. */
async function linkTx(cid: string, invoiceId: string, orderId: string, by: UserAggr, at: string): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const invoiceRef = invoicesRef(cid).doc(invoiceId);
    const [invoiceSnap, orderSnap, lockSnap] = await Promise.all([tx.get(invoiceRef), tx.get(ordersRef(cid).doc(orderId)), tx.get(orderLockRef(cid, orderId))]);
    if (!invoiceSnap.exists || !orderSnap.exists) return false;
    const invoice = invoiceSnap.data() as NfseInvoice;
    if (!isActive(invoice) || (invoice.orderIds ?? []).length > 0) return false;
    const lockedBy = lockSnap.data()?.invoiceId as string | undefined;
    if (lockedBy && lockedBy !== invoiceId) {
      const other = await tx.get(invoicesRef(cid).doc(lockedBy));
      if (other.exists && isActive(other.data() as NfseInvoice)) return false;
    }
    const order = orderSnap.data() as Order;
    tx.set(
      invoiceRef,
      {
        orderIds: [orderId],
        orders: [{ orderId, orderNumber: order.number ?? null, value: invoiceValueOfOrder(order).value }],
        customer: order.customer?.id ? { id: order.customer.id, name: order.customer.name ?? null } : invoice.customer ?? null,
        linkedBy: by,
        linkedAt: at,
        updatedAt: at,
      },
      { merge: true },
    );
    tx.set(orderLockRef(cid, orderId), { invoiceId, updatedAt: at });
    return true;
  });
}

async function companyAggr(cid: string) {
  const data = (await companyRef(cid).get()).data() ?? {};
  return { id: cid, name: (data.name as string) ?? '' };
}

/** Applies the proposal with the owner's answers. Owner and admin (route). */
export async function applyImport(cid: string, batchId: string, answers: ImportAnswers, user: UserAggr, override?: Partial<ImportDeps>): Promise<ImportBatchDoc> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const batch = await readBatch(cid, batchId);
  if (batch.status !== 'proposed' || !batch.proposal) throw new NfseServiceError('IMPORT_NOT_READY', 'The import is not waiting to be applied');
  const proposal = batch.proposal;
  const at = deps.now().toISOString();
  const applied: AppliedRecord = { createdCustomerIds: [], filled: [], recipients: [], invoiceCustomers: [], links: [], autoIssue: [], emitterFields: [], defaultEmitter: false };
  const company = await companyAggr(cid);

  for (const group of proposal.groups) {
    const yes = group.action === 'complete' || (group.action === 'ask' && answers.sameCustomer?.[group.key] === true);
    let targetId: string | null = null;
    let targetName: string = group.legalName;
    let existing = false;

    if (yes && group.customerId) {
      const snap = await customersRef(cid).doc(group.customerId).get();
      if (snap.exists) {
        existing = true;
        targetId = snap.id;
        const current = snap.data() as ImportCustomer;
        targetName = current.name || group.legalName;
        const values: Record<string, unknown> = {};
        for (const field of fillsFor({ ...current, id: snap.id }, groupData(group))) {
          values[field] = field === 'taxId' ? group.taxId : field === 'legalName' ? group.legalName : field === 'fiscalAddress' ? group.address : group.email;
        }
        if (Object.keys(values).length > 0) {
          await snap.ref.set({ ...values, updatedAt: at, updatedBy: user }, { merge: true });
          applied.filled.push({ customerId: snap.id, values });
        }
      }
    }
    if (!targetId) {
      // A CPF/CNPJ someone saved meanwhile is not duplicated.
      const same = await customersRef(cid).where('taxId', '==', group.taxId).limit(1).get();
      if (!same.empty) {
        targetId = same.docs[0].id;
        targetName = (same.docs[0].data().name as string) || group.legalName;
      } else {
        const ref = customersRef(cid).doc();
        await ref.set({
          name: group.legalName,
          nameLower: group.legalName.toLowerCase(),
          keywords: generateSearchKeywords(group.legalName),
          taxId: group.taxId,
          legalName: group.legalName,
          fiscalAddress: group.address ?? null,
          invoiceEmail: group.email ?? null,
          email: null,
          phone: null,
          company,
          createdAt: at,
          createdBy: user,
          importBatchId: batchId,
        });
        targetId = ref.id;
        applied.createdCustomerIds.push(ref.id);
      }
    }

    // Stores billed on this CNPJ: "Nota fiscal para" → the target.
    if (existing) {
      for (const store of group.stores) {
        const snap = await customersRef(cid).doc(store.customerId).get();
        const current = snap.data() as ImportCustomer | undefined;
        if (!current || clean(current.taxId) || current.invoiceRecipient?.id) continue;
        await snap.ref.set({ invoiceRecipient: { id: targetId, name: targetName }, updatedAt: at, updatedBy: user }, { merge: true });
        applied.recipients.push({ customerId: store.customerId, targetId });
      }
    }

    for (const invoiceId of group.invoiceIds) {
      const ref = invoicesRef(cid).doc(invoiceId);
      const snap = await ref.get();
      const inv = snap.data() as NfseInvoice | undefined;
      if (!inv || inv.recipient?.customerId) continue;
      await ref.set({ customer: inv.customer?.id ? inv.customer : { id: targetId, name: targetName }, recipient: { customerId: targetId }, updatedAt: at }, { merge: true });
      applied.invoiceCustomers.push({ invoiceId, customerId: targetId });
    }

    if (existing) {
      for (const link of group.links) {
        if (await linkTx(cid, link.invoiceId, link.orderId, user, at)) applied.links.push({ invoiceId: link.invoiceId, orderId: link.orderId });
      }
    }
  }

  // "Emitir sozinha" only for the customers the owner turned on, among the suggested.
  const suggested = new Set(proposal.autoIssue.map((s) => s.customerId));
  for (const customerId of answers.autoIssueCustomerIds ?? []) {
    if (!suggested.has(customerId)) continue;
    const snap = await customersRef(cid).doc(customerId).get();
    if (!snap.exists || snap.data()?.autoIssueInvoice === true) continue;
    await snap.ref.set({ autoIssueInvoice: true, updatedAt: at, updatedBy: user }, { merge: true });
    applied.autoIssue.push(customerId);
  }

  // Emitter: only what is still empty.
  const emitterRef = emittersRef(cid).doc(batch.emitterId);
  const emitter = (await emitterRef.get()).data() as Partial<FiscalEmitter> | undefined;
  const emitterUpdate: Record<string, unknown> = { importBatchId: batchId, updatedAt: at };
  for (const [field, value] of Object.entries(proposal.emitter.fill)) {
    const current = (emitter as Record<string, unknown> | undefined)?.[field];
    if (current === undefined || current === null || current === '') {
      emitterUpdate[field] = value;
      applied.emitterFields.push(field);
    }
  }
  if (batch.enabledInCity !== null && batch.enabledInCity !== undefined) emitterUpdate.enabledInCity = batch.enabledInCity;
  await emitterRef.set(emitterUpdate, { merge: true });

  const settingsRef = companyRef(cid).collection('settings').doc('nfse');
  const settings = (await settingsRef.get()).data() ?? {};
  const settingsUpdate: Record<string, unknown> = {};
  if (!settings.defaultEmitterId) {
    settingsUpdate.defaultEmitterId = batch.emitterId;
    applied.defaultEmitter = true;
  }
  if (!settings.provider) settingsUpdate.provider = 'direct';
  if (Object.keys(settingsUpdate).length > 0) await settingsRef.set({ ...settingsUpdate, updatedAt: at }, { merge: true });

  const expiresAt = new Date(deps.now().getTime() + UNDO_DAYS * 86_400_000).toISOString();
  const update = { status: 'applied' as const, answers, applied, appliedAt: at, appliedBy: user, expiresAt, updatedAt: at };
  await importsRef(cid).doc(batchId).set(update, { merge: true });
  console.log(
    `[nfse-import] batch ${batchId} of company ${cid} applied (${applied.createdCustomerIds.length} created, ${applied.filled.length} filled, ${applied.links.length} linked)`,
  );
  return { ...batch, ...update };
}

// ----------------------------------------------------------------------------
// Undo ("Desfazer importação")
// ----------------------------------------------------------------------------

const same = (a: unknown, b: unknown) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

/** Reverts what is still as the import left it. Owner and admin (route). */
export async function undoImport(cid: string, batchId: string, user: UserAggr, override?: Partial<ImportDeps>): Promise<ImportBatchDoc> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const batch = await readBatch(cid, batchId);
  if (batch.status !== 'applied' || !batch.applied) throw new NfseServiceError('IMPORT_NOT_READY', 'Only an applied import can be undone');
  if (!batch.expiresAt || deps.now().toISOString() > batch.expiresAt) throw new NfseServiceError('IMPORT_UNDO_EXPIRED', 'The import can no longer be undone');
  const applied = batch.applied;
  const at = deps.now().toISOString();

  // 1. Notas off the orders the import linked.
  for (const link of applied.links) {
    const ref = invoicesRef(cid).doc(link.invoiceId);
    const inv = (await ref.get()).data() as NfseInvoice | undefined;
    if (!inv || !(inv.orderIds ?? []).includes(link.orderId)) continue;
    await ref.set({ orderIds: [], orders: [], updatedAt: at }, { merge: true });
    await releaseLocks(cid, link.invoiceId, [link.orderId]);
  }
  // 2. Notas off the customers.
  for (const item of applied.invoiceCustomers) {
    const ref = invoicesRef(cid).doc(item.invoiceId);
    const inv = (await ref.get()).data() as NfseInvoice | undefined;
    if (!inv || inv.recipient?.customerId !== item.customerId) continue;
    await ref.set({ customer: (inv.orderIds ?? []).length > 0 ? inv.customer : null, recipient: { customerId: null }, updatedAt: at }, { merge: true });
  }
  // 3. "Nota fiscal para", "Emitir sozinha" and the filled fields, when unchanged since.
  for (const item of applied.recipients) {
    const ref = customersRef(cid).doc(item.customerId);
    const c = (await ref.get()).data() as ImportCustomer | undefined;
    if (c?.invoiceRecipient?.id === item.targetId) await ref.update({ invoiceRecipient: FieldValue.delete(), updatedAt: at });
  }
  for (const customerId of applied.autoIssue) {
    const ref = customersRef(cid).doc(customerId);
    if ((await ref.get()).data()?.autoIssueInvoice === true) await ref.update({ autoIssueInvoice: FieldValue.delete(), updatedAt: at });
  }
  for (const item of applied.filled) {
    const ref = customersRef(cid).doc(item.customerId);
    const c = (await ref.get()).data() as Record<string, unknown> | undefined;
    if (!c) continue;
    const update: Record<string, unknown> = {};
    for (const [field, value] of Object.entries(item.values)) if (same(c[field], value)) update[field] = FieldValue.delete();
    if (Object.keys(update).length > 0) await ref.update({ ...update, updatedAt: at });
  }
  // 4. Customers the import created, unless they got orders since.
  let customersDeleted = 0;
  let customersKept = 0;
  for (const customerId of applied.createdCustomerIds) {
    const orders = await ordersRef(cid).where('customer.id', '==', customerId).limit(1).get();
    if (!orders.empty) {
      customersKept++;
      continue;
    }
    const pointing = await customersRef(cid).where('invoiceRecipient.id', '==', customerId).get();
    for (const p of pointing.docs) await p.ref.update({ invoiceRecipient: FieldValue.delete(), updatedAt: at });
    await customersRef(cid).doc(customerId).delete();
    customersDeleted++;
  }
  // The emitter keeps its configuration (and stays the default): it is needed to issue.
  const emitterRef = emittersRef(cid).doc(batch.emitterId);
  if ((await emitterRef.get()).data()?.importBatchId === batchId) await emitterRef.set({ importBatchId: null, updatedAt: at }, { merge: true });

  const update = { status: 'undone' as const, undoneAt: at, undoneBy: user, undo: { customersDeleted, customersKept }, updatedAt: at };
  await importsRef(cid).doc(batchId).set(update, { merge: true });
  console.log(`[nfse-import] batch ${batchId} of company ${cid} undone (${customersDeleted} deleted, ${customersKept} kept)`);
  return { ...batch, ...update };
}

// ----------------------------------------------------------------------------
// "Ligar a uma OS" and "Desligar da OS" (§4.7)
// ----------------------------------------------------------------------------

async function readInvoice(cid: string, invoiceId: string): Promise<NfseInvoice> {
  const snap = await invoicesRef(cid).doc(invoiceId).get();
  if (!snap.exists) throw new NfseServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
  return { ...(snap.data() as NfseInvoice), id: snap.id };
}

export interface LinkCandidate {
  id: string;
  number: number | null;
  customerId: string | null;
  customerName: string | null;
  value: number;
  date: string | null;
  hasNota: boolean;
  sameCustomer: boolean;
}

/** Orders for "Ligar a uma OS": of the same customer (and its stores) first, similar value and date first. */
export async function linkCandidates(cid: string, invoiceId: string): Promise<LinkCandidate[]> {
  await assertEnabled(cid);
  const invoice = await readInvoice(cid, invoiceId);
  const customerIds = [invoice.customer?.id, invoice.recipient?.customerId].filter((id): id is string => !!id);
  for (const id of [...customerIds]) {
    const stores = await customersRef(cid).where('invoiceRecipient.id', '==', id).get();
    stores.docs.forEach((d) => customerIds.push(d.id));
  }
  const { orders } = await loadCompanyData(cid);
  const ranked = rankOrdersForNota({ value: Number(invoice.value) || 0, date: invoice.effectiveDate ?? null, customerIds }, orders);
  return ranked.slice(0, 40).map((o) => ({
    id: o.id,
    number: o.number,
    customerId: o.customerId,
    customerName: o.customerName,
    value: o.value,
    date: o.date,
    hasNota: o.locked,
    sameCustomer: !!o.customerId && customerIds.includes(o.customerId),
  }));
}

/** "Ligar a uma OS": a direct nota without orders gets one; the order is then locked. */
export async function linkInvoiceToOrder(cid: string, invoiceId: string, orderId: string, user: UserAggr, override?: Partial<ImportDeps>): Promise<NfseInvoice> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const invoice = await readInvoice(cid, invoiceId);
  if (invoice.provider !== 'direct' || !isActive(invoice)) throw new NfseServiceError('INVOICE_NOT_LINKABLE', 'Only an issued direct nota can be linked');
  if ((invoice.orderIds ?? []).length > 0) throw new NfseServiceError('INVOICE_HAS_ORDER', 'The nota is already linked to an order');
  const order = (await ordersRef(cid).doc(orderId).get()).data() as Order | undefined;
  if (!order) throw new NfseServiceError('ORDER_NOT_FOUND', 'Order not found');
  if (order.status === 'quote' || order.status === 'canceled') throw new NfseServiceError('ORDER_NOT_ALLOWED', 'Quotes and canceled orders cannot have a nota');
  const linked = await linkTx(cid, invoiceId, orderId, user, deps.now().toISOString());
  if (!linked) throw new NfseServiceError('ORDER_HAS_INVOICE', 'The order already has an active nota');
  return readInvoice(cid, invoiceId);
}

/** "Desligar da OS": only notas made outside the PraticOS (a link the import or someone made). */
export async function unlinkInvoice(cid: string, invoiceId: string, user: UserAggr, override?: Partial<ImportDeps>): Promise<NfseInvoice> {
  const deps = withDeps(override);
  await assertEnabled(cid);
  const invoice = await readInvoice(cid, invoiceId);
  if (invoice.provider !== 'direct' || invoice.source !== 'external') throw new NfseServiceError('INVOICE_NOT_LINKABLE', 'Only notas made outside the PraticOS can be unlinked');
  const orderIds = invoice.orderIds ?? [];
  if (orderIds.length === 0) return invoice;
  const at = deps.now().toISOString();
  const recipientId = invoice.recipient?.customerId ?? null;
  await invoicesRef(cid).doc(invoiceId).set(
    {
      orderIds: [],
      orders: [],
      customer: recipientId ? { id: recipientId, name: invoice.recipient?.legalName ?? null } : invoice.customer ?? null,
      unlinkedBy: user,
      unlinkedAt: at,
      updatedAt: at,
    },
    { merge: true },
  );
  await releaseLocks(cid, invoiceId, orderIds);
  return readInvoice(cid, invoiceId);
}

// ----------------------------------------------------------------------------
// Daily reading
// ----------------------------------------------------------------------------

/** Daily: every emitter with a valid certificate reads its mailbox from `lastNsu`. */
export async function syncCompanyMailboxes(cid: string, override?: Partial<ImportDeps>): Promise<number> {
  const deps = withDeps(override);
  const today = todayInSaoPaulo(deps.now());
  const emitters = await emittersRef(cid).get();
  let read = 0;
  for (const doc of emitters.docs) {
    const emitter = { ...(doc.data() as FiscalEmitter), id: doc.id };
    if (emitter.certificate?.status !== 'active' || (emitter.certificate.notAfter ?? '').slice(0, 10) < today) continue;
    try {
      const client = await clientFor(cid, emitter, deps);
      const result = await readMailbox(cid, emitter, client, deps, { linkCustomers: true });
      read += result.documents;
      if (result.documents > 0) await recalcTotals(cid, emitter.id, deps);
    } catch (error) {
      console.warn(`[nfse-sync] emitter ${emitter.id} of company ${cid} not read (${describeError(error)})`);
    }
  }
  return read;
}
