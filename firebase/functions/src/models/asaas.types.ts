/**
 * Asaas integration types (server-only documents and API DTOs).
 * See docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md
 */

import { PaymentTransaction, UserAggr } from './types';

export type AsaasEnvironment = 'sandbox' | 'production';
export type AsaasConnectionMode = 'apiKey' | 'flapp';

/** AES-256-GCM output, every field base64 */
export interface EncryptedSecret {
  iv: string;
  tag: string;
  ciphertext: string;
}

/** companies/{companyId}/private/asaas */
export interface AsaasConnectionDoc {
  mode: AsaasConnectionMode;
  environment: AsaasEnvironment;
  encryptedApiKey: EncryptedSecret;
  accountName: string;
  walletId?: string;
  webhookId?: string;
  webhookTokenHash?: string;
  /** Events subscribed at connect (missing on connections made before NFS-e). */
  webhookEvents?: string[];
  status: 'active' | 'invalid';
  connectedBy: UserAggr;
  connectedAt: string;
}

export type ChargeMode = 'single' | 'cardInstallments';
export type ChargeStatus = 'pending' | 'paid' | 'overdue' | 'canceled' | 'refunded';

/** companies/{companyId}/orders/{orderId}/charges/{chargeId} */
export interface OrderCharge {
  id: string;
  asaasPaymentId: string;
  asaasInstallmentId?: string;
  mode: ChargeMode;
  installmentCount?: number;
  value: number;
  dueDate: string; // YYYY-MM-DD
  status: ChargeStatus;
  invoiceUrl: string;
  paidAsaasPaymentIds: string[];
  createdBy: UserAggr;
  createdAt: string;
  paidAt?: string;
  /** Server-only copy of every transaction booked on the order (used by the repair trigger). */
  appliedTransactions?: PaymentTransaction[];
  /** Server-only: Asaas payments refunded on this charge; never booked again. */
  refundedAsaasPaymentIds?: string[];
  /** Paid outside Asaas: marked received in cash on Asaas by the server (no booking). */
  paidOutside?: boolean;
  /** Installment plan canceled by the server: the order came to owe less than it. */
  autoCanceled?: boolean;
  /**
   * Server-only: receiveInCash in progress or with an unknown outcome
   * (timeout/5xx); a RECEIVED_IN_CASH webhook for it must not book, and the
   * next reconciliation confirms the payment status on Asaas.
   */
  settlingOutsideAt?: string;
  /** Server-only: value sent in that receiveInCash. */
  settlingOutsideValue?: number;
  /** Server-only: lease of the outside-payment reconciliation (ISO). */
  adjustingUntil?: string;
  /** Server-only: bumped by a reconciliation that found the lease taken (the holder runs again). */
  dirtyCount?: number;
  dirtyAt?: string;
}

/** One order covered by a CustomerCharge and how much of the charge goes to it. */
export interface CustomerChargeAllocation {
  orderId: string;
  orderNumber?: number | null;
  amount: number;
}

/** Order + transaction written on it when a CustomerCharge payment was booked (repair copy). */
export interface CustomerChargeAppliedTransaction {
  orderId: string;
  asaasPaymentId: string;
  transaction: PaymentTransaction;
}

/**
 * companies/{companyId}/customerCharges/{chargeId}: one Asaas charge for
 * several orders of the same customer ("Mandar cobrança" from "Receber de
 * João"). Written only by the server; read like the order `charges`.
 */
export interface CustomerCharge {
  id: string;
  customer: { id: string; name?: string | null };
  asaasPaymentId: string;
  value: number;
  dueDate: string; // YYYY-MM-DD
  status: ChargeStatus;
  invoiceUrl: string;
  /** Order ids covered (for array-contains queries), same order as `allocations`. */
  orderIds: string[];
  /** Oldest first; sum = value. */
  allocations: CustomerChargeAllocation[];
  paidAsaasPaymentIds: string[];
  createdBy: UserAggr;
  createdAt: string;
  paidAt?: string;
  /** Receipt (`companies/{cid}/receipts/{id}`) written when it was paid through Asaas. */
  receiptId?: string;
  /** Paid outside Asaas: marked received in cash on Asaas by the server (no booking). */
  paidOutside?: boolean;
  /**
   * Server-only: receiveInCash in progress or with an unknown outcome
   * (timeout/5xx); a RECEIVED_IN_CASH webhook for it must not book, and the
   * next reconciliation confirms the payment status on Asaas.
   */
  settlingOutsideAt?: string;
  /** Server-only: value sent in that receiveInCash. */
  settlingOutsideValue?: number;
  /** Server-only: lease of the outside-payment reconciliation (ISO). */
  adjustingUntil?: string;
  /** Server-only: bumped by a reconciliation that found the lease taken (the holder runs again). */
  dirtyCount?: number;
  dirtyAt?: string;
  /** Server-only. */
  appliedTransactions?: CustomerChargeAppliedTransaction[];
  /** Server-only. */
  refundedAsaasPaymentIds?: string[];
}

