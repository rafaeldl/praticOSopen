// One shape for an order, whether it came from Firestore (who sees values) or
// from the API projection (who does not). Pure: no Vue, no Firebase, so the
// rules are covered by vitest (tests/orders-model.test.ts).
import {
  allowedTransitions,
  dayKey,
  isOverdue,
  orderPermissions,
  orderTotal,
  receivePermissions,
  remainingBalance,
  roundMoney,
  type OrderRole,
} from '@/lib/rules/order-rules'
import { instantOf, wallParts } from '@/lib/zone'
import { readingsOf } from '@/lib/device-reading'

export type OrderStatus = 'quote' | 'approved' | 'progress' | 'done' | 'canceled'
export const STATUSES: OrderStatus[] = ['quote', 'approved', 'progress', 'done', 'canceled']
export const OPEN_STATUSES: OrderStatus[] = ['quote', 'approved', 'progress']
export type HoldReason = 'part' | 'customer' | 'authorization' | 'other'
export const HOLD_REASONS: HoldReason[] = ['part', 'customer', 'authorization', 'other']

export interface Aggr {
  id?: string
  name?: string
}
export interface DeviceAggr extends Aggr {
  serial?: string | null
}
export interface OrderLine {
  /** Stored id, the API id, or null until line-ids.ts derives it. */
  id: string | null
  kind: 'service' | 'product'
  catalogId?: string
  name: string
  description?: string | null
  /** null: no price (out of the total). undefined: hidden from this person. */
  value?: number | null
  quantity?: number
  /** Product line total; undefined when hidden. */
  total?: number | null
  deviceId?: string | null
}
export interface OrderTransaction {
  id?: string
  type: 'payment' | 'discount'
  amount: number
  paymentMethod?: string
  createdAt?: string
}
export interface OrderPhoto {
  id?: string
  url: string
  storagePath?: string
  description?: string
}
export interface Order {
  id: string
  number?: number
  status: OrderStatus
  customer?: Aggr & { phone?: string }
  devices: DeviceAggr[]
  lines: OrderLine[]
  /** Services and products were in the source: false for list rows of the API. */
  hasLines: boolean
  photos: OrderPhoto[]
  onHold?: { reason: HoldReason; note?: string; since: string } | null
  /** Work stage while `progress` (lib/orders/stages.ts): the stage, the place in its column and since when. */
  stage?: { id: string; rank: number; since: string } | null
  assignedTo?: Aggr | null
  dueDate?: string | null
  scheduledDate?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  /** When it became done (UTC ISO, written only by the server; gone when it leaves done). */
  completedAt?: string | null
  /** Opaque version for expectedUpdatedAt (versionOf): sent back as is, never converted by zone. */
  version?: string | null
  createdBy?: Aggr | null
  /** Money: absent for who does not see values. */
  showsMoney: boolean
  total?: number
  discount?: number
  paidAmount?: number
  transactions: OrderTransaction[]
  /** Proof files of payments (receiptDocumentId); only for who sees values. */
  documents?: unknown[]
  address?: string | null
  customData?: Record<string, unknown>
  /** Each device's reading at this visit, by device id (lib/device-reading.ts). */
  deviceReadings?: Record<string, number>
  /** Files attached to the order (nota, contrato, garantia, outro): never a payment proof (order.document.open). */
  attachments: OrderAttachment[]
  /** What the customer rated on the share link (1 to 5), when there is a valid score. */
  rating?: { score: number; comment?: string } | null
  /** The customer link kept on the order (OrderShareLink): only to know if one is active. */
  shareLink?: { token: string | null; expiresAt: string | null } | null
}

export type AttachmentType = 'receipt' | 'invoice' | 'contract' | 'warranty' | 'other'
export const ATTACHMENT_TYPES: AttachmentType[] = ['receipt', 'invoice', 'contract', 'warranty', 'other']
export interface OrderAttachment {
  id: string
  url: string
  storagePath?: string
  fileName?: string
  contentType?: string
  fileSize?: number
  type: AttachmentType
  createdAt?: string | null
}

type Raw = Record<string, unknown>

