// Mandar ao cliente, receber e cobrar: pure rules (no Vue, no Firebase), covered
// by tests/receive-model.test.ts. Money is compared in cents, like the server
// (toCents in order-payment math): never "100 vezes menor", never a float drift.
import type { OrderStatus } from '@/lib/orders/model'
import { whatsappUrl } from '@/lib/share'

export const toCents = (value: number): number => Math.round((Number.isFinite(value) ? value : 0) * 100)
export const fromCents = (cents: number): number => cents / 100

// ---------------------------------------------------------------------------
// Payments of one order ("Já recebido")
// ---------------------------------------------------------------------------

export interface OrderDocument {
  id?: string
  url?: string
  contentType?: string
  fileName?: string | null
}

export interface Payment {
  id: string | null
  type: 'payment' | 'discount'
  amount: number
  /** Chosen by who registered (pix, cash, card, other). */
  method?: string
  /** Asaas: how the customer paid (PIX, BOLETO, CREDIT_CARD...). */
  billingType?: string
  /** Day the money came in: paidAt, or createdAt for old ones (paidOn in the app). */
  paidOn: string | null
  createdAt: string | null
  createdBy?: { id?: string; name?: string } | null
  /** Share of a receipt over several orders: undone in the receipt. */
  receiptGroupId?: string
  /** The proof file (documents[receiptDocumentId]) or the Asaas receipt page. */
  proofUrl?: string
  isAsaas: boolean
}

type Raw = Record<string, unknown>

function isoOf(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'string') return Number.isNaN(Date.parse(value)) ? null : new Date(value).toISOString()
  if (value instanceof Date) return value.toISOString()
  const ts = value as { toDate?: () => Date; seconds?: number }
  if (typeof ts.toDate === 'function') return ts.toDate().toISOString()
  if (typeof ts.seconds === 'number') return new Date(ts.seconds * 1000).toISOString()
  return null
}

/** Asaas webhook payments: `asaas_` ids (OrderPaymentMath.isAsaasTransaction). Locked. */
export const isAsaasId = (id: unknown): boolean => typeof id === 'string' && id.startsWith('asaas_')

/** Payments and discounts, newest day first (receive.history order in the app). */
export function paymentsOf(transactions: readonly unknown[], documents: readonly unknown[] = []): Payment[] {
  const docs = new Map<string, OrderDocument>()
  for (const doc of documents as OrderDocument[]) if (doc?.id) docs.set(doc.id, doc)
  return (transactions as Raw[])
    .filter((tx) => tx && (tx.type === 'payment' || tx.type === 'discount') && typeof tx.amount === 'number')
    .map((tx): Payment => {
      const createdAt = isoOf(tx.createdAt)
      const proof = typeof tx.receiptDocumentId === 'string' ? docs.get(tx.receiptDocumentId)?.url : undefined
      return {
        id: typeof tx.id === 'string' ? tx.id : null,
        type: tx.type as Payment['type'],
        amount: tx.amount as number,
        method: typeof tx.paymentMethod === 'string' ? tx.paymentMethod : undefined,
        billingType: typeof tx.billingType === 'string' ? tx.billingType : undefined,
        paidOn: isoOf(tx.paidAt) ?? createdAt,
        createdAt,
        createdBy: (tx.createdBy as Payment['createdBy']) ?? null,
        receiptGroupId: typeof tx.receiptGroupId === 'string' ? tx.receiptGroupId : undefined,
        proofUrl: safeUrl(proof) ?? safeUrl(tx.receiptUrl),
        isAsaas: isAsaasId(tx.id),
      }
    })
    .sort((a, b) => (b.paidOn ?? '').localeCompare(a.paidOn ?? ''))
}

/** Only http(s) links leave the screen as a link (never javascript: from a stored field). */
export function safeUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.toString() : undefined
  } catch {
    return undefined
  }
}

/**
 * "Remover": manual payments and discounts with an id the server can find.
 * Asaas payments only leave by a refund (409 ASAAS_LOCKED); a share of a receipt
 * over several orders is undone in the receipt (409 RECEIPT_SHARE).
 */
export function canRemove(payment: Payment): boolean {
  return !payment.isAsaas && !payment.receiptGroupId && !!payment.id
}

/** "Desfazer pagamentos": only with a manual one, and blocked by a receipt share (pay.order.undo-all). */
export function undoAllState(payments: readonly Payment[]): 'none' | 'blocked' | 'allowed' {
  const manual = payments.filter((p) => !p.isAsaas)
  if (!manual.length) return 'none'
  return manual.some((p) => p.receiptGroupId) ? 'blocked' : 'allowed'
}

/**
 * What an order still owes for Financeiro > Receber: a done order with a
 * balance, and an open one (approved, in progress) that already got a down
 * payment (fin.tab.receivable; not the app's P1 of the user test, where the
 * order with a down payment vanished). Quotes, canceled and open orders with
 * nothing paid are not owed yet. Cents, like the server.
 */
