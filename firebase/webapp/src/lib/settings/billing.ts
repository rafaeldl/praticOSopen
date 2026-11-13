// Plans bought on the web (issue #664, docs/WEB_CHECKOUT.md). The server owns
// everything: the switch (config/webCheckout), prices, the guard against a
// second subscription and the Asaas checkout. This file only reads and asks.
import { api } from '@/lib/session'

export type WebPlan = 'starter' | 'pro' | 'business'
export type WebCycle = 'monthly' | 'yearly'
export type WebBillingType = 'CREDIT_CARD' | 'PIX' | 'BOLETO'
export type WebBillingStatus = 'pending' | 'active' | 'cancelled' | 'refunded'
export type CheckoutBlock = 'STORE_SUBSCRIPTION_ACTIVE' | 'WEB_SUBSCRIPTION_ACTIVE' | 'OUTSIDE_BRAZIL' | null

// Companies outside Brazil subscribe in the app (the web charges only in reais, with CPF/CNPJ).
export const APP_STORE_URL = 'https://apps.apple.com/app/praticos/id1534604555'
export const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos'

export interface WebOffer {
  plans: { plan: WebPlan; prices: Partial<Record<WebCycle, number>> }[]
  cycles: WebCycle[]
  billingTypes: Partial<Record<WebCycle, WebBillingType[]>>
  guaranteeDays: number
}

export interface WebSubscription {
  status: WebBillingStatus
  plan: WebPlan
  cycle: WebCycle
  billingType: WebBillingType
  value: number
  paidUntil: string | null
  nextDueDate: string | null
  checkoutUrl: string | null
  refundEligible: boolean
}

export interface WebBillingView {
  enabled: boolean
  offer: WebOffer | null
  block: CheckoutBlock
  subscription: WebSubscription | null
  /** Billing data typed at the last checkout (older servers omit it). */
  billingInfo?: {
    name: string
    taxId: string
    email: string | null
    postalCode: string | null
    addressNumber: string | null
  } | null
}

export interface CheckoutBody {
  plan: WebPlan
  cycle: WebCycle
  billingType: WebBillingType
  name: string
  taxId: string
  email: string
  /** CEP (8 digits) and number: Asaas needs the address to issue the NFS-e. */
  postalCode: string
  addressNumber: string
}

export const loadBilling = () => api<WebBillingView>('/v1/app/billing')

export const startCheckout = (body: CheckoutBody) =>
  api<{ checkoutUrl: string }>('/v1/app/billing/checkout', { method: 'POST', body })

export const cancelBilling = (refund: boolean) =>
  api<{ status: WebBillingStatus }>('/v1/app/billing/cancel', { method: 'POST', body: { refund } })

/**
 * What the Plano screen offers about buying on the web:
 * - hidden: switch off, or the person cannot buy;
 * - store: subscribed in the App Store / Google Play, change it in the app;
 * - subscription: a web subscription to see (pay, cancel, refund);
 * - app: company outside Brazil, subscribe in the app (App Store / Google Play);
 * - buy: may choose a plan.
 */
export type BillingEntry = 'hidden' | 'store' | 'subscription' | 'app' | 'buy'

export function billingEntry(view: WebBillingView | null): BillingEntry {
  if (!view) return 'hidden'
  if (view.block === 'STORE_SUBSCRIPTION_ACTIVE') return 'store'
  const sub = view.subscription
  if (sub && sub.status !== 'refunded') return 'subscription'
  if (!view.enabled) return 'hidden'
  return view.block === 'OUTSIDE_BRAZIL' ? 'app' : 'buy'
}

/** Whether the plan form shows: on, no store subscription and no renewing web one. */
export function canBuy(view: WebBillingView | null): boolean {
  return !!view?.enabled && !!view.offer && view.block === null
}

/** Methods offered for a cycle, in the server's order. */
export function methodsFor(offer: WebOffer | null, cycle: WebCycle): WebBillingType[] {
  return offer?.billingTypes[cycle] ?? []
}

/** Yearly price over 12 months, to show next to the monthly one. */
export function monthlyEquivalent(yearly: number): number {
  return Math.round((yearly / 12) * 100) / 100
}