/**
 * The order's version for `expectedUpdatedAt`: what the API sent (`version`),
 * or the stored `updatedAt` as is (a Timestamp as its millis), the same rule as
 * the server's order-version.ts. Never read as an instant: the app writes local
 * time without a zone, which the browser and the server would read differently.
 */
export function versionOf(raw: Raw): string | null {
  if (typeof raw.version === 'string' && raw.version) return raw.version
  const value = raw.updatedAt
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'string') return value
  if (typeof value === 'number') return String(value)
  if (value instanceof Date) return String(value.getTime())
  const ts = value as { toMillis?: () => number; seconds?: number; nanoseconds?: number }
  if (typeof ts.toMillis === 'function') return String(ts.toMillis())
  if (typeof ts.seconds === 'number') return String(ts.seconds * 1000 + Math.floor((ts.nanoseconds ?? 0) / 1e6))
  return null
}

/** Firestore Timestamp, Date, ISO string or millis → ISO string. */
export function isoOf(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null
  // Text without a zone (the app's visit and delivery) is the company's local time.
  if (typeof value === 'string') {
    const date = instantOf(value)
    return Number.isNaN(date.getTime()) ? null : date.toISOString()
  }
  if (value instanceof Date) return value.toISOString()
  if (typeof value === 'number') return new Date(value).toISOString()
  const ts = value as { toDate?: () => Date; seconds?: number }
  if (typeof ts.toDate === 'function') return ts.toDate().toISOString()
  if (typeof ts.seconds === 'number') return new Date(ts.seconds * 1000).toISOString()
  return null
}

const num = (value: unknown): number | undefined => (typeof value === 'number' && Number.isFinite(value) ? value : undefined)
const priced = (value: unknown, show: boolean): number | null | undefined => (show ? (num(value) ?? null) : undefined)

function linesOf(raw: Raw, show: boolean): OrderLine[] {
  const services = (Array.isArray(raw.services) ? raw.services : []) as Raw[]
  const products = (Array.isArray(raw.products) ? raw.products : []) as Raw[]
  const service = services.map((line): OrderLine => {
    const catalog = (line.service ?? {}) as Raw
    return {
      id: typeof line.id === 'string' ? line.id : null,
      kind: 'service',
      catalogId: catalog.id as string | undefined,
      name: (catalog.name as string) ?? (line.description as string) ?? '',
      description: (line.description as string | null) ?? null,
      value: priced(line.value, show),
      deviceId: (line.deviceId as string | null) ?? null,
    }
  })
  const product = products.map((line): OrderLine => {
    const catalog = (line.product ?? {}) as Raw
    const value = priced(line.value, show)
    const quantity = num(line.quantity) ?? 1
    return {
      id: typeof line.id === 'string' ? line.id : null,
      kind: 'product',
      catalogId: catalog.id as string | undefined,
      name: (catalog.name as string) ?? (line.description as string) ?? '',
      description: (line.description as string | null) ?? null,
      value,
      quantity,
      total: show ? (value === null || value === undefined ? null : (num(line.total) ?? roundMoney(value * quantity))) : undefined,
      deviceId: (line.deviceId as string | null) ?? null,
    }
  })
  return [...service, ...product]
}

function devicesOf(raw: Raw): DeviceAggr[] {
  const list = Array.isArray(raw.devices) ? (raw.devices as DeviceAggr[]) : []
  if (list.length) return list.filter((device) => device && (device.id || device.name))
  const one = raw.device as DeviceAggr | undefined
  return one && (one.id || one.name) ? [one] : []
}

function statusOf(value: unknown): OrderStatus {
  return STATUSES.includes(value as OrderStatus) ? (value as OrderStatus) : 'quote'
}

/**
 * What was paid. Legacy orders marked paid before `paidAmount` existed (old
 * app, until 2026-01) have `payment: 'paid'` and no paidAmount: their total
 * counts as paid (server effectivePaidAmount), so they never show a balance.
 */
export function paidAmountOf(raw: Raw): number {
  const paid = num(raw.paidAmount)
  if (paid !== undefined) return paid
  return raw.payment === 'paid' ? (num(raw.total) ?? 0) : 0
}

