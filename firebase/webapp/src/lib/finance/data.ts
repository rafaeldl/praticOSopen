// Financeiro through the API (docs/WEB_API.md, "Financeiro"): the numbers come
// from the server, never from orders read in the browser. The browser sends
// its zone; the server uses it only when it is one of the company's country.
import { api } from '@/lib/session'
import { currentZone } from '@/lib/zone'

export interface FinanceRow {
  id: string
  number: number | null
  status: 'quote' | 'approved' | 'progress' | 'done' | 'canceled' | null
  customer: { id: string | null; name: string | null } | null
  device: string | null
  total: number
  paid: number
  open: number
  createdAt: string | null
  amount: number
}

export interface Debtor {
  key: string
  customer: { id: string | null; name: string | null } | null
  amount: number
  since: string | null
  orders: FinanceRow[]
}

export interface FinanceSummary {
  month: string
  zone: string
  from: string
  to: string
  received: { total: number; orders: FinanceRow[] }
  sold: { total: number; orders: FinanceRow[] }
  receivable: { total: number; owed: number; depositOwed: number; customers: number; debtors: Debtor[]; deposits: FinanceRow[] }
  progress: { total: number; orders: FinanceRow[] }
  truncated: boolean
}

export interface ReportRow extends FinanceRow {
  payment: 'paid' | 'pending'
  updatedAt: string | null
}

export interface Ranked {
  name: string | null
  total: number
  count: number
  quantity: number
}

export interface ReportCustomer {
  id: string | null
  name: string | null
  total: number
  paid: number
  remaining: number
  count: number
}

export interface FinanceReport {
  zone: string
  today: string
  from: string
  to: string
  count: number
  paidCount: number
  revenue: number
  paid: number
  remaining: number
  composition: { services: number; products: number }
  customers: ReportCustomer[]
  services: Ranked[]
  products: Ranked[]
  orders: ReportRow[]
  truncated: boolean
}

export interface ReportQuery {
  from: string
  to: string
  /** A customer id, or 'none' for orders without one. */
  customer?: string | null
  payment?: 'paid' | 'unpaid' | null
}

const zone = () => encodeURIComponent(currentZone())

export function financeSummary(month: string, signal?: AbortSignal): Promise<FinanceSummary> {
  return api<FinanceSummary>(`/v1/app/finance/summary?month=${encodeURIComponent(month)}&zone=${zone()}`, { signal })
}

export function financeReport(query: ReportQuery, signal?: AbortSignal): Promise<FinanceReport> {
  const params = new URLSearchParams({ from: query.from, to: query.to, zone: currentZone() })
  if (query.customer) params.set('customer', query.customer)
  if (query.payment) params.set('payment', query.payment)
  return api<FinanceReport>(`/v1/app/finance/report?${params.toString()}`, { signal })
}

/** Financeiro > Receber: every order that still owes, oldest first (read on the server). */
export function receivableRows(): Promise<{ orders: FinanceRow[]; truncated: boolean }> {
  return api<{ orders: FinanceRow[]; truncated: boolean }>(`/v1/app/finance/receivable?zone=${zone()}`)
}
