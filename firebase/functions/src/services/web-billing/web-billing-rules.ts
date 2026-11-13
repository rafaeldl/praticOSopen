/**
 * Web checkout of PraticOS plans (issue #664, docs/WEB_CHECKOUT.md): pure rules.
 *
 * Asaas (Rafsoft's account) charges; RevenueCat stays the only source of the
 * plan through a promotional entitlement (appUserID = companyId) that lasts
 * until the paid period ends plus a few days. No Firestore, no network here.
 */

import type { Subscription, SubscriptionPlan, SubscriptionStatus, SubscriptionStore } from '../../models/types';
import type { RcSubscriber } from '../revenuecat.client';
import type { ResolvedSubscriptionState } from '../subscription-plans';

export type WebPlan = Exclude<SubscriptionPlan, 'free'>;
export type WebCycle = 'monthly' | 'yearly';
export type WebBillingType = 'CREDIT_CARD' | 'PIX' | 'BOLETO';

export const WEB_PLANS: readonly WebPlan[] = ['starter', 'pro', 'business'];
export const WEB_CYCLES: readonly WebCycle[] = ['monthly', 'yearly'];
export const WEB_BILLING_TYPES: readonly WebBillingType[] = ['CREDIT_CARD', 'PIX', 'BOLETO'];

/**
 * Prices in BRL, the same as the stores (épico #721, approved 2026-11-12).
 * Yearly = 10 months. Change here and in the store products together.
 */
export const WEB_PRICES: Readonly<Record<WebPlan, Record<WebCycle, number>>> = {
  starter: { monthly: 59.9, yearly: 599 },
  pro: { monthly: 119, yearly: 1190 },
  business: { monthly: 249, yearly: 2490 },
};

/** Days the plan stays on after the paid period, so a late renewal does not drop it. */
export const WEB_GRACE_DAYS = 5;

/** Days after the first payment in which the customer may cancel with a full refund (CDC art. 49). */
export const WEB_GUARANTEE_DAYS = 7;

/** Monthly is charged on the card only (it renews without the customer acting). */
export const DEFAULT_BILLING_TYPES: Readonly<Record<WebCycle, readonly WebBillingType[]>> = {
  monthly: ['CREDIT_CARD'],
  yearly: ['PIX', 'BOLETO', 'CREDIT_CARD'],
};

/** config/webCheckout (server only; clients cannot read config/*). */
export interface WebCheckoutConfig {
  /** Master switch. Off until Apple approves the iPhone version (docs/WEB_CHECKOUT.md). */
  enabled: boolean;
  /** Yearly only after the yearly products exist in the App Store and Google Play (parity). */
  yearlyEnabled: boolean;
  /** Payment methods offered per cycle. */
  billingTypes: Record<WebCycle, WebBillingType[]>;
}

export function parseWebCheckoutConfig(data: Record<string, unknown> | null | undefined): WebCheckoutConfig {
  const pick = (cycle: WebCycle): WebBillingType[] => {
    const raw = (data?.billingTypes as Record<string, unknown> | undefined)?.[cycle];
    const list = Array.isArray(raw) ? raw.filter((t): t is WebBillingType => WEB_BILLING_TYPES.includes(t as WebBillingType)) : [];
    return list.length ? [...new Set(list)] : [...DEFAULT_BILLING_TYPES[cycle]];
  };
  return {
    enabled: data?.enabled === true,
    yearlyEnabled: data?.yearlyEnabled === true,
    billingTypes: { monthly: pick('monthly'), yearly: pick('yearly') },
  };
}

/** What the web sells right now: prices per plan and the cycles/methods on offer. */
export function webOffer(config: WebCheckoutConfig) {
  const cycles = WEB_CYCLES.filter((cycle) => cycle === 'monthly' || config.yearlyEnabled);
  return {
    plans: WEB_PLANS.map((plan) => ({
      plan,
      prices: Object.fromEntries(cycles.map((cycle) => [cycle, WEB_PRICES[plan][cycle]])) as Partial<Record<WebCycle, number>>,
    })),
    cycles,
    billingTypes: Object.fromEntries(cycles.map((cycle) => [cycle, config.billingTypes[cycle]])) as Partial<
      Record<WebCycle, WebBillingType[]>
    >,
    guaranteeDays: WEB_GUARANTEE_DAYS,
  };
}

// ============================================================================
// Record kept in companies/{cid}/private/webBilling (server only)
// ============================================================================

/**
 * - pending: subscription created in Asaas, first charge not paid yet;
 * - active: paid, renewing;
 * - cancelled: no new charges; the plan lasts until paidUntil;
 * - refunded: money returned (guarantee or chargeback); the plan ended.
 */
export type WebBillingStatus = 'pending' | 'active' | 'cancelled' | 'refunded';

export interface WebBillingPayment {
  status: 'paid' | 'refunded';
  value: number;
  dueDate: string;
  paidAt?: string;
  refundedAt?: string;
}