/** A Firestore document or an API projection. `showsMoney` false drops every value. */
export function normalizeOrder(id: string, raw: Raw, showsMoney: boolean): Order {
  const hold = raw.onHold as Order['onHold']
  const status = statusOf(raw.status)
  return {
    id,
    number: num(raw.number),
    status,
    customer: (raw.customer as Order['customer']) ?? undefined,
    devices: devicesOf(raw),
    lines: linesOf(raw, showsMoney),
    hasLines: Array.isArray(raw.services) || Array.isArray(raw.products),
    photos: (Array.isArray(raw.photos) ? (raw.photos as OrderPhoto[]) : []).filter((photo) => photo?.url),
    // A mark outside approved and progress is ignored (order.hold.view).
    onHold: hold && hold.reason && (status === 'approved' || status === 'progress') ? { ...hold, since: isoOf(hold.since) ?? '' } : null,
    stage: stageOfRaw(raw.stage, status),
    assignedTo: (raw.assignedTo as Aggr | null) ?? null,
    dueDate: isoOf(raw.dueDate),
    scheduledDate: isoOf(raw.scheduledDate),
    createdAt: isoOf(raw.createdAt),
    updatedAt: isoOf(raw.updatedAt),
    completedAt: isoOf(raw.completedAt),
    version: versionOf(raw),
    createdBy: (raw.createdBy as Aggr | null) ?? null,
    showsMoney,
    total: showsMoney ? (num(raw.total) ?? 0) : undefined,
    discount: showsMoney ? (num(raw.discount) ?? 0) : undefined,
    paidAmount: showsMoney ? paidAmountOf(raw) : undefined,
    transactions: showsMoney && Array.isArray(raw.transactions) ? (raw.transactions as OrderTransaction[]) : [],
    documents: showsMoney && Array.isArray(raw.documents) ? (raw.documents as unknown[]) : undefined,
    attachments: attachmentsOf(raw.documents, showsMoney),
    address: (raw.address as string | null) ?? null,
    customData: (raw.customData as Record<string, unknown>) ?? undefined,
    deviceReadings: readingsOf(raw.deviceReadings),
    rating: ratingOf(raw.rating),
    shareLink: shareLinkOf(raw.shareLink),
  }
}

/** A stage outside `progress` is ignored (the trigger removes it). */
function stageOfRaw(value: unknown, status: OrderStatus): Order['stage'] {
  const raw = (value ?? null) as { id?: unknown; rank?: unknown; since?: unknown } | null
  if (status !== 'progress' || !raw || typeof raw !== 'object' || typeof raw.id !== 'string' || !raw.id) return null
  return { id: raw.id, rank: typeof raw.rank === 'number' && Number.isFinite(raw.rank) ? raw.rank : Number.POSITIVE_INFINITY, since: isoOf(raw.since) ?? '' }
}

function shareLinkOf(value: unknown): Order['shareLink'] {
  const raw = (value ?? null) as { token?: unknown; expiresAt?: unknown } | null
  if (!raw || typeof raw !== 'object') return null
  return { token: typeof raw.token === 'string' && raw.token ? raw.token : null, expiresAt: isoOf(raw.expiresAt) }
}

/** The app's OrderRating.hasRating: a whole score from 1 to 5, else nothing. */
export function ratingOf(value: unknown): Order['rating'] {
  const raw = (value ?? null) as { score?: unknown; comment?: unknown } | null
  const score = raw?.score
  if (typeof score !== 'number' || !Number.isInteger(score) || score < 1 || score > 5) return null
  const comment = typeof raw?.comment === 'string' ? raw.comment.trim() : ''
  return comment ? { score, comment } : { score }
}

// ---------------------------------------------------------------------------
// Dates and states
// ---------------------------------------------------------------------------

export const isOpen = (order: Pick<Order, 'status'>) => OPEN_STATUSES.includes(order.status)
export const isActive = (order: Pick<Order, 'status'>) => order.status === 'approved' || order.status === 'progress'
export const isHeld = (order: Pick<Order, 'status' | 'onHold'>) => !!order.onHold && isActive(order)

export function overdue(order: Pick<Order, 'status' | 'dueDate'>, now: Date): boolean {
  return isOverdue(order.status, order.dueDate, now)
}

