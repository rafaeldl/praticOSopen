// A first access that created the company but has not finished (sessionStorage,
// per tab): reloading continues it instead of opening a company without its
// checklists, and a retry completes the same company. Small: the router reads it.
export interface PendingOnboarding {
  uid: string
  companyId: string
  withSamples: boolean
  localeTag: string
  /** The seed was asked for: the segment cannot change any more (its checklists may be in). */
  seedTried: boolean
}

const KEY = 'praticos.onboarding'

export function readPending(uid: string | null): PendingOnboarding | null {
  if (!uid) return null
  try {
    const value = JSON.parse(sessionStorage.getItem(KEY) ?? 'null') as PendingOnboarding | null
    return value && value.uid === uid && typeof value.companyId === 'string' ? value : null
  } catch {
    return null
  }
}

export function writePending(value: PendingOnboarding | null): void {
  try {
    if (value) sessionStorage.setItem(KEY, JSON.stringify(value))
    else sessionStorage.removeItem(KEY)
  } catch {
    // Without storage the flow still works; only a reload loses the place.
  }
}