export interface WebBillingRecord {
  status: WebBillingStatus;
  plan: WebPlan;
  cycle: WebCycle;
  billingType: WebBillingType;
  value: number;
  environment: 'sandbox' | 'production';
  asaasCustomerId: string;
  asaasSubscriptionId: string;
  /** Invoice page of the first charge (where the customer pays). */
  checkoutUrl?: string;
  createdAt: string;
  createdBy: string;
  /** First confirmed payment: starts the 7-day guarantee. */
  firstPaidAt?: string;
  /** End of the promotional entitlement granted in RevenueCat (ISO). */
  paidUntil?: string;
  /** Due date of the next charge Asaas will generate (YYYY-MM-DD). */
  nextDueDate?: string;
  cancelledAt?: string;
  cancelReason?: 'customer' | 'store' | 'asaas' | 'refund' | 'chargeback';
  refundedAt?: string;
  payments?: Record<string, WebBillingPayment>;
  updatedAt?: string;
}

// ============================================================================
// Dates
// ============================================================================

/** YYYY-MM-DD in São Paulo (Asaas dates are local). */
export function saoPauloDate(now: Date): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo' }).format(now);
}

function parseDay(day: string): [number, number, number] | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(day);
  return match ? [Number(match[1]), Number(match[2]) - 1, Number(match[3])] : null;
}

/** Due date one cycle later; the 31st of a short month becomes its last day. */
export function addCycle(day: string, cycle: WebCycle): string {
  const parts = parseDay(day);
  if (!parts) throw new Error(`invalid date: ${day}`);
  const [y, m, d] = parts;
  const targetYear = cycle === 'yearly' ? y + 1 : y + Math.floor((m + 1) / 12);
  const targetMonth = cycle === 'yearly' ? m : (m + 1) % 12;
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
  const date = new Date(Date.UTC(targetYear, targetMonth, Math.min(d, lastDay)));
  return date.toISOString().slice(0, 10);
}

/**
 * End of the plan paid by a charge due on `dueDate`: the next due date plus
 * WEB_GRACE_DAYS, at the end of that day in São Paulo (03:00 UTC next day).
 */
export function periodEndOf(dueDate: string, cycle: WebCycle): { nextDueDate: string; endMs: number } {
  const nextDueDate = addCycle(dueDate, cycle);
  const [y, m, d] = parseDay(nextDueDate)!;
  return { nextDueDate, endMs: Date.UTC(y, m, d + WEB_GRACE_DAYS + 1, 3) };
}

/** Whether the 7-day guarantee still covers the record at `now`. */
export function refundEligible(record: WebBillingRecord | null | undefined, now: Date): boolean {
  if (!record || (record.status !== 'active' && record.status !== 'cancelled') || !record.firstPaidAt) return false;
  const paidAt = Date.parse(record.firstPaidAt);
  return !Number.isNaN(paidAt) && now.getTime() - paidAt <= WEB_GUARANTEE_DAYS * 24 * 60 * 60 * 1000;
}

// ============================================================================
// Checkout guard: never charge twice
// ============================================================================

export type CheckoutBlock = 'STORE_SUBSCRIPTION_ACTIVE' | 'WEB_SUBSCRIPTION_ACTIVE' | 'OUTSIDE_BRAZIL' | null;

/**
 * The web sells only to companies in Brazil: Asaas charges in reais and needs
 * a CPF/CNPJ. A company with no country is Brazilian (the app's default).
 * Companies abroad subscribe in the app (App Store / Google Play).
 */
export function sellsOnWeb(country: string | null | undefined): boolean {
  return !country || country.trim().toUpperCase() === 'BR';
}

function inForce(subscription: Subscription | undefined, now: Date): boolean {
  if (!subscription || subscription.plan === 'free' || subscription.status === 'expired') return false;
  if (!subscription.expiresAt) return true;
  const end = Date.parse(subscription.expiresAt);
  return Number.isNaN(end) || end > now.getTime();
}

/**
 * Why the company cannot buy on the web now, or null:
 * - a store subscription (App Store / Google Play) is in force: "use the app";
 * - a web subscription is already active (renewing): change it by cancelling first.
 * - the company is outside Brazil: subscribe in the app (checked last, so a
 *   web subscriber who changed country still sees and manages the subscription).
 * A cancelled web plan still running, the launch courtesy and Free may buy.
 */
export function checkoutBlock(
  subscription: Subscription | undefined,
  record: WebBillingRecord | null | undefined,
  now: Date,
  country?: string | null,
): CheckoutBlock {
  if (
    inForce(subscription, now) &&
    subscription?.source === 'store' &&
    (subscription.store === 'app_store' || subscription.store === 'play_store')
  ) {
    return 'STORE_SUBSCRIPTION_ACTIVE';
  }
  if (record?.status === 'active') return 'WEB_SUBSCRIPTION_ACTIVE';
  if (!sellsOnWeb(country)) return 'OUTSIDE_BRAZIL';
  return null;
}

// ============================================================================
// Asaas webhook → action
// ============================================================================

