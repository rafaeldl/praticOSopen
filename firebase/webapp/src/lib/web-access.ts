// The web app opens only for allowed accounts (GET /v1/app/web-access, closed by
// default). A "yes" is remembered for a while so the start does not wait for the
// API; it is checked again on every start and a "no" closes the app at once.
// This gates screens only: the data is protected by the rules and the API.
import { readStorage, writeStorage } from './storage'

export type WebAccess = 'unknown' | 'allowed' | 'denied' | 'error'

export const ALLOWED_TTL_MS = 12 * 60 * 60 * 1000
/** A remembered "yes" younger than this is not asked again on start. */
export const RECHECK_AFTER_MS = 10 * 60 * 1000
const keyOf = (uid: string) => `praticos.webAccess.${uid}`

/** A remembered "yes" still valid at `now`. */
export function rememberedAccess(uid: string, now = Date.now()): boolean {
  const saved = Number(readStorage(keyOf(uid)) ?? 0)
  return saved > 0 && now - saved < ALLOWED_TTL_MS
}

/** Remembered "yes" old enough to confirm again in the background. */
export function shouldRecheck(uid: string, now = Date.now()): boolean {
  const saved = Number(readStorage(keyOf(uid)) ?? 0)
  return now - saved >= RECHECK_AFTER_MS
}

export function rememberAccess(uid: string, allowed: boolean, now = Date.now()): void {
  writeStorage(keyOf(uid), allowed ? String(now) : '0')
}

/** Asks the server. Throws on network or server failure, so the caller can tell "no" from "could not ask". */
export async function fetchWebAccess(request: (path: string) => Promise<{ allowed?: boolean }>): Promise<boolean> {
  const data = await request('/v1/app/web-access')
  return data?.allowed === true
}
