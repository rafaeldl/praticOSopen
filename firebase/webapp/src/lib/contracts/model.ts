// Recurring contracts (contract.*): pure rules, no Vue and no Firebase.
//
// The contract lives in the order that repeats (`isContract: true`, `contract`
// map, lib/models/order.dart OrderContract). Dates are the app's: the company's
// local time without a zone ("2026-12-03T00:00:00.000", Dart toIso8601String).
// They are handled here as that text ("wall"), with calendar arithmetic in UTC,
// so no browser or company zone ever moves a day.
//
// The web never generates an order: the app (on opening) or the server job do
// (docs/CONTRACTS_SERVER_JOB.md). The web edits the schedule, pauses, stops,
// and shows the next order planned.

export type Frequency = 'daily' | 'weekly' | 'monthly' | 'yearly'

export interface Repeat {
  frequency: string
  interval: number
}

/** "Com que frequência?": the app's 8 choices (ContractRepeat.options). */
export const REPEAT_OPTIONS: readonly Repeat[] = [
  { frequency: 'daily', interval: 1 },
  { frequency: 'weekly', interval: 1 },
  { frequency: 'weekly', interval: 2 },
  { frequency: 'monthly', interval: 1 },
  { frequency: 'monthly', interval: 2 },
  { frequency: 'monthly', interval: 3 },
  { frequency: 'monthly', interval: 6 },
  { frequency: 'yearly', interval: 1 },
]

export interface Contract {
  frequency: string | null
  interval: number
  startDate: string | null
  endDate: string | null
  nextDueDate: string | null
  lastGeneratedDate: string | null
  generatedCount: number
  autoGenerate: boolean
  active: boolean
  reminderDaysBefore: number | null
  /** Web only: set by "Pausar", gone on "Retomar". The app ignores it. */
  pausedAt: string | null
  parentOrderId: string | null
  parentOrderNumber: number | null
}

export type ContractState = 'active' | 'paused' | 'ended'

// ---------------------------------------------------------------------------
// Wall text
// ---------------------------------------------------------------------------

const WALL = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?)?$/
const pad = (value: number, size = 2) => String(value).padStart(size, '0')

/** Millis of a wall text read as if it were UTC (calendar arithmetic only). */
export function wallMillis(wall: string): number {
  const match = WALL.exec(wall)
  if (!match) return NaN
  const [, y, m, d, h = '0', min = '0', s = '0', ms = '0'] = match
  return Date.UTC(Number(y), Number(m) - 1, Number(d), Number(h), Number(min), Number(s), Number(ms.padEnd(3, '0').slice(0, 3)))
}