/** companies/{companyId}/settings/payments */
export interface PaymentSettingsDoc {
  asaasEnabled: boolean;
  asaasConnected: boolean;
  asaasAccountName?: string;
  asaasEnvironment?: AsaasEnvironment;
  /** NFS-e flag, set only by the server/admin script (enable-asaas-pilot --nfse). */
  nfseEnabled?: boolean;
  /** The default nota service was saved (PUT /v1/app/nfse/service). */
  nfseReady?: boolean;
}

/** Input of POST /v1/app/customers/:customerId/charges */
export interface CreateCustomerChargeInput {
  /** Orders to charge, oldest first (the app's `Debtor.orders` order). */
  orderIds: string[];
  value: number;
  dueDate?: string;
  customerTaxId?: string;
}

/** Input of POST /v1/app/orders/:orderId/charges */
export interface CreateChargeInput {
  value: number;
  mode: ChargeMode;
  installmentCount?: number;
  dueDate?: string;
  customerTaxId?: string;
}

// ============================================================================
// Asaas API DTOs (only the fields PraticOS uses)
// ============================================================================

export interface AsaasErrorItem {
  code: string;
  description: string;
}

/** GET /v3/myAccount/commercialInfo */
export interface AsaasAccountInfo {
  name?: string;
  companyName?: string;
  tradingName?: string;
  email?: string;
  cpfCnpj?: string;
}

export interface AsaasWallet {
  id: string;
}

export type AsaasWebhookEventType =
  | 'PAYMENT_RECEIVED'
  | 'PAYMENT_CONFIRMED'
  | 'PAYMENT_OVERDUE'
  | 'PAYMENT_REFUNDED'
  | 'PAYMENT_DELETED'
  | 'PAYMENT_RECEIVED_IN_CASH_UNDONE'
  | 'PAYMENT_PARTIALLY_REFUNDED'
  | 'INVOICE_CREATED'
  | 'INVOICE_UPDATED'
  | 'INVOICE_SYNCHRONIZED'
  | 'INVOICE_AUTHORIZED'
  | 'INVOICE_PROCESSING_CANCELLATION'
  | 'INVOICE_CANCELED'
  | 'INVOICE_CANCELLATION_DENIED'
  | 'INVOICE_ERROR';

export interface AsaasCreateWebhookInput {
  name: string;
  url: string;
  email: string;
  enabled: boolean;
  interrupted: boolean;
  apiVersion: number;
  authToken: string;
  sendType: 'SEQUENTIALLY' | 'NON_SEQUENTIALLY';
  events: AsaasWebhookEventType[];
}

export interface AsaasWebhook {
  id: string;
}

/** Customer fields the city needs on a nota (e-mail and address with CEP). */
export interface AsaasCustomerContact {
  email?: string | null;
  postalCode?: string | null;
  address?: string | null;
  addressNumber?: string | null;
  complement?: string | null;
  province?: string | null;
}

export interface AsaasCustomer extends AsaasCustomerContact {
  id: string;
  name: string;
  cpfCnpj?: string;
  externalReference?: string | null;
}

export interface AsaasCreateCustomerInput extends AsaasCustomerContact {
  name: string;
  cpfCnpj: string;
  email?: string;
  externalReference: string;
  notificationDisabled: boolean;
}

export type AsaasBillingType = 'UNDEFINED' | 'BOLETO' | 'CREDIT_CARD' | 'PIX';

export interface AsaasCreatePaymentInput {
  customer: string;
  billingType: AsaasBillingType;
  dueDate: string;
  description: string;
  externalReference: string;
  value?: number;
  installmentCount?: number;
  totalValue?: number;
}

export interface AsaasPayment {
  id: string;
  customer: string;
  status: string;
  billingType: AsaasBillingType;
  value: number;
  dueDate: string;
  invoiceUrl: string;
  externalReference?: string | null;
  installment?: string | null;
  installmentNumber?: number | null;
  /** GET /payments/{id} of a removed payment. */
  deleted?: boolean;
}

