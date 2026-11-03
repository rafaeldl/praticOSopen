// Financeiro (fatia 6): periods, export and the rules of the notas list.
import { describe, expect, test } from 'vitest'
import { parseXlsx } from '../src/lib/customers/import'
import { crc32, toCsv, toXlsx } from '../src/lib/finance/export'
import { addDays, daysBetween, isDay, periodOf, shiftMonth, weekday } from '../src/lib/finance/period'
import {
  askedFields,
  blockerOf,
  canCancel,
  canFix,
  invoiceOf,
  isActive,
  matches,
  monthList,
  querySince,
  queryUntil,
  safeHttps,
  type Preview,
} from '../src/lib/nfse/model'
import { isValidTaxId } from '../src/lib/tax-id'

describe('period', () => {
  test('days and weeks', () => {
    expect(isDay('2026-02-29')).toBe(false)
    expect(isDay('2028-02-29')).toBe(true)
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01')
    expect(weekday('2026-11-01')).toBe(0)
    expect(daysBetween('2026-03-01', '2026-03-31')).toBe(30)
    expect(shiftMonth('2026-01', -1)).toBe('2025-12')
    expect(shiftMonth('2026-12', 1)).toBe('2027-01')
  })

  test('the week always has seven days, Sunday to Saturday', () => {
    for (let day = '2026-01-01'; day < '2027-01-01'; day = addDays(day, 1)) {
      const week = periodOf('week', 0, day)
      expect(weekday(week.from)).toBe(0)
      expect(daysBetween(week.from, week.to)).toBe(6)
      expect(week.from <= day && day <= week.to).toBe(true)
    }
  })
})

describe('export', () => {
  test('CSV for a comma country: semicolons, comma decimals, quotes and no formulas', () => {
    const csv = toCsv([['OS', 'Cliente', 'Total'], [12, 'Ana; "Bia"', 150.5], [13, '=HYPERLINK("x")', 80]], ',')
    expect(csv.startsWith('﻿')).toBe(true)
    expect(csv).toContain('OS;Cliente;Total\r\n')
    expect(csv).toContain('12;"Ana; ""Bia""";150,50\r\n')
    expect(csv).toContain(`13;"'=HYPERLINK(""x"")";80\r\n`)
  })

  test('CSV for a dot country uses commas', () => {
    expect(toCsv([[1.25, 'a,b']], '.')).toBe('﻿1.25,"a,b"\r\n')
  })

  test('crc32 of a known text', () => {
    expect(crc32(new TextEncoder().encode('123456789'))).toBe(0xcbf43926)
  })

  test('XLSX opens again with the same rows, numbers as numbers', async () => {
    const data = toXlsx([
      { name: 'OS', rows: [['OS', 'Cliente', 'Total'], [12, 'Ação & <cia>', 150.5]] },
      { name: 'Clientes', rows: [['Nome'], ['Ana']] },
    ])
    const rows = await parseXlsx(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer)
    expect(rows).toEqual([['OS', 'Cliente', 'Total'], ['12', 'Ação & <cia>', '150.5']])
    const text = new TextDecoder().decode(data)
    expect(text).toContain('<sheet name="Clientes" sheetId="2"')
    expect(text).toContain('<c r="C2" s="1"><v>150.5</v></c>')
  })
})

const nota = (id: string, data: Record<string, unknown>) =>
  invoiceOf(id, { status: 'authorized', value: 100, customer: { id: 'ana', name: 'Ana Souza' }, orderIds: [`o-${id}`], orders: [{ orderId: `o-${id}`, orderNumber: 10, value: 100 }], effectiveDate: '2026-03-10', createdAt: '2026-03-10T12:00:00.000Z', ...data })

