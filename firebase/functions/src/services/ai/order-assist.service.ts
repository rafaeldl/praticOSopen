/**
 * aiOrderAssist: photo and/or audio/text → a structured draft of a NEW order
 * (docs/AI_ORDER_ASSIST.md; specs 2026-10-11-telas-os-ia, 2026-10-09-os-ai-assistant).
 *
 * The function never writes the order. It returns a draft (customer guess,
 * vehicle/plate, services and products matched against the company catalog,
 * notes) and the app fills the blank "Nova OS" with it; the user saves.
 *
 * Tenant isolation: every lookup takes the companyId resolved by the auth
 * middleware (never from the body). Customer names are matched on the server
 * and are NOT sent to the model; only the catalog names/prices are.
 */

import { z } from 'zod';
import type { LlmClient, LlmInlinePart } from './llm.client';
import { LlmUnavailableError } from './llm.client';
import { removeAccents } from '../../utils/search.utils';
import { matchCustomer, matchDevice } from './fuzzy-match';
import type { AiSettings, QuotaReservation } from './ai-quota.service';

// ============================================================================
// Input
// ============================================================================

/** Decoded size of a base64 string, in bytes. */
function base64Bytes(data: string): number {
  const padding = data.endsWith('==') ? 2 : data.endsWith('=') ? 1 : 0;
  return Math.floor((data.length * 3) / 4) - padding;
}

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
export const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
export const MAX_AUDIO_BYTES = 3 * 1024 * 1024;
export const MAX_PHOTOS = 4;
export const MAX_ORDER_LINES = 50;
const MAX_OPERATIONS = 30;

const orderLineSchema = z
  .object({
    name: z.string().trim().min(1).max(200),
    value: z.number().finite().nullable().optional(),
    quantity: z.number().finite().positive().optional(),
  })
  .strict();

const base64Of = (maxBytes: number) =>
  z
    .string()
    .min(4)
    .regex(BASE64, 'must be base64')
    .refine((v) => base64Bytes(v) <= maxBytes, `must be at most ${maxBytes} bytes`);

export const orderAssistInputSchema = z
  .object({
    text: z.string().trim().min(1).max(2000).optional(),
    audio: z
      .object({
        mimeType: z.enum(['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/webm']),
        data: base64Of(MAX_AUDIO_BYTES),
      })
      .strict()
      .optional(),
    photos: z
      .array(
        z
          .object({
            mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
            data: base64Of(MAX_PHOTO_BYTES),
          })
          .strict(),
      )
      .max(MAX_PHOTOS)
      .optional(),
    locale: z.enum(['pt', 'en', 'es']).optional(),
    /**
     * Lines already in the order, in screen order. Lets the model change or
     * remove them ("a pintura é 300", "tira a lavação") instead of adding new
     * ones. Older apps don't send it: then the model can only add.
     */
    order: z
      .object({
        services: z.array(orderLineSchema).max(MAX_ORDER_LINES).optional(),
        products: z.array(orderLineSchema).max(MAX_ORDER_LINES).optional(),
      })
      .strict()
      .optional(),
  })
  .strict()
  .refine((v) => !!v.text || !!v.audio || (v.photos?.length ?? 0) > 0, {
    message: 'send text, audio or at least one photo',
  });

export type OrderAssistInput = z.infer<typeof orderAssistInputSchema>;
export type OrderLine = z.infer<typeof orderLineSchema>;

// ============================================================================
// Model answer
// ============================================================================

/** Any non-string or blank value becomes undefined (models sometimes send null). */
const optionalText = z.preprocess(
  (v) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, 2000) : undefined),
  z.string().optional(),
);

/** Id of an order line in the prompt: S1, S2… (services) and P1, P2… (products). */
const LINE_ID = /^[SP][1-9]\d{0,2}$/;
const lineId = z.preprocess(
  (v) => (typeof v === 'string' ? v.trim().toUpperCase() : v),
  z.string().regex(LINE_ID),
);

const draftOperationSchema = z.object({
  action: z.enum(['add', 'update', 'remove']).catch('add'),
  /** Line to change or remove; null when unsure (see candidates). */
  line: lineId.nullable().optional().catch(null),
  /** Lines that fit equally when the model can't tell which one was meant. */
  candidates: z
    .array(z.unknown())
    .transform((ids) => ids.flatMap((id) => (lineId.safeParse(id).success ? [lineId.parse(id)] : [])))
    .optional()
    .catch([]),
  kind: z.enum(['service', 'product']).catch('service'),
  name: z.string().trim().min(1).max(200),
  value: z.number().finite().nonnegative().nullable().optional(),
  quantity: z.number().finite().positive().nullable().optional(),
});

