/**
 * The import proposal (issue #569, spec §4.3): from the notas the CNPJ already
 * issued, what the PraticOS fills by itself. Pure functions: the service loads
 * the notas, customers and orders and saves what comes out.
 *
 * Rules:
 * - Only what is empty is filled; nothing someone typed is replaced.
 * - Sure matches go without asking: same CPF/CNPJ, or the same name with an
 *   order of the same value and date, or several orders of one customer whose
 *   name shares a word with the nota's. Anything else is asked ("Este é o
 *   mesmo cliente?"); without an answer it becomes a new customer.
 * - Stores billed on one CNPJ: the CNPJ stays on the customer with most notas;
 *   the other customers whose orders match get "Nota fiscal para" pointing to it.
 * - A nota links to an order only when exactly one order has its value
 *   (to the cent) within 10 days of its date, and no other nota wants it.
 * - Our DPS series is one the CNPJ never used (default 10).
 */

import type { FiscalAddress, FiscalDescriptionStyle, FiscalEmitter, FiscalEmitterService, FiscalRegime } from '../../models/nfse-direct.types';

/** Days between the nota's date and the order's for a link. */
export const LINK_WINDOW_DAYS = 10;
/** Order matches that make a customer sure even with a different name. */
export const SURE_ORDER_MATCHES = 3;
/** Share of a customer's orders with a nota for the "Emitir sozinha" suggestion. */
export const AUTO_ISSUE_SHARE = 0.8;
export const AUTO_ISSUE_MIN_ORDERS = 3;
export const DEFAULT_DPS_SERIES = 10;

const SEPARATORS = [' - ', ', ', ' / ', '; '] as const;

/** One nota of the emitter, as stored by the reading. */
export interface ImportNota {
  invoiceId: string;
  canceled: boolean;
  /** YYYY-MM-DD */
  date: string | null;
  value: number;
  recipient: {
    taxId: string;
    legalName: string | null;
    address: FiscalAddress | null;
    email: string | null;
  } | null;
  series: string | null;
  description: string;
  service: { nationalCode: string | null; municipalCode: string | null; nbs: string | null; name: string | null; issRate: number | null };
  regime: FiscalRegime | null;
  simplesOption: number | null;
  simplesTaxRate: number | null;
  municipalRegistration: string | null;
  cityCode: string | null;
  cityName: string | null;
  /** Already linked to orders (by hand or a previous import). */
  linked: boolean;
}

export interface ImportCustomer {
  id: string;
  name: string;
  taxId?: string | null;
  legalName?: string | null;
  fiscalAddress?: FiscalAddress | null;
  invoiceEmail?: string | null;
  email?: string | null;
  invoiceRecipient?: { id: string } | null;
}

export interface ImportOrder {
  id: string;
  number: number | null;
  customerId: string | null;
  customerName: string | null;
  /** Nota value of the order (services minus their share of the discount). */
  value: number;
  /** YYYY-MM-DD: when it was done, else created. */
  date: string | null;
  done: boolean;
  /** Already has an active nota. */
  locked: boolean;
}

export type CustomerField = 'taxId' | 'legalName' | 'fiscalAddress' | 'invoiceEmail';

export interface ProposedStore {
  customerId: string;
  customerName: string;
  orders: number;
}

export interface ProposedLink {
  invoiceId: string;
  orderId: string;
  orderNumber: number | null;
  orderValue: number;
  customerId: string;
}

/** Everyone the CNPJ issued notas to, under one CPF/CNPJ. */
export interface ProposedGroup {
  key: string;
  taxId: string;
  legalName: string;
  address: FiscalAddress | null;
  email: string | null;
  notas: number;
  lastDate: string | null;
  /** complete: fills an existing customer; create: a new one; ask: "Este é o mesmo cliente?". */
  action: 'complete' | 'create' | 'ask';
  reason: 'taxId' | 'nameAndOrders' | 'orders' | 'name' | 'none';
  customerId: string | null;
  customerName: string | null;
  /** What a "complete" (or a "yes") fills on the customer. */
  fills: CustomerField[];
  /** Other customers (stores) that get "Nota fiscal para" pointing to this one. */
  stores: ProposedStore[];
  invoiceIds: string[];
  /** Links that hold when the customer is this one (sure, or after "Sim"). */
  links: ProposedLink[];
}

