/**
 * The nota goes to the customer's e-mail (issue #611): after it is issued
 * (PDF + XML, number, value, public lookup link) and after it is canceled
 * (notice with the PDF marked "CANCELADA"). Sent through Resend by a direct
 * call (attachments do not fit a Firestore document), from the nfseApi only:
 * the key RESEND_API_KEY lives in Secret Manager and only nfse-api@ reads it.
 *
 * Rules:
 * - Address: `invoiceEmail` of the recipient customer, else its e-mail, else
 *   the e-mail the nota went out with; none → nothing is sent (`noEmail`).
 * - settings/nfse.emailToCustomer === false turns the automatic send off
 *   (who sends it by WhatsApp); "Enviar de novo" still works.
 * - A failure never fails the issue or the cancellation: it is saved on the
 *   invoice (`emailDelivery`) and shown on the nota screen.
 *
 * Logs carry codes and ids only: never the address nor the content.
 */

import { defineSecret } from 'firebase-functions/params';
import { db, storage } from '../firestore.service';
import { ensureDanfse } from './danfse.service';
import { NfseServiceError } from './errors';
import { QR_CODE_URL } from './danfse/render';
import type { NfseEmailDelivery, NfseEmailKind } from '../../models/nfse-direct.types';

/** Resend API key (Secret Manager; bound to nfseApi and nfseDaily only). */
export const RESEND_API_KEY = defineSecret('RESEND_API_KEY');

/** Sender address; the display name is the company's. Domain verified in Resend (docs/NFSE_DIRECT.md). */
export const NFSE_EMAIL_FROM = 'notas@praticos.app';
const RESEND_URL = 'https://api.resend.com/emails';
const EMAIL_PATTERN = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[^\s@<>"',;]+$/;

export interface OutgoingEmail {
  from: string;
  to: string;
  replyTo: string | null;
  subject: string;
  text: string;
  html: string;
  attachments: Array<{ filename: string; content: Buffer; contentType: string }>;
  /** Same key → the provider sends once (retries of the same event). */
  idempotencyKey: string;
}

/** The provider refused or could not be reached. [code] is saved on the invoice. */
export class EmailSendError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'EmailSendError';
  }
}

export interface EmailDeps {
  send: (email: OutgoingEmail) => Promise<{ id: string | null }>;
  readFile: (path: string) => Promise<Buffer>;
  /** Storage path of the PDF with the watermark the nota needs now. */
  ensurePdf: (companyId: string, invoiceId: string) => Promise<string>;
  now: () => Date;
}

/** POST /emails of Resend. Never called by tests (they replace `send`). */
export async function sendWithResend(email: OutgoingEmail, apiKey = RESEND_API_KEY.value()): Promise<{ id: string | null }> {
  if (!apiKey) throw new EmailSendError('EMAIL_NOT_CONFIGURED', 'RESEND_API_KEY is not set');
  let res: Response;
  try {
    res = await fetch(RESEND_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': email.idempotencyKey,
      },
      body: JSON.stringify({
        from: email.from,
        to: [email.to],
        ...(email.replyTo ? { reply_to: email.replyTo } : {}),
        subject: email.subject,
        text: email.text,
        html: email.html,
        attachments: email.attachments.map((a) => ({ filename: a.filename, content: a.content.toString('base64'), content_type: a.contentType })),
      }),
      signal: AbortSignal.timeout(15000),
    });
  } catch {
    throw new EmailSendError('EMAIL_UNREACHABLE', 'Resend did not answer');
  }
  const body = (await res.json().catch(() => ({}))) as { id?: unknown; name?: unknown };
  if (!res.ok) {
    const name = typeof body.name === 'string' ? body.name.replace(/[^a-z_]/gi, '').slice(0, 40) : '';
    throw new EmailSendError(`EMAIL_REJECTED_${res.status}${name ? `_${name}` : ''}`.toUpperCase(), `Resend answered ${res.status}`);
  }
  return { id: typeof body.id === 'string' ? body.id : null };
}

export function defaultEmailDeps(): EmailDeps {
  return {
    send: (email) => sendWithResend(email),
    readFile: async (path) => (await storage.bucket().file(path).download())[0],
    ensurePdf: (companyId, invoiceId) => ensureDanfse(companyId, invoiceId),
    now: () => new Date(),
  };
}

// ----------------------------------------------------------------------------
// Content (Portuguese: the NFS-e and the DANFSe exist only in Brazil)
// ----------------------------------------------------------------------------