/** The company's calendar day as a UTC midnight, so days subtract exactly. */
const dayIndex = (date: Date) => {
  const p = wallParts(date)
  return Date.UTC(p.y, p.m - 1, p.d) / 86400000
}

/** Whole calendar days from `from` to `to` (company's days), never negative. */
export function daysBetween(from: Date, to: Date): number {
  return Math.max(0, dayIndex(to) - dayIndex(from))
}

/** How late, for "Atrasada 3 dias / há 2 meses / há 1 ano" (home.row.overdue). */
export function lateness(order: Pick<Order, 'status' | 'dueDate'>, now: Date): { unit: 'days' | 'months' | 'years'; count: number } | null {
  if (!overdue(order, now) || !order.dueDate) return null
  const days = Math.max(1, daysBetween(new Date(order.dueDate), now))
  if (days >= 365) return { unit: 'years', count: Math.floor(days / 365) }
  if (days >= 60) return { unit: 'months', count: Math.floor(days / 30) }
  return { unit: 'days', count: days }
}

export function holdDays(order: Pick<Order, 'onHold' | 'status'>, now: Date): number | null {
  if (!isHeld(order) || !order.onHold?.since) return null
  return daysBetween(new Date(order.onHold.since), now)
}

export const sameDay = (iso: string | null | undefined, now: Date) => !!iso && dayKey(new Date(iso)) === dayKey(now)

/** today / tomorrow / yesterday, or null: the screen writes the date then. */
export function relativeDay(iso: string, now: Date): 'today' | 'tomorrow' | 'yesterday' | null {
  const diff = dayIndex(new Date(iso)) - dayIndex(now)
  return diff === 0 ? 'today' : diff === 1 ? 'tomorrow' : diff === -1 ? 'yesterday' : null
}

/** Midnight means "only the day": the hour is not shown. */
export function hasTime(iso: string): boolean {
  const p = wallParts(instantOf(iso))
  return p.h !== 0 || p.min !== 0
}

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

export function totals(order: Order) {
  const { unpricedCount } = orderTotal(
    order.lines.filter((line) => line.kind === 'service'),
    order.lines.filter((line) => line.kind === 'product'),
    0,
  )
  const total = order.total ?? 0
  const paid = order.paidAmount ?? 0
  const discount = order.discount ?? 0
  const subtotal = roundMoney(total + discount)
  return { total, paid, discount, subtotal, unpricedCount, remaining: remainingBalance(total, paid) }
}

/**
 * Payment under the total on every row that charges something (not quotes or
 * canceled): "Pago" when all came in, "falta R$ X" when part did, nothing when
 * nothing did (the total is what is left). Same rule as the app's list.
 */
export function paymentOnRow(order: Order): { paid: true } | { left: number } | null {
  if (!order.showsMoney || order.status === 'quote' || order.status === 'canceled') return null
  const total = order.total ?? 0
  if (total <= 0) return null
  const paid = order.paidAmount ?? 0
  const left = total - paid
  if (left <= 0.009) return { paid: true }
  return paid > 0.009 ? { left: roundMoney(left) } : null
}

/** "falta receber R$ X" on a done row (home.row.remaining): total > 0 and balance above 0,009. */
export function remainingOnRow(order: Order): number | null {
  if (!order.showsMoney || order.status !== 'done') return null
  const total = order.total ?? 0
  const left = total - (order.paidAmount ?? 0)
  return total > 0 && left > 0.009 ? roundMoney(left) : null
}

// ---------------------------------------------------------------------------
// Permissions on one order
// ---------------------------------------------------------------------------

export function orderRoleOf(role: string | null | undefined): OrderRole | null {
  const r = role === 'owner' ? 'admin' : role
  return r === 'admin' || r === 'manager' || r === 'supervisor' || r === 'consultant' || r === 'technician' ? r : null
}

export interface OrderAccess {
  canEdit: boolean
  canEditMainFields: boolean
  canExecute: boolean
  canAssign: boolean
  canDelete: boolean
  canChangeHold: boolean
  canReceive: boolean
  canDiscount: boolean
  transitions: OrderStatus[]
}

