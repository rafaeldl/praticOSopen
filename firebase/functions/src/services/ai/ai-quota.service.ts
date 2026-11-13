/**
 * AI assistant switches and monthly quota (docs/AI_ORDER_ASSIST.md).
 *
 * - config/ai   { enabledForAll?: boolean, defaultProvider?: 'gemini'|'claude', financeActions?: boolean }
 *   Global switch for every company. Read at most once a minute per instance.
 * - companies/{cid}/settings/ai   { enabled?: boolean, monthlyLimit?: number, provider?: ..., financeActions?: boolean }
 *   Per company. Each field it has wins over the global one, so a company can
 *   be turned off (or kept on Gemini) while the rest follows config/ai.
 *   No doc and no global switch → the assistant is off.
 * Both are written only by admins/scripts (Admin SDK, `npm run ai`). The
 * Firestore rules have no match for them, so app users can neither read nor
 * write them.
 * - companies/{cid}/aiUsage/{YYYY-MM}  { count, limit, day, dayCount, updatedAt }
 *   One counter per calendar month (UTC). A new month is a new document, so
 *   no reset job is needed. `day` (YYYY-MM-DD, UTC) and `dayCount` keep the
 *   day's requests for the daily ceiling (aiPerDay: Free, Starter and Pro); a new
 *   day starts again at 0. Also without client rules (Admin SDK only).
 *
 * The ceilings come from the plan table (docs/plans/plans.json): aiPerMonth
 * and aiPerDay of the plan in force (effectivePlan: an expired plan is Free).
 *
 * Every call to the model counts, applied or not (spec 2026-10-09 §4.2). A call
 * that fails before the model answers (our error, model unavailable) is
 * released so the user is not charged for it.
 */

import { db, FieldValue } from '../firestore.service';
import type { SubscriptionPlan } from '../../models/types';
import { isLlmProvider, type LlmProvider } from './llm.client';
import { PLAN_IDS } from '../plan-table.generated';
import { currentPlanRows, planRow, tableVersionOf } from '../subscription-plans';
import { effectivePlan } from '../plan-limits.service';
import { checkCompanyPlanFeature, type PlanFeature } from '../plan-features.service';

/** Requests per month by plan (docs/plans/plans.json). -1 = unlimited. */
export const AI_REQUESTS_PER_MONTH: Record<SubscriptionPlan, number> = Object.fromEntries(
  PLAN_IDS.map((plan) => [plan, currentPlanRows()[plan].aiPerMonth]),
) as Record<SubscriptionPlan, number>;

export interface AiSettings {
  enabled: boolean;
  /** Overrides the plan limit when set (pilot). -1 = unlimited. */
  monthlyLimit?: number;
  /** Model provider ('gemini' | 'claude'); unset = AI_PROVIDER env, else gemini. */
  provider?: LlmProvider;
  /** The assistant may propose payments, discounts and status changes. */
  financeActions?: boolean;
}

export type QuotaReservation =
  | { ok: true; used: number; limit: number; monthKey: string; dayKey: string }
  | {
      ok: false;
      used: number;
      limit: number;
      monthKey: string;
      dayKey: string;
      /** Which ceiling was reached; on 'day', used and limit are the day's. */
      period: 'month' | 'day';
    };

/** Calendar month key in UTC, e.g. "2026-10". */
export function monthKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 7);
}

/** Calendar day key in UTC, e.g. "2026-10-09". */
export function dayKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function validLimit(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= -1;
}

type Json = Record<string, unknown>;

/** companies/{id}.subscription, or just a plan name. */
const subscriptionOf = (value: unknown): Json | null =>
  typeof value === 'string' ? { plan: value } : value && typeof value === 'object' ? (value as Json) : null;

/** Monthly limit for the company: pilot override, else the plan in force (missing plan = free). */
export function resolveAiLimit(subscription: unknown, settings: AiSettings | null, now: Date = new Date()): number {
  if (settings && validLimit(settings.monthlyLimit)) return settings.monthlyLimit;
  const sub = subscriptionOf(subscription);
  return planRow(effectivePlan(sub, now), tableVersionOf(sub)).aiPerMonth;
}

/** Daily limit: the plan's aiPerDay; none while a pilot override sets the month. */
export function resolveAiDailyLimit(subscription: unknown, settings: AiSettings | null, now: Date = new Date()): number {
  if (settings && validLimit(settings.monthlyLimit)) return -1;
  const sub = subscriptionOf(subscription);
  return planRow(effectivePlan(sub, now), tableVersionOf(sub)).aiPerDay;
}

/**
 * Combines the global switch (config/ai) with the company's own settings/ai.
 * A field the company sets wins; otherwise the global one applies.
 */
