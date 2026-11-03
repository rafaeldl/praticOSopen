/**
 * Wrong invite codes per user (GET /v1/app/invites/:token and accept by code).
 *
 * The counter lives in Firestore (`inviteCodeAttempts/{uid}`, server only) so
 * it holds across instances: after MAX_WRONG_CODES unknown codes within an
 * hour the user is refused (429) until the hour is over, also for a right code.
 */
import { db } from './firestore.service';
import { toDate } from '../models/types';

export const MAX_WRONG_CODES = 10;
export const WRONG_CODES_WINDOW_MS = 60 * 60 * 1000;
const COLLECTION = 'inviteCodeAttempts';

interface Attempts {
  windowStart?: string;
  failures?: number;
}

function ref(userId: string) {
  return db.collection(COLLECTION).doc(userId);
}

function windowIsOpen(data: Attempts | undefined, now: number): boolean {
  const start = toDate(data?.windowStart)?.getTime();
  return start !== undefined && now - start < WRONG_CODES_WINDOW_MS;
}

/** True when the user already used up the wrong codes of this hour. */
export async function isBlocked(userId: string): Promise<boolean> {
  const snap = await ref(userId).get();
  const data = snap.exists ? (snap.data() as Attempts) : undefined;
  return windowIsOpen(data, Date.now()) && (data?.failures ?? 0) >= MAX_WRONG_CODES;
}

/** Counts one unknown code for the user. */
export async function recordWrongCode(userId: string): Promise<void> {
  const docRef = ref(userId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    const data = snap.exists ? (snap.data() as Attempts) : undefined;
    const now = Date.now();
    const next: Attempts = windowIsOpen(data, now)
      ? { windowStart: data?.windowStart, failures: (data?.failures ?? 0) + 1 }
      : { windowStart: new Date(now).toISOString(), failures: 1 };
    tx.set(docRef, next);
  });
}