export interface ProposedEmitter {
  /** Fields that will be filled (empty on the emitter today). */
  fill: Partial<Pick<FiscalEmitter, 'regime' | 'simplesOption' | 'cityCode' | 'cityName' | 'municipalRegistration' | 'service' | 'descriptionStyle' | 'dpsSeries'>>;
  /** What the summary shows (current value, or the one to fill). */
  view: {
    legalName: string;
    regime: FiscalRegime | null;
    municipalRegistration: string | null;
    service: FiscalEmitterService | null;
    descriptionStyle: FiscalDescriptionStyle | null;
    dpsSeries: string | null;
  };
}

export interface AutoIssueSuggestion {
  customerId: string;
  customerName: string;
  orders: number;
  withNota: number;
}

export interface ImportProposal {
  counts: {
    notas: number;
    canceled: number;
    customers: number;
    newCustomers: number;
    completedCustomers: number;
    ask: number;
    linked: number;
    historyOnly: number;
  };
  emitter: ProposedEmitter;
  groups: ProposedGroup[];
  autoIssue: AutoIssueSuggestion[];
}

// ----------------------------------------------------------------------------
// Names
// ----------------------------------------------------------------------------

const STOP_WORDS = new Set(['ltda', 'me', 'epp', 'eireli', 'sa', 's', 'a', 'mei', 'cia', 'e', 'de', 'da', 'do', 'das', 'dos', 'ss', 'slu']);
const GENERIC_WORDS = new Set(['comercio', 'servicos', 'servico', 'auto', 'pecas', 'veiculos', 'industria', 'empresa', 'oficina', 'transportes', 'logistica']);

export function nameTokens(name: string | null | undefined): string[] {
  return (name ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w && !STOP_WORDS.has(w));
}

/** Same name once the "LTDA", "ME"... and accents are gone. */
export function sameName(a: string | null | undefined, b: string | null | undefined): boolean {
  const x = nameTokens(a).join(' ');
  return x.length > 0 && x === nameTokens(b).join(' ');
}

/** The names share a meaningful word ("Auto Center Exemplo" × "EXEMPLO PECAS LTDA"). */
export function similarName(a: string | null | undefined, b: string | null | undefined): boolean {
  const words = new Set(nameTokens(a).filter((w) => w.length >= 4 && !GENERIC_WORDS.has(w)));
  return nameTokens(b).some((w) => words.has(w));
}

const digits = (v: string | null | undefined) => (v ?? '').replace(/[^0-9A-Za-z]/g, '').toUpperCase();

function dayDiff(a: string, b: string): number {
  return Math.abs(Date.parse(`${a.slice(0, 10)}T12:00:00Z`) - Date.parse(`${b.slice(0, 10)}T12:00:00Z`)) / 86_400_000;
}

const cents = (v: number) => Math.round((Number(v) || 0) * 100);

// ----------------------------------------------------------------------------
// Emitter
// ----------------------------------------------------------------------------

/** Uppercase and separator the owner uses, from the old descriptions. */
export function learnDescriptionStyle(descriptions: string[]): FiscalDescriptionStyle | null {
  const texts = descriptions.map((d) => d.trim()).filter((d) => /[A-Za-zÀ-ÿ]/.test(d));
  if (texts.length === 0) return null;
  const upper = texts.filter((t) => t === t.toLocaleUpperCase('pt-BR')).length;
  let separator: string = ', ';
  let best = 0;
  for (const sep of SEPARATORS) {
    const count = texts.filter((t) => t.includes(sep)).length;
    if (count > best) {
      best = count;
      separator = sep;
    }
  }
  if (best < texts.length * 0.2) separator = ', ';
  return { uppercase: upper >= texts.length * 0.7, separator };
}

/** First series from 10 the CNPJ never used (§5.3): never continue another issuer's. */
export function chooseDpsSeries(used: Array<string | null | undefined>): string {
  const taken = new Set(used.map((s) => Number(String(s ?? '').trim())).filter((n) => Number.isFinite(n)));
  let candidate = DEFAULT_DPS_SERIES;
  while (taken.has(candidate)) candidate++;
  return String(candidate);
}

