/**
 * NFS-e direct to the national system (Emissor Nacional, Sefin/ADN), without
 * Asaas. Spec: docs/superpowers/specs/2026-11-05-nfse-direta-design.md (§7).
 *
 * Every document here is written only by the server (Admin SDK); the app reads
 * fiscalEmitters, invoices and settings/nfse (financial roles) and nfseImports
 * (owner and admin). The certificate material lives in /nfseCertificates and the
 * counters in companies/{cid}/private/nfse/**, both closed in firestore.rules.
 */

import type { UserAggr } from './types';

/** Who issues the nota of a new invoice. Absent on old invoices: 'asaas'. */
export type NfseProvider = 'asaas' | 'direct';

/** Where an invoice came from: issued by PraticOS, or read from the government (import/sync). */
export type NfseInvoiceSource = 'praticos' | 'external';

/** Tax regime of an emitter. Decides the DPS fields (§5.2). */
export type FiscalRegime = 'mei' | 'simples';

/**
 * When the server issues the nota by itself, only when the order is done
 * (§5.8). Same key as the Asaas `autoIssue` ('manual' | 'paid' | 'completed'):
 * the values never overlap, and the Asaas engine only acts on its own values.
 */
export type NfseDirectAutoIssue = 'never' | 'selectedCustomers' | 'allOrders';

export const NFSE_DIRECT_AUTO_ISSUE: readonly NfseDirectAutoIssue[] = ['never', 'selectedCustomers', 'allOrders'];

/** State of an emitter's certificate. `pending` = sent by the accountant, waiting for the owner to confirm. */
export type FiscalCertificateStatus = 'active' | 'pending' | 'expired' | 'deleted';

/** What the app may know about the certificate (never the material). */
export interface FiscalEmitterCertificate {
  holderName: string;
  /** End of validity, ISO 8601. */
  notAfter: string;
  uploadedAt: string;
  uploadedBy: UserAggr;
  status: FiscalCertificateStatus;
}

/** Default service of the notas of one emitter. */
export interface FiscalEmitterService {
  /** cTribNac, national service code (6 digits). */
  nationalCode: string;
  /** cTribMun, when the city uses its own list. */
  municipalCode?: string | null;
  /** NBS code (required by the 2027 layout). */
  nbs?: string | null;
  name: string;
  /** ISS rate in percent, from the city's history for the service. */
  issRate: number;
  /** Simples only: approximate % of taxes on the nota (pTotTribSN), from the accountant. */
  simplesTaxRate?: number | null;
}

/** How the description of the notas is written, learned from the emitter's old notas. */
export interface FiscalDescriptionStyle {
  uppercase: boolean;
  /** Joins the services of one order, e.g. " - ". */
  separator: string;
}

/** Notas issued this year and this month (any source), minus canceled (§5.7). */
export interface FiscalEmitterTotals {
  year: number;
  yearValue: number;
  /** 1-12 */
  month: number;
  monthValue: number;
}

/**
 * companies/{cid}/fiscalEmitters/{emitterId}: one CNPJ that issues notas.
 * A company may have several (one Simples and several MEIs).
 */
export interface FiscalEmitter {
  id: string;
  /** CNPJ, normalized (digits; uppercase letters for the alphanumeric CNPJ). Unique per company. */
  taxId: string;
  legalName: string;
  tradeName?: string | null;
  regime: FiscalRegime;
  /** regApTribSN of the Simples (1, 2 or 3); absent for MEI. */
  simplesOption?: number | null;
  /** IBGE code of the city (7 digits). */
  cityCode: string;
  cityName: string;
  /** Only when the national registry has it (E0116 × E0120). */
  municipalRegistration?: string | null;
  /** Enabled to issue in the city, per the national registry (CNC). */
  enabledInCity: boolean;
  service?: FiscalEmitterService | null;
  descriptionStyle?: FiscalDescriptionStyle | null;
  /** Our DPS series, one the CNPJ never used (§5.3). */
  dpsSeries: string;
  certificate?: FiscalEmitterCertificate | null;
  totals?: FiscalEmitterTotals | null;
  importBatchId?: string | null;
  createdAt: string;
  updatedAt?: string;
}

/** The emitter embedded in an invoice. */
export interface FiscalEmitterAggr {
  id: string;
  taxId: string;
  legalName: string;
  /** Null for an emitter not configured yet (the import reads notas before the regime is set). */
  regime: FiscalRegime | null;
}

/** Structured address of the nota (customer and recipient). */
export interface FiscalAddress {
  postalCode?: string | null;
  street?: string | null;
  number?: string | null;
  complement?: string | null;
  district?: string | null;
  /** IBGE code of the city. */
  cityCode?: string | null;
  cityName?: string | null;
  /** UF, two letters. */
  state?: string | null;
}

/** Who received the nota (tomador), as sent. */
export interface NfseRecipient {
  /** The customer the nota went to (the "Nota fiscal para" one, or the order's customer); null when typed by hand. */
  customerId?: string | null;
  taxId: string;
  legalName: string;
  address?: FiscalAddress | null;
  email?: string | null;
}

/** Our request to the government: the DPS id is deterministic (city + CNPJ + series + number). */
export interface NfseDps {
  id: string;
  series: string;
  number: number;
}

/** Why the user canceled (event e101101). */
export type NfseCancelReason = 'issueError' | 'serviceNotProvided';

