const countryCurrencyMap: Record<string, { currency: string; locale: string }> = {
  BR: { currency: 'BRL', locale: 'pt-BR' },
  US: { currency: 'USD', locale: 'en-US' },
  PT: { currency: 'EUR', locale: 'pt-PT' },
  ES: { currency: 'EUR', locale: 'es-ES' },
  MX: { currency: 'MXN', locale: 'es-MX' },
  AR: { currency: 'ARS', locale: 'es-AR' },
  CL: { currency: 'CLP', locale: 'es-CL' },
  CO: { currency: 'COP', locale: 'es-CO' },
  PE: { currency: 'PEN', locale: 'es-PE' },
  UY: { currency: 'UYU', locale: 'es-UY' },
  PY: { currency: 'PYG', locale: 'es-PY' },
  BO: { currency: 'BOB', locale: 'es-BO' },
  GB: { currency: 'GBP', locale: 'en-GB' },
  CA: { currency: 'CAD', locale: 'en-CA' },
  AO: { currency: 'AOA', locale: 'pt-AO' },
  MZ: { currency: 'MZN', locale: 'pt-MZ' },
}

export function getCurrencyConfig(country?: string): { currency: string; locale: string } {
  if (country && countryCurrencyMap[country]) {
    return countryCurrencyMap[country]
  }
  return { currency: 'BRL', locale: 'pt-BR' }
}

export function formatCurrency(value: number | string | undefined, country?: string): string {
  const num = typeof value === 'number' ? value : parseFloat(String(value)) || 0
  const config = getCurrencyConfig(country)
  return new Intl.NumberFormat(config.locale, {
    style: 'currency',
    currency: config.currency,
  }).format(num)
}

export function formatDate(dateStr: string | undefined, lang: string = 'pt'): string {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  const locale = lang === 'en' ? 'en-US' : lang === 'es' ? 'es-ES' : 'pt-BR'
  return date.toLocaleDateString(locale, {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}