/** The part of an Asaas webhook event the billing flow reads. */
export interface BillingWebhookEvent {
  id: string;
  event: string;
  payment?: {
    id: string;
    subscription?: string | null;
    value?: number;
    dueDate?: string;
    status?: string;
    billingType?: string;
  };
  subscription?: { id: string; status?: string };
}

export type BillingAction =
  | { kind: 'grant'; paymentId: string; dueDate: string; nextDueDate: string; endMs: number; value: number }
  | { kind: 'revoke'; paymentId: string; reason: 'refund' | 'chargeback' }
  | { kind: 'markCancelled' }
  | { kind: 'none'; why: string };

const PAID_EVENTS = new Set(['PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED']);
const REFUND_EVENTS = new Set(['PAYMENT_REFUNDED']);
const CHARGEBACK_EVENTS = new Set(['PAYMENT_CHARGEBACK_REQUESTED', 'PAYMENT_CHARGEBACK_DISPUTE']);
const SUBSCRIPTION_END_EVENTS = new Set(['SUBSCRIPTION_DELETED', 'SUBSCRIPTION_INACTIVATED']);

/** Asaas subscription id the event is about, or null. */
export function subscriptionIdOf(event: BillingWebhookEvent): string | null {
  const id = event.payment?.subscription ?? event.subscription?.id;
  return typeof id === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(id) ? id : null;
}

/**
 * What a webhook event does to the company's plan:
 * - payment confirmed/received → grant until next due date + grace (never
 *   again for a payment already refunded);
 * - refund or chargeback → revoke now (plan drops to Free);
 * - subscription deleted/inactivated → mark cancelled (plan lasts until paidUntil);
 * - overdue and everything else → nothing (the entitlement ends on its date).
 */
export function decideBillingAction(event: BillingWebhookEvent, record: WebBillingRecord): BillingAction {
  const payment = event.payment;
  if (PAID_EVENTS.has(event.event)) {
    if (!payment?.id || !payment.dueDate) return { kind: 'none', why: 'payment without id or due date' };
    if (record.payments?.[payment.id]?.status === 'refunded') return { kind: 'none', why: 'payment already refunded' };
    if (record.status === 'refunded') return { kind: 'none', why: 'subscription refunded' };
    const { nextDueDate, endMs } = periodEndOf(payment.dueDate, record.cycle);
    return { kind: 'grant', paymentId: payment.id, dueDate: payment.dueDate, nextDueDate, endMs, value: payment.value ?? record.value };
  }
  if (REFUND_EVENTS.has(event.event) || CHARGEBACK_EVENTS.has(event.event)) {
    if (!payment?.id) return { kind: 'none', why: 'refund without payment id' };
    return { kind: 'revoke', paymentId: payment.id, reason: CHARGEBACK_EVENTS.has(event.event) ? 'chargeback' : 'refund' };
  }
  if (SUBSCRIPTION_END_EVENTS.has(event.event)) {
    if (record.status === 'cancelled' || record.status === 'refunded') return { kind: 'none', why: 'already ended' };
    return { kind: 'markCancelled' };
  }
  return { kind: 'none', why: `event ${event.event} needs nothing` };
}

// ============================================================================
// RevenueCat state → origin `web`
// ============================================================================

/** Whether the entitlement of `plan` in the subscriber is a promotional one. */
export function isPromotionalEntitlement(subscriber: RcSubscriber, plan: SubscriptionPlan): boolean {
  const entitlement = subscriber.entitlements?.[plan];
  if (!entitlement) return false;
  const store = (entitlement.store ?? subscriber.subscriptions?.[entitlement.product_identifier]?.store ?? '').toLowerCase();
  return store === 'promotional' || entitlement.product_identifier.startsWith('rc_promo');
}

/**
 * The state written for a company that bought on the web: a promotional
 * entitlement of the same plan as an active or cancelled web record is the
 * web subscription (store `web`; status `cancelled` once it stops renewing).
 * A promotional granted by hand (no web record, other plan, refunded) stays
 * as before (store null).
 */
export function applyWebOrigin(
  state: ResolvedSubscriptionState,
  subscriber: RcSubscriber,
  record: WebBillingRecord | null | undefined,
): ResolvedSubscriptionState {
  if (
    !record ||
    state.plan === 'free' ||
    state.store !== null ||
    record.plan !== state.plan ||
    (record.status !== 'active' && record.status !== 'cancelled') ||
    !isPromotionalEntitlement(subscriber, state.plan)
  ) {
    return state;
  }
  const store: SubscriptionStore = 'web';
  const status: SubscriptionStatus = record.status === 'cancelled' ? 'cancelled' : state.status;
  return { ...state, store, status };
}

/** A store purchase is in force while the web still renews: the web recurrence must stop. */
export function storeOverlapsWeb(state: ResolvedSubscriptionState, record: WebBillingRecord | null | undefined): boolean {
  return (state.store === 'app_store' || state.store === 'play_store') && record?.status === 'active';
}
