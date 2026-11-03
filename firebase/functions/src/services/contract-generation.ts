/**
 * Recurring contracts: the same generation the app runs when it opens
 * (lib/mobx/order_store.dart generateOrderFromContract / checkAndGenerateDueOrders,
 * lib/models/order.dart OrderContract). Pure functions, no Firestore: the
 * shared cases in docs/web-app/contract-cases/contract-generation.json run
 * them here and the real app code in Dart.
 *
 * Dates: the app writes `DateTime.toIso8601String()` of a local DateTime,
 * which has no offset ("2026-12-02T00:00:00.000") and means wall-clock time
 * on the phone. Every date here is a wall-clock value (milliseconds of that
 * wall time read as UTC). Naive strings are taken as they are; strings with
 * Z or an offset, and `now`, are converted to America/Sao_Paulo. What is
 * written back is naive again, like the app.
 */

/** Time zone of the scheduled job and of `now` on the server. */
export const CONTRACT_TIME_ZONE = 'America/Sao_Paulo';

const DAY_MS = 24 * 60 * 60 * 1000;

const wallFormat = new Intl.DateTimeFormat('en-US', {
  timeZone: CONTRACT_TIME_ZONE,
  hourCycle: 'h23',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

/** Wall-clock time in America/Sao_Paulo of an instant. */
export function wallClockOf(instant: Date): number {
  const parts: Record<string, number> = {};
  for (const part of wallFormat.formatToParts(instant)) {
    if (part.type !== 'literal') parts[part.type] = Number(part.value);
  }
  return (
    Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second) +
    instant.getUTCMilliseconds()
  );
}

/** The instant whose wall-clock time in America/Sao_Paulo is `wall` (tests and tools). */
export function instantOfWall(wall: number): Date {
  let guess = wall + 3 * 60 * 60 * 1000;
  for (let i = 0; i < 3; i++) guess += wall - wallClockOf(new Date(guess));
  return new Date(guess);
}

const ISO = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d{1,9}))?)?)?(Z|[+-]\d{2}(?::?\d{2})?)?$/;

/**
 * Wall-clock value of a date the app wrote, or null (like `DateTime.parse` of
 * a missing field). Out-of-range parts roll over like Dart (`2026-02-31` is
 * 3 March). Anything that is not such a string is null.
 */
export function parseContractDate(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const match = ISO.exec(value.trim());
  if (!match) return null;
  const [, y, mo, d, h = '0', mi = '0', s = '0', fraction = '', zone] = match;
  const ms = Number(fraction.padEnd(3, '0').slice(0, 3));
  const wall = Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s), ms);
  if (!zone) return wall;
  if (zone === 'Z') return wallClockOf(new Date(wall));
  const sign = zone[0] === '-' ? -1 : 1;
  const digits = zone.slice(1).replace(':', '');
  const offset = (Number(digits.slice(0, 2)) * 60 + Number(digits.slice(2) || 0)) * 60_000;
  return wallClockOf(new Date(wall - sign * offset));
}

const pad = (value: number, size = 2) => String(value).padStart(size, '0');

/** Same text as Dart's `toIso8601String()` of a local DateTime without microseconds. */
export function formatContractDate(wall: number): string {
  const d = new Date(wall);
  return (
    `${pad(d.getUTCFullYear(), 4)}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}` +
    `T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}.${pad(d.getUTCMilliseconds(), 3)}`
  );
}

/** `companies/{cid}/orders/{id}.contract` as the app writes it. */
export interface ContractData {
  frequency?: string | null;
  interval?: number | null;
  startDate?: string | null;
  endDate?: string | null;
  nextDueDate?: string | null;
  lastGeneratedDate?: string | null;
  generatedCount?: number | null;
  autoGenerate?: boolean | null;
  active?: boolean | null;
  reminderDaysBefore?: number | null;
  parentOrderId?: string | null;
  parentOrderNumber?: number | null;
  /** Paused on the web (text or Timestamp): generates nothing, like the app. */
  pausedAt?: unknown;
}

type Json = Record<string, unknown>;