const NONE: OrderAccess = {
  canEdit: false,
  canEditMainFields: false,
  canExecute: false,
  canAssign: false,
  canDelete: false,
  canChangeHold: false,
  canReceive: false,
  canDiscount: false,
  transitions: [],
}

/** What this person may do on this order. The server checks again. */
export function accessOf(order: Order, role: string | null | undefined, uid: string | null, useFinancial: boolean): OrderAccess {
  const r = orderRoleOf(role)
  if (!r) return NONE
  const isCreator = !!uid && order.createdBy?.id === uid
  const base = orderPermissions(r, isCreator, order.status)
  if (!base.canAccess) return NONE
  const money = receivePermissions(r, isCreator, useFinancial)
  // Cancel is never offered as a transition here: it has its own confirmed action.
  return {
    canEdit: base.canEdit,
    canEditMainFields: base.canEditMainFields,
    canExecute: base.canExecute,
    canAssign: base.canAssign,
    canDelete: base.canDelete,
    canChangeHold: r !== 'consultant' && isActive(order),
    canReceive: money.canReceive && order.showsMoney,
    canDiscount: money.canDiscount && order.showsMoney,
    transitions: allowedTransitions(r, isCreator, order.status) as OrderStatus[],
  }
}

/**
 * Nova OS: createOrder, but never the technician (AuthorizationService.canCreateOrder;
 * the permission matrix still lists it, the app does not offer it).
 */
export function canCreateOrders(role: string | null | undefined, hasCreateOrder: boolean): boolean {
  return hasCreateOrder && orderRoleOf(role) !== 'technician'
}

/** Initial status a creator may pick (getAvailableStatuses as creator), never canceled (defect 12). */
export function createStatuses(role: string | null | undefined): OrderStatus[] {
  const r = orderRoleOf(role)
  if (r === 'admin' || r === 'manager') return ['quote', 'approved', 'progress', 'done']
  if (r === 'consultant') return ['quote', 'approved']
  if (r === 'supervisor') return ['quote', 'approved', 'progress']
  return []
}

export type NextStep =
  | { kind: 'status'; to: 'approved' | 'progress' | 'done' }
  | { kind: 'resume' }
  | { kind: 'receive'; amount: number }

/** The blue button: one next step, or none. */
export function nextStep(order: Order, access: OrderAccess): NextStep | null {
  if (order.status === 'quote' && access.transitions.includes('approved')) return { kind: 'status', to: 'approved' }
  if (order.status === 'approved' && access.transitions.includes('progress')) {
    return isHeld(order) && access.canChangeHold ? { kind: 'resume' } : { kind: 'status', to: 'progress' }
  }
  if (order.status === 'progress') {
    if (isHeld(order)) return access.canChangeHold ? { kind: 'resume' } : null
    if (access.transitions.includes('done')) return { kind: 'status', to: 'done' }
  }
  if (order.status === 'done' && access.canReceive) {
    const left = totals(order).remaining
    if (left > 0) return { kind: 'receive', amount: left }
  }
  return null
}

// ---------------------------------------------------------------------------
// List: filters, groups, summary
// ---------------------------------------------------------------------------

export type ListFilter = 'open' | 'late' | 'quotes' | 'onHold' | 'unpaid' | 'mine' | 'done' | 'all'

/** Technician: Minhas, Paradas, Todas. Everyone else: the five of the app. */
export function filtersFor(role: string | null | undefined, showsMoney = false): ListFilter[] {
  if (orderRoleOf(role) === 'technician') return ['mine', 'onHold', 'all']
  // Same filters and order as the app (HomeContent._buildFilters); Sem receber only with values.
  return ['open', 'late', 'quotes', 'onHold', ...(showsMoney ? (['unpaid'] as ListFilter[]) : []), 'done', 'all']
}

export function defaultFilter(role: string | null | undefined): ListFilter {
  return orderRoleOf(role) === 'technician' ? 'mine' : 'open'
}

/** Statuses the server query asks for. Quotes, Paradas and Minhas filter the open ones here, like the app. */
export function queryStatuses(filter: ListFilter): OrderStatus[] | null {
  if (filter === 'done' || filter === 'unpaid') return ['done']
  if (filter === 'all') return null
  return OPEN_STATUSES
}