export interface EmailFacts {
  kind: NfseEmailKind;
  companyName: string;
  number: string | null;
  value: number;
  accessKey: string | null;
  customerName: string | null;
}

const escapeHtml = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** Display name safe for a From header: no quotes, brackets or line breaks. */
export function displayName(name: string): string {
  return name.replace(/[\r\n"<>\\]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 70) || 'PraticOS';
}

const brl = (value: number) => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);

export function lookupUrl(accessKey: string | null): string | null {
  return accessKey && /^\d{50}$/.test(accessKey) ? `${QR_CODE_URL}${accessKey}` : null;
}

export function buildEmailContent(facts: EmailFacts): { subject: string; text: string; html: string } {
  const nota = facts.number ? `nota fiscal nº ${facts.number}` : 'nota fiscal';
  const value = brl(facts.value);
  const link = lookupUrl(facts.accessKey);
  const hello = facts.customerName ? `Olá, ${facts.customerName}.` : 'Olá.';
  const lines =
    facts.kind === 'issued'
      ? [
          hello,
          `${facts.companyName} emitiu a ${nota}, no valor de ${value}.`,
          'O PDF e o XML da nota estão anexados.',
          ...(link ? [`Consulte a nota no portal nacional da NFS-e: ${link}`] : []),
        ]
      : [
          hello,
          `${facts.companyName} cancelou a ${nota}, no valor de ${value}.`,
          'O PDF anexado mostra a nota marcada como CANCELADA.',
          ...(link ? [`Consulte a situação no portal nacional da NFS-e: ${link}`] : []),
        ];
  const footer = 'Mensagem enviada pelo PraticOS a pedido da empresa. Para falar com ela, responda este e-mail.';
  const subject =
    facts.kind === 'issued'
      ? `${capitalize(nota)} de ${facts.companyName}`
      : `${capitalize(nota)} de ${facts.companyName} foi cancelada`;
  const html = [
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.5;color:#1d1d1f">',
    ...lines.map((line) =>
      link && line.endsWith(link)
        ? `<p>${escapeHtml(line.slice(0, -link.length))}<a href="${escapeHtml(link)}">${escapeHtml(link)}</a></p>`
        : `<p>${escapeHtml(line)}</p>`,
    ),
    `<p style="font-size:13px;color:#6e6e73">${escapeHtml(footer)}</p>`,
    '</div>',
  ].join('');
  return { subject: subject.slice(0, 200), text: [...lines, '', footer].join('\n'), html };
}

const capitalize = (text: string) => text.charAt(0).toUpperCase() + text.slice(1);

// ----------------------------------------------------------------------------
// Send
// ----------------------------------------------------------------------------

interface InvoiceDoc {
  provider?: string;
  status?: string;
  number?: string | null;
  value?: number;
  accessKey?: string | null;
  xmlPath?: string | null;
  customer?: { id?: string; name?: string | null };
  recipient?: { customerId?: string | null; legalName?: string | null; email?: string | null } | null;
  emitter?: { legalName?: string } | null;
}

const clean = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);

/** Which e-mail the nota of [invoice] goes to now (see the rules on top). */
async function recipientEmail(companyId: string, invoice: InvoiceDoc): Promise<string | null> {
  const customerId = invoice.recipient?.customerId ?? invoice.customer?.id;
  if (customerId) {
    const customer = (await db.collection('companies').doc(companyId).collection('customers').doc(customerId).get()).data();
    const fromCustomer = clean(customer?.invoiceEmail) ?? clean(customer?.email);
    if (fromCustomer) return fromCustomer;
  }
  return clean(invoice.recipient?.email);
}

export interface SendOptions {
  /** "Enviar de novo": ignores emailToCustomer and goes again. */
  manual?: boolean;
}

/**
 * Sends the e-mail of [kind] for a direct nota and saves the result on the
 * invoice. Never throws for the automatic send; for the manual one throws
 * only when the nota cannot have an e-mail (EMAIL_NOT_AVAILABLE).
 */