export function resolveAiSettings(
  company: Record<string, unknown> | undefined,
  global: Record<string, unknown> | undefined,
): AiSettings {
  const enabled =
    typeof company?.enabled === 'boolean' ? company.enabled : global?.enabledForAll === true;
  const provider = isLlmProvider(company?.provider)
    ? company?.provider
    : isLlmProvider(global?.defaultProvider)
      ? global?.defaultProvider
      : undefined;
  const financeActions =
    typeof company?.financeActions === 'boolean' ? company.financeActions : global?.financeActions === true;
  return {
    enabled,
    monthlyLimit: validLimit(company?.monthlyLimit) ? company?.monthlyLimit : undefined,
    provider: provider as LlmProvider | undefined,
    financeActions,
  };
}

const GLOBAL_TTL_MS = 60_000;
let globalCache: { data: Record<string, unknown> | undefined; at: number } | undefined;

/** Clears the cached config/ai (tests). */
export function resetAiGlobalCache(): void {
  globalCache = undefined;
}

async function getGlobalAiConfig(now = Date.now()): Promise<Record<string, unknown> | undefined> {
  if (globalCache && now - globalCache.at < GLOBAL_TTL_MS) return globalCache.data;
  const snap = await db.collection('config').doc('ai').get();
  globalCache = { data: snap.exists ? (snap.data() as Record<string, unknown>) : undefined, at: now };
  return globalCache.data;
}

export async function getAiSettings(
  companyId: string,
  planHasFeature: (companyId: string, feature: PlanFeature) => Promise<boolean> = async (id, feature) =>
    (await checkCompanyPlanFeature(id, feature)).allowed,
): Promise<AiSettings> {
  const [snap, global] = await Promise.all([
    db.collection('companies').doc(companyId).collection('settings').doc('ai').get(),
    getGlobalAiConfig(),
  ]);
  const company = snap.exists ? (snap.data() as Record<string, unknown>) : undefined;
  const settings = resolveAiSettings(company, global);
  // Payments, discounts and status changes by the assistant are Pro (#724).
  if (settings.financeActions && !(await planHasFeature(companyId, 'aiFinance'))) {
    return { ...settings, financeActions: false };
  }
  return settings;
}

/** This month's use and limit, without counting anything (status for the app). */
export async function getAiUsage(
  companyId: string,
  settings: AiSettings | null,
  now: Date = new Date(),
): Promise<{ used: number; limit: number }> {
  const companyRef = db.collection('companies').doc(companyId);
  const [companySnap, usageSnap] = await Promise.all([companyRef.get(), usageRef(companyId, monthKey(now)).get()]);
  const subscription = (companySnap.data() as Json | undefined)?.subscription;
  const used = Number((usageSnap.data() as Json | undefined)?.count ?? 0) || 0;
  return { used, limit: resolveAiLimit(subscription, settings, now) };
}

function usageRef(companyId: string, key: string) {
  return db.collection('companies').doc(companyId).collection('aiUsage').doc(key);
}

/**
 * Counts one request for the company in this month and day, atomically.
 * Refuses (and counts nothing) when the month's or the day's ceiling is
 * already reached.
 */
export async function reserveAiRequest(
  companyId: string,
  settings: AiSettings | null,
  now: Date = new Date(),
): Promise<QuotaReservation> {
  const key = monthKey(now);
  const today = dayKey(now);
  const companyRef = db.collection('companies').doc(companyId);
  const ref = usageRef(companyId, key);
  return db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const [companySnap, usageSnap] = await Promise.all([tx.get(companyRef), tx.get(ref)]);
    const subscription = (companySnap.data() as Json | undefined)?.subscription;
    const limit = resolveAiLimit(subscription, settings, now);
    const dailyLimit = resolveAiDailyLimit(subscription, settings, now);
    const usage = (usageSnap.data() as Json | undefined) ?? {};
    const current = Number(usage.count ?? 0) || 0;
    const todayCount = usage.day === today ? Number(usage.dayCount ?? 0) || 0 : 0;
    if (limit !== -1 && current >= limit) {
      return { ok: false, used: current, limit, monthKey: key, dayKey: today, period: 'month' } as QuotaReservation;
    }
    if (dailyLimit !== -1 && todayCount >= dailyLimit) {
      return { ok: false, used: todayCount, limit: dailyLimit, monthKey: key, dayKey: today, period: 'day' } as QuotaReservation;
    }
    tx.set(
      ref,
      { count: current + 1, limit, day: today, dayCount: todayCount + 1, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return { ok: true, used: current + 1, limit, monthKey: key, dayKey: today } as QuotaReservation;
  });
}

/** Gives back a reserved request (the model never answered). Never below 0. */
export async function releaseAiRequest(companyId: string, key: string, day?: string): Promise<void> {
  const ref = usageRef(companyId, key);
  await db.runTransaction(async (tx: FirebaseFirestore.Transaction) => {
    const snap = await tx.get(ref);
    const usage = (snap.data() as Json | undefined) ?? {};
    const current = Number(usage.count ?? 0) || 0;
    if (current <= 0) return;
    const update: Json = { count: current - 1, updatedAt: FieldValue.serverTimestamp() };
    const dayCount = Number(usage.dayCount ?? 0) || 0;
    if (day && usage.day === day && dayCount > 0) update.dayCount = dayCount - 1;
    tx.set(ref, update, { merge: true });
  });
}
