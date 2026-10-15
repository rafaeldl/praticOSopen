/**
 * Webhook events PraticOS subscribes on a company's Asaas account.
 * Dependency-free so the admin scripts can import it.
 */

import { AsaasCreateWebhookInput } from '../../models/asaas.types';

/** NFS-e events (docs/NFSE_ASAAS.md). */
export const NFSE_WEBHOOK_EVENTS: AsaasCreateWebhookInput['events'] = [
  'INVOICE_CREATED',
  'INVOICE_UPDATED',
  'INVOICE_SYNCHRONIZED',
  'INVOICE_AUTHORIZED',
  'INVOICE_PROCESSING_CANCELLATION',
  'INVOICE_CANCELED',
  'INVOICE_CANCELLATION_DENIED',
  'INVOICE_ERROR',
];

export const ASAAS_WEBHOOK_EVENTS: AsaasCreateWebhookInput['events'] = [
  'PAYMENT_RECEIVED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_OVERDUE',
  'PAYMENT_REFUNDED',
  'PAYMENT_DELETED',
  'PAYMENT_RECEIVED_IN_CASH_UNDONE',
  'PAYMENT_PARTIALLY_REFUNDED',
  ...NFSE_WEBHOOK_EVENTS,
];

/**
 * Whether the connection's webhook receives the NFS-e events. Connections
 * made before they were added have no `webhookEvents` and must reconnect,
 * or a city rejection would never reach PraticOS.
 */
export function hasNfseWebhookEvents(webhookEvents: readonly string[] | undefined | null): boolean {
  if (!Array.isArray(webhookEvents)) return false;
  return NFSE_WEBHOOK_EVENTS.every((event) => webhookEvents.includes(event));
}