export const llmDraftSchema = z.object({
  transcript: optionalText,
  customer: z.object({ name: optionalText, phone: optionalText }).nullable().optional().catch(undefined),
  device: z
    .object({ name: optionalText, serial: optionalText, manufacturer: optionalText })
    .nullable()
    .optional()
    .catch(undefined),
  operations: z.array(draftOperationSchema).max(MAX_OPERATIONS).catch([]).default([]),
  notes: optionalText,
  /** When the customer wants it ready: "YYYY-MM-DD", "HH:MM" only when said. */
  dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().catch(undefined),
  dueTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).optional().catch(undefined),
});

export type LlmDraft = z.infer<typeof llmDraftSchema>;

/** JSON Schema for the model answer, matching [llmDraftSchema] (adapted per provider). */
const STRING = { type: 'string' };
export const LLM_RESPONSE_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  properties: {
    transcript: STRING,
    customer: { type: 'object', additionalProperties: false, properties: { name: STRING, phone: STRING } },
    device: {
      type: 'object',
      additionalProperties: false,
      properties: { name: STRING, serial: STRING, manufacturer: STRING },
    },
    operations: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          action: { type: 'string', enum: ['add', 'update', 'remove'] },
          line: { type: ['string', 'null'] },
          candidates: { type: 'array', items: STRING },
          kind: { type: 'string', enum: ['service', 'product'] },
          name: STRING,
          value: { type: ['number', 'null'] },
          quantity: { type: ['number', 'null'] },
        },
        required: ['action', 'kind', 'name'],
      },
    },
    notes: STRING,
    dueDate: STRING,
    dueTime: STRING,
  },
  required: ['operations'],
};

/**
 * Parses the model's JSON text. Tolerates ```json fences and drops invalid
 * items instead of failing the whole draft. Throws [LlmUnavailableError] when
 * the text is not a JSON object at all.
 */
export function parseLlmDraft(raw: string): LlmDraft {
  const text = raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new LlmUnavailableError('model answer is not JSON');
  }
  if (!json || typeof json !== 'object' || Array.isArray(json)) {
    throw new LlmUnavailableError('model answer is not an object');
  }
  const obj = json as Record<string, unknown>;
  // Keep only the valid operations, one by one.
  const operations = (Array.isArray(obj.operations) ? obj.operations : []).flatMap((op) => {
    const parsed = draftOperationSchema.safeParse(op);
    return parsed.success ? [parsed.data] : [];
  });
  const kept = operations.slice(0, MAX_OPERATIONS);
  const parsed = llmDraftSchema.safeParse({ ...obj, operations: kept });
  if (parsed.success) return parsed.data;
  // Bad top-level fields: keep the operations, drop the rest.
  return { operations: kept };
}

// ============================================================================
// Prompt
// ============================================================================

export interface CatalogEntry {
  id: string;
  name: string;
  value?: number | null;
}

export interface CompanyCatalog {
  services: CatalogEntry[];
  products: CatalogEntry[];
}

const LANGUAGE: Record<string, string> = { pt: 'Brazilian Portuguese', en: 'English', es: 'Spanish' };
const PROMPT_CATALOG_LIMIT = 150;

/** Today in Brazil (the app's main market), e.g. "2026-10-13 (Tuesday)". */
export function todayLabel(now: Date = new Date(), timeZone = 'America/Sao_Paulo'): string {
  const date = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
  const weekday = new Intl.DateTimeFormat('en-US', { timeZone, weekday: 'long' }).format(now);
  return `${date} (${weekday})`;
}

