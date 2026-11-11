/**
 * Automatic nota of the NFS-e direct when an order is done (issue #571,
 * spec §5.8). Two halves, because only the nfse-api account opens certificates:
 *
 * 1. `requestDirectAutoIssue` runs in the order trigger (default account, no
 *    certificate): when the order became `done` and the company's rule says
 *    so, it creates `companies/{cid}/private/nfse/autoIssue/{orderId}`. The id
 *    is the order: a second trigger run, or the order done again after being
 *    reopened, finds it there and does nothing (once per order).
 * 2. `processDirectAutoIssue` runs in the nfse-api account (`nfseAutoIssue`,
 *    the trigger on that document, and the daily sweep): claims the request,
 *    issues the nota like the issue sheet would (the decision-3 emitter, the
 *    sheet's description and value) and, when it cannot, leaves the reason on
 *    the order as an `auto-{orderId}` invoice in `error`.
 *
 * Rules (settings/nfse.autoIssue, read through `directAutoIssueOf`, so the
 * Asaas values 'paid'/'completed' are 'never' here and the Asaas engine never
 * acts on these): `selectedCustomers` issues only when the customer's
 * `autoIssueInvoice` is true; `allOrders` unless it is false; `never` nothing.
 * The key is one, so one order never gets a nota from both engines.
 *
 * Never blocks the order: every failure here is caught and recorded. Logs
 * carry ids and codes only.
 */

import { db } from '../firestore.service';
import type { NfseInvoice } from '../../models/asaas.types';
import type { Order, UserAggr } from '../../models/types';
import { directAutoIssueOf, type NfseDirectAutoIssue } from '../../models/nfse-direct.types';
import { AsaasServiceError } from '../asaas/errors';
import { todayInSaoPaulo } from '../asaas/charge.service';
import { invoiceValueOfOrder } from '../asaas/invoice.service';
import { NfseServiceError } from './errors';
import { issueDirectInvoice, type IssueDeps } from './issue.service';

/** Author of the notas the server issues by itself (same as the Asaas engine's). */
export const DIRECT_AUTO_ISSUE_USER: UserAggr = { id: 'system', name: 'PraticOS' };

/** A request still `processing` after this was cut short (timeout, crash): the sweep takes it again. */
export const STALE_PROCESSING_MS = 10 * 60 * 1000;

/** Doc id of the error record of an automatic nota that failed (one per order, like the Asaas engine). */
export const directAutoIssueErrorId = (orderId: string) => `auto-${orderId}`;

/**
 * Failures that are not the order's problem, or that mean there is nothing to
 * issue: nothing is recorded on the order.
 */
const SILENT = new Set([
  'NFSE_DIRECT_NOT_ENABLED',
  'ORDER_HAS_INVOICE',
  'ORDER_NOT_FOUND',
  'NFSE_ORDER_NOT_ALLOWED',
  'CUSTOMER_REQUIRED',
  'NO_SERVICES',
]);

/** Codes the app and the web explain on the order ("Falta o CPF ou CNPJ do cliente"). */
export const DIRECT_AUTO_ISSUE_ERRORS = [
  'RECIPIENT_TAX_ID_REQUIRED',
  'CERT_EXPIRED',
  'CERT_NOT_FOUND',
  'EMITTER_NOT_READY',
  'EMITTER_NOT_FOUND',
  'DAILY_LIMIT_REACHED',
  'KEY_VAULT_UNAVAILABLE',
  'SEFIN_UNAVAILABLE',
  'AUTO_ISSUE_FAILED',
] as const;

type RequestStatus = 'pending' | 'processing' | 'done';

export interface DirectAutoIssueRequest {
  orderId: string;
  status: RequestStatus;
  /** The rule that asked for it, for the logs. */
  rule: NfseDirectAutoIssue;
  createdAt: string;
  claimedAt?: string | null;
  attempts?: number;
  /** How it ended: the nota, a recorded error, or nothing to do. */
  result?: { invoiceId?: string | null; errorCode?: string | null; skipped?: string | null } | null;
  finishedAt?: string | null;
}

const companyRef = (companyId: string) => db.collection('companies').doc(companyId);
const invoicesRef = (companyId: string) => companyRef(companyId).collection('invoices');
export const autoIssueRequestRef = (companyId: string, orderId: string) =>
  companyRef(companyId).collection('private').doc('nfse').collection('autoIssue').doc(orderId);

