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
}

/** companies/{companyId}/settings/payments */
export interface PaymentSettingsDoc {
  asaasEnabled: boolean;
  asaasConnected: boolean;
  asaasAccountName?: string;
  asaasEnvironment?: AsaasEnvironment;
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
  | 'PAYMENT_DELETED';

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
  /** '<companyId>:<orderId>:<chargeId>' set by createOrderCharge. */
  externalReference?: string | null;
  /** Installment id, only for installment payments. */
  installment?: string | null;
  installmentNumber?: number | null;
  description?: string | null;
}

export interface AsaasWebhookEvent {
  /** Unique event id (e.g. 'evt_05b7...&368604920'), used for idempotency. */
  id: string;
  /** Event name; only AsaasWebhookEventName values are handled. */
  event: string;
  dateCreated?: string;
  payment?: AsaasPaymentEvent;
}
