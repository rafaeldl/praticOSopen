export type PublicChargeStatus = 'pending' | 'overdue' | 'paid'
export type PublicChargeMode = 'single' | 'cardInstallments'
export type ChargeLang = 'pt' | 'en' | 'es'

/** Shape of data.charge returned by GET /public/orders/:token */
export interface PublicOrderCharge {
  status: PublicChargeStatus
  value: number
  /** YYYY-MM-DD */
  dueDate: string
  mode: PublicChargeMode
  installmentCount?: number
  invoiceUrl: string
}

export type ChargeView =
  | { kind: 'pay'; value: number; dueDate: string; invoiceUrl: string; installmentCount: number | null }
  | { kind: 'overdue' }
  | { kind: 'paid' }
  | { kind: 'none' }

/** Only https links hosted on asaas.com (or a subdomain, e.g. sandbox.asaas.com). */
export function isSafeInvoiceUrl(url: string | undefined): boolean {
  if (!url) return false
  try {
    const parsed = new URL(url)
    if (parsed.protocol !== 'https:') return false
    const host = parsed.hostname.toLowerCase()
    return host === 'asaas.com' || host.endsWith('.asaas.com')
  } catch {
    return false
  }
}

export function getChargeView(charge: PublicOrderCharge | null | undefined): ChargeView {
  if (!charge) return { kind: 'none' }
  if (charge.status === 'paid') return { kind: 'paid' }
  if (charge.status === 'overdue') return { kind: 'overdue' }
  if (charge.status === 'pending' && isSafeInvoiceUrl(charge.invoiceUrl)) {
    return {
      kind: 'pay',
      value: charge.value,
      dueDate: charge.dueDate,
      invoiceUrl: charge.invoiceUrl,
      installmentCount: charge.mode === 'cardInstallments' && charge.installmentCount
        ? charge.installmentCount
        : null,
    }
  }
  return { kind: 'none' }
}

/** A pending or overdue charge can still turn into paid while the customer is away. */
export function shouldRefreshCharge(charge: PublicOrderCharge | null | undefined): boolean {
  return charge?.status === 'pending' || charge?.status === 'overdue'
}

/** Formats a YYYY-MM-DD due date as a calendar date (no timezone shift). */
export function formatChargeDueDate(dueDate: string, lang: ChargeLang): string {
  const [year, month, day] = dueDate.split('-').map(Number)
  if (!year || !month || !day) return dueDate
  const locale = lang === 'en' ? 'en-US' : lang === 'es' ? 'es-ES' : 'pt-BR'
  return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  })
}
