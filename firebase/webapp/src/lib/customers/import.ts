// Customers from a spreadsheet (desk extra of fatia 03): CSV or XLSX read in
// the browser, columns guessed and confirmed, repeated phones found before
// anything is saved. Nothing leaves the browser until "Importar".
import { phoneMatchKey } from '@/lib/phone'
import { isValidTaxId, normalizeTaxId } from '@/lib/tax-id'
import { fold } from './model'

export type ImportField = '' | 'name' | 'phone' | 'email' | 'address' | 'taxId'
export const IMPORT_FIELDS: ImportField[] = ['', 'name', 'phone', 'email', 'address', 'taxId']
/** Lines per request (POST /v1/app/customers/import takes up to 500). */
export const IMPORT_CHUNK = 400
export const IMPORT_MAX_ROWS = 5000

/** CSV with comma, semicolon or tab, quotes and line breaks inside quotes. */
export function parseCsv(text: string): string[][] {
  const clean = text.replace(/^﻿/, '')
  const firstLine = clean.split(/\r?\n/, 1)[0] ?? ''
  const separator = ['\t', ';', ','].map((sep) => [sep, firstLine.split(sep).length] as const).sort((a, b) => b[1] - a[1])[0]?.[0] ?? ','
  const rows: string[][] = []
  let row: string[] = []
  let cell = ''
  let quoted = false
  for (let i = 0; i < clean.length; i++) {
    const char = clean[i] as string
    if (quoted) {
      if (char === '"' && clean[i + 1] === '"') {
        cell += '"'
        i++
      } else if (char === '"') quoted = false
      else cell += char
    } else if (char === '"' && cell === '') quoted = true
    else if (char === separator) {
      row.push(cell)
      cell = ''
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && clean[i + 1] === '\n') i++
      row.push(cell)
      rows.push(row)
      row = []
      cell = ''
    } else cell += char
  }
  if (cell !== '' || row.length) {
    row.push(cell)
    rows.push(row)
  }
  return rows.map((r) => r.map((value) => value.trim())).filter((r) => r.some(Boolean))
}

/** Column a header most likely holds. */
export function guessField(header: string): ImportField {
  const text = fold(header)
  if (/cpf|cnpj|documento|tax/.test(text)) return 'taxId'
  if (/mail/.test(text)) return 'email'
  if (/cel|tel|fone|whats|phone|movil/.test(text)) return 'phone'
  if (/end|rua|logradouro|address|direcc/.test(text)) return 'address'
  if (/nome|cliente|razao|name|nombre/.test(text)) return 'name'
  return ''
}

/** One guess per column; a field already taken by an earlier column is not repeated. */
export function guessFields(headers: string[]): ImportField[] {
  const taken = new Set<ImportField>()
  return headers.map((header) => {
    const field = guessField(header)
    if (!field || taken.has(field)) return ''
    taken.add(field)
    return field
  })
}

export interface ImportRow {
  line: number
  name: string
  phone: string
  email: string
  address: string
  taxId: string
  state: 'ok' | 'noName' | 'badTaxId' | 'duplicate' | 'repeated'
  /** Who already has the phone (duplicate) or the earlier line (repeated). */
  clash?: string
}

/**
 * Lines with what each will do. Without a name: out. Invalid CPF/CNPJ: out. A
 * phone already of a customer: out (duplicate). The same phone twice in the
 * file: the first goes in, the next is out (repeated).
 */
export function reviewRows(
  rows: string[][],
  fields: ImportField[],
  customers: { name: string; phone: string | null }[],
  country?: string | null,
): ImportRow[] {
  const known = new Map<string, string>()
  for (const customer of customers) {
    const key = customer.phone ? phoneMatchKey(customer.phone, country) : ''
    if (key.length >= 8 && !known.has(key)) known.set(key, customer.name)
  }
  const inFile = new Map<string, number>()
  const value = (row: string[], field: ImportField) => {
    const index = fields.indexOf(field)
    return index < 0 ? '' : (row[index] ?? '').trim()
  }
  return rows.map((row, index) => {
    const line = index + 2
    const item: ImportRow = {
      line,
      name: value(row, 'name'),
      phone: value(row, 'phone'),
      email: value(row, 'email'),
      address: value(row, 'address'),
      taxId: value(row, 'taxId'),
      state: 'ok',
    }
    const key = item.phone ? phoneMatchKey(item.phone, country) : ''
    if (!item.name) item.state = 'noName'
    else if (item.taxId && !isValidTaxId(item.taxId)) item.state = 'badTaxId'
    else if (key.length >= 8 && known.has(key)) {
      item.state = 'duplicate'
      item.clash = known.get(key)
    } else if (key.length >= 8 && inFile.has(key)) {
      item.state = 'repeated'
      item.clash = String(inFile.get(key))
    } else if (key.length >= 8) inFile.set(key, line)
    return item
  })
}