export interface AutoIssueDeps {
  now: () => Date;
  /** Issue deps (tests replace the certificate and the government). */
  issue?: Partial<IssueDeps>;
}

const defaults = (override?: Partial<AutoIssueDeps>): AutoIssueDeps => ({ now: () => new Date(), ...override });

/** Whether the rule issues for this customer's switch (`autoIssueInvoice`: true, false or absent). */
export function autoIssueApplies(rule: NfseDirectAutoIssue, customerSwitch: unknown): boolean {
  if (rule === 'selectedCustomers') return customerSwitch === true;
  if (rule === 'allOrders') return customerSwitch !== false;
  return false;
}

async function orderHasInvoice(companyId: string, orderId: string): Promise<boolean> {
  const snap = await invoicesRef(companyId).where('orderIds', 'array-contains', orderId).limit(1).get();
  return !snap.empty;
}

/**
 * Order trigger: the order became `done`. Creates the request when the
 * company has the NFS-e direct and its rule covers this customer. Returns
 * whether a request was created (false when there was nothing to do or it
 * already existed). Never throws for an expected case.
 */
export async function requestDirectAutoIssue(
  companyId: string,
  orderId: string,
  override?: Partial<AutoIssueDeps>,
): Promise<boolean> {
  const deps = defaults(override);
  const payments = (await companyRef(companyId).collection('settings').doc('payments').get()).data();
  if (payments?.nfseDirectEnabled !== true) return false;
  const rule = directAutoIssueOf((await companyRef(companyId).collection('settings').doc('nfse').get()).data()?.autoIssue);
  if (rule === 'never') return false;

  const order = (await companyRef(companyId).collection('orders').doc(orderId).get()).data();
  if (!order || order.status !== 'done') return false;
  const customerId = order.customer?.id as string | undefined;
  if (!customerId) return false;
  const customer = (await companyRef(companyId).collection('customers').doc(customerId).get()).data();
  if (!autoIssueApplies(rule, customer?.autoIssueInvoice)) return false;
  // An order that ever had a nota (any engine, any status) is left to the user.
  if (await orderHasInvoice(companyId, orderId)) return false;

  const request: DirectAutoIssueRequest = { orderId, status: 'pending', rule, createdAt: deps.now().toISOString(), attempts: 0 };
  try {
    await autoIssueRequestRef(companyId, orderId).create(request as unknown as Record<string, unknown>);
  } catch (error) {
    // ALREADY_EXISTS: the trigger ran twice, or the order was done before.
    if ((error as { code?: unknown })?.code === 6) return false;
    throw error;
  }
  console.log(`[nfse-auto] request for order ${orderId} of company ${companyId} (${rule})`);
  return true;
}

/** Takes the request for this run, or null when another run has it or it is finished. */
async function claim(companyId: string, orderId: string, now: Date): Promise<DirectAutoIssueRequest | null> {
  const ref = autoIssueRequestRef(companyId, orderId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const request = snap.data() as DirectAutoIssueRequest | undefined;
    if (!request) return null;
    const stale =
      request.status === 'processing' && now.getTime() - Date.parse(request.claimedAt ?? request.createdAt) >= STALE_PROCESSING_MS;
    if (request.status !== 'pending' && !stale) return null;
    const attempts = (request.attempts ?? 0) + 1;
    tx.update(ref, { status: 'processing', claimedAt: now.toISOString(), attempts });
    return { ...request, status: 'processing', attempts };
  });
}

async function finish(companyId: string, orderId: string, result: NonNullable<DirectAutoIssueRequest['result']>, now: Date): Promise<void> {
  await autoIssueRequestRef(companyId, orderId).update({ status: 'done', result, finishedAt: now.toISOString() });
}

/** The code recorded on the order for a failure, or null when nothing is recorded. */
export function autoIssueErrorCode(error: unknown): string | null {
  if (error instanceof NfseServiceError) {
    if (SILENT.has(error.code)) return null;
    // Refused: issueDirectInvoice already left the nota in `error` with the government's reason.
    if (error.code === 'NFSE_REFUSED') return null;
    return (DIRECT_AUTO_ISSUE_ERRORS as readonly string[]).includes(error.code) ? error.code : 'AUTO_ISSUE_FAILED';
  }
  if (error instanceof AsaasServiceError) return SILENT.has(error.code) ? null : 'AUTO_ISSUE_FAILED';
  return 'AUTO_ISSUE_FAILED';
}

