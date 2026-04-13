interface CacheEntry<T> {
  data: T
  timestamp: number
}

const cache = new Map<string, CacheEntry<any>>()

// TTL by period: today = no cache, recent periods = short, historical = long
const PERIOD_TTL: Record<string, number> = {
  today: 0, // never cache today
  '7d': 2 * 60_000, // 2 min
  '30d': 5 * 60_000, // 5 min
  '90d': 10 * 60_000, // 10 min
  '6m': 30 * 60_000, // 30 min
  '1y': 60 * 60_000, // 1 hour
  all: 60 * 60_000, // 1 hour
}

const DEFAULT_TTL_MS = 60_000

export function getTtlForPeriod(period: string): number {
  return PERIOD_TTL[period] ?? DEFAULT_TTL_MS
}

export function getCached<T>(key: string, ttlMs: number = DEFAULT_TTL_MS): T | null {
  if (ttlMs <= 0) return null
  const entry = cache.get(key)
  if (!entry) return null
  if (Date.now() - entry.timestamp > ttlMs) {
    cache.delete(key)
    return null
  }
  return entry.data as T
}

export function setCache<T>(key: string, data: T): void {
  cache.set(key, { data, timestamp: Date.now() })
}