/**
 * OrderContract.stepFrom: one period after `base`. Daily and weekly keep the
 * time of day; monthly and yearly are midnight, and day 31 rolls into the next
 * month like Dart's DateTime (31 Jan + 1 month is 3 March). Null for an
 * unknown frequency.
 */
export function stepFrom(contract: ContractData, base: number): number | null {
  const step = contract.interval ?? 1;
  const d = new Date(base);
  switch (contract.frequency) {
    case 'daily':
      return base + step * DAY_MS;
    case 'weekly':
      return base + 7 * step * DAY_MS;
    case 'monthly':
      return Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + step, d.getUTCDate());
    case 'yearly':
      return Date.UTC(d.getUTCFullYear() + step, d.getUTCMonth(), d.getUTCDate());
    default:
      return null;
  }
}

/** OrderContract.computeNextDueDate: from lastGeneratedDate (else startDate). */
export function computeNextDueDate(contract: ContractData): number | null {
  const base = parseContractDate(contract.lastGeneratedDate) ?? parseContractDate(contract.startDate);
  return base === null ? null : stepFrom(contract, base);
}

/**
 * OrderContract.nextDueAfter: the first due date after `now`, stepping from
 * nextDueDate. Missed periods are skipped, not made up, and the schedule's
 * day is kept.
 */
export function nextDueAfter(contract: ContractData, now: number): number | null {
  const due = parseContractDate(contract.nextDueDate);
  if (due === null) return null;
  let next = stepFrom(contract, due);
  for (let guard = 0; next !== null && next <= now && guard < 100000; guard++) {
    next = stepFrom(contract, next);
  }
  return next;
}

const dayOf = (wall: number) => Math.floor(wall / DAY_MS);

/** `wall` falls after the contract's last day (endDate counts as included). */
function afterEnd(contract: ContractData, wall: number): boolean {
  const end = parseContractDate(contract.endDate);
  return end !== null && dayOf(wall) > dayOf(end);
}

/**
 * OrderContract.isDueAt: active, not paused (pausedAt), nextDueDate at or before now and the due day
 * not after the contract's last day.
 */
export function isContractDue(contract: ContractData | null | undefined, now: number): boolean {
  if (!contract || contract.active !== true) return false;
  // Paused (OrderContract.isRunning in the app): no order until resumed.
  if (contract.pausedAt !== undefined && contract.pausedAt !== null) return false;
  const next = parseContractDate(contract.nextDueDate);
  return next !== null && next <= now && !afterEnd(contract, next);
}

/** OrderContract.isExpired: endDate before now. */
export function isContractExpired(contract: ContractData, now: number): boolean {
  const end = parseContractDate(contract.endDate);
  return end !== null && end < now;
}

/** The app only generates when the contract is due and set to create orders. */
export function shouldGenerate(contract: ContractData | null | undefined, now: number): boolean {
  return isContractDue(contract, now) && contract?.autoGenerate === true;
}

/** Fields of `contract` written on the template after a generation. */
export interface ContractAdvance {
  lastGeneratedDate: string;
  generatedCount: number;
  nextDueDate: string | null;
  /** Present (false) only when the contract stops. */
  active?: false;
}

/**
 * OrderContract.advanceAfterGenerating: lastGeneratedDate = now, one more
 * generated, nextDueDate = the first due date after now (nextDueAfter), and
 * inactive when there is none or it falls after endDate.
 */
export function advanceContract(contract: ContractData, now: number): ContractAdvance {
  const next = nextDueAfter(contract, now);
  const advance: ContractAdvance = {
    lastGeneratedDate: formatContractDate(now),
    generatedCount: (contract.generatedCount ?? 0) + 1,
    nextDueDate: next === null ? null : formatContractDate(next),
  };
  if (next === null || afterEnd(contract, next)) advance.active = false;
  return advance;
}

/**
 * Id of the order generated for one due date of one template:
 * `contract_{templateId}_{YYYYMMDD}`, the due day in the company time zone
 * (America/Sao_Paulo: companies have no time zone of their own yet). The app
 * uses the same id (lib/utils/contract_generation.dart contractOrderId), so
 * the job, the route, a retry and the app write the same document.
 */