/** Back to the app's text: "2026-12-03T00:00:00.000". */
export function wallFromMillis(millis: number): string {
  const date = new Date(millis)
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}T${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(date.getUTCSeconds())}.${pad(date.getUTCMilliseconds(), 3)}`
}

/** "2026-12-03" of a wall text. */
export const dayOf = (wall: string) => wall.slice(0, 10)

/** Midnight of a day ("2026-12-03" → "2026-12-03T00:00:00.000"). */
export const midnight = (day: string) => `${day.slice(0, 10)}T00:00:00.000`

/**
 * A stored date as wall text. Zoneless text (the app's) is kept as written;
 * anything that is an instant (text with a zone, a Timestamp) goes through
 * `toWall`, the company's clock.
 */
export function wallOfStored(value: unknown, toWall: (date: Date) => string): string | null {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'string') {
    if (WALL.test(value)) {
      const millis = wallMillis(value)
      return Number.isNaN(millis) ? null : wallFromMillis(millis)
    }
    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : toWall(date)
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : toWall(value)
  const ts = value as { toDate?: () => Date; seconds?: number }
  if (typeof ts.toDate === 'function') return toWall(ts.toDate())
  if (typeof ts.seconds === 'number') return toWall(new Date(ts.seconds * 1000))
  return null
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

type Raw = Record<string, unknown>
const int = (value: unknown): number | null => (typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : null)

/** The `contract` map as the app reads it (OrderContract.fromJson), or null. */
export function normalizeContract(raw: unknown, toWall: (date: Date) => string): Contract | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const c = raw as Raw
  const date = (value: unknown) => wallOfStored(value, toWall)
  return {
    frequency: typeof c.frequency === 'string' ? c.frequency : null,
    interval: Math.max(1, int(c.interval) ?? 1),
    startDate: date(c.startDate),
    endDate: date(c.endDate),
    nextDueDate: date(c.nextDueDate),
    lastGeneratedDate: date(c.lastGeneratedDate),
    generatedCount: int(c.generatedCount) ?? 0,
    // The config screen reads a missing autoGenerate as on.
    autoGenerate: c.autoGenerate !== false,
    active: c.active === true,
    reminderDaysBefore: int(c.reminderDaysBefore),
    pausedAt: date(c.pausedAt),
    parentOrderId: typeof c.parentOrderId === 'string' ? c.parentOrderId : null,
    parentOrderNumber: int(c.parentOrderNumber),
  }
}

/** A contract the order holds (the repeating order), not the parent link of a generated one. */
export const isTemplate = (isContract: unknown, contract: Contract | null): contract is Contract => isContract === true && !!contract && !contract.parentOrderId

/** Ativos (active and paused) or Encerrados. The app lists `active != true` as Encerrados. */
export function stateOf(contract: Contract): ContractState {
  if (contract.active) return 'active'
  return contract.pausedAt ? 'paused' : 'ended'
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

/**
 * One period after `base` (OrderContract.stepFrom): daily and weekly keep the
 * time; monthly and yearly are midnight and day 31 rolls like Dart's DateTime
 * (31/01 + 1 month = 03/03). Null for an unknown frequency.
 */
export function stepFrom(base: string, repeat: Repeat): string | null {
  const millis = wallMillis(base)
  if (Number.isNaN(millis)) return null
  const step = Math.max(1, repeat.interval || 1)
  const date = new Date(millis)
  const y = date.getUTCFullYear()
  const m = date.getUTCMonth()
  const d = date.getUTCDate()
  switch (repeat.frequency) {
    case 'daily':
      return wallFromMillis(millis + step * 86_400_000)
    case 'weekly':
      return wallFromMillis(millis + step * 7 * 86_400_000)
    case 'monthly':
      return wallFromMillis(Date.UTC(y, m + step, d))
    case 'yearly':
      return wallFromMillis(Date.UTC(y + step, m, d))
    default:
      return null
  }
}

/** Steps from `base` until the day is not before `minDay`. `base` itself counts when `includeBase`. */
function firstOnOrAfter(base: string, repeat: Repeat, minDay: string, includeBase: boolean): string | null {
  let next: string | null = includeBase ? base : stepFrom(base, repeat)
  let guard = 0
  while (next && dayOf(next) < minDay && guard++ < 100_000) next = stepFrom(next, repeat)
  return next
}

const nextDay = (day: string) => dayOf(wallFromMillis(wallMillis(midnight(day)) + 86_400_000))

/**
 * Next order after the schedule changed (frequency, interval or start): the
 * schedule counts periods from the start (the start itself is the order that
 * holds the contract, as in the app), and the next one is the first from today
 * on, after the last one generated. Missed periods are never made up.
 */
export function plannedNext(contract: Pick<Contract, 'frequency' | 'interval' | 'startDate' | 'lastGeneratedDate'>, today: string): string | null {
  const repeat = { frequency: contract.frequency ?? 'monthly', interval: contract.interval }
  const start = contract.startDate ?? midnight(today)
  const last = contract.lastGeneratedDate ? nextDay(dayOf(contract.lastGeneratedDate)) : ''
  const minDay = last > today ? last : today
  return firstOnOrAfter(start, repeat, minDay, false)
}

/** The due day falls after the contract's last day (endDate is included). */
export function afterEnd(contract: Pick<Contract, 'endDate'>, due: string): boolean {
  return !!contract.endDate && dayOf(due) > dayOf(contract.endDate)
}

export type Planned =
  | { kind: 'date'; date: string; late: boolean }
  | { kind: 'manual'; date: string | null }
  | { kind: 'none' }

/**
 * "A próxima OS prevista" of an active contract. Late: the day passed and the
 * order was not born yet (nobody opened the app; the server job is off).
 */
export function nextPlanned(contract: Contract, today: string): Planned {
  const due = contract.nextDueDate
  if (!due || afterEnd(contract, due)) return { kind: 'none' }
  if (!contract.autoGenerate) return { kind: 'manual', date: due }
  return { kind: 'date', date: due, late: dayOf(due) < today }
}

// ---------------------------------------------------------------------------
// Changes (only the fields that change are written)
// ---------------------------------------------------------------------------

export type ContractPatch = Partial<Pick<Contract, 'frequency' | 'interval' | 'startDate' | 'endDate' | 'nextDueDate' | 'autoGenerate' | 'active' | 'pausedAt'>>

/** "Repetir" turned on (OrderStore.toggleContract): every month, creates the order, on, 3 days notice. */
export function newContract(input: { repeat: Repeat; startDay: string; endDay: string | null; autoGenerate: boolean }, today: string): Contract {
  const startDate = midnight(input.startDay)
  const base = { frequency: input.repeat.frequency, interval: input.repeat.interval, startDate, lastGeneratedDate: null }
  return {
    ...base,
    endDate: input.endDay ? midnight(input.endDay) : null,
    nextDueDate: plannedNext(base, today),
    generatedCount: 0,
    autoGenerate: input.autoGenerate,
    active: true,
    reminderDaysBefore: 3,
    pausedAt: null,
    parentOrderId: null,
    parentOrderNumber: null,
  }
}

export interface ScheduleInput {
  repeat: Repeat
  startDay: string
  endDay: string | null
  autoGenerate: boolean
}

/** End never before the start: a later start pulls the end along (contract.config.dates). */
export function clampEnd(startDay: string, endDay: string | null): string | null {
  return endDay && endDay < startDay ? startDay : endDay
}

/** What "Salvar" writes: only what changed; the next order again when the schedule changed. */
export function scheduleChanges(contract: Contract, input: ScheduleInput, today: string): ContractPatch {
  const patch: ContractPatch = {}
  const startDate = midnight(input.startDay)
  const endDay = clampEnd(input.startDay, input.endDay)
  const endDate = endDay ? midnight(endDay) : null
  if (input.repeat.frequency !== contract.frequency) patch.frequency = input.repeat.frequency
  if (input.repeat.interval !== contract.interval) patch.interval = input.repeat.interval
  if (!contract.startDate || dayOf(contract.startDate) !== input.startDay) patch.startDate = startDate
  if ((contract.endDate ? dayOf(contract.endDate) : null) !== endDay) patch.endDate = endDate
  if (input.autoGenerate !== contract.autoGenerate) patch.autoGenerate = input.autoGenerate
  const scheduleMoved = 'frequency' in patch || 'interval' in patch || 'startDate' in patch
  if (scheduleMoved || !contract.nextDueDate) {
    const next = plannedNext({ ...contract, frequency: input.repeat.frequency, interval: input.repeat.interval, startDate }, today)
    if (next !== contract.nextDueDate) patch.nextDueDate = next
  }
  return patch
}

/** "Pausar": no order is born while paused (active false, as the app reads it). */
export function pauseChanges(nowWall: string): ContractPatch {
  return { active: false, pausedAt: nowWall }
}

/**
 * "Retomar": the next order is the first from today on, stepping from the one
 * that was due. Periods of the pause are not made up.
 */
export function resumeChanges(contract: Contract, today: string): ContractPatch {
  const repeat = { frequency: contract.frequency ?? 'monthly', interval: contract.interval }
  const next = contract.nextDueDate ? firstOnOrAfter(contract.nextDueDate, repeat, today, true) : plannedNext(contract, today)
  return { active: true, pausedAt: null, nextDueDate: next }
}

/**
 * "Parar de repetir": the contract stays (Encerrados, with its history), off,
 * ending today unless it already ended earlier. The app erases it (defect 62).
 */
export function stopChanges(contract: Contract, today: string): ContractPatch {
  const patch: ContractPatch = { active: false, pausedAt: null }
  if (!contract.endDate || dayOf(contract.endDate) > today) patch.endDate = midnight(today)
  return patch
}

/** A day of the ended row: endDate, else the last order born (contract.list.row). */
export const endedDay = (contract: Contract) => contract.endDate ?? contract.lastGeneratedDate

/** Sorted for the list: next order first (no date last), then by customer. */
export function byNext(a: { contract: Contract; customer: string }, b: { contract: Contract; customer: string }): number {
  const x = a.contract.nextDueDate ?? '9999'
  const y = b.contract.nextDueDate ?? '9999'
  return x === y ? a.customer.localeCompare(b.customer) : x < y ? -1 : 1
}

/** The repeat of a contract as one of the choices, the current one added when it is another (contract.config.frequency). */
export function repeatChoices(current: Repeat | null): Repeat[] {
  const list = [...REPEAT_OPTIONS]
  if (current && !list.some((r) => r.frequency === current.frequency && r.interval === current.interval)) list.push(current)
  return list
}

export const repeatKey = (repeat: Repeat) => `${repeat.frequency}:${repeat.interval}`
export function repeatOfKey(key: string): Repeat {
  const [frequency = 'monthly', interval = '1'] = key.split(':')
  return { frequency, interval: Math.max(1, Number(interval) || 1) }
}

/**
 * The screen's title: "Contratos", or "{Contratos} que se repetem" when the
 * segment already calls each order "Contrato" (contracts_title.dart).
 */
export function titleClashes(orderPlural: string, contractsWord: string): boolean {
  return orderPlural.trim().toLowerCase() === contractsWord.trim().toLowerCase()
}