function mostUsedService(notas: ImportNota[]): FiscalEmitterService | null {
  const counts = new Map<string, { n: number; nota: ImportNota }>();
  for (const nota of notas) {
    const code = nota.service.nationalCode;
    if (!code) continue;
    const key = `${code}|${nota.service.municipalCode ?? ''}`;
    const entry = counts.get(key);
    // Notas are newest first: the first seen keeps the newest name and rate.
    if (entry) entry.n++;
    else counts.set(key, { n: 1, nota });
  }
  const top = [...counts.values()].sort((a, b) => b.n - a.n)[0];
  if (!top) return null;
  const s = top.nota.service;
  return {
    nationalCode: s.nationalCode!,
    municipalCode: s.municipalCode,
    nbs: s.nbs,
    name: s.name ?? s.nationalCode!,
    issRate: s.issRate ?? 0,
    simplesTaxRate: top.nota.simplesTaxRate,
  };
}

const empty = (v: unknown) => v === undefined || v === null || v === '';

export function proposeEmitter(emitter: Partial<FiscalEmitter>, notas: ImportNota[]): ProposedEmitter {
  const active = notas.filter((n) => !n.canceled);
  const latest = active[0] ?? notas[0] ?? null;
  const fill: ProposedEmitter['fill'] = {};
  if (latest) {
    if (empty(emitter.regime) && latest.regime) fill.regime = latest.regime;
    if (empty(emitter.simplesOption) && latest.regime === 'simples' && latest.simplesOption) fill.simplesOption = latest.simplesOption;
    if (empty(emitter.cityCode) && latest.cityCode) fill.cityCode = latest.cityCode;
    if (empty(emitter.cityName) && latest.cityName) fill.cityName = latest.cityName;
    if (empty(emitter.municipalRegistration) && latest.municipalRegistration) fill.municipalRegistration = latest.municipalRegistration;
  }
  if (empty(emitter.service)) {
    const service = mostUsedService(active);
    if (service) fill.service = service;
  }
  if (empty(emitter.descriptionStyle)) {
    const style = learnDescriptionStyle(active.map((n) => n.description));
    if (style) fill.descriptionStyle = style;
  }
  if (empty(emitter.dpsSeries)) fill.dpsSeries = chooseDpsSeries(notas.map((n) => n.series));
  return {
    fill,
    view: {
      legalName: emitter.legalName ?? '',
      regime: (emitter.regime ?? fill.regime ?? null) as FiscalRegime | null,
      municipalRegistration: emitter.municipalRegistration ?? fill.municipalRegistration ?? null,
      service: emitter.service ?? fill.service ?? null,
      descriptionStyle: emitter.descriptionStyle ?? fill.descriptionStyle ?? null,
      dpsSeries: emitter.dpsSeries ?? fill.dpsSeries ?? null,
    },
  };
}

// ----------------------------------------------------------------------------
// Orders
// ----------------------------------------------------------------------------

/** Orders a nota could be for: same value to the cent, within the window, without a nota. */
export function orderCandidates(nota: Pick<ImportNota, 'value' | 'date'>, orders: ImportOrder[]): ImportOrder[] {
  if (!nota.date || !(nota.value > 0)) return [];
  return orders.filter((o) => !o.locked && o.date && cents(o.value) === cents(nota.value) && dayDiff(o.date, nota.date!) <= LINK_WINDOW_DAYS);
}

/**
 * Order picker of "Ligar a uma OS" (§4.7): orders of the customer first, then
 * the closest in value and date. Orders that already have a nota go last.
 */
export function rankOrdersForNota(
  nota: { value: number; date: string | null; customerIds: string[] },
  orders: ImportOrder[],
): ImportOrder[] {
  const score = (o: ImportOrder) => {
    const sameCustomer = o.customerId && nota.customerIds.includes(o.customerId) ? 0 : 1;
    const valueGap = Math.abs(cents(o.value) - cents(nota.value)) / Math.max(cents(nota.value), 100);
    const dateGap = nota.date && o.date ? dayDiff(o.date, nota.date) / 30 : 3;
    return (o.locked ? 100 : 0) + sameCustomer * 10 + Math.min(valueGap, 5) + Math.min(dateGap, 5);
  };
  return [...orders].sort((a, b) => score(a) - score(b));
}