/** Fields of companies/{cid}/invoices/{id} added by the direct engine (all optional on old invoices). */
export interface NfseDirectInvoiceFields {
  provider?: NfseProvider;
  source?: NfseInvoiceSource;
  emitter?: FiscalEmitterAggr;
  recipient?: NfseRecipient;
  dps?: NfseDps;
  /** Chave de acesso (50 characters). */
  accessKey?: string | null;
  /** Storage paths (tenants/{cid}/invoices/{id}/nfse.xml and .pdf). */
  xmlPath?: string | null;
  pdfPath?: string | null;
  /** Watermark of the PDF at pdfPath: a canceled nota gets a new one with "CANCELADA" (#564). */
  pdfSituation?: 'normal' | 'canceled' | 'replaced' | null;
  cancelReason?: NfseCancelReason | null;
  importBatchId?: string | null;
  /** Why the government refused it, in plain words (group + pt/en/es), when status is 'error'. */
  refusal?: { code: string | null; group: 'customerData' | 'emitterSetup' | 'certificate' | 'other'; message: Record<'pt' | 'en' | 'es', string>; govText: string | null } | null;
  /** Last send without a clear answer (the reconcile waits 3 minutes from it). */
  lastAttemptAt?: string | null;
  /** Last e-mail of the nota to the customer (issue #611). */
  emailDelivery?: NfseEmailDelivery | null;
}

/** Which e-mail: the issued nota or the notice that it was canceled. */
export type NfseEmailKind = 'issued' | 'canceled';

/**
 * Result of the last e-mail to the customer, saved on the invoice:
 * `sent` (to, at), `failed` (errorCode) or `skipped` (reason: the customer
 * has no e-mail, or the company turned the automatic send off).
 */
export interface NfseEmailDelivery {
  status: 'sent' | 'failed' | 'skipped';
  kind: NfseEmailKind;
  to: string | null;
  at: string;
  /** "Enviar de novo" (not the automatic send). */
  manual: boolean;
  reason?: 'noEmail' | 'turnedOff';
  errorCode?: string;
  providerId?: string | null;
}

/** Fields of companies/{cid}/settings/nfse added by the direct engine. */
export interface NfseDirectSettingsFields {
  provider?: NfseProvider;
  defaultEmitterId?: string | null;
  autoIssue?: NfseDirectAutoIssue;
  /** false: the nota does not go to the customer's e-mail on its own (issue #611). Absent = true. */
  emailToCustomer?: boolean;
}

/** Fields of companies/{cid}/customers/{id} for the nota (written by the app and by the import). */
export interface CustomerFiscalFields {
  legalName?: string | null;
  fiscalAddress?: FiscalAddress | null;
  /** E-mail the nota goes to (falls back to the customer's e-mail). */
  invoiceEmail?: string | null;
  /** "Nota fiscal para": another customer of the company receives this customer's notas. */
  invoiceRecipient?: { id: string; name?: string | null } | null;
  /** Issue the nota when an order of this customer is done (§4.5). */
  autoIssueInvoice?: boolean | null;
  /** Last emitter used for this customer: marked first in the issue sheet (decision 3). */
  lastEmitterId?: string | null;
}

/** companies/{cid}/private/nfse/emitters/{emitterId}: server-only counters. */
export interface FiscalEmitterPrivate {
  /** Next DPS number of `dpsSeries`, reserved in a transaction with the `creating` invoice. */
  nextDpsNumber: number;
  /** Last NSU read from the ADN (import and daily sync). */
  lastNsu: number;
  /** Day (YYYY-MM-DD, São Paulo) of `issuedToday`. */
  issuedOn?: string;
  /** Notas reserved on `issuedOn` (the daily ceiling, issue #560). */
  issuedToday?: number;
  /** Ceiling of this emitter when it differs from the default (set by hand, server only). */
  dailyIssueLimit?: number;
}

/** companies/{cid}/nfseImports/{batchId}: the import proposal and what was applied, for "Desfazer". */
export interface NfseImportBatch {
  id: string;
  emitterId: string;
  status: 'reading' | 'proposed' | 'applied' | 'undone' | 'failed';
  /** Undo is offered until then (30 days after applying). */
  expiresAt?: string | null;
  createdAt: string;
  appliedAt?: string | null;
  appliedBy?: UserAggr | null;
}

/** settings/nfse.autoIssue read as the direct engine sees it: anything else (incl. the Asaas values) is 'never'. */
export function directAutoIssueOf(value: unknown): NfseDirectAutoIssue {
  return NFSE_DIRECT_AUTO_ISSUE.includes(value as NfseDirectAutoIssue) ? (value as NfseDirectAutoIssue) : 'never';
}

/** Provider of an invoice or of settings/nfse; absent means the Asaas engine (everything before the direct one). */
export function nfseProviderOf(doc: { provider?: unknown } | null | undefined): NfseProvider {
  return doc?.provider === 'direct' ? 'direct' : 'asaas';
}

/** The emitter as embedded in an invoice. */
export function fiscalEmitterAggr(emitter: Pick<FiscalEmitter, 'id' | 'taxId' | 'legalName' | 'regime'>): FiscalEmitterAggr {
  // Firestore refuses undefined: a field the emitter does not have yet goes as null.
  return { id: emitter.id, taxId: emitter.taxId, legalName: emitter.legalName ?? '', regime: emitter.regime ?? null };
}
