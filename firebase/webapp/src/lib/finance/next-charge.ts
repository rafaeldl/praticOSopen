// "Próxima cobrança" of the Financeiro (fin.tab.next-charge), the app's rule in
// lib/utils/next_charge.dart and FinancialTabStore._resolveNextCharge: debts of
// the last 90 days first, oldest first; then the older ones, newest first; no
// date at the end. A customer with an open payment link (of the customer or of
// any open order) is skipped, and if the links can't be read in time nothing is
// suggested, so nobody gets charged twice. "Agora não" lasts 30 days.
//
// Web difference (registered in the matrix): the app keeps "Agora não" in the
// phone (SharedPreferences); here it is kept in this browser, per company.
import { readStorage, writeStorage } from '@/lib/storage'
import type { Debtor, FinanceRow } from './data'

export const NEXT_CHARGE_RECENT_DAYS = 90
export const NEXT_CHARGE_SNOOZE_DAYS = 30
export const NEXT_CHARGE_READ_TIMEOUT_MS = 8000
const DAY = 86_400_000

/** Order of the suggestion; snoozed keys never come back. */
export function nextChargeCandidates(debtors: readonly Debtor[], snoozed: ReadonlySet<string>, now: Date): Debtor[] {
  const limit = now.getTime() - NEXT_CHARGE_RECENT_DAYS * DAY
  const at = (debtor: Debtor) => (debtor.since ? Date.parse(debtor.since) : Number.NaN)
  const open = debtors.filter((debtor) => !snoozed.has(debtor.key))
  const dated = open.filter((debtor) => Number.isFinite(at(debtor)))
  const recent = dated.filter((debtor) => at(debtor) >= limit).sort((a, b) => at(a) - at(b))
  const older = dated.filter((debtor) => at(debtor) < limit).sort((a, b) => at(b) - at(a))
  const undated = open.filter((debtor) => !Number.isFinite(at(debtor)))
  return [...recent, ...older, ...undated]
}

/**
 * Every open order of the debtor's customer, done or not: a link on any of them
 * means "already charged" (the app reads debtor.openOrders). The running ones
 * come from the summary's Em andamento and deposit lists.
 */
export function openOrdersOf(debtor: Debtor, running: readonly FinanceRow[]): string[] {
  const id = debtor.customer?.id ?? null
  const more = id ? running.filter((row) => row.customer?.id === id) : []
  return [...new Set([...debtor.orders, ...more].map((row) => row.id))]
}

/**
 * The first candidate without an open link. `hasOpenCharge` throwing or taking
 * longer than the timeout hides the suggestion (null), never skips the check.
 */
export async function resolveNextCharge(
  candidates: readonly Debtor[],
  hasOpenCharge: (debtor: Debtor) => Promise<boolean>,
  timeoutMs = NEXT_CHARGE_READ_TIMEOUT_MS,
): Promise<Debtor | null> {
  for (const debtor of candidates) {
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      const open = await Promise.race([
        hasOpenCharge(debtor),
        new Promise<never>((_, reject) => (timer = setTimeout(() => reject(new Error('timeout')), timeoutMs))),
      ])
      if (!open) return debtor
    } catch {
      return null
    } finally {
      clearTimeout(timer)
    }
  }
  return null
}

// ---------------------------------------------------------------------------
// "Agora não": kept in this browser, per company, for 30 days
// ---------------------------------------------------------------------------

const snoozeKey = (companyId: string) => `praticos.nextChargeSnooze.${companyId}`

function readSnoozes(companyId: string): Record<string, number> {
  try {
    const value = JSON.parse(readStorage(snoozeKey(companyId)) ?? '{}') as unknown
    return value && typeof value === 'object' ? (value as Record<string, number>) : {}
  } catch {
    return {}
  }
}

/** Active snoozes; the expired ones are dropped as they are read, like the app. */
export function snoozedKeys(companyId: string, now: Date): Set<string> {
  const all = readSnoozes(companyId)
  const since = now.getTime() - NEXT_CHARGE_SNOOZE_DAYS * DAY
  const active = Object.fromEntries(Object.entries(all).filter(([, at]) => typeof at === 'number' && at > since))
  if (Object.keys(active).length !== Object.keys(all).length) writeStorage(snoozeKey(companyId), JSON.stringify(active))
  return new Set(Object.keys(active))
}

export function snoozeNextCharge(companyId: string, debtorKey: string, now: Date): void {
  writeStorage(snoozeKey(companyId), JSON.stringify({ ...readSnoozes(companyId), [debtorKey]: now.getTime() }))
}

/** "Mandar cobrança": one charge for the customer's orders (Asaas ready), or one order's link. */
export function sendPath(debtor: Debtor, customerChargeReady: boolean): 'customer' | 'order' {
  return debtor.orders.length > 1 && !!debtor.customer?.id && customerChargeReady ? 'customer' : 'order'
}
