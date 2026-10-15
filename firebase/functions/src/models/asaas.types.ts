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
  /** Server-only: receiveInCash in progress; a webhook for it must not book. */
  settlingOutsideAt?: string;
  /** Server-only: lease of the outside-payment reconciliation (ISO). */
  adjustingUntil?: string;
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
  /** Server-only: receiveInCash in progress; a webhook for it must not book. */
  settlingOutsideAt?: string;
  /** Server-only: lease of the outside-payment reconciliation (ISO). */
  adjustingUntil?: string;
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
  | 'PAYMENT_PARTIALLY_REFUNDED';

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

export interface AsaasCustomer {
  id: string;
  name: string;
  cpfCnpj?: string;
  externalReference?: string | null;
}

export interface AsaasCreateCustomerInput {
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
}
