/**
 * Automatic nota of a paid charge, through the NFS-e direct of the company
 * that received the money (docs/NFSE_DIRECT.md, "Nota de cobrança paga").
 * First user: the PraticOS plans sold on the web, issued by the company in
 * `config/webCheckout.invoiceIssuerCompanyId` (docs/WEB_CHECKOUT.md). The
 * request is source-agnostic (`charge.source`), so the Asaas charges of the
 * orders can use it later.
 *
 * Two halves, like the automatic nota of an order (auto-issue.service.ts),
 * because only the nfse-api account opens certificates:
 *
 * 1. `requestChargeInvoice` (any account, e.g. the payment webhook) creates
 *    companies/{issuer}/private/nfse/chargeInvoices/{charge.key}. The id is
 *    the charge: the same payment confirmed twice (CONFIRMED, then RECEIVED,
 *    or a webhook retry) finds it there and does nothing.
 *    `requestChargeInvoiceCancel` (the money went back) marks it to cancel.
 * 2. `processChargeInvoice` (nfse-api: the trigger on that document and the
 *    daily sweep) claims it in a transaction, issues the nota, and cancels it
 *    when the cancel was asked.
 *
 * Retry: a failure that may pass (government or key vault down, daily limit,
 * certificate or emitter not ready, anything unexpected) leaves the request
 * in `retry`; the daily sweep tries again, up to MAX_CHARGE_ATTEMPTS, then
 * `failed`. A nota sent without a clear answer stays `creating` and the
 * existing reconcile finishes it (same DPS number). A refusal by the
 * government or a recipient without CPF/CNPJ ends `failed` at once (the
 * refused nota is in the list with the reason). Every `failed` logs an
 * error line: that is the alert to issue it by hand.
 *
 * Logs carry ids and codes only, never the recipient's data.
 */

import { db } from '../firestore.service';
import type { UserAggr } from '../../models/types';
import type { NfseChargeRef } from '../../models/nfse-direct.types';
import { NfseServiceError } from './errors';
import { activeChargeInvoiceId, cancelDirectInvoice, issueDirectChargeInvoice, type ChargeRecipient, type IssueDeps } from './issue.service';

/** Author of the notas the server issues by itself (same as the automatic nota of an order). */
export const CHARGE_INVOICE_USER: UserAggr = { id: 'system', name: 'PraticOS' };

/** Issue attempts before giving up (the first by the trigger, then one per daily sweep). */
export const MAX_CHARGE_ATTEMPTS = 6;

/** A request still `processing` after this was cut short (timeout, crash): the sweep takes it again. */
export const STALE_CHARGE_PROCESSING_MS = 10 * 60 * 1000;

/** Failures that do not pass by trying again. */
const FINAL = new Set(['NFSE_REFUSED', 'RECIPIENT_TAX_ID_REQUIRED', 'VALIDATION_ERROR']);

export type ChargeInvoiceStatus = 'pending' | 'processing' | 'retry' | 'done' | 'failed';
export type ChargeCancelStatus = 'pending' | 'processing' | 'retry' | 'done' | 'failed' | 'notNeeded';

export interface ChargeInvoiceRequest {
  charge: NfseChargeRef;
  /** Company that paid (the subscriber), for the logs and the support. */
  payerCompanyId?: string | null;
  value: number;
  description: string;
  recipient: ChargeRecipient;
  emitterId?: string | null;
  status: ChargeInvoiceStatus;
  attempts: number;
  createdAt: string;
  claimedAt?: string | null;
  lastErrorCode?: string | null;
  invoiceId?: string | null;
  finishedAt?: string | null;
  /** The money went back: the nota is canceled (or never issued). */
  cancel?: {
    status: ChargeCancelStatus;
    reason: 'refund';
    requestedAt: string;
    attempts?: number;
    claimedAt?: string | null;
    lastErrorCode?: string | null;
    finishedAt?: string | null;
  } | null;
}

export interface ChargeInvoiceDeps {
  now: () => Date;
  issue?: Partial<IssueDeps>;
}

const defaults = (override?: Partial<ChargeInvoiceDeps>): ChargeInvoiceDeps => ({ now: () => new Date(), ...override });

