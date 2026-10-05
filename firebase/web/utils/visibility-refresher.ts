export interface VisibilityRefresherOptions {
  refresh: () => unknown
  /** Only refresh while this returns true (e.g. charge still pending). */
  when?: () => boolean
  /** Minimum time between refreshes; the public API allows 30 req/min per link. */
  minIntervalMs?: number
  now?: () => number
}

/**
 * Returns a handler to call with the current document visibility state.
 * Pure (no Nuxt/DOM access) so it can be unit tested with node --test.
 */
export function createVisibilityRefresher(options: VisibilityRefresherOptions) {
  const { refresh, when, minIntervalMs = 10_000, now = Date.now } = options
  let lastRun: number | null = null

  return function onVisibility(visibilityState: string): void {
    if (visibilityState !== 'visible') return
    if (when && !when()) return
    const current = now()
    if (lastRun !== null && current - lastRun < minIntervalMs) return
    lastRun = current
    try {
      Promise.resolve(refresh()).catch(() => {})
    } catch {
      // refresh failures must never surface from an event listener
    }
  }
}