const byDate = (key: 'dueDate' | 'scheduledDate' | 'createdAt', dir = 1) => (a: Order, b: Order) =>
  ((a[key] ?? '').localeCompare(b[key] ?? '') || a.id.localeCompare(b.id)) * dir

/**
 * The technician's "Agora" (HomeRules.nextVisit, home.next.card): of their open
 * orders with a visit today, the first not started yet, else the first running.
 */
export function nextVisit(rows: Order[], now: Date, uid: string | null): Order | null {
  const today = rows.filter((o) => isOpen(o) && o.assignedTo?.id === uid && sameDay(o.scheduledDate, now)).sort(byDate('scheduledDate'))
  return today.find((o) => o.status !== 'progress') ?? today[0] ?? null
}

/**
 * Rows of a filter in screen order (home.rules.groups). The rows come from the
 * filter's own server query (lib/orders/data.ts), so none is left out here:
 * open: late (oldest promise first), then today, then server order.
 * late: oldest promise first. quotes: oldest first.
 * onHold: stopped longest first. mine: today's visits by hour first.
 */
export function rowsFor(filter: ListFilter, rows: Order[], now: Date, uid: string | null): Order[] {
  switch (filter) {
    case 'open': {
      const late = rows.filter((o) => overdue(o, now)).sort(byDate('dueDate'))
      const today = rows.filter((o) => !overdue(o, now) && (sameDay(o.dueDate, now) || sameDay(o.scheduledDate, now)))
      const rest = rows.filter((o) => !late.includes(o) && !today.includes(o))
      return [...late, ...today, ...rest]
    }
    case 'late':
      return [...rows].sort(byDate('dueDate'))
    case 'quotes':
      return [...rows].sort(byDate('createdAt'))
    case 'onHold':
      return [...rows].sort((a, b) => (a.onHold?.since ?? '').localeCompare(b.onHold?.since ?? '') || a.id.localeCompare(b.id))
    case 'mine': {
      const visits = rows.filter((o) => sameDay(o.scheduledDate, now)).sort(byDate('scheduledDate'))
      return [...visits, ...rowsFor('open', rows.filter((o) => !visits.includes(o)), now, uid)]
    }
    default:
      return rows
  }
}

/**
 * Does the order still belong to the filter? Only for an order changed on this
 * screen (a status, a hold, a payment): it leaves the list at once instead of
 * waiting for the next read. What the list shows comes from the server query.
 */
export function matchesFilter(filter: ListFilter, order: Order, now: Date, uid: string | null): boolean {
  switch (filter) {
    case 'open':
      return isOpen(order)
    case 'late':
      return isOpen(order) && overdue(order, now)
    case 'unpaid':
      return remainingOnRow(order) !== null
    case 'quotes':
      return order.status === 'quote'
    case 'onHold':
      return isHeld(order)
    case 'mine':
      return isOpen(order) && order.assignedTo?.id === uid
    case 'done':
      return order.status === 'done'
    case 'all':
      return true
  }
}

/** "Todas": by month of creation in arrival order; without a date, a last group without title. */
export function monthGroups(rows: Order[]): { key: string; month: Date | null; rows: Order[] }[] {
  const groups: { key: string; month: Date | null; rows: Order[] }[] = []
  const undated: Order[] = []
  for (const row of rows) {
    if (!row.createdAt) {
      undated.push(row)
      continue
    }
    const date = new Date(row.createdAt)
    const key = `${date.getFullYear()}-${date.getMonth()}`
    let group = groups.find((item) => item.key === key)
    if (!group) groups.push((group = { key, month: new Date(date.getFullYear(), date.getMonth(), 1), rows: [] }))
    group.rows.push(row)
  }
  if (undated.length) groups.push({ key: 'none', month: null, rows: undated })
  return groups
}

export type Summary =
  | { kind: 'open'; open: number; late: number }
  | { kind: 'quotes'; count: number }
  | { kind: 'onHold'; count: number }
  | { kind: 'mine'; count: number; today: boolean }
  | { kind: 'unpaid'; count: number; amount: number }
  | null

/** What the server counted for a filter (Firestore aggregation or the API's total). */
export interface FilterCounts {
  count: number
  /** Em aberto: how many of them are late. */
  late?: number
  /** Sem receber: what is left to receive. */
  amount?: number
}