/** Notas with exactly one candidate order, that order wanted by no other nota. */
export function uniqueLinks(notas: ImportNota[], orders: ImportOrder[]): Map<string, ImportOrder> {
  const wanted = new Map<string, number>();
  const single = new Map<string, ImportOrder>();
  for (const nota of notas) {
    if (nota.canceled || nota.linked) continue;
    const candidates = orderCandidates(nota, orders);
    for (const o of candidates) wanted.set(o.id, (wanted.get(o.id) ?? 0) + 1);
    if (candidates.length === 1) single.set(nota.invoiceId, candidates[0]);
  }
  for (const [invoiceId, order] of [...single]) {
    if ((wanted.get(order.id) ?? 0) > 1) single.delete(invoiceId);
  }
  return single;
}

// ----------------------------------------------------------------------------
// Customers
// ----------------------------------------------------------------------------

/** What filling [customer] with the group's data would change (only empty fields). */
export function fillsFor(customer: ImportCustomer | null, group: Pick<ProposedGroup, 'taxId' | 'legalName' | 'address' | 'email'>): CustomerField[] {
  const fields: CustomerField[] = [];
  if (empty(customer?.taxId) && group.taxId) fields.push('taxId');
  if (empty(customer?.legalName) && group.legalName) fields.push('legalName');
  if (empty(customer?.fiscalAddress) && group.address) fields.push('fiscalAddress');
  if (empty(customer?.invoiceEmail) && empty(customer?.email) && group.email) fields.push('invoiceEmail');
  return fields;
}

export interface ProposalInput {
  emitter: Partial<FiscalEmitter>;
  /** Newest first. */
  notas: ImportNota[];
  customers: ImportCustomer[];
  orders: ImportOrder[];
}

