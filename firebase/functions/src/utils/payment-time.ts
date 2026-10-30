/** An ISO string that ends with 'Z' or an offset ('+02:00', '-0300'). */
const ZONED_ISO = /(?:[zZ]|[+-]\d{2}:?\d{2})$/;

/**
 * The app writes `createdAt` as the phone's local time without a zone
 * ('2026-10-29T17:39:47.433185'); Date.parse would read it as UTC here and
 * put a payment made right after the link three hours before it. Such
 * strings are read as Brazil time (UTC-3, no daylight saving since 2019).
 */
export function parseTransactionTime(value: string): number {
  const trimmed = value.trim();
  if (ZONED_ISO.test(trimmed)) return Date.parse(trimmed);
  const withTime = /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? `${trimmed}T00:00:00` : trimmed;
  return Date.parse(`${withTime}-03:00`);
}

export function toMillis(value: unknown): number {
  if (!value) return NaN;
  if (typeof value === 'string') return parseTransactionTime(value);
  if (value instanceof Date) return value.getTime();
  const maybe = value as { toMillis?: () => number; toDate?: () => Date };
  if (typeof maybe.toMillis === 'function') return maybe.toMillis();
  if (typeof maybe.toDate === 'function') return maybe.toDate().getTime();
  return NaN;
}

interface DatedTransaction {
  type?: string;
  paidAt?: unknown;
  createdAt?: unknown;
}

/**
 * When the money of the latest `payment` transaction came in (UTC ISO), or
 * null without dated payments. Same date the app counts a payment on:
 * `paidAt`, or `createdAt` on old payments.
 */
export function latestPaymentAt(transactions: DatedTransaction[] | undefined): string | null {
  const times = (transactions ?? [])
    .filter((t) => t.type === 'payment')
    .map((t) => toMillis(t.paidAt ?? t.createdAt))
    .filter(Number.isFinite);
  return times.length > 0 ? new Date(Math.max(...times)).toISOString() : null;
}