export async function sendInvoiceEmail(
  companyId: string,
  invoiceId: string,
  kind: NfseEmailKind,
  options: SendOptions = {},
  override?: Partial<EmailDeps>,
): Promise<NfseEmailDelivery | null> {
  const deps = { ...defaultEmailDeps(), ...override };
  const company = db.collection('companies').doc(companyId);
  const ref = company.collection('invoices').doc(invoiceId);
  const snap = await ref.get();
  const invoice = snap.data() as InvoiceDoc | undefined;
  const issued = invoice?.status === 'authorized' || invoice?.status === 'cancellationDenied';
  const fits = kind === 'issued' ? issued : invoice?.status === 'canceled';
  if (!invoice || invoice.provider !== 'direct' || !invoice.xmlPath || !fits) {
    if (options.manual) throw new NfseServiceError('EMAIL_NOT_AVAILABLE', 'Only issued or canceled direct notas go by e-mail');
    return null;
  }

  const at = deps.now().toISOString();
  const save = async (delivery: NfseEmailDelivery) => {
    await ref.update({ emailDelivery: delivery });
    return delivery;
  };
  const base = { kind, at, manual: options.manual === true };

  if (!options.manual) {
    const settings = (await company.collection('settings').doc('nfse').get()).data();
    if (settings?.emailToCustomer === false) return save({ ...base, status: 'skipped', to: null, reason: 'turnedOff' });
  }
  const to = await recipientEmail(companyId, invoice);
  if (!to) return save({ ...base, status: 'skipped', to: null, reason: 'noEmail' });
  if (!EMAIL_PATTERN.test(to)) return save({ ...base, status: 'failed', to, errorCode: 'INVALID_EMAIL' });

  try {
    const companyData = (await company.get()).data() ?? {};
    const companyName = displayName(clean(companyData.name) ?? clean(invoice.emitter?.legalName) ?? 'PraticOS');
    const replyTo = clean(companyData.email);
    const pdf = await deps.readFile(await deps.ensurePdf(companyId, invoiceId));
    const file = `nota-${(invoice.number ?? invoiceId).replace(/[^\w-]/g, '')}`;
    const attachments: OutgoingEmail['attachments'] = [{ filename: `${file}.pdf`, content: pdf, contentType: 'application/pdf' }];
    if (kind === 'issued') {
      attachments.push({ filename: `${file}.xml`, content: await deps.readFile(invoice.xmlPath), contentType: 'application/xml' });
    }
    const content = buildEmailContent({
      kind,
      companyName,
      number: invoice.number ?? null,
      value: Number(invoice.value) || 0,
      accessKey: invoice.accessKey ?? null,
      customerName: clean(invoice.recipient?.legalName) ?? clean(invoice.customer?.name),
    });
    const { id } = await deps.send({
      from: `"${companyName}" <${NFSE_EMAIL_FROM}>`,
      to,
      replyTo: replyTo && EMAIL_PATTERN.test(replyTo) ? replyTo : null,
      ...content,
      attachments,
      idempotencyKey: options.manual ? `nfse-${companyId}-${invoiceId}-${kind}-${at}` : `nfse-${companyId}-${invoiceId}-${kind}`,
    });
    console.log(`[nfse] e-mail (${kind}) of invoice ${invoiceId} of company ${companyId} sent`);
    return save({ ...base, status: 'sent', to, providerId: id });
  } catch (error) {
    const code = error instanceof EmailSendError ? error.code : error instanceof NfseServiceError ? error.code : 'EMAIL_FAILED';
    console.error(`[nfse] e-mail (${kind}) of invoice ${invoiceId} of company ${companyId} not sent (${code})`, (error as Error)?.name);
    return save({ ...base, status: 'failed', to, errorCode: code });
  }
}

/** "Enviar de novo": the e-mail that fits the nota now (canceled → the notice). */
export async function resendInvoiceEmail(companyId: string, invoiceId: string, override?: Partial<EmailDeps>): Promise<NfseEmailDelivery | null> {
  const snap = await db.collection('companies').doc(companyId).collection('invoices').doc(invoiceId).get();
  if (!snap.exists) throw new NfseServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
  const kind: NfseEmailKind = snap.data()?.status === 'canceled' ? 'canceled' : 'issued';
  return sendInvoiceEmail(companyId, invoiceId, kind, { manual: true }, override);
}

/** Best effort after issuing or canceling: never throws. */
export async function notifyInvoiceEmail(companyId: string, invoiceId: string, kind: NfseEmailKind): Promise<NfseEmailDelivery | null> {
  try {
    return await sendInvoiceEmail(companyId, invoiceId, kind);
  } catch (error) {
    console.error(`[nfse] e-mail (${kind}) of invoice ${invoiceId} of company ${companyId} not saved`, (error as Error)?.name);
    return null;
  }
}
