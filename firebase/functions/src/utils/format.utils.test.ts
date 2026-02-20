import {
  getFormatContext,
  normalizePhone,
  getPeriodLabel,
  formatCurrentMonthLabel,
  formatDateRangeLabel,
} from './format.utils';

// ============================================================================
// getFormatContext
// ============================================================================

describe('getFormatContext', () => {
  test('defaults to BR when no country provided', () => {
    expect(getFormatContext()).toEqual({
      country: 'BR',
      locale: 'pt-BR',
      currency: 'BRL',
    });
  });

  test('defaults to BR when undefined', () => {
    expect(getFormatContext(undefined)).toEqual({
      country: 'BR',
      locale: 'pt-BR',
      currency: 'BRL',
    });
  });

  test('resolves known countries', () => {
    expect(getFormatContext('US')).toEqual({ country: 'US', locale: 'en-US', currency: 'USD' });
    expect(getFormatContext('FR')).toEqual({ country: 'FR', locale: 'fr-FR', currency: 'EUR' });
    expect(getFormatContext('PT')).toEqual({ country: 'PT', locale: 'pt-PT', currency: 'EUR' });
    expect(getFormatContext('MX')).toEqual({ country: 'MX', locale: 'es-MX', currency: 'MXN' });
    expect(getFormatContext('AR')).toEqual({ country: 'AR', locale: 'es-AR', currency: 'ARS' });
    expect(getFormatContext('GB')).toEqual({ country: 'GB', locale: 'en-GB', currency: 'GBP' });
    expect(getFormatContext('CL')).toEqual({ country: 'CL', locale: 'es-CL', currency: 'CLP' });
    expect(getFormatContext('CO')).toEqual({ country: 'CO', locale: 'es-CO', currency: 'COP' });
  });

  test('is case-insensitive', () => {
    expect(getFormatContext('br')).toEqual({ country: 'BR', locale: 'pt-BR', currency: 'BRL' });
    expect(getFormatContext('us')).toEqual({ country: 'US', locale: 'en-US', currency: 'USD' });
    expect(getFormatContext('Fr')).toEqual({ country: 'FR', locale: 'fr-FR', currency: 'EUR' });
  });

  test('falls back to BR defaults for unknown countries', () => {
    expect(getFormatContext('XX')).toEqual({ country: 'XX', locale: 'pt-BR', currency: 'BRL' });
    expect(getFormatContext('ZZ')).toEqual({ country: 'ZZ', locale: 'pt-BR', currency: 'BRL' });
  });

  test('EUR countries share currency but have distinct locales', () => {
    const eurCountries = ['PT', 'ES', 'FR', 'DE', 'IT'];
    for (const c of eurCountries) {
      expect(getFormatContext(c).currency).toBe('EUR');
    }
    // But locales differ
    const locales = eurCountries.map(c => getFormatContext(c).locale);
    expect(new Set(locales).size).toBe(eurCountries.length);
  });
});

// ============================================================================
// normalizePhone
// ============================================================================

describe('normalizePhone', () => {
  test('adds default country code (55) to short numbers', () => {
    expect(normalizePhone('48999990000')).toBe('+5548999990000');
  });

  test('keeps number that already has country code', () => {
    expect(normalizePhone('5548999990000')).toBe('+5548999990000');
  });

  test('strips non-digit characters', () => {
    expect(normalizePhone('(48) 99999-0000')).toBe('+5548999990000');
  });

  test('supports custom country code', () => {
    expect(normalizePhone('5551234567', '1')).toBe('+15551234567');
  });
});

// ============================================================================
// Period label helpers (ISO-neutral output)
// ============================================================================

describe('getPeriodLabel', () => {
  test('today returns ISO date', () => {
    const result = getPeriodLabel('today');
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  test('week returns ISO range', () => {
    const result = getPeriodLabel('week');
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}\/\d{4}-\d{2}-\d{2}$/);
  });

  test('month returns YYYY-MM', () => {
    const result = getPeriodLabel('month');
    expect(result).toMatch(/^\d{4}-\d{2}$/);
  });

  test('year returns YYYY', () => {
    const result = getPeriodLabel('year');
    expect(result).toMatch(/^\d{4}$/);
  });

  test('unknown period passes through', () => {
    expect(getPeriodLabel('custom')).toBe('custom');
  });
});

describe('formatCurrentMonthLabel', () => {
  test('returns YYYY-MM format', () => {
    const result = formatCurrentMonthLabel();
    expect(result).toMatch(/^\d{4}-\d{2}$/);

    const now = new Date();
    const expected = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    expect(result).toBe(expected);
  });
});

describe('formatDateRangeLabel', () => {
  test('same day returns single ISO date', () => {
    const d = new Date(2026, 0, 15); // Jan 15
    expect(formatDateRangeLabel(d, d)).toBe('2026-01-15');
  });

  test('full month returns YYYY-MM', () => {
    const start = new Date(2026, 1, 1);  // Feb 1
    const end = new Date(2026, 1, 28);   // Feb 28
    expect(formatDateRangeLabel(start, end)).toBe('2026-02');
  });

  test('partial month returns ISO range', () => {
    const start = new Date(2026, 0, 10);
    const end = new Date(2026, 0, 20);
    expect(formatDateRangeLabel(start, end)).toBe('2026-01-10/2026-01-20');
  });

  test('cross-month returns ISO range', () => {
    const start = new Date(2026, 0, 15);
    const end = new Date(2026, 1, 15);
    expect(formatDateRangeLabel(start, end)).toBe('2026-01-15/2026-02-15');
  });
});
