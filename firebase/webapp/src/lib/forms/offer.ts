// "Fazer o checklist de entrada?" after a new order is saved
// (lib/screens/order/new_order_offers.dart). Nova OS marks the order; the
// order screen asks once it opens. Three "Agora não" in a row stop the offer,
// counted in this browser per company, like the app counts on the phone.
import { readStorage, writeStorage } from '@/lib/storage'

export const OFFER_LIMIT = 3
const key = (companyId: string) => `praticos.checklistOffer.${companyId}`

let pending: string | null = null

/** Nova OS saved an order that may get a check-in checklist. */
export function markOffer(orderId: string): void {
  pending = orderId
}

/** The order just created waits for the question (the order screen may mount more than once before it asks). */
export function offerWaiting(orderId: string): boolean {
  return pending === orderId
}

/** Asked, or found not to apply: never again for this order. */
export function offerDone(orderId: string): void {
  if (pending === orderId) pending = null
}

export function declinedCount(companyId: string): number {
  return Number(readStorage(key(companyId)) ?? 0) || 0
}

export function rememberDecline(companyId: string, declined: boolean): void {
  writeStorage(key(companyId), declined ? String(declinedCount(companyId) + 1) : '0')
}

/**
 * Only with a device, without a contract, for who may add checklists to this
 * order, before three refusals. The app ties it to the automotive segment; the
 * web asks wherever the company has an active checklist (the segment's own
 * configuration, instead of a fixed id).
 */
export function shouldOffer(input: { hasDevice: boolean; isContract: boolean; canManageForms: boolean; declined: number; activeTemplates: number }): boolean {
  return input.hasDevice && !input.isContract && input.canManageForms && input.declined < OFFER_LIMIT && input.activeTemplates > 0
}
