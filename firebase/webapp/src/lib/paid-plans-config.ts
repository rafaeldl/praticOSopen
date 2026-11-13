/**
 * `config/paidPlans`, the one document that turns the plans on: the same rule
 * as the server (firebase/functions/src/services/paid-plans-config.ts) and the
 * app (lib/services/paid_plans_config.dart). Shared cases in
 * docs/web-app/contract-cases/paid-plans-config.json.
 *
 *   enabled        true: limits and features for every company
 *   companyIds     ids with the plans on while `enabled` is off (the demo
 *                  account of the App Review); never an id in the code
 *   limitsStartAt  day the limits start for the Free companies that already
 *                  exist: notice in the 15 days before, and a month of grace
 *                  from it
 */

type Json = Record<string, unknown>

export interface PaidPlansConfig {
  enabled: boolean
  companyIds: string[]
  limitsStartAt: Date | null
}

/** Days before `limitsStartAt` the Free companies are told. */
export const FREE_LIMITS_NOTICE_DAYS = 15

const DAY_MS = 24 * 60 * 60 * 1000

/** ISO string, Firestore Timestamp or epoch millis; anything else is null. */
function dateOf(value: unknown): Date | null {
  if (typeof value === 'string') {
    const time = Date.parse(value)
    return Number.isNaN(time) ? null : new Date(time)
  }
  if (typeof value === 'number' && Number.isFinite(value)) return new Date(value)
  if (value && typeof value === 'object' && typeof (value as { toDate?: unknown }).toDate === 'function') {
    return (value as { toDate(): Date }).toDate()
  }
  return null
}

export function parsePaidPlansConfig(data: Json | null | undefined): PaidPlansConfig {
  const ids = Array.isArray(data?.companyIds) ? data.companyIds : []
  return {
    enabled: data?.enabled === true,
    companyIds: ids.filter((id): id is string => typeof id === 'string' && id.length > 0),
    limitsStartAt: dateOf(data?.limitsStartAt),
  }
}

/** The plans are on for this company: on for everyone, or listed in `companyIds`. */
export function paidPlansOnFor(config: PaidPlansConfig, companyId: string | null | undefined): boolean {
  return config.enabled || (!!companyId && config.companyIds.includes(companyId))
}

/** The same instant one calendar month later (UTC; Jan 31 rolls over like Date.UTC). */
export function oneMonthAfter(date: Date): Date {
  return new Date(
    Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth() + 1,
      date.getUTCDate(),
      date.getUTCHours(),
      date.getUTCMinutes(),
      date.getUTCSeconds(),
      date.getUTCMilliseconds(),
    ),
  )
}

/**
 * Whether the month before counts for the month of grace of the orders. In
 * the month from `limitsStartAt` it does not: a company already over the
 * limit when the limits start still gets its month (decision of 2026-11-13).
 */
export function lastMonthCounts(limitsStartAt: Date | null, now: Date): boolean {
  return limitsStartAt === null || now.getTime() >= oneMonthAfter(limitsStartAt).getTime()
}

/**
 * The notice to the Free companies that already exist: from 15 days before
 * `limitsStartAt` until it. Only for a company whose plan in force is Free
 * (`isFree`); the courtesy has its own notice.
 */
export function freeLimitsNoticeDue(
  config: PaidPlansConfig,
  isFree: boolean,
  now: Date,
): { startsAt: Date; daysLeft: number } | null {
  const start = config.limitsStartAt
  if (!start || !isFree) return null
  const left = start.getTime() - now.getTime()
  if (left <= 0 || left > FREE_LIMITS_NOTICE_DAYS * DAY_MS) return null
  return { startsAt: start, daysLeft: Math.ceil(left / DAY_MS) }
}