/**
 * The sentence on top (home.summary.count) from the server's counts, so it
 * holds before every page is loaded. Without counts (a filter the API cannot
 * count), it waits for the whole list, as before.
 */
export function summaryFromCounts(filter: ListFilter, counts: FilterCounts | null, visible: Order[], loadedAll: boolean, now: Date): Summary {
  // Minhas: "N com você hoje" needs every row; until then, how many are with the person.
  if (filter === 'mine' && loadedAll) return summaryOf(filter, visible, true, now)
  if (!counts) return summaryOf(filter, visible, loadedAll, now)
  if (!counts.count) return null
  if (filter === 'open') return { kind: 'open', open: counts.count, late: counts.late ?? 0 }
  if (filter === 'quotes') return { kind: 'quotes', count: counts.count }
  if (filter === 'onHold') return { kind: 'onHold', count: counts.count }
  if (filter === 'unpaid') return { kind: 'unpaid', count: counts.count, amount: roundMoney(counts.amount ?? 0) }
  if (filter === 'mine') return { kind: 'mine', count: counts.count, today: false }
  return null
}

/** One sentence on top (home.summary.count) from the rows: only with the whole list loaded and something in it. */
export function summaryOf(filter: ListFilter, visible: Order[], loadedAll: boolean, now: Date): Summary {
  if (!loadedAll || !visible.length) return null
  if (filter === 'open') return { kind: 'open', open: visible.length, late: visible.filter((o) => overdue(o, now)).length }
  if (filter === 'quotes') return { kind: 'quotes', count: visible.length }
  if (filter === 'unpaid') return { kind: 'unpaid', count: visible.length, amount: roundMoney(visible.reduce((sum, o) => sum + (remainingOnRow(o) ?? 0), 0)) }
  if (filter === 'onHold') return { kind: 'onHold', count: visible.length }
  if (filter === 'mine') {
    const today = visible.filter((o) => sameDay(o.scheduledDate, now) || sameDay(o.dueDate, now)).length
    return today ? { kind: 'mine', count: today, today: true } : { kind: 'mine', count: visible.length, today: false }
  }
  return null
}

const fold = (text: string) =>
  text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()

/** Number, customer, status text, device name or serial; ignores case and accents. */
/** The exact number first, then the rest in screen order (search). */
export function exactFirst(rows: Order[], query: string): Order[] {
  const number = Number(query.trim())
  if (!Number.isInteger(number) || number <= 0) return rows
  return [...rows.filter((o) => o.number === number), ...rows.filter((o) => o.number !== number)]
}

export function matchesSearch(order: Order, query: string, statusText: string): boolean {
  const words = fold(query).split(/\s+/).filter(Boolean)
  if (!words.length) return true
  const hay = fold(
    [order.number ?? '', order.customer?.name ?? '', statusText, ...order.devices.flatMap((d) => [d.name ?? '', d.serial ?? ''])].join(' '),
  )
  return words.every((word) => hay.includes(word))
}

/** "Gol +2" (home.row.detail). */
export function deviceSummary(order: Order): string {
  const [first, ...more] = order.devices
  if (!first) return ''
  const name = first.name ?? first.serial ?? ''
  return more.length ? `${name} +${more.length}` : name
}

/** Service names for one list line ("5× pintura (capô, porta)"): the same service (case and
 * spaces ignored) shows once, with how many times, in the order it first appears, followed by
 * the descriptions of its lines (each once). Same rule as the app (servicesSummary in
 * lib/utils/order_items.dart). */
export function servicesSummary(order: Order): string {
  const keyOf = (text: string) => text.trim().toLowerCase().replace(/\s+/g, ' ')
  const seen = new Map<string, { name: string; count: number; notes: Map<string, string> }>()
  for (const line of order.lines) {
    if (line.kind !== 'service') continue
    const name = (line.name ?? '').trim()
    if (!name) continue
    const key = keyOf(name)
    let entry = seen.get(key)
    if (!entry) seen.set(key, (entry = { name, count: 0, notes: new Map() }))
    entry.count += 1
    const note = (line.description ?? '').trim()
    if (note && keyOf(note) !== key && !entry.notes.has(keyOf(note))) entry.notes.set(keyOf(note), note)
  }
  return [...seen.values()]
    .map(({ name, count, notes }) => `${count > 1 ? `${count}× ` : ''}${name}${notes.size ? ` (${[...notes.values()].join(', ')})` : ''}`)
    .join(', ')
}