export function buildSystemPrompt(locale: string, deviceLabel?: string, today: string = todayLabel()): string {
  const device = deviceLabel || 'device (vehicle, appliance, equipment)';
  return [
    'You help a small service business fill or change a service order (OS) from a photo, a short audio or a text.',
    'Return ONLY JSON following the schema. Never invent data that is not in the input.',
    `- transcript: what the person said, verbatim, when there is audio (in ${LANGUAGE[locale] ?? LANGUAGE.pt}).`,
    '- customer: the customer name and phone only when said or clearly written. Nicknames are fine.',
    `- device: the ${device}. Put a license plate, serial number or model code in "serial" (uppercase, no spaces);`,
    '  brand in "manufacturer"; a short readable name in "name" (e.g. "Gol 2018", "Split Samsung 12000 BTU").',
    '- operations: what to do with the order lines. The lines already in the order are listed below with ids',
    '  (S1, S2… services; P1, P2… parts). Each operation has an "action":',
    '  "add": a new service or part. Prefer the exact name from the catalog lists below when one clearly',
    '  matches; otherwise use a short name.',
    '  "update": change the unit price ("value") and/or the "quantity" of a line already in the order. Set',
    '  "line" to its id, "name" to its name, and leave the field that does not change null.',
    '  "remove": take a line out of the order. Set "line" to its id and "name" to its name.',
    '  Never add again something that is already a line just because it was mentioned: change it or leave it.',
    '  "Troca X por Y" means remove X and add Y. A price said next to a name ("a pintura de 33") tells which',
    '  line is meant. "Mais um/dois" on a part already in the order updates its quantity (current + n).',
    '  When the words fit more than one line equally, set "line" to null and list every fitting id in',
    '  "candidates"; do not guess. When the user changes or removes something that is not in the order,',
    '  return no operation for it.',
    '  "value" is the unit price in the currency, as a number ("500" → 500, "1,5 mil" → 1500), or null when',
    '  no price was said. "200 cada" means unit value 200 with quantity. "garantia" or "cortesia" means value 0.',
    '  Parts/materials are kind "product"; labor is kind "service".',
    `- dueDate: when the order must be ready ("pronto sexta", "entregar amanhã", "dia 20"), as YYYY-MM-DD.`,
    `  Today is ${today}; a weekday means the next one after today. dueTime as HH:MM only when a time was said.`,
    '  Leave both out when no deadline was said, and do not repeat the deadline in notes.',
    '- notes: what the customer asked or the defect (seen in the photo or said), short. Not the deadline.',
    `Write names and notes in ${LANGUAGE[locale] ?? LANGUAGE.pt}.`,
  ].join('\n');
}

export function buildUserText(input: OrderAssistInput, catalog: CompanyCatalog): string {
  const list = (entries: CatalogEntry[]) =>
    entries
      .slice(0, PROMPT_CATALOG_LIMIT)
      .map((e) => `- ${e.name}${typeof e.value === 'number' ? ` (${e.value})` : ''}`)
      .join('\n') || '(empty)';
  const lines = (prefix: 'S' | 'P', entries: OrderLine[]) =>
    entries.map((l, i) => {
      const value = typeof l.value === 'number' ? `, value ${l.value}` : ', no value';
      const quantity = prefix === 'P' ? `, quantity ${l.quantity ?? 1}` : '';
      return `${prefix}${i + 1}: ${l.name}${value}${quantity}`;
    });
  const current = [...lines('S', input.order?.services ?? []), ...lines('P', input.order?.products ?? [])];
  const parts = [
    'Services catalog:',
    list(catalog.services),
    'Products catalog:',
    list(catalog.products),
    'Lines already in the order:',
    current.join('\n') || '(none: new order)',
  ];
  if (input.text) parts.push('Text from the user:', input.text);
  if (input.audio) parts.push('An audio from the user is attached.');
  if (input.photos?.length) parts.push(`${input.photos.length} photo(s) attached.`);
  return parts.join('\n');
}

// ============================================================================
// Catalog matching (pure)
// ============================================================================

