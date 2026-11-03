/**
 * Version of an order for `expectedUpdatedAt` (409 ORDER_CHANGED): the stored
 * `updatedAt` as is, never converted by time zone.
 *
 * The app writes `updatedAt` as local time without a zone (Dart
 * `toIso8601String()`, with microseconds); the server writes ISO with `Z`;
 * old documents carry a Timestamp; many have none. Read as an instant, the
 * text without a zone depends on the reader's zone (browser vs Function), so
 * the client gets this opaque value (`version`) and sends it back unchanged.
 */

const ZONED = /(?:Z|[+-]\d{2}:?\d{2})$/i;

function timestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  const stamp = value as { toMillis?: () => number; seconds?: unknown; nanoseconds?: unknown; _seconds?: unknown; _nanoseconds?: unknown } | null;
  if (!stamp || typeof stamp !== 'object') return null;
  if (typeof stamp.toMillis === 'function') return stamp.toMillis();
  const seconds = typeof stamp.seconds === 'number' ? stamp.seconds : typeof stamp._seconds === 'number' ? stamp._seconds : null;
  if (seconds === null) return null;
  const nanos = typeof stamp.nanoseconds === 'number' ? stamp.nanoseconds : typeof stamp._nanoseconds === 'number' ? stamp._nanoseconds : 0;
  return seconds * 1000 + Math.floor(nanos / 1e6);
}

/** Text stays text; a Timestamp (or Date) becomes its millis; a number its digits; nothing is null. */
export function orderVersion(stored: unknown): string | null {
  if (stored === undefined || stored === null || stored === '') return null;
  if (typeof stored === 'string') return stored;
  if (typeof stored === 'number' && Number.isFinite(stored)) return String(stored);
  const millis = timestampMillis(stored);
  return millis === null ? null : String(millis);
}

/**
 * Does the version the client saw still match? Only the exact opaque version
 * (`orderVersion`). An ISO instant with a zone is also accepted against a value
 * that is itself an instant (a Timestamp, or text with a zone) when it is the
 * same instant. Against text without a zone (saved by the app) anything but the
 * raw text is 409: a screen holding the server's `…Z` version must not write
 * over what the app saved after it (revisao-pr515-3 R1). Nothing stored:
 * nothing to compare, never a refusal.
 */
export function versionMatches(stored: unknown, expected: string): boolean {
  const version = orderVersion(stored);
  if (version === null || expected === version) return true;
  if (!ZONED.test(expected)) return false;
  const expectedMillis = Date.parse(expected);
  if (Number.isNaN(expectedMillis)) return false;
  if (typeof stored === 'string') return ZONED.test(stored) && Date.parse(stored) === expectedMillis;
  return Number(version) === expectedMillis;
}

const TYPE_RANK = (value: unknown): number => {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'boolean') return 1;
  if (typeof value === 'number') return 2;
  if (timestampMillis(value) !== null) return 3;
  if (typeof value === 'string') return 4;
  return 5;
};

/**
 * Firestore's order of values: null < boolean < number < Timestamp < text;
 * text by UTF-8 bytes (not by time: "10:00:00Z" comes after "10:00:00.5Z").
 */
export function compareFirestoreValues(a: unknown, b: unknown): number {
  const rankA = TYPE_RANK(a);
  const rankB = TYPE_RANK(b);
  if (rankA !== rankB) return rankA - rankB;
  if (rankA === 2) return (a as number) - (b as number);
  if (rankA === 1) return Number(a) - Number(b);
  if (rankA === 3) {
    const stampA = a as { seconds?: number; _seconds?: number; nanoseconds?: number; _nanoseconds?: number; toMillis?: () => number };
    const stampB = b as typeof stampA;
    const seconds = (s: typeof stampA) => s.seconds ?? s._seconds;
    const nanos = (s: typeof stampA) => s.nanoseconds ?? s._nanoseconds ?? 0;
    if (seconds(stampA) !== undefined && seconds(stampB) !== undefined) {
      return (seconds(stampA)! - seconds(stampB)!) || nanos(stampA) - nanos(stampB);
    }
    return (timestampMillis(a) ?? 0) - (timestampMillis(b) ?? 0);
  }
  if (rankA === 4) return Buffer.compare(Buffer.from(a as string, 'utf8'), Buffer.from(b as string, 'utf8'));
  return 0;
}