/** Lines grouped by device when the order has two or more (order.item.by-device). */
export function linesByDevice(order: Order): { device: DeviceAggr | null; lines: OrderLine[] }[] {
  if (order.devices.length < 2) return [{ device: null, lines: order.lines }]
  const ids = new Set(order.devices.map((device) => device.id))
  const groups = order.devices.map((device) => ({ device, lines: order.lines.filter((line) => line.deviceId === device.id) }))
  const general = order.lines.filter((line) => !line.deviceId || !ids.has(line.deviceId))
  return [...groups.filter((group) => group.lines.length), ...(general.length ? [{ device: null, lines: general }] : [])]
}

/** Company initials (home.profile.initials): first and last word, skipping connectives. */
export function initialsOf(name: string | null | undefined): string {
  const skip = new Set(['da', 'de', 'do', 'das', 'dos', 'e', '&', 'y'])
  const words = (name ?? '').split(/\s+/).filter((word) => word && !skip.has(word.toLowerCase()))
  if (!words.length) return ''
  const first = words[0] as string
  const last = words.length > 1 ? (words[words.length - 1] as string) : ''
  return (first.charAt(0) + last.charAt(0)).toUpperCase()
}

/**
 * The order's documents (OrderDocument in the app) that are not a payment proof:
 * a file linked to a transaction belongs to "Já recebido". Only http(s) links.
 */
/**
 * A payment proof: type receipt or linked to a payment. The same rule as the
 * server's projection (order-projection.ts attachedDocuments): money, so only
 * for who sees values.
 */
export const isPaymentProof = (doc: { type?: unknown; linkedTransactionId?: unknown }): boolean => doc.type === 'receipt' || !!doc.linkedTransactionId

export function attachmentsOf(value: unknown, showsMoney = false): OrderAttachment[] {
  if (!Array.isArray(value)) return []
  return (value as Raw[])
    // A proof linked to a payment lives in "Já recebido"; a "Comprovante" attached by hand only for who sees values.
    .filter((doc) => doc && typeof doc.id === 'string' && !doc.linkedTransactionId && (showsMoney || !isPaymentProof(doc)) && typeof doc.url === 'string' && /^https?:\/\//.test(doc.url))
    .map((doc) => ({
      id: doc.id as string,
      url: doc.url as string,
      storagePath: typeof doc.storagePath === 'string' ? doc.storagePath : undefined,
      fileName: typeof doc.fileName === 'string' ? doc.fileName : undefined,
      contentType: typeof doc.contentType === 'string' ? doc.contentType : undefined,
      fileSize: typeof doc.fileSize === 'number' ? doc.fileSize : undefined,
      type: ATTACHMENT_TYPES.includes(doc.type as AttachmentType) ? (doc.type as AttachmentType) : 'other',
      createdAt: isoOf(doc.createdAt),
    }))
}

/** What the Storage takes for an order document (isValidDocument): image, PDF or Word, below 10 MB. */
export function attachmentProblem(file: { type: string; size: number }): 'type' | 'size' | null {
  const allowed = /^image\/[a-z0-9.+-]+$/i.test(file.type) || ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'].includes(file.type)
  if (!allowed) return 'type'
  return file.size >= 10 * 1024 * 1024 ? 'size' : null
}

/** "320 KB", "1,4 MB": the size by the company's country. */
export function fileSizeParts(bytes: number | undefined): { value: number; unit: 'B' | 'KB' | 'MB' } | null {
  if (typeof bytes !== 'number' || bytes < 0) return null
  if (bytes < 1024) return { value: bytes, unit: 'B' }
  if (bytes < 1024 * 1024) return { value: Math.round(bytes / 1024), unit: 'KB' }
  return { value: Math.round((bytes / (1024 * 1024)) * 10) / 10, unit: 'MB' }
}