describe('notas', () => {
  const NOW = Date.parse('2026-04-05T12:00:00.000Z')

  test('reads what the list needs and only https links', () => {
    const n = invoiceOf('n1', { status: 'weird', pdfUrl: 'javascript:alert(1)', xmlUrl: 'https://asaas.test/x.xml', customer: { name: 'Bia' } })
    expect(n.status).toBe('creating')
    expect(n.pdfUrl).toBeNull()
    expect(n.xmlUrl).toBe('https://asaas.test/x.xml')
    expect(safeHttps('http://x.test')).toBeNull()
  })

  test('the month: issued count and total, attention on top, refused-and-reissued hidden', () => {
    const list = [
      nota('a', { value: 100 }),
      nota('b', { status: 'cancellationDenied', value: 50 }),
      nota('c', { status: 'canceled', value: 30 }),
      nota('d', { status: 'error', orderIds: ['o-x'], value: 20 }),
      nota('e', { status: 'scheduled', orderIds: ['o-x'], value: 20, effectiveDate: '2026-03-20' }),
      nota('f', { status: 'error', orderIds: ['o-f'], value: 40 }),
      nota('g', { status: 'authorized', conflict: true, value: 70 }),
      nota('old', { status: 'error', orderIds: ['o-old'], effectiveDate: '2026-01-10' }),
      nota('stale', { status: 'creating', createdAt: '2026-03-10T12:00:00.000Z' }),
      nota('april', { effectiveDate: '2026-04-02' }),
    ]
    const result = monthList(list, '2026-03', '2026-04-05', NOW)
    expect(result.issuedCount).toBe(2)
    expect(result.issuedTotal).toBe(150)
    expect(result.attention.map((n) => n.id)).toEqual(['b', 'f', 'g'])
    expect(result.rows.map((n) => n.id)).toEqual(['e', 'a', 'c'])
  })

  test('a creating nota counts as active only for 15 minutes', () => {
    const n = nota('x', { status: 'creating', createdAt: '2026-04-05T11:50:00.000Z' })
    expect(isActive(n, NOW)).toBe(true)
    expect(isActive(n, NOW + 10 * 60_000)).toBe(false)
  })

  test('what the read asks for: from the earlier of the month and last month, until the month ends', () => {
    expect(querySince('2026-04', '2026-04-05')).toBe('2026-03-01')
    expect(querySince('2026-01', '2026-04-05')).toBe('2026-01-01')
    expect(queryUntil('2028-02')).toBe('2028-02-29')
  })

  test('search ignores accents and case, finds number and order', () => {
    const n = nota('s', { customer: { name: 'João Ávila' }, number: '4521', orders: [{ orderId: 'o', orderNumber: 187, value: 1 }] })
    expect(matches(n, 'joao avila')).toBe(true)
    expect(matches(n, '452')).toBe(true)
    expect(matches(n, '187')).toBe(true)
    expect(matches(n, 'maria')).toBe(false)
  })

  test('cancel and fix follow the status', () => {
    expect(canCancel(nota('1', { status: 'scheduled' }))).toBe(true)
    expect(canCancel(nota('2', { status: 'error' }))).toBe(false)
    expect(canFix(nota('3', { status: 'error' }))).toBe(true)
    expect(canFix(nota('4', { status: 'error', conflict: true }))).toBe(false)
  })

  const preview = (over: Partial<Preview> = {}): Preview => ({
    value: 270,
    orders: [{ orderId: 'o1', orderNumber: 182, value: 270, servicesTotal: 300, productsTotal: 100, discount: 40 }],
    hasProducts: true,
    serviceDescription: 'Serviços',
    effectiveDate: '2026-04-05',
    customer: { id: 'ana', name: 'Ana', hasTaxId: true, contact: {}, missingData: [] },
    invoicedOrders: {},
    municipalServiceName: '14.01',
    ...over,
  })

  test('what keeps "Emitir" grey, first reason first', () => {
    const form = { taxId: '', contact: {}, asking: [] }
    expect(blockerOf(preview({ invoicedOrders: { o1: 'n9' } }), form, isValidTaxId)).toEqual({ kind: 'invoiced', numbers: '182' })
    expect(blockerOf(preview({ value: 0 }), form, isValidTaxId)).toEqual({ kind: 'zero' })
    const noTax = preview({ customer: { id: 'ana', name: 'Ana', hasTaxId: false, contact: {}, missingData: [] } })
    expect(blockerOf(noTax, form, isValidTaxId)).toEqual({ kind: 'taxId' })
    expect(blockerOf(noTax, { ...form, taxId: '529.982.247-25' }, isValidTaxId)).toBeNull()
    const asking = askedFields(['email', 'postalCode'])
    expect(asking).toEqual(['email', 'postalCode', 'address', 'addressNumber', 'province'])
    expect(blockerOf(preview(), { ...form, asking }, isValidTaxId)).toEqual({ kind: 'contact' })
    const full = { email: 'ana@exemplo.test', postalCode: '88000-000', address: 'Rua A', addressNumber: '10', province: 'Centro' }
    expect(blockerOf(preview(), { ...form, asking, contact: full }, isValidTaxId)).toBeNull()
    expect(blockerOf(preview(), { ...form, asking, contact: { ...full, postalCode: '8800' } }, isValidTaxId)).toEqual({ kind: 'contact' })
  })
})
