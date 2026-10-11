/**
 * AI assistant pilot switch and monthly quota (docs/AI_ORDER_ASSIST.md).
 *
 * - companies/{cid}/settings/ai   { enabled: boolean, monthlyLimit?: number }
 *   Pilot switch, written only by admins/scripts (Admin SDK). The Firestore
 *   rules have no match for it, so app users can neither read nor write it.
 *   Missing doc or enabled != true → the assistant is off for the company.
 * - companies/{cid}/aiUsage/{YYYY-MM}  { count, limit, updatedAt }
 *   One counter per calendar month (UTC). A new month is a new document, so
 *   no reset job is needed. Also without client rules (Admin SDK only).
 *
 * Every call to the model counts, applied or not (spec 2026-10-09 §4.2). A call
 * that fails before the model answers (our error, model unavailable) is
 * released so the user is not charged for it.
 */

import { db, FieldValue } from '../firestore.service';
import type { SubscriptionPlan } from '../../models/types';

/** Requests per month by plan (decided 2026-10-09). -1 = unlimited. */
export const AI_REQUESTS_PER_MONTH: Record<SubscriptionPlan, number> = {
  free: 10,
  starter: 150,
  pro: 400,
  business: 1000,
};

export interface AiSettings {
  enabled: boolean;
  /** Overrides the plan limit when set (pilot). -1 = unlimited. */
  monthlyLimit?: number;
}

export type QuotaReservation =
  | { ok: true; used: number; limit: number; monthKey: string }
  | { ok: false; used: number; limit: number; monthKey: string };

/** Calendar month key in UTC, e.g. "2026-10". */
export function monthKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 7);
}

function isPlan(value: unknown): value is SubscriptionPlan {
  return typeof value === 'string' && value in AI_REQUESTS_PER_MONTH;
}

function validLimit(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= -1;
}

/** Limit for the company: pilot override, else its plan (missing plan = free). */
export function resolveAiLimit(plan: unknown, settings: AiSettings | null): number {
  if (settings && validLimit(settings.monthlyLimit)) return settings.monthlyLimit;
  return AI_REQUESTS_PER_MONTH[isPlan(plan) ? plan : 'free'];
}

export async function getAiSettings(companyId: string): Promise<AiSettings | null> {
  const snap = await db.collection('companies').doc(companyId).collection('settings').doc('ai').get();
  if (!snap.exists) return null;
  const data = snap.data() as Record<string, unknown>;
  return {
    enabled: data.enabled === true,
    monthlyLimit: validLimit(data.monthlyLimit) ? data.monthlyLimit : undefined,
  };
}

function usageRef(companyId: string, key: string) {
  return db.collection('companies').doc(companyId).collection('aiUsage').doc(key);
}

/**
 * Counts one request for the company in this month, atomically. Refuses (and
 * counts nothing) when the month's limit is already reached.
 */
export async function reserveAiRequest(
  companyId: string,
  settings: AiSettings | null,
  now: Date = new Date(),
): Promise<QuotaReservation> {
  const key = monthKey(now);
  const companyRef = db.collection('companies').doc(companyId);
  const ref = usageRef(companyId, key);
  return db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const [companySnap, usageSnap] = await Promise.all([tx.get(companyRef), tx.get(ref)]);
    const plan = (companySnap.data() as Record<string, unknown> | undefined)?.subscription as
      | { plan?: unknown }
      | undefined;
    const limit = resolveAiLimit(plan?.plan, settings);
    const current = Number((usageSnap.data() as Record<string, unknown> | undefined)?.count ?? 0) || 0;
    if (limit !== -1 && current >= limit) {
      return { ok: false, used: current, limit, monthKey: key } as QuotaReservation;
    }
    tx.set(ref, { count: current + 1, limit, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, used: current + 1, limit, monthKey: key } as QuotaReservation;
  });
}

/** Gives back a reserved request (the model never answered). Never below 0. */
export async function releaseAiRequest(companyId: string, key: string): Promise<void> {
  const ref = usageRef(companyId, key);
  await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const snap = await tx.get(ref);
    const current = Number((snap.data() as Record<string, unknown> | undefined)?.count ?? 0) || 0;
    if (current <= 0) return;
    tx.set(ref, { count: current - 1, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
}