export function normalizeName(text: string): string {
  return removeAccents(text.toLowerCase())
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Best catalog entry for a spoken name: exact (no accents/case) → one contains
 * the other → most shared words (≥ half of the spoken words). Returns the match
 * and up to 3 alternatives.
 */
export function matchCatalog(
  name: string,
  entries: CatalogEntry[],
): { match: CatalogEntry | null; alternatives: CatalogEntry[] } {
  const target = normalizeName(name);
  if (!target) return { match: null, alternatives: [] };
  const normalized = entries.map((e) => ({ e, n: normalizeName(e.name) })).filter((x) => x.n);

  const exact = normalized.find((x) => x.n === target);
  const words = target.split(' ').filter((w) => w.length > 1);
  const scored = normalized
    .filter((x) => x !== exact)
    .map((x) => {
      const contains = x.n.includes(target) || target.includes(x.n);
      const shared = words.filter((w) => x.n.split(' ').includes(w)).length;
      return { e: x.e, score: (contains ? 100 : 0) + shared };
    })
    .filter((s) => s.score >= 100 || (words.length > 0 && s.score >= Math.ceil(words.length / 2)))
    .sort((a, b) => b.score - a.score);

  if (exact) return { match: exact.e, alternatives: scored.slice(0, 3).map((s) => s.e) };
  const [best, ...rest] = scored;
  return { match: best?.e ?? null, alternatives: rest.slice(0, 3).map((s) => s.e) };
}

// ============================================================================
// Orchestration
// ============================================================================

export interface CustomerHit {
  id: string;
  name: string;
  phone?: string;
}

export interface DeviceHit {
  id: string;
  name: string;
  serial?: string;
  manufacturer?: string;
}

export interface OrderAssistDeps {
  llm: LlmClient;
  getSettings(companyId: string): Promise<AiSettings | null>;
  reserve(companyId: string, settings: AiSettings | null): Promise<QuotaReservation>;
  release(companyId: string, monthKey: string): Promise<void>;
  loadCatalog(companyId: string): Promise<CompanyCatalog>;
  /**
   * Customers that may be the one said: the company's customers (all of them
   * when the list is small) plus exact lookups by phone and name. The service
   * picks among them with [matchCustomer], without AI.
   */
  findCustomers(companyId: string, guess: { name?: string; phone?: string }): Promise<CustomerHit[]>;
  /** Same for vehicles/devices: the company's list plus plate lookups ([matchDevice]). */
  findDevices(companyId: string, guess: { name?: string; serial?: string; manufacturer?: string }): Promise<DeviceHit[]>;
  /** Segment label of the device ("Veículo"), optional. */
  deviceLabel?(companyId: string): Promise<string | undefined>;
  /** This month's use and limit without counting (GET /status), optional. */
  getUsage?(companyId: string, settings: AiSettings | null): Promise<{ used: number; limit: number }>;
}

export interface DraftItem {
  kind: 'service' | 'product';
  /** Catalog name when matched, else what the model said. */
  name: string;
  /** Price to put in the order: spoken value, else catalog value, else null ("sem valor"). */
  value: number | null;
  quantity: number;
  catalogId: string | null;
  alternatives: CatalogEntry[];
}

/** A line already in the order: its kind and index in `input.order.services`/`products`. */
export interface LineRef {
  kind: 'service' | 'product';
  index: number;
}

export interface DraftChange {
  action: 'update' | 'remove';
  /** The line to change; null when ambiguous (see [candidates]). */
  line: LineRef | null;
  /** When [line] is null: the lines that fit, for the app to ask which one. */
  candidates: LineRef[];
  /** Name of the line as the model saw it. */
  name: string;
  /** New unit price, when it changes. */
  value?: number;
  /** New quantity (parts only), when it changes. */
  quantity?: number;
}

export interface OrderDraft {
  transcript: string | null;
  customer: { match: CustomerHit | null; guess: { name?: string; phone?: string } | null; alternatives: CustomerHit[] } | null;
  device: {
    match: DeviceHit | null;
    guess: { name?: string; serial?: string; manufacturer?: string } | null;
    alternatives: DeviceHit[];
  } | null;
  /** New lines to add (older apps read only this). */
  items: DraftItem[];
  /** Changes to lines already in the order (sent in `input.order`). */
  changes: DraftChange[];
  notes: string | null;
  /** "YYYY-MM-DD", or "YYYY-MM-DDTHH:MM" when a time was said. */
  dueDate: string | null;
  usage: { used: number; limit: number };
}

export type OrderAssistErrorCode = 'AI_DISABLED' | 'AI_QUOTA_EXCEEDED' | 'AI_UNAVAILABLE';

export class OrderAssistError extends Error {
  constructor(
    public readonly code: OrderAssistErrorCode,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'OrderAssistError';
  }
}

export const ORDER_ASSIST_HTTP_STATUS: Record<OrderAssistErrorCode, number> = {
  AI_DISABLED: 403,
  AI_QUOTA_EXCEEDED: 429,
  AI_UNAVAILABLE: 503,
};

function toItem(item: LlmDraft['operations'][number], catalog: CompanyCatalog): DraftItem {
  const entries = item.kind === 'product' ? catalog.products : catalog.services;
  const { match, alternatives } = matchCatalog(item.name, entries);
  const spoken = typeof item.value === 'number' ? item.value : null;
  const catalogValue = typeof match?.value === 'number' ? match.value : null;
  const quantity = item.kind === 'product' ? Math.max(1, Math.round(item.quantity ?? 1)) : 1;
  return {
    kind: item.kind,
    name: match?.name ?? item.name,
    value: spoken ?? catalogValue,
    quantity,
    catalogId: match?.id ?? null,
    alternatives,
  };
}

/** Line id from the prompt ("S2") → the line, when it exists in the order. */
function lineRef(id: string | null | undefined, order: OrderAssistInput['order']): LineRef | null {
  if (!id) return null;
  const kind = id[0] === 'P' ? 'product' : 'service';
  const index = Number(id.slice(1)) - 1;
  const size = (kind === 'product' ? order?.products : order?.services)?.length ?? 0;
  return index >= 0 && index < size ? { kind, index } : null;
}

/** Update/remove operations → changes on existing lines. Drops lines that don't exist. */
export function toChanges(operations: LlmDraft['operations'], order: OrderAssistInput['order']): DraftChange[] {
  return operations.flatMap((op): DraftChange[] => {
    if (op.action === 'add') return [];
    const fits = (op.candidates ?? [])
      .map((id) => lineRef(id, order))
      .filter((r, i, all): r is LineRef => !!r && all.findIndex((o) => o?.kind === r.kind && o.index === r.index) === i);
    const line = lineRef(op.line, order) ?? (fits.length === 1 ? fits[0] : null);
    if (!line && fits.length < 2) return [];
    const change: DraftChange = { action: op.action, line, candidates: line ? [] : fits, name: op.name };
    if (op.action === 'update') {
      if (typeof op.value === 'number') change.value = op.value;
      // Quantity only exists on parts; when ambiguous the app applies it if the chosen line is a part.
      if (typeof op.quantity === 'number' && (line?.kind ?? 'product') === 'product') {
        change.quantity = Math.max(1, Math.round(op.quantity));
      }
      if (change.value === undefined && change.quantity === undefined) return [];
    }
    return [change];
  });
}

async function resolveCustomer(companyId: string, draft: LlmDraft, deps: OrderAssistDeps): Promise<OrderDraft['customer']> {
  const guess = draft.customer?.name || draft.customer?.phone ? { ...draft.customer } : null;
  if (!guess) return null;
  const { match, alternatives } = matchCustomer(guess, await deps.findCustomers(companyId, guess));
  return { match, guess, alternatives };
}

async function resolveDevice(companyId: string, draft: LlmDraft, deps: OrderAssistDeps): Promise<OrderDraft['device']> {
  const d = draft.device;
  if (!d || (!d.name && !d.serial && !d.manufacturer)) return null;
  // Kept as read (Mercosul stays Mercosul): it may become a new vehicle.
  const guess = { ...d, serial: d.serial ? d.serial.toUpperCase().replace(/[^A-Z0-9]/g, '') || undefined : undefined };
  const { match, alternatives } = matchDevice(guess, await deps.findDevices(companyId, guess));
  return { match, guess, alternatives };
}

/**
 * Runs the assistant for one request. Order: pilot switch → quota (counts the
 * call) → catalog → model → parse → match. Releases the reserved request when
 * the model fails.
 */
export async function runOrderAssist(
  companyId: string,
  input: OrderAssistInput,
  deps: OrderAssistDeps,
): Promise<OrderDraft> {
  const settings = await deps.getSettings(companyId);
  if (!settings?.enabled) {
    throw new OrderAssistError('AI_DISABLED', 'The assistant is not enabled for this company');
  }

  const reservation = await deps.reserve(companyId, settings);
  if (!reservation.ok) {
    throw new OrderAssistError('AI_QUOTA_EXCEEDED', 'Monthly AI limit reached', {
      used: reservation.used,
      limit: reservation.limit,
    });
  }

  let draft: LlmDraft;
  let catalog: CompanyCatalog;
  try {
    catalog = await deps.loadCatalog(companyId);
    const locale = input.locale ?? 'pt';
    const media: LlmInlinePart[] = [
      ...(input.photos ?? []).map((p) => ({ mimeType: p.mimeType, data: p.data })),
      ...(input.audio ? [{ mimeType: input.audio.mimeType, data: input.audio.data }] : []),
    ];
    const raw = await deps.llm.generateJson({
      systemPrompt: buildSystemPrompt(locale, await deps.deviceLabel?.(companyId)),
      userText: buildUserText(input, catalog),
      media,
      responseSchema: LLM_RESPONSE_SCHEMA,
      provider: settings.provider,
    });
    draft = parseLlmDraft(raw);
  } catch (error) {
    try {
      await deps.release(companyId, reservation.monthKey);
    } catch {
      // Best effort: a failed release only costs the user one request.
    }
    if (error instanceof LlmUnavailableError) {
      throw new OrderAssistError('AI_UNAVAILABLE', 'The assistant could not answer now');
    }
    throw error;
  }

  const [customer, device] = await Promise.all([
    resolveCustomer(companyId, draft, deps),
    resolveDevice(companyId, draft, deps),
  ]);

  return {
    transcript: draft.transcript ?? null,
    customer,
    device,
    items: draft.operations.filter((op) => op.action === 'add').map((op) => toItem(op, catalog)),
    changes: toChanges(draft.operations, input.order),
    notes: draft.notes ?? null,
    dueDate: draft.dueDate ? (draft.dueTime ? `${draft.dueDate}T${draft.dueTime}` : draft.dueDate) : null,
    usage: { used: reservation.used, limit: reservation.limit },
  };
}