export interface AsaasList<T> {
  object: 'list';
  hasMore: boolean;
  totalCount: number;
  limit: number;
  offset: number;
  data: T[];
}

// ============================================================================
// Webhook (POST /webhooks/asaas/:companyId)
// ============================================================================

/** Webhook events PraticOS subscribes to (same list as the webhook registration). */
export type AsaasWebhookEventName = AsaasWebhookEventType;

/** Subset of the Asaas payment object sent in webhook events (extra fields are ignored). */
export interface AsaasPaymentEvent {
  id: string;
  value: number;
  netValue?: number;
  /** PIX | BOLETO | CREDIT_CARD | DEBIT_CARD | UNDEFINED | RECEIVED_IN_CASH ... */
  billingType: string;
  status: string;
  /** '<companyId>:<orderId>:<chargeId>' (createOrderCharge) or '<companyId>:cc:<chargeId>' (createCustomerCharge). */
  externalReference?: string | null;
  /** Installment id, only for installment payments. */
  installment?: string | null;
  installmentNumber?: number | null;
  description?: string | null;
  /** Asaas receipt page of a confirmed/received payment (absent in older or pending payloads). */
  transactionReceiptUrl?: string | null;
  /** Refunds of the payment (PAYMENT_PARTIALLY_REFUNDED), when Asaas sends them. */
  refunds?: Array<{ value?: number; status?: string }> | null;
}

export interface AsaasWebhookEvent {
  /** Unique event id (e.g. 'evt_05b7...&368604920'), used for idempotency. */
  id: string;
  /** Event name; only AsaasWebhookEventName values are handled. */
  event: string;
  dateCreated?: string;
  payment?: AsaasPaymentEvent;
  /** INVOICE_* events. */
  invoice?: AsaasInvoice;
}

// ============================================================================
// NFS-e (nota fiscal de serviço) through Asaas — docs/NFSE_ASAAS.md
// ============================================================================

/**
 * Status of a PraticOS invoice. 'creating' is ours (doc written before the
 * Asaas call); the others mirror the Asaas invoice status.
 */
export type InvoiceStatus =
  | 'creating'
  | 'scheduled'
  | 'synchronized'
  | 'authorized'
  | 'processingCancellation'
  | 'cancellationDenied'
  | 'canceled'
  | 'error';

/** Taxes sent on every invoice (percent). Required by Asaas. */
export interface InvoiceTaxes {
  retainIss: boolean;
  iss: number;
  pis: number;
  cofins: number;
  csll: number;
  inss: number;
  ir: number;
}

/**
 * companies/{cid}/settings/nfse — the company's default service for notas.
 * Written only by the server (PUT /v1/app/nfse/service); read by financial roles.
 */
export interface NfseServiceSettings {
  /** Asaas municipal service id (when the city publishes a list). */
  municipalServiceId?: string | null;
  /** Municipal service code typed by hand (city without a list / national portal). */
  municipalServiceCode?: string | null;
  municipalServiceName: string;
  taxes: InvoiceTaxes;
  /** Template of the service description; `{os}` and `{servicos}` are replaced. */
  descriptionTemplate: string;
  /** When a nota is issued without anyone asking (absent: 'manual'). */
  autoIssue?: NfseAutoIssue;
  /** Asaas account the service was set up on (another account has its own setup). */
  asaasEnvironment?: AsaasEnvironment;
  asaasWalletId?: string | null;
  updatedAt: string;
  updatedBy: UserAggr;
}

/**
 * When the server issues the nota of an order by itself: never ('manual',
 * default), when the order becomes paid, or when it becomes done.
 */
export type NfseAutoIssue = 'manual' | 'paid' | 'completed';

/** One order covered by an invoice and the services value it contributed. */
export interface InvoiceOrderPart {
  orderId: string;
  orderNumber?: number | null;
  value: number;
}

/**
 * companies/{cid}/invoices/{invoiceId}: one NFS-e, for one order (default)
 * or several orders of the same customer. Written only by the server.
 */