/**
 * Issues the nota of a requested order (nfse-api account). Idempotent: the
 * request is claimed in a transaction, an order that already has a nota is
 * skipped, and the error record has a fixed id.
 */
export async function processDirectAutoIssue(
  companyId: string,
  orderId: string,
  override?: Partial<AutoIssueDeps>,
): Promise<DirectAutoIssueRequest['result']> {
  const deps = defaults(override);
  const now = deps.now();
  const request = await claim(companyId, orderId, now);
  if (!request) return null;

  if (await orderHasInvoice(companyId, orderId)) {
    const result = { skipped: 'hasInvoice' };
    await finish(companyId, orderId, result, now);
    return result;
  }

  try {
    const invoice = await issueDirectInvoice(companyId, { orderIds: [orderId] }, DIRECT_AUTO_ISSUE_USER, { auto: true }, {
      ...deps.issue,
      now: deps.now,
    });
    console.log(`[nfse-auto] order ${orderId} of company ${companyId}: invoice ${invoice.id} (${invoice.status})`);
    const result = { invoiceId: invoice.id };
    await finish(companyId, orderId, result, deps.now());
    return result;
  } catch (error) {
    const errorCode = autoIssueErrorCode(error);
    const code = (error as { code?: unknown })?.code ?? (error as Error)?.name ?? 'unknown';
    if (errorCode === 'AUTO_ISSUE_FAILED') {
      // Not an expected case: the log line is the alert.
      console.error(`[nfse-auto] order ${orderId} of company ${companyId} failed unexpectedly (${String(code)})`);
    } else {
      console.warn(`[nfse-auto] order ${orderId} of company ${companyId} not issued (${String(code)})`);
    }
    // A nota made before the failure (refused, or still waiting for the government) already tells the story.
    if (errorCode && !(await orderHasInvoice(companyId, orderId))) {
      await recordAutoIssueError(companyId, orderId, errorCode, deps.now());
    }
    const result = errorCode ? { errorCode } : { skipped: String(code) };
    await finish(companyId, orderId, result, deps.now());
    return result;
  }
}

async function recordAutoIssueError(companyId: string, orderId: string, errorCode: string, now: Date): Promise<void> {
  const order = (await companyRef(companyId).collection('orders').doc(orderId).get()).data() as Order | undefined;
  const value = order ? invoiceValueOfOrder(order).value : 0;
  const at = now.toISOString();
  const record: NfseInvoice & { provider: 'direct'; source: 'praticos' } = {
    id: directAutoIssueErrorId(orderId),
    status: 'error',
    provider: 'direct',
    source: 'praticos',
    customer: { id: order?.customer?.id ?? '', name: order?.customer?.name ?? null },
    orderIds: [orderId],
    orders: [{ orderId, orderNumber: order?.number ?? null, value }],
    value,
    serviceDescription: '',
    observations: '',
    effectiveDate: todayInSaoPaulo(now),
    municipalServiceName: '',
    statusDescription: null,
    errorCode,
    auto: true,
    createdBy: DIRECT_AUTO_ISSUE_USER,
    createdAt: at,
    updatedAt: at,
  };
  const ref = invoicesRef(companyId).doc(record.id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, record as unknown as Record<string, unknown>);
  });
}

/**
 * Daily sweep (and backup of the trigger): requests still pending, or cut
 * short while processing, are processed now.
 */
export async function processPendingDirectAutoIssues(companyId: string, override?: Partial<AutoIssueDeps>): Promise<number> {
  const deps = defaults(override);
  const snap = await companyRef(companyId).collection('private').doc('nfse').collection('autoIssue').where('status', 'in', ['pending', 'processing']).get();
  let processed = 0;
  for (const doc of snap.docs) {
    const result = await processDirectAutoIssue(companyId, doc.id, deps).catch((error) => {
      console.error(`[nfse-auto] sweep of order ${doc.id} of company ${companyId} failed`, (error as Error)?.name);
      return null;
    });
    if (result) processed++;
  }
  return processed;
}
