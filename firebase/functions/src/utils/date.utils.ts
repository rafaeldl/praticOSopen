/**
 * Date Utilities
 * Helper functions for date manipulation and period calculations
 */

export type PeriodType = 'today' | 'week' | 'month' | 'year' | 'custom';

export interface DateRange {
  start: Date;
  end: Date;
}

/**
 * Get the start and end dates for a given period type
 */
export function getPeriodDates(
  period: PeriodType,
  customStart?: string,
  customEnd?: string
): DateRange {
  const now = new Date();
  let start: Date;
  let end: Date;

  switch (period) {
    case 'today':
      start = startOfDay(now);
      end = endOfDay(now);
      break;

    case 'week':
      start = startOfWeek(now);
      end = endOfDay(now);
      break;

    case 'month':
      start = startOfMonth(now);
      end = endOfDay(now);
      break;

    case 'year':
      start = startOfYear(now);
      end = endOfDay(now);
      break;

    case 'custom':
      if (!customStart || !customEnd) {
        throw new Error('Custom period requires startDate and endDate');
      }
      start = startOfDay(new Date(customStart));
      end = endOfDay(new Date(customEnd));
      break;

    default:
      start = startOfDay(now);
      end = endOfDay(now);
  }

  return { start, end };
}

/**
 * Get start of day (00:00:00.000)
 */
export function startOfDay(date: Date): Date {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}

/**
 * Get end of day (23:59:59.999)
 */
export function endOfDay(date: Date): Date {
  const result = new Date(date);
  result.setHours(23, 59, 59, 999);
  return result;
}

/**
 * Get start of week (Sunday)
 */
export function startOfWeek(date: Date): Date {
  const result = new Date(date);
  const day = result.getDay();
  result.setDate(result.getDate() - day);
  return startOfDay(result);
}

/**
 * Get start of month
 */
export function startOfMonth(date: Date): Date {
  const result = new Date(date);
  result.setDate(1);
  return startOfDay(result);
}

/**
 * Get start of year
 */
export function startOfYear(date: Date): Date {
  const result = new Date(date);
  result.setMonth(0, 1);
  return startOfDay(result);
}

/**
 * Check if a date is today
 */
export function isToday(date: Date): boolean {
  const today = new Date();
  return (
    date.getDate() === today.getDate() &&
    date.getMonth() === today.getMonth() &&
    date.getFullYear() === today.getFullYear()
  );
}

/**
 * Check if a date is overdue (before today)
 */
export function isOverdue(date: Date): boolean {
  const today = startOfDay(new Date());
  return date < today;
}

/**
 * Calculate days overdue
 */
export function daysOverdue(date: Date): number {
  const today = startOfDay(new Date());
  const targetDate = startOfDay(date);
  const diffTime = today.getTime() - targetDate.getTime();
  return Math.floor(diffTime / (1000 * 60 * 60 * 24));
}

/**
 * Format date to ISO string (date only)
 */
export function toISODateString(date: Date): string {
  return date.toISOString().split('T')[0];
}

/**
 * Format date to ISO string with time
 */
export function toISOString(date: Date): string {
  return date.toISOString();
}

/**
 * Convert Firestore Timestamp to Date
 */
export function timestampToDate(
  timestamp: FirebaseFirestore.Timestamp | { _seconds: number; _nanoseconds: number } | undefined
): Date | undefined {
  if (!timestamp) return undefined;
  if ('toDate' in timestamp) {
    return timestamp.toDate();
  }
  if ('_seconds' in timestamp) {
    return new Date(timestamp._seconds * 1000);
  }
  return undefined;
}