export interface NfseInvoice {
  id: string;
  asaasInvoiceId?: string;
  status: InvoiceStatus;
  customer: { id: string; name?: string | null };
  /** Order ids covered (array-contains queries), same order as `orders`. */
  orderIds: string[];
  orders: InvoiceOrderPart[];
  value: number;
  serviceDescription: string;
  observations: string;
  effectiveDate: string; // YYYY-MM-DD
  municipalServiceName: string;
  number?: string | null;
  validationCode?: string | null;
  pdfUrl?: string | null;
  xmlUrl?: string | null;
  /** Asaas statusDescription (error or cancellation reason), shown only as detail. */
  statusDescription?: string | null;
  /** Our error code when an automatic nota could not be issued (status 'error'). */
  errorCode?: string | null;
  /** Issued by the server on its own (NfseServiceSettings.autoIssue). */
  auto?: boolean;
  /** PraticOS gave up on it (issue refused) and canceled it on Asaas: its events are ignored. */
  canceledOnAsaas?: boolean;
  createdBy: UserAggr;
  createdAt: string;
  updatedAt?: string;
  authorizedAt?: string;
  canceledAt?: string;
  /** Asaas account the nota was issued on (cancel only through the same account). */
  asaasEnvironment?: AsaasEnvironment;
  asaasWalletId?: string | null;
  /**
   * A nota with error came back to life on Asaas after its orders already had
   * another nota: kept for the record, does not lock the orders (see syncInvoice).
   */
  conflict?: boolean;
}

/** Input of POST /v1/app/nfse/orders/:orderId/invoices and /customers/:customerId/invoices */
export interface CreateInvoiceInput {
  orderIds: string[];
  serviceDescription?: string;
  effectiveDate?: string;
  customerTaxId?: string;
  /** Missing customer data typed in the issue sheet (sent to the Asaas customer). */
  customerData?: AsaasCustomerContact;
}

export type AsaasInvoiceStatus =
  | 'SCHEDULED'
  | 'SYNCHRONIZED'
  | 'AUTHORIZED'
  | 'PROCESSING_CANCELLATION'
  | 'CANCELED'
  | 'CANCELLATION_DENIED'
  | 'ERROR';

/** POST /v3/invoices */
export interface AsaasCreateInvoiceInput {
  customer: string;
  serviceDescription: string;
  observations: string;
  externalReference: string;
  value: number;
  deductions: number;
  effectiveDate: string;
  municipalServiceId?: string | null;
  municipalServiceCode?: string | null;
  municipalServiceName: string;
  taxes: InvoiceTaxes;
}

/** Asaas invoice object (API responses and the `invoice` of INVOICE_* events). */
export interface AsaasInvoice {
  id: string;
  status: AsaasInvoiceStatus | string;
  customer?: string | null;
  payment?: string | null;
  statusDescription?: string | null;
  pdfUrl?: string | null;
  xmlUrl?: string | null;
  number?: string | null;
  validationCode?: string | null;
  value?: number;
  effectiveDate?: string | null;
  externalReference?: string | null;
}

/** GET /v3/fiscalInfo (only the fields PraticOS shows). */
export interface AsaasFiscalInfo {
  email?: string | null;
  municipalInscription?: string | null;
  simplesNacional?: boolean | null;
  cnae?: string | null;
  specialTaxRegime?: string | null;
  serviceListItem?: string | null;
  rpsSerie?: string | null;
  rpsNumber?: number | null;
  loteNumber?: number | null;
  passwordSent?: boolean | null;
  accessTokenSent?: boolean | null;
  certificateSent?: boolean | null;
}

/** POST /v3/fiscalInfo (multipart). City credentials/certificate stay in the Asaas panel. */
export interface AsaasSaveFiscalInfoInput {
  email: string;
  simplesNacional: boolean;
  municipalInscription?: string;
  cnae?: string;
  specialTaxRegime?: string;
  serviceListItem?: string;
  rpsSerie?: string;
  rpsNumber?: number;
  loteNumber?: number;
}

/** GET /v3/fiscalInfo/municipalOptions */
export interface AsaasMunicipalOptions {
  authenticationType?: 'CERTIFICATE' | 'TOKEN' | 'USER_AND_PASSWORD' | string | null;
  supportsCancellation?: boolean | null;
  usesSpecialTaxRegimes?: boolean | null;
  usesServiceListItem?: boolean | null;
  specialTaxRegimesList?: Array<{ label: string; value: string }> | null;
  municipalInscriptionHelp?: string | null;
  specialTaxRegimeHelp?: string | null;
  serviceListItemHelp?: string | null;
  digitalCertificatedHelp?: string | null;
  municipalServiceCodeHelp?: string | null;
}

/** GET /v3/fiscalInfo/services item */
export interface AsaasMunicipalService {
  id: string;
  description: string;
  issTax?: number | null;
}