/** Firestore id of a charge key (no slashes, bounded). */
export const chargeDocId = (key: string) => key.replace(/\//g, '_').slice(0, 300);

export const chargeInvoicesRef = (companyId: string) =>
  db.collection('companies').doc(companyId).collection('private').doc('nfse').collection('chargeInvoices');
export const chargeInvoiceRef = (companyId: string, key: string) => chargeInvoicesRef(companyId).doc(chargeDocId(key));

export interface ChargeInvoiceInput {
  charge: NfseChargeRef;
  payerCompanyId?: string | null;
  value: number;
  description: string;
  recipient: ChargeRecipient;
  emitterId?: string | null;
}

/** Asks for the nota of a paid charge. Returns false when it was asked before (idempotent). */
export async function requestChargeInvoice(issuerCompanyId: string, input: ChargeInvoiceInput, now: Date = new Date()): Promise<boolean> {
  const request: ChargeInvoiceRequest = {
    charge: { ...input.charge, key: chargeDocId(input.charge.key) },
    payerCompanyId: input.payerCompanyId ?? null,
    value: input.value,
    description: input.description,
    recipient: { name: input.recipient.name, taxId: input.recipient.taxId, email: input.recipient.email ?? null },
    emitterId: input.emitterId ?? null,
    status: 'pending',
    attempts: 0,
    createdAt: now.toISOString(),
  };
  try {
    await chargeInvoiceRef(issuerCompanyId, input.charge.key).create(request as unknown as Record<string, unknown>);
  } catch (error) {
    if ((error as { code?: unknown })?.code === 6) return false;
    throw error;
  }
  console.log(`[nfse-charge] request ${chargeDocId(input.charge.key)} for issuer ${issuerCompanyId}`);
  return true;
}

/**
 * The money of the charge went back. Not issued yet: it never will be
 * (`notNeeded`). Issued: the nfse-api cancels it. Unknown charge: nothing.
 * Idempotent.
 */
export async function requestChargeInvoiceCancel(issuerCompanyId: string, key: string, now: Date = new Date()): Promise<'requested' | 'notNeeded' | 'unknown' | 'already'> {
  const ref = chargeInvoiceRef(issuerCompanyId, key);
  return db.runTransaction(async (tx) => {
    const request = (await tx.get(ref)).data() as ChargeInvoiceRequest | undefined;
    if (!request) return 'unknown';
    if (request.cancel) return 'already';
    const at = now.toISOString();
    // Not issued (and not being issued now): it stops here.
    if (request.status === 'pending' || request.status === 'retry' || request.status === 'failed') {
      tx.update(ref, {
        status: request.status === 'failed' ? 'failed' : 'done',
        finishedAt: request.finishedAt ?? at,
        cancel: { status: 'notNeeded', reason: 'refund', requestedAt: at, finishedAt: at },
      });
      return 'notNeeded';
    }
    // Issued, or being issued: the processor cancels it once it exists.
    tx.update(ref, { cancel: { status: 'pending', reason: 'refund', requestedAt: at, attempts: 0 } });
    return 'requested';
  });
}

type Claimed = ChargeInvoiceRequest & { id: string };

function stale(claimedAt: string | null | undefined, fallback: string, now: Date): boolean {
  return now.getTime() - Date.parse(claimedAt ?? fallback) >= STALE_CHARGE_PROCESSING_MS;
}

async function claimIssue(companyId: string, id: string, now: Date, sweep: boolean): Promise<Claimed | null> {
  const ref = chargeInvoicesRef(companyId).doc(id);
  return db.runTransaction(async (tx) => {
    const request = (await tx.get(ref)).data() as ChargeInvoiceRequest | undefined;
    if (!request) return null;
    const takes =
      request.status === 'pending' ||
      (sweep && request.status === 'retry') ||
      (sweep && request.status === 'processing' && stale(request.claimedAt, request.createdAt, now));
    if (!takes) return null;
    if (request.cancel && request.status !== 'processing') {
      // Refunded while waiting for a retry: no nota. (A run cut short while
      // processing may have issued it: that one goes on, finds it and cancels it.)
      tx.update(ref, {
        status: 'done',
        finishedAt: now.toISOString(),
        'cancel.status': 'notNeeded',
        'cancel.finishedAt': now.toISOString(),
      });
      return null;
    }
    const attempts = (request.attempts ?? 0) + 1;
    tx.update(ref, { status: 'processing', claimedAt: now.toISOString(), attempts });
    return { ...request, id, status: 'processing', attempts };
  });
}

async function claimCancel(companyId: string, id: string, now: Date, sweep: boolean): Promise<Claimed | null> {
  const ref = chargeInvoicesRef(companyId).doc(id);
  return db.runTransaction(async (tx) => {
    const request = (await tx.get(ref)).data() as ChargeInvoiceRequest | undefined;
    const cancel = request?.cancel;
    if (!request || !cancel || request.status !== 'done' || !request.invoiceId) return null;
    const takes =
      cancel.status === 'pending' ||
      (sweep && cancel.status === 'retry') ||
      (sweep && cancel.status === 'processing' && stale(cancel.claimedAt, cancel.requestedAt, now));
    if (!takes) return null;
    const attempts = (cancel.attempts ?? 0) + 1;
    tx.update(ref, { 'cancel.status': 'processing', 'cancel.claimedAt': now.toISOString(), 'cancel.attempts': attempts });
    return { ...request, id, cancel: { ...cancel, status: 'processing', attempts } };
  });
}

const codeOf = (error: unknown): string =>
  error instanceof NfseServiceError ? error.code : String((error as { code?: unknown })?.code ?? (error as Error)?.name ?? 'unknown');

async function issueOne(companyId: string, request: Claimed, deps: ChargeInvoiceDeps): Promise<void> {
  const ref = chargeInvoicesRef(companyId).doc(request.id);
  try {
    const invoice = await issueDirectChargeInvoice(
      companyId,
      { charge: request.charge, value: request.value, description: request.description, recipient: request.recipient, emitterId: request.emitterId },
      CHARGE_INVOICE_USER,
      { auto: true },
      { ...deps.issue, now: deps.now },
    );
    await ref.update({ status: 'done', invoiceId: invoice.id, lastErrorCode: null, finishedAt: deps.now().toISOString() });
    console.log(`[nfse-charge] ${request.id} of issuer ${companyId}: invoice ${invoice.id} (${invoice.status})`);
  } catch (error) {
    const code = codeOf(error);
    if (code === 'CHARGE_HAS_INVOICE') {
      // Issued before (a run cut short after the nota): take that one.
      const invoiceId = ((error as NfseServiceError).details?.invoiceId as string | undefined) ?? null;
      await ref.update({ status: 'done', invoiceId, lastErrorCode: null, finishedAt: deps.now().toISOString() });
      return;
    }
    // The DPS number was reserved before the failure (e.g. the certificate did
    // not open): that nota waits as `creating` and the reconcile sends the same
    // DPS. It is this charge's nota; trying again would only find it.
    const reserved = code === 'NFSE_REFUSED' ? null : await activeChargeInvoiceId(companyId, request.charge.key).catch(() => null);
    if (reserved) {
      await ref.update({ status: 'done', invoiceId: reserved, lastErrorCode: code, finishedAt: deps.now().toISOString() });
      console.warn(`[nfse-charge] ${request.id} of issuer ${companyId}: invoice ${reserved} left creating (${code}); the reconcile finishes it`);
      return;
    }
    const final = FINAL.has(code) || request.attempts >= MAX_CHARGE_ATTEMPTS;
    const refusedId = ((error as NfseServiceError).details?.invoiceId as string | undefined) ?? null;
    await ref.update({
      status: final ? 'failed' : 'retry',
      lastErrorCode: code,
      ...(refusedId ? { invoiceId: refusedId } : {}),
      ...(final ? { finishedAt: deps.now().toISOString() } : {}),
    });
    if (final) {
      console.error(`[nfse-charge] ${request.id} of issuer ${companyId} failed (${code}) after ${request.attempts} attempt(s): issue it by hand`);
    } else {
      console.warn(`[nfse-charge] ${request.id} of issuer ${companyId} not issued (${code}); retry ${request.attempts}/${MAX_CHARGE_ATTEMPTS}`);
    }
  }
}

async function cancelOne(companyId: string, request: Claimed, deps: ChargeInvoiceDeps): Promise<void> {
  const ref = chargeInvoicesRef(companyId).doc(request.id);
  const attempts = request.cancel?.attempts ?? 1;
  const invoiceSnap = await db.collection('companies').doc(companyId).collection('invoices').doc(request.invoiceId!).get();
  const invoice = invoiceSnap.data() as { status?: string } | undefined;
  const at = deps.now().toISOString();
  if (!invoice || invoice.status === 'canceled' || invoice.status === 'error') {
    await ref.update({ 'cancel.status': invoice?.status === 'canceled' ? 'done' : 'notNeeded', 'cancel.finishedAt': at, 'cancel.lastErrorCode': null });
    return;
  }
  if (invoice.status === 'creating') {
    // Still waiting for the government: the reconcile settles it, the sweep cancels after.
    await ref.update({ 'cancel.status': 'retry', 'cancel.lastErrorCode': 'INVOICE_CREATING' });
    return;
  }
  try {
    await cancelDirectInvoice(companyId, request.invoiceId!, 'serviceNotProvided', CHARGE_INVOICE_USER, { ...deps.issue, now: deps.now });
    await ref.update({ 'cancel.status': 'done', 'cancel.finishedAt': deps.now().toISOString(), 'cancel.lastErrorCode': null });
    console.log(`[nfse-charge] ${request.id} of issuer ${companyId}: invoice ${request.invoiceId} canceled (refund)`);
  } catch (error) {
    const code = codeOf(error);
    // Refused (deadline of the city) or not cancelable: only by hand, in the portal.
    const final = code === 'CANCEL_REFUSED' || code === 'INVOICE_NOT_CANCELABLE' || attempts >= MAX_CHARGE_ATTEMPTS;
    await ref.update({
      'cancel.status': final ? 'failed' : 'retry',
      'cancel.lastErrorCode': code,
      ...(final ? { 'cancel.finishedAt': deps.now().toISOString() } : {}),
    });
    if (final) {
      console.error(`[nfse-charge] cancel of ${request.id} (invoice ${request.invoiceId}) of issuer ${companyId} failed (${code}): cancel it by hand`);
    } else {
      console.warn(`[nfse-charge] cancel of ${request.id} of issuer ${companyId} not done (${code}); retry ${attempts}/${MAX_CHARGE_ATTEMPTS}`);
    }
  }
}

/**
 * Issues (and, when asked, cancels) the nota of one request. The trigger
 * passes sweep=false (only `pending` work); the daily sweep passes true (also
 * `retry` and runs cut short). Safe to run twice: every step is claimed.
 */
export async function processChargeInvoice(
  companyId: string,
  id: string,
  override?: Partial<ChargeInvoiceDeps>,
  sweep = false,
): Promise<boolean> {
  const deps = defaults(override);
  let worked = false;
  const issue = await claimIssue(companyId, id, deps.now(), sweep);
  if (issue) {
    worked = true;
    await issueOne(companyId, issue, deps);
  }
  const cancel = await claimCancel(companyId, id, deps.now(), sweep);
  if (cancel) {
    worked = true;
    await cancelOne(companyId, cancel, deps);
  }
  return worked;
}

/** Daily sweep: requests (and cancels) pending, to retry, or cut short. */
export async function processPendingChargeInvoices(companyId: string, override?: Partial<ChargeInvoiceDeps>): Promise<number> {
  const deps = defaults(override);
  const open = ['pending', 'processing', 'retry'];
  const [issues, cancels] = await Promise.all([
    chargeInvoicesRef(companyId).where('status', 'in', open).get(),
    chargeInvoicesRef(companyId).where('cancel.status', 'in', open).get(),
  ]);
  const ids = new Set([...issues.docs, ...cancels.docs].map((doc) => doc.id));
  let processed = 0;
  for (const id of ids) {
    const worked = await processChargeInvoice(companyId, id, deps, true).catch((error) => {
      console.error(`[nfse-charge] sweep of ${id} of issuer ${companyId} failed`, (error as Error)?.name);
      return false;
    });
    if (worked) processed++;
  }
  return processed;
}
