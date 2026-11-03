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

/** Project bucket: from FIREBASE_CONFIG in Cloud Functions, else the project's default. */
export function projectBucket(): string {
  try {
    const bucket = JSON.parse(process.env.FIREBASE_CONFIG ?? '{}').storageBucket;
    if (typeof bucket === 'string' && bucket) return bucket;
  } catch {
    // FIREBASE_CONFIG is not JSON: fall through
  }
  return process.env.STORAGE_BUCKET || 'praticos.appspot.com';
}

/** Path of a Storage download URL of the project bucket, or null for any other URL. */
function storagePathOfUrl(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:') return null;
  const bucket = projectBucket();
  const prefix =
    url.hostname === 'firebasestorage.googleapis.com' ? `/v0/b/${bucket}/o/` :
    url.hostname === 'storage.googleapis.com' ? `/${bucket}/` : null;
  if (!prefix || !url.pathname.startsWith(prefix)) return null;
  try {
    return decodeURIComponent(url.pathname.slice(prefix.length));
  } catch {
    return null;
  }
}

/** [path] sits inside [prefix] with no `..` step out of it. */
export function isInsideFolder(prefix: string, path: unknown): path is string {
  return typeof path === 'string' && path.startsWith(prefix) && !path.includes('..') && !path.includes('\\');
}

/**
 * The file must sit under [prefix] (the folder the Storage rules give to that
 * order or receipt), be an image or a PDF, and its URL must be the download
 * URL of that same file in the project bucket.
 */
export function validateReceiptFile(prefix: string, file: ReceiptFileInput | undefined): void {
  if (!file) return;
  if (
    !isInsideFolder(prefix, file.storagePath) ||
    typeof file.url !== 'string' ||
    storagePathOfUrl(file.url) !== file.storagePath ||
    !FILE_TYPES.test(file.contentType ?? '')
  ) {
    throw new AsaasServiceError('INVALID_FILE', 'Invalid receipt file');
  }
}

/** Clock difference tolerated between the client and the server. */
const CLOCK_SKEW_MS = 5 * 60 * 1000;
/** A payment may carry the day before the order was created (time zones). */
const BEFORE_CREATION_MS = 24 * 60 * 60 * 1000;

/**
 * ISO date the money came in: a valid date, not in the future and, when
 * [notBefore] (the order creation) is known, not before that day.
 */
export function validatePaidAt(paidAt: string, notBefore?: unknown): string {
  const date = new Date(paidAt);
  const time = date.getTime();
  const created = toTime(notBefore);
  const floor = created === null ? null : created - BEFORE_CREATION_MS;
  if (Number.isNaN(time) || time > Date.now() + CLOCK_SKEW_MS || (floor !== null && time < floor)) {
    throw new AsaasServiceError('INVALID_PAID_AT', 'Invalid payment date');
  }
  return date.toISOString();
}

/** Milliseconds of an ISO string, Date or Firestore Timestamp; null when unknown. */
function toTime(value: unknown): number | null {
  if (!value) return null;
  if (typeof value === 'string' || value instanceof Date) {
    const t = new Date(value).getTime();
    return Number.isNaN(t) ? null : t;
  }
  const v = value as { toDate?: () => Date; seconds?: number; _seconds?: number };
  if (typeof v.toDate === 'function') return v.toDate().getTime();
  const seconds = v.seconds ?? v._seconds;
  return typeof seconds === 'number' ? seconds * 1000 : null;
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
