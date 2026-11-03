// Pure rules of the catalog screens (fatia 05): search, kinds by permission,
// bulk price math and the spreadsheet review. Each comes from the app
// (lib/screens/catalog/*) and says where it does not copy a defect.
import { parseMoney } from '@/lib/format'
import { fold } from '@/lib/customers/model'

export type CatalogKind = 'service' | 'product'
export const KINDS: CatalogKind[] = ['service', 'product']

export interface CatalogItem {
  id: string
  name: string
  /** Absent without viewPrices: the server never sends it. Null: "sem valor". */
  value?: number | null
  photo: string | null
  customData: Record<string, unknown> | null
  version: string | null
}

/** Kinds the person sees, in the app's order (catalog.list.switch): services first. */
export function visibleKinds(can: (permission: 'viewServices' | 'viewProducts') => boolean): CatalogKind[] {
  return KINDS.filter((kind) => can(kind === 'service' ? 'viewServices' : 'viewProducts'))
}

/** The kind on screen: the one asked in the URL when allowed, else the first allowed. */
export function pickKind(asked: unknown, kinds: CatalogKind[]): CatalogKind | null {
  return kinds.includes(asked as CatalogKind) ? (asked as CatalogKind) : (kinds[0] ?? null)
}

/** Name for comparing: no accents, no case, single spaces. */
export const nameKey = (name: string) => fold(name).replace(/\s+/g, ' ').trim()

/**
 * By name, "contains", ignoring accents and case. The app does not ignore
 * accents (C14, not copied); `keywords` is not used, as in the app.
 */
export function itemMatches(item: Pick<CatalogItem, 'name'>, query: string): boolean {
  const text = nameKey(query)
  return !text || nameKey(item.name).includes(text)
}

/** Alphabetical, accents and case aside (the app's Firestore order puts "a" after "Z": C20, not copied). */
export function sortByName<T extends { name: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }) || a.name.localeCompare(b.name))
}

// ─── Bulk price ──────────────────────────────────────────────────────────────

export interface PriceRule {
  direction: 'up' | 'down'
  /** 10 means 10 %. */
  percent: number
  /** Whole currency units (R$ 54,90 → R$ 55). */
  round: boolean
}

/** Valid percent for the direction: lowering past 100 % would make prices negative. */
export function percentOk(rule: Pick<PriceRule, 'direction' | 'percent'>): boolean {
  return Number.isFinite(rule.percent) && rule.percent >= 0 && rule.percent <= (rule.direction === 'down' ? 100 : 1000)
}

/** Cents without the binary drift of `x * 100`. */
const toCents = (value: number) => Math.round(Number((value * 100).toFixed(6)))

/**
 * New price, worked in cents so nothing ends 100 times smaller or drifts.
 * `digits`: decimal places of the company's currency (2 for BRL, 0 for CLP).
 */
export function newPrice(value: number, rule: PriceRule, digits = 2): number {
  const factor = rule.direction === 'up' ? 100 + rule.percent : 100 - rule.percent
  const cents = Math.max(0, Math.round((toCents(value) * factor) / 100))
  if (rule.round || digits === 0) return Math.round(cents / 100)
  return cents / 100
}

export interface PriceChange {
  item: CatalogItem
  from: number
  to: number
}

/** What changes, before and after. Items without a price stay as they are and are counted apart. */
export function priceChanges(items: CatalogItem[], rule: PriceRule, digits = 2): { changes: PriceChange[]; withoutPrice: number; same: number } {
  const changes: PriceChange[] = []
  let withoutPrice = 0
  let same = 0
  for (const item of items) {
    if (typeof item.value !== 'number') {
      withoutPrice++
      continue
    }
    const to = newPrice(item.value, rule, digits)
    if (toCents(to) === toCents(item.value)) same++
    else changes.push({ item, from: item.value, to })
  }
  return { changes, withoutPrice, same }
}

/** One transaction on the server: up to 500 items, so a batch is all or nothing. */
export const MAX_PRICE_BATCH = 500

/** What goes to POST /prices. Frozen once sent: a retry resends it as it is (revisão A1). */
export interface PriceBatch {
  kind: CatalogKind
  /** Same key on every retry of the same batch. */
  batchId: string
  changes: PriceChange[]
}

export function priceBatch(kind: CatalogKind, changes: PriceChange[], newId: () => string = () => crypto.randomUUID()): PriceBatch {
  if (changes.length > MAX_PRICE_BATCH) throw new Error('batch too big')
  return { kind, batchId: newId(), changes: changes.map((change) => ({ ...change })) }
}

/** The way back: each item from the new price to the one it had, under a key of its own. */
export function reverseBatch(batch: PriceBatch, newId: () => string = () => crypto.randomUUID()): PriceBatch {
  return { kind: batch.kind, batchId: newId(), changes: batch.changes.map((change) => ({ item: change.item, from: change.to, to: change.from })) }
}