export function contractOrderId(templateId: string, nextDueDate: string | null | undefined): string {
  const due = parseContractDate(nextDueDate);
  if (due === null) return `contract_${templateId}_`;
  const d = new Date(due);
  return `contract_${templateId}_${pad(d.getUTCFullYear(), 4)}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}`;
}

const isJson = (value: unknown): value is Json => !!value && typeof value === 'object' && !Array.isArray(value);
const orNull = <T>(value: T | undefined): T | null => (value === undefined ? null : value);

/** Order.fromJson device normalization: `device` alone becomes `devices`, and `device` is the first. */
function normalizedDevices(template: Json): { device: Json | null; devices: Json[] | null } {
  let devices = Array.isArray(template.devices) ? (template.devices as Json[]) : null;
  let device = isJson(template.device) ? template.device : null;
  if ((!devices || devices.length === 0) && device) devices = [device];
  if (devices && devices.length > 0) device = devices[0];
  return { device, devices };
}

// pausedAt is left out, as OrderContract.toJson leaves it out when null.
const emptyContract = (): Record<Exclude<keyof ContractData, 'pausedAt'>, null> => ({
  frequency: null,
  interval: null,
  startDate: null,
  endDate: null,
  nextDueDate: null,
  lastGeneratedDate: null,
  generatedCount: null,
  autoGenerate: null,
  active: null,
  reminderDaysBefore: null,
  parentOrderId: null,
  parentOrderNumber: null,
});

/**
 * The order generateOrderFromContract creates, field for field (Order.toJson,
 * nulls included). `number` stays null: the onCreate trigger numbers it, as it
 * does for the app. `company` is the company aggregate { id, name, country }.
 */
export function buildContractOrder(template: Json, templateId: string, company: Json, now: number): Json {
  const nowText = formatContractDate(now);
  const { device, devices } = normalizedDevices(template);
  const services = Array.isArray(template.services)
    ? (template.services as Json[]).map((s) => ({
        service: orNull(s?.service),
        description: orNull(s?.description),
        value: orNull(s?.value),
        photo: null,
        deviceId: null,
      }))
    : null;
  const products = Array.isArray(template.products)
    ? (template.products as Json[]).map((p) => ({
        product: orNull(p?.product),
        description: orNull(p?.description),
        value: orNull(p?.value),
        quantity: orNull(p?.quantity),
        total: orNull(p?.total),
        photo: null,
        deviceId: null,
      }))
    : null;

  let total = 0;
  for (const s of services ?? []) total += (s.value as number | null) ?? 0;
  for (const p of products ?? []) {
    total += (p.total as number | null) ?? ((p.value as number | null) ?? 0) * ((p.quantity as number | null) ?? 1);
  }

  const deviceIds = (devices ?? []).map((d) => d?.id).filter((id): id is string => typeof id === 'string');
  const createdBy = orNull(template.createdBy);

  return {
    id: null,
    createdAt: nowText,
    createdBy,
    updatedAt: nowText,
    updatedBy: createdBy,
    company: { id: orNull(company.id), name: orNull(company.name), country: orNull(company.country) },
    customer: orNull(template.customer),
    device,
    devices: devices ? [...devices] : null,
    services,
    products,
    // Order() starts with `photos = []` and generateOrderFromContract never sets it.
    photos: [],
    total,
    discount: null,
    dueDate: null,
    scheduledDate: null,
    done: null,
    paid: null,
    payment: 'unpaid',
    status: 'quote',
    number: null,
    paidAmount: null,
    transactions: null,
    assignedTo: orNull(template.assignedTo),
    shareLink: null,
    rating: null,
    address: null,
    latitude: null,
    longitude: null,
    customData: null,
    documents: null,
    deviceIds: deviceIds.length ? deviceIds : null,
    contract: {
      ...emptyContract(),
      parentOrderId: templateId,
      parentOrderNumber: typeof template.number === 'number' ? template.number : null,
    },
    isContract: null,
  };
}