export function buildProposal(input: ProposalInput): ImportProposal {
  const notas = [...input.notas].sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
  const customersById = new Map(input.customers.map((c) => [c.id, c]));
  const byTaxId = new Map<string, ImportCustomer[]>();
  for (const c of input.customers) {
    const t = digits(c.taxId);
    if (t) byTaxId.set(t, [...(byTaxId.get(t) ?? []), c]);
  }
  const links = uniqueLinks(notas, input.orders);

  // 1. Group the notas by recipient.
  const raw = new Map<string, ImportNota[]>();
  for (const nota of notas) {
    const t = digits(nota.recipient?.taxId);
    if (t.length !== 11 && t.length !== 14) continue;
    raw.set(t, [...(raw.get(t) ?? []), nota]);
  }

  const groups: ProposedGroup[] = [];
  for (const [taxId, groupNotas] of raw) {
    const newest = groupNotas[0];
    const withAddress = groupNotas.find((n) => n.recipient?.address);
    const withEmail = groupNotas.find((n) => n.recipient?.email);
    const legalName = groupNotas.find((n) => n.recipient?.legalName)?.recipient?.legalName ?? taxId;
    // Orders this group's notas link to, per customer.
    const ordersByCustomer = new Map<string, ProposedLink[]>();
    for (const nota of groupNotas) {
      const order = links.get(nota.invoiceId);
      if (!order?.customerId) continue;
      const link: ProposedLink = { invoiceId: nota.invoiceId, orderId: order.id, orderNumber: order.number, orderValue: order.value, customerId: order.customerId };
      ordersByCustomer.set(order.customerId, [...(ordersByCustomer.get(order.customerId) ?? []), link]);
    }
    const ranked = [...ordersByCustomer.entries()].sort((a, b) => b[1].length - a[1].length);

    let action: ProposedGroup['action'] = 'create';
    let reason: ProposedGroup['reason'] = 'none';
    let target: ImportCustomer | null = null;

    const sameTaxId = byTaxId.get(taxId) ?? [];
    if (sameTaxId.length > 0) {
      // A duplicated CNPJ keeps the one with more orders here.
      target = [...sameTaxId].sort((a, b) => (ordersByCustomer.get(b.id)?.length ?? 0) - (ordersByCustomer.get(a.id)?.length ?? 0))[0];
      action = 'complete';
      reason = 'taxId';
    } else {
      const named = input.customers.filter((c) => !digits(c.taxId) && (sameName(c.name, legalName) || sameName(c.legalName, legalName)));
      const namedWithOrders = named.find((c) => ordersByCustomer.has(c.id));
      const top = ranked[0] ? customersById.get(ranked[0][0]) : undefined;
      if (namedWithOrders) {
        target = namedWithOrders;
        action = 'complete';
        reason = 'nameAndOrders';
      } else if (top && !digits(top.taxId)) {
        const matches = ranked[0][1].length;
        target = top;
        reason = 'orders';
        action = matches >= SURE_ORDER_MATCHES && (similarName(top.name, legalName) || similarName(top.legalName, legalName)) ? 'complete' : 'ask';
      } else if (named.length > 0) {
        target = named[0];
        action = 'ask';
        reason = 'name';
      }
    }

    // Stores: other customers with 2+ linked orders and no CNPJ or recipient of their own.
    const stores: ProposedStore[] = [];
    if (target) {
      for (const [customerId, customerLinks] of ranked) {
        if (customerId === target.id || customerLinks.length < 2) continue;
        const c = customersById.get(customerId);
        if (!c || digits(c.taxId) || c.invoiceRecipient?.id) continue;
        stores.push({ customerId, customerName: c.name, orders: customerLinks.length });
      }
    }
    const allowed = new Set([target?.id, ...stores.map((s) => s.customerId)].filter(Boolean) as string[]);
    const group: ProposedGroup = {
      key: taxId,
      taxId,
      legalName,
      address: withAddress?.recipient?.address ?? null,
      email: withEmail?.recipient?.email ?? null,
      notas: groupNotas.length,
      lastDate: newest.date,
      action,
      reason,
      customerId: target?.id ?? null,
      customerName: target?.name ?? null,
      fills: [],
      stores,
      invoiceIds: groupNotas.map((n) => n.invoiceId),
      links: ranked.flatMap(([customerId, l]) => (allowed.has(customerId) ? l : [])),
    };
    group.fills = fillsFor(target, group);
    groups.push(group);
  }

  // 2. One customer is the target of one CNPJ only: the group with more notas keeps it.
  const owner = new Map<string, ProposedGroup>();
  for (const g of [...groups].sort((a, b) => b.notas - a.notas)) {
    if (!g.customerId) continue;
    const seen = owner.get(g.customerId);
    if (!seen) {
      owner.set(g.customerId, g);
      continue;
    }
    Object.assign(g, { action: 'create', reason: 'none', customerId: null, customerName: null, stores: [], links: [] });
    g.fills = fillsFor(null, g);
  }
  // A store is a store of one group only, and never a target itself.
  const taken = new Set<string>(owner.keys());
  for (const g of [...groups].sort((a, b) => b.notas - a.notas)) {
    g.stores = g.stores.filter((s) => {
      if (taken.has(s.customerId)) return false;
      taken.add(s.customerId);
      return true;
    });
    const allowed = new Set([g.customerId, ...g.stores.map((s) => s.customerId)]);
    g.links = g.links.filter((l) => allowed.has(l.customerId));
  }

  groups.sort((a, b) => b.notas - a.notas || a.legalName.localeCompare(b.legalName));

  // 3. "Emitir sozinha": sure customers with a nota in almost every order since the first nota.
  const firstDate = notas.map((n) => n.date).filter(Boolean).sort()[0] ?? null;
  const autoIssue: AutoIssueSuggestion[] = [];
  for (const g of groups) {
    if (g.action !== 'complete' || !g.customerId || !firstDate) continue;
    const customerIds = new Set([g.customerId, ...g.stores.map((s) => s.customerId)]);
    const done = input.orders.filter((o) => o.done && o.customerId && customerIds.has(o.customerId) && o.date && o.date >= firstDate);
    const withNota = done.filter((o) => o.locked || g.links.some((l) => l.orderId === o.id)).length;
    if (done.length >= AUTO_ISSUE_MIN_ORDERS && withNota >= done.length * AUTO_ISSUE_SHARE) {
      autoIssue.push({ customerId: g.customerId, customerName: g.customerName ?? g.legalName, orders: done.length, withNota });
    }
  }

  const sureLinks = groups.filter((g) => g.action === 'complete').reduce((sum, g) => sum + g.links.length, 0);
  const active = notas.filter((n) => !n.canceled).length;
  return {
    counts: {
      notas: notas.length,
      canceled: notas.length - active,
      customers: groups.length,
      newCustomers: groups.filter((g) => g.action === 'create').length,
      completedCustomers: groups.filter((g) => g.action === 'complete').length,
      ask: groups.filter((g) => g.action === 'ask').length,
      linked: sureLinks,
      historyOnly: notas.length - sureLinks,
    },
    emitter: proposeEmitter(input.emitter, notas),
    groups,
    autoIssue,
  };
}