/** Body of POST /prices. */
export const priceBatchBody = (batch: PriceBatch) => ({ batchId: batch.batchId, changes: batch.changes.map((change) => ({ id: change.item.id, from: change.from, to: change.to })) })

// ─── Spreadsheet import ─────────────────────────────────────────────────────

export type CatalogField = '' | 'name' | 'kind' | 'value'
export const CATALOG_FIELDS: CatalogField[] = ['', 'name', 'kind', 'value']
/** Lines per request (POST /import takes up to 500). */
export const CATALOG_IMPORT_CHUNK = 200
export const CATALOG_IMPORT_MAX_ROWS = 5000

/** Column a header most likely holds. Price first: "Valor do serviço" is a price. */
export function guessCatalogField(header: string): CatalogField {
  const text = fold(header)
  if (/preco|valor|price|precio|value|custo|cost/.test(text)) return 'value'
  if (/tipo|type|kind|categoria|category/.test(text)) return 'kind'
  if (/nome|descri|servico|produto|peca|item|name|nombre|servicio|producto/.test(text)) return 'name'
  return ''
}

export function guessCatalogFields(headers: string[]): CatalogField[] {
  const taken = new Set<CatalogField>()
  return headers.map((header) => {
    const field = guessCatalogField(header)
    if (!field || taken.has(field)) return ''
    taken.add(field)
    return field
  })
}

/**
 * Kind written in a cell: "Serviço", "mão de obra" → service; "Produto",
 * "Peça", "Material", "Componente" → product; empty → the default; anything
 * else → null (the line stays out, never guessed).
 */
export function parseKind(text: string, fallback: CatalogKind, productLabel = ''): CatalogKind | null {
  const value = nameKey(text)
  if (!value) return fallback
  if (/^(servico|servicos|service|services|servicio|servicios|mao de obra|labor|s)$/.test(value)) return 'service'
  if (/^(produto|produtos|product|products|producto|productos|peca|pecas|part|parts|pieza|piezas|material|materiais|componente|componentes|component|p)$/.test(value)) return 'product'
  if (productLabel && value === nameKey(productLabel)) return 'product'
  return null
}

export interface CatalogImportRow {
  line: number
  name: string
  kind: CatalogKind | null
  /** undefined: no price column (or the person does not edit prices); null: empty cell. */
  value?: number | null
  rawValue: string
  state: 'ok' | 'noName' | 'badKind' | 'badPrice' | 'duplicate' | 'repeated'
  /** Earlier line with the same name (repeated). */
  clash?: number
}

/**
 * Lines with what each will do. Without a name, with a kind that is neither
 * service nor product, or with a price that does not read: out. A name already
 * in the catalog (same kind, accents and case aside): out. The same name twice
 * in the file: the first goes in. Prices read as typed: "150" is 150, never 1,50.
 */
export function reviewCatalogRows(
  rows: string[][],
  fields: CatalogField[],
  existing: Record<CatalogKind, { name: string }[]>,
  options: { defaultKind: CatalogKind; country?: string | null; prices: boolean; productLabel?: string },
): CatalogImportRow[] {
  const known: Record<CatalogKind, Set<string>> = {
    service: new Set(existing.service.map((item) => nameKey(item.name))),
    product: new Set(existing.product.map((item) => nameKey(item.name))),
  }
  const inFile = new Map<string, number>()
  const cell = (row: string[], field: CatalogField) => {
    const index = fields.indexOf(field)
    return index < 0 ? '' : (row[index] ?? '').trim()
  }
  const withPrice = options.prices && fields.includes('value')
  return rows.map((row, index) => {
    const line = index + 2
    const rawValue = cell(row, 'value')
    const item: CatalogImportRow = {
      line,
      name: cell(row, 'name').replace(/\s+/g, ' '),
      kind: parseKind(cell(row, 'kind'), options.defaultKind, options.productLabel),
      rawValue,
      state: 'ok',
    }
    if (withPrice) {
      const parsed = rawValue ? parseMoney(rawValue, options.country) : null
      item.value = parsed
      if (rawValue && (parsed === null || parsed < 0)) item.state = 'badPrice'
    }
    const key = `${item.kind}|${nameKey(item.name)}`
    if (!item.name) item.state = 'noName'
    else if (!item.kind) item.state = 'badKind'
    else if (item.state === 'badPrice') return item
    else if (known[item.kind].has(nameKey(item.name))) item.state = 'duplicate'
    else if (inFile.has(key)) {
      item.state = 'repeated'
      item.clash = inFile.get(key)
    } else inFile.set(key, line)
    return item
  })
}

/** Bodies of POST /import per kind, for the lines that go in. */
export function catalogImportPayload(rows: CatalogImportRow[]): Record<CatalogKind, { name: string; value?: number | null }[]> {
  const out: Record<CatalogKind, { name: string; value?: number | null }[]> = { service: [], product: [] }
  for (const row of rows) {
    if (row.state !== 'ok' || !row.kind) continue
    out[row.kind].push({ name: row.name, ...(row.value !== undefined ? { value: row.value } : {}) })
  }
  return out
}
