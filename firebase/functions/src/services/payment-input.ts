/**
 * Checks of what a client sends with a payment: the date the money came in
 * and the proof file (uploaded to Storage by the client before the call).
 * Shared by the order payment routes and the customer receipt ("Receber de
 * João"), so both accept the same things.
 */
import { AsaasServiceError } from './asaas/errors';

export interface ReceiptFileInput {
  url: string;
  storagePath: string;
  fileName?: string;
  contentType: string;
}

const FILE_TYPES = /^(image\/[a-z0-9.+-]+|application\/pdf)$/;

/**
 * The file must sit under [prefix] (the folder the Storage rules give to that
 * order or receipt), be an image or a PDF and come from an https URL.
 */
export function validateReceiptFile(prefix: string, file: ReceiptFileInput | undefined): void {
  if (!file) return;
  let url: URL | null = null;
  try {
    url = new URL(file.url);
  } catch {
    url = null;
  }
  if (
    typeof file.storagePath !== 'string' ||
    !file.storagePath.startsWith(prefix) ||
    file.storagePath.includes('..') ||
    !url ||
    url.protocol !== 'https:' ||
    !FILE_TYPES.test(file.contentType ?? '')
  ) {
    throw new AsaasServiceError('INVALID_FILE', 'Invalid receipt file');
  }
}

/** ISO date the money came in: a valid date, at most one day ahead (time zones). */
export function validatePaidAt(paidAt: string): string {
  const date = new Date(paidAt);
  const tomorrow = Date.now() + 24 * 60 * 60 * 1000;
  if (Number.isNaN(date.getTime()) || date.getTime() > tomorrow) {
    throw new AsaasServiceError('INVALID_PAID_AT', 'Invalid payment date');
  }
  return date.toISOString();
}

/** Storage folder of the receipts of one order. */
export function orderFilesPrefix(companyId: string, orderId: string): string {
  return `tenants/${companyId}/orders/${orderId}/`;
}

/** Storage folder of a customer receipt (shared by the orders it covers). */
export function receiptFilesPrefix(companyId: string, receiptId: string): string {
  return `tenants/${companyId}/receipts/${receiptId}/`;
}

/** A customer receipt's file is shared by several orders: never deleted from one of them. */
export function isSharedReceiptPath(storagePath: string | undefined): boolean {
  return !!storagePath && /^tenants\/[^/]+\/receipts\//.test(storagePath);
}