export function receivableOf(order: { status: OrderStatus; total?: number; paidAmount?: number; showsMoney: boolean }): number | null {
  if (!order.showsMoney || !receivesMoney(order.status)) return null
  const total = toCents(order.total ?? 0)
  const paid = toCents(order.paidAmount ?? 0)
  if (total <= 0 || paid >= total) return null
  if (order.status !== 'done' && paid <= 0) return null
  return fromCents(total - paid)
}

/** Quotes and canceled orders show the history only (pay.order.blocked-status). */
export const receivesMoney = (status: OrderStatus): boolean => status !== 'quote' && status !== 'canceled'

// ---------------------------------------------------------------------------
// Receipt over several orders of one customer (pay.customer.*)
// ---------------------------------------------------------------------------

export interface OpenOrder {
  id: string
  number: number | null
  open: number
  createdAt: string | null
  /** Created by who asks: a consultant's own order. */
  own: boolean
}

export interface Allocation {
  orderId: string
  number: number | null
  amount: number
  settles: boolean
}

/**
 * Splits what came in over the picked orders, oldest first, each one up to what
 * it still owes (customer_receipt_service and the server's registerCustomerReceipt).
 * Never more than what the picked orders owe; cents all the way.
 */
export function allocate(amount: number, picked: readonly OpenOrder[]): Allocation[] {
  let left = toCents(amount)
  const sorted = [...picked].sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? '') || (a.number ?? 0) - (b.number ?? 0))
  const result: Allocation[] = []
  for (const order of sorted) {
    if (left <= 0) break
    const owed = toCents(order.open)
    const cents = Math.min(owed, left)
    if (cents <= 0) continue
    left -= cents
    result.push({ orderId: order.id, number: order.number, amount: fromCents(cents), settles: cents === owed })
  }
  return result
}

export const owedOf = (orders: readonly OpenOrder[]): number => fromCents(orders.reduce((sum, order) => sum + toCents(order.open), 0))

/** "Quita as OS 12, 15. Paga R$ 50 da OS 18. Ficam R$ 30." parts (receivePreview* in the app). */
export function allocationSummary(allocations: readonly Allocation[], owed: number): { settled: (number | null)[]; part: Allocation | null; left: number } {
  const settled = allocations.filter((a) => a.settles).map((a) => a.number)
  const part = allocations.find((a) => !a.settles) ?? null
  const paid = allocations.reduce((sum, a) => sum + toCents(a.amount), 0)
  return { settled, part, left: fromCents(Math.max(0, toCents(owed) - paid)) }
}

/** "AAAA-MM-DD" of a local day, and the paidAt the app writes: now for today, noon for another day (receive_date_row). */
export function paidAtFor(day: string, now: Date): string {
  const today = localDay(now)
  if (day === today) return now.toISOString()
  const [y, m, d] = day.split('-').map(Number)
  return new Date(y as number, (m as number) - 1, d as number, 12, 0, 0).toISOString()
}

export function localDay(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export function addDays(day: string, days: number): string {
  const [y, m, d] = day.split('-').map(Number)
  return localDay(new Date(y as number, (m as number) - 1, (d as number) + days))
}

// ---------------------------------------------------------------------------
// Link to the customer (order.share-sheet.*)
// ---------------------------------------------------------------------------

export type SharePermission = 'view' | 'approve' | 'comment'
export interface ShareToken {
  token: string
  url: string
  permissions: SharePermission[]
  expiresAt: string
  isExpired?: boolean
  createdAt?: string
}

/**
 * The link to send: the newest one still valid (the API already drops revoked
 * ones). Two tabs that each made a link end up on the same one, the one the
 * server kept (revokeOlderTokens keeps the newest).
 */
export function pickToken(tokens: readonly ShareToken[], now: Date): ShareToken | null {
  return (
    tokens
      .filter((token) => !token.isExpired && Date.parse(token.expiresAt) > now.getTime())
      .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''))[0] ?? null
  )
}

export type PermissionKind = 'all' | 'approve' | 'comment' | 'view'
export function permissionKind(permissions: readonly string[]): PermissionKind {
  const approve = permissions.includes('approve')
  const comment = permissions.includes('comment')
  if (approve && comment) return 'all'
  if (approve) return 'approve'
  if (comment) return 'comment'
  return 'view'
}
export const PERMISSIONS_OF: Record<PermissionKind, SharePermission[]> = {
  all: ['view', 'approve', 'comment'],
  approve: ['view', 'approve'],
  comment: ['view', 'comment'],
  view: ['view'],
}

/** Days the link still has, to the nearest day (the picker shows the token's real validity, defect 81). */
export function validityDays(token: Pick<ShareToken, 'expiresAt'>, now: Date): number {
  return Math.max(1, Math.round((Date.parse(token.expiresAt) - now.getTime()) / 86_400_000))
}

