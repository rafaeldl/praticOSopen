/**
 * Format Utilities
 * Helper functions for formatting and data normalization
 */

/**
 * Normalize phone number (remove formatting, add country code if needed)
 */
export function normalizePhone(phone: string, defaultCountryCode = '55'): string {
  let cleaned = phone.replace(/\D/g, '');

  // Add country code if not present
  if (!cleaned.startsWith(defaultCountryCode) && cleaned.length <= 11) {
    cleaned = defaultCountryCode + cleaned;
  }

  return '+' + cleaned;
}

// ============================================================================
// Period Label Helpers (locale-neutral for bot formatting)
// ============================================================================

/**
 * Get period label as ISO-friendly string (bot formats with locale)
 */
export function getPeriodLabel(period: string): string {
  const now = new Date();
  switch (period) {
    case 'today':
      return toISODate(now);
    case 'week':
      return `${toISODate(weekStart(now))}/${toISODate(now)}`;
    case 'month':
      return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    case 'year':
      return String(now.getFullYear());
    default:
      return period;
  }
}

/**
 * Get current month label as YYYY-MM
 */
export function formatCurrentMonthLabel(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Format date range label as ISO range (YYYY-MM-DD/YYYY-MM-DD)
 */
export function formatDateRangeLabel(start: Date, end: Date): string {
  const sameDay = start.toDateString() === end.toDateString();
  if (sameDay) return toISODate(start);

  const sameMonth = start.getMonth() === end.getMonth() &&
    start.getFullYear() === end.getFullYear();
  const isFullMonth = sameMonth &&
    start.getDate() === 1 &&
    end.getDate() === new Date(end.getFullYear(), end.getMonth() + 1, 0).getDate();

  if (isFullMonth) {
    return `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`;
  }

  return `${toISODate(start)}/${toISODate(end)}`;
}

function toISODate(d: Date): string {
  return d.toISOString().split('T')[0];
}

function weekStart(d: Date): Date {
  const result = new Date(d);
  result.setDate(result.getDate() - result.getDay());
  return result;
}

// ============================================================================
// Format Context (for bot raw data responses)
// ============================================================================

const COUNTRY_CURRENCY: Record<string, string> = {
  BR: 'BRL', US: 'USD', PT: 'EUR', ES: 'EUR', FR: 'EUR', DE: 'EUR',
  IT: 'EUR', MX: 'MXN', AR: 'ARS', CO: 'COP', CL: 'CLP', GB: 'GBP',
  CA: 'CAD', AU: 'AUD', PE: 'PEN', UY: 'UYU',
};

const COUNTRY_LOCALE: Record<string, string> = {
  BR: 'pt-BR', US: 'en-US', PT: 'pt-PT', ES: 'es-ES', FR: 'fr-FR',
  DE: 'de-DE', IT: 'it-IT', MX: 'es-MX', AR: 'es-AR', CO: 'es-CO',
  CL: 'es-CL', GB: 'en-GB', CA: 'en-CA', AU: 'en-AU', PE: 'es-PE',
  UY: 'es-UY',
};

/**
 * Get format context (country, locale, currency) for bot responses.
 * The bot LLM uses this to format values in the correct locale/currency.
 */
export function getFormatContext(country?: string) {
  const c = (country || 'BR').toUpperCase();
  return {
    country: c,
    locale: COUNTRY_LOCALE[c] || 'pt-BR',
    currency: COUNTRY_CURRENCY[c] || 'BRL',
  };
}