/** Body of POST /customers/import for the lines that go in. */
export function importPayload(rows: ImportRow[]) {
  return rows
    .filter((row) => row.state === 'ok')
    .map((row) => ({
      name: row.name,
      ...(row.phone ? { phone: row.phone } : {}),
      ...(row.email ? { email: row.email } : {}),
      ...(row.address ? { address: row.address } : {}),
      ...(row.taxId ? { taxId: normalizeTaxId(row.taxId) } : {}),
    }))
}

// ─── XLSX ────────────────────────────────────────────────────────────────────
// An .xlsx is a zip of XML files. Only the first sheet and its shared texts are
// read, with the browser's own inflate (DecompressionStream): no library.

async function inflate(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([data as BlobPart]).stream().pipeThrough(new DecompressionStream('deflate-raw'))
  return new Uint8Array(await new Response(stream).arrayBuffer())
}

async function unzip(buffer: ArrayBuffer, wanted: (name: string) => boolean): Promise<Map<string, string>> {
  const view = new DataView(buffer)
  const bytes = new Uint8Array(buffer)
  // End of central directory: the last 0x06054b50 signature.
  let end = -1
  for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 65_557); i--) {
    if (view.getUint32(i, true) === 0x06054b50) {
      end = i
      break
    }
  }
  if (end < 0) throw new Error('not a zip')
  const count = view.getUint16(end + 10, true)
  let at = view.getUint32(end + 16, true)
  const files = new Map<string, string>()
  const decoder = new TextDecoder()
  for (let n = 0; n < count; n++) {
    if (view.getUint32(at, true) !== 0x02014b50) break
    const method = view.getUint16(at + 10, true)
    const size = view.getUint32(at + 20, true)
    const nameLength = view.getUint16(at + 28, true)
    const extraLength = view.getUint16(at + 30, true)
    const commentLength = view.getUint16(at + 32, true)
    const local = view.getUint32(at + 42, true)
    const name = decoder.decode(bytes.subarray(at + 46, at + 46 + nameLength))
    at += 46 + nameLength + extraLength + commentLength
    if (!wanted(name)) continue
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true)
    const raw = bytes.subarray(start, start + size)
    files.set(name, decoder.decode(method === 8 ? await inflate(raw) : raw))
  }
  return files
}

/** "B12" → 1 (column index). */
function columnOf(ref: string): number {
  const letters = ref.replace(/\d+/g, '')
  let index = 0
  for (const char of letters) index = index * 26 + (char.charCodeAt(0) - 64)
  return index - 1
}

export async function parseXlsx(buffer: ArrayBuffer): Promise<string[][]> {
  const files = await unzip(buffer, (name) => name === 'xl/sharedStrings.xml' || /^xl\/worksheets\/sheet\d+\.xml$/.test(name) || name === 'xl/workbook.xml')
  const sheetName = [...files.keys()].filter((name) => name.startsWith('xl/worksheets/')).sort()[0]
  if (!sheetName) throw new Error('no sheet')
  const parser = new DOMParser()
  const shared = files.get('xl/sharedStrings.xml')
  const strings = shared
    ? [...parser.parseFromString(shared, 'application/xml').getElementsByTagName('si')].map((si) =>
        [...si.getElementsByTagName('t')].map((t) => t.textContent ?? '').join(''),
      )
    : []
  const sheet = parser.parseFromString(files.get(sheetName) as string, 'application/xml')
  const rows: string[][] = []
  for (const row of sheet.getElementsByTagName('row')) {
    const cells: string[] = []
    for (const cell of row.getElementsByTagName('c')) {
      const type = cell.getAttribute('t')
      const raw = cell.getElementsByTagName('v')[0]?.textContent ?? ''
      const text = type === 's' ? (strings[Number(raw)] ?? '') : type === 'inlineStr' ? [...cell.getElementsByTagName('t')].map((t) => t.textContent ?? '').join('') : raw
      cells[columnOf(cell.getAttribute('r') ?? 'A1')] = text.trim()
    }
    rows.push(Array.from(cells, (value) => value ?? ''))
  }
  return rows.filter((r) => r.some(Boolean))
}

/** Rows of a chosen file: .xlsx by its zip, anything else as text (CSV, TXT, pasted). */
export async function readFile(file: File): Promise<string[][]> {
  if (/\.xlsx$/i.test(file.name)) return parseXlsx(await file.arrayBuffer())
  if (/\.xls$/i.test(file.name)) throw new Error('xls')
  return parseCsv(await file.text())
}