/** Which message goes with the link: by where the order stands (share_link_service). */
export function messageKind(status: OrderStatus): 'approved' | 'progress' | 'done' | 'quote' | 'other' {
  if (status === 'approved' || status === 'progress' || status === 'done' || status === 'quote') return status
  return 'other'
}

/**
 * "Ver como o cliente vê": the same link with `?preview=1`. The customer page
 * then shows a banner and turns approve/reject/rate/comment off, and the api
 * does not count the visit (share-token.middleware countsAsVisit).
 */
export function previewUrl(url: string): string {
  const parsed = new URL(url)
  parsed.searchParams.set('preview', '1')
  return parsed.toString()
}

/** wa.me with the text; without a number WhatsApp asks for the contact. */
export function whatsappLink(number: string, text: string): string {
  return whatsappUrl(number, text)
}

// ---------------------------------------------------------------------------
// Asaas charges (charge.*, pay.widget.charge-*)
// ---------------------------------------------------------------------------

export type ChargeStatus = 'pending' | 'overdue' | 'paid' | 'canceled' | 'refunded'
export interface Charge {
  id: string
  status: ChargeStatus
  value: number
  dueDate: string
  mode?: 'single' | 'cardInstallments'
  installmentCount?: number
  paidCount: number
  invoiceUrl?: string
  createdAt: string | null
  autoCanceled?: boolean
  orderIds?: string[]
}

export function chargeOf(id: string, raw: Raw): Charge {
  return {
    id,
    status: (['pending', 'overdue', 'paid', 'canceled', 'refunded'].includes(raw.status as string) ? raw.status : 'canceled') as ChargeStatus,
    value: typeof raw.value === 'number' ? raw.value : 0,
    dueDate: typeof raw.dueDate === 'string' ? raw.dueDate : '',
    mode: raw.mode === 'cardInstallments' ? 'cardInstallments' : 'single',
    installmentCount: typeof raw.installmentCount === 'number' ? raw.installmentCount : undefined,
    paidCount: Array.isArray(raw.paidAsaasPaymentIds) ? raw.paidAsaasPaymentIds.length : 0,
    invoiceUrl: asaasUrl(raw.invoiceUrl),
    createdAt: isoOf(raw.createdAt),
    autoCanceled: raw.autoCanceled === true,
    orderIds: Array.isArray(raw.orderIds) ? (raw.orderIds as string[]) : undefined,
  }
}

/** Only an https Asaas page is offered as a payment link (ASAAS_INTEGRATION, public page). */
export function asaasUrl(value: unknown): string | undefined {
  const url = safeUrl(value)
  if (!url) return undefined
  const host = new URL(url).hostname
  return url.startsWith('https:') && (host === 'asaas.com' || host.endsWith('.asaas.com')) ? url : undefined
}

export const isOpenCharge = (charge: Pick<Charge, 'status'>) => charge.status === 'pending' || charge.status === 'overdue'

const newestFirst = (a: Charge, b: Charge) => (b.createdAt ?? '').localeCompare(a.createdAt ?? '') || b.id.localeCompare(a.id)

/** The open link, the newest one (the server keeps one per debt). */
export function openChargeOf(charges: readonly Charge[]): Charge | null {
  return [...charges].filter(isOpenCharge).sort(newestFirst)[0] ?? null
}

/** The installment plan the server canceled, while the order still owes (pay.order.charge-canceled-resend). */
export function canceledPlanOf(charges: readonly Charge[], remaining: number): Charge | null {
  const latest = [...charges].sort(newestFirst)[0]
  return latest && latest.autoCanceled && toCents(remaining) > 0 ? latest : null
}

export interface ChargeState {
  expired: boolean
  /** The order now owes less than the link charges, and nothing was paid by it (pay.widget.charge-changed). */
  changed: boolean
  /** Owed beyond what the link charges ("Falta mais R$ X fora do link"). */
  outside: number
}

export function chargeState(charge: Charge, remaining: number, today: string): ChargeState {
  const value = toCents(charge.value)
  const owed = toCents(remaining)
  return {
    expired: charge.status === 'overdue' || (!!charge.dueDate && charge.dueDate < today),
    changed: value > owed && charge.paidCount === 0,
    outside: owed > value ? fromCents(owed - value) : 0,
  }
}

/** Installments 2 to 12: each value in cents, the last one takes the rest. */
export function installmentValue(total: number, count: number): number {
  return fromCents(Math.floor(toCents(total) / count))
}

/** Value of a new charge: what was asked, if more than 0 and not above what is owed; else what is owed (create_customer_charge). */
export function initialChargeValue(asked: number | null | undefined, owed: number): number {
  return asked && toCents(asked) > 0 && toCents(asked) <= toCents(owed) ? asked : owed
}
