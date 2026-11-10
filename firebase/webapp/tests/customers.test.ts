// Fatia 03: phone and CPF/CNPJ by the contract cases (one rule for app, server
// and web), masks and segment fields, the list rules and the spreadsheet import.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test, vi } from 'vitest'
import { formatPhone, phoneMatchKey, whatsappNumber } from '../src/lib/phone'
import { formatTaxId, isValidCnpj, isValidCpf, isValidTaxId, normalizeTaxId } from '../src/lib/tax-id'
import { nextTick, ref } from 'vue'
import { applyMask, useMask, buildFields, fieldMasks, namespaceFields, readCustom, validateField, writeCustom, type FormField } from '../src/lib/segment-fields'
import {
  addMonths,
  badgeOf,
  byRecent,
  canOfferCreate,
  customerMatches,
  deviceMatches,
  draftFromSearch,
  findByPhone,
  groupByInitial,
  isBrazilianPlate,
  orderNumberMatches,
  shortList,
  modelSuggestions,
  plateMatches,
  serialError,
  type DeviceRow,
} from '../src/lib/customers/model'
import { guessFields, importPayload, parseCsv, parseXlsx, reviewRows } from '../src/lib/customers/import'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn() }))

const dir = resolve(process.cwd(), '../../docs/web-app/contract-cases')
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const cases = (file: string): any[] => JSON.parse(readFileSync(resolve(dir, file), 'utf8')).cases

describe('phone (contract cases)', () => {
  test.each(cases('phone.json'))('$id', (c) => {
    const { kind, raw, country } = c.given
    if (kind === 'normalize') expect(whatsappNumber(raw, country)).toBe(c.expect.number)
    else if (kind === 'matchKey') expect(phoneMatchKey(raw, country)).toBe(c.expect.number)
    else expect(formatPhone(raw, country)).toBe(c.expect.text)
  })
})

describe('tax-id (contract cases)', () => {
  test.each(cases('tax-id.json'))('$id', (c) => {
    const { kind, value } = c.given
    if (kind === 'normalize') expect(normalizeTaxId(value)).toBe(c.expect.result)
    else if (kind === 'format') expect(formatTaxId(value)).toBe(c.expect.result)
    else if (kind === 'cpf') expect(isValidCpf(value)).toBe(c.expect.valid)
    else if (kind === 'cnpj') expect(isValidCnpj(value)).toBe(c.expect.valid)
    else expect(isValidTaxId(value)).toBe(c.expect.valid)
  })
})

describe('masks (easy_mask)', () => {
  const phone = ['(99) 9999-9999', '(99) 99999-9999']
  test.each([
    ['48', '(48'],
    ['4832223344', '(48) 3222-3344'],
    ['48984087801', '(48) 98408-7801'],
    ['(48) 98408-7801', '(48) 98408-7801'],
  ])('phone %s → %s', (typed, shown) => expect(applyMask(typed, phone)).toBe(shown))
  test('plate with letters and digits', () => {
    expect(applyMask('abc1d23', ['AAA-9999', 'AAA9N99'])).toBe('abc1d23')
    expect(applyMask('abc1234', ['AAA-9999'])).toBe('abc-1234')
  })
  test('no mask keeps the text', () => expect(applyMask('anything', [])).toBe('anything'))
})

describe('mask that arrives after typing (CI #517)', () => {
  const typed = (target: { value: string }) => ({ target }) as unknown as Event

  test('typed before the segment loaded: masked when it arrives, nothing lost', async () => {
    const masks = ref<string[]>([])
    const phone = ref('')
    const onInput = useMask(phone, () => masks.value)
    const input = { value: '48912345678' }
    onInput(typed(input))
    expect(phone.value).toBe('48912345678')
    // The segment (and the company's country) arrive now.
    masks.value = ['(99) 9999-9999', '(99) 99999-9999']
    await nextTick()
    expect(phone.value).toBe('(48) 91234-5678')
    // Typing on goes on with the mask.
    onInput(typed({ value: '(48) 91234-567' }))
    expect(phone.value).toBe('(48) 9123-4567')
  })

  test('serial: mask and uppercase also for what was typed early', async () => {
    const masks = ref<string[]>([])
    const serial = ref('')
    const onInput = useMask(serial, () => masks.value, (text) => text.toUpperCase())
    onInput(typed({ value: 'abc1234' }))
    expect(serial.value).toBe('ABC1234')
    masks.value = ['AAA-9999', 'AAA9N99']
    await nextTick()
    expect(serial.value).toBe('ABC-1234')
  })

  test('empty field stays empty when the mask arrives', async () => {
    const masks = ref<string[]>([])
    const phone = ref('')
    useMask(phone, () => masks.value)
    masks.value = ['(99) 99999-9999']
    await nextTick()
    expect(phone.value).toBe('')
  })
})

describe('segment fields', () => {
  const global = { customFields: [{ key: 'customer.phone', type: 'text', masksByCountry: { BR: ['(99) 99999-9999'] } }, { key: 'customer._entity', type: 'label' }] }
  const segment = {
    customFields: [
      { key: 'customer.birth', type: 'date', order: 2 },
      { key: 'customer.vip', type: 'select', options: ['sim', 'não'], order: 1, required: true },
      { key: 'device.mileage', type: 'number', min: 0, max: 999999 },
    ],
  }
  const fields = buildFields([global, segment]) as FormField[]
  test('labels out, ordered by order, masks by country', () => {
    expect(fields.map((f) => f.key)).toEqual(['customer.vip', 'customer.birth', 'customer.phone', 'device.mileage'])
    expect(fieldMasks(fields.find((f) => f.key === 'customer.phone'), 'BR')).toEqual(['(99) 99999-9999'])
    expect(fieldMasks(fields.find((f) => f.key === 'customer.phone'), 'US')).toEqual([])
    expect(namespaceFields('customer', ['customer.phone'], fields).map((f) => f.key)).toEqual(['customer.vip', 'customer.birth'])
  })
  test('reads by field name or old key; writes only the field name', () => {
    const vip = fields[0] as FormField
    expect(readCustom({ 'customer.vip': 'sim' }, vip)).toBe('sim')
    expect(writeCustom({ 'customer.vip': 'sim', other: 1 }, [vip], { vip: 'não' })).toEqual({ vip: 'não', other: 1 })
    expect(writeCustom({ vip: 'sim' }, [vip], { vip: '' })).toBeNull()
  })
  test('required holds for select and date too (the app skips it there)', () => {
    expect(validateField(fields[0] as FormField, null)).toBe('required')
    const mileage = fields.find((f) => f.key === 'device.mileage') as FormField
    expect(validateField(mileage, 1.5)).toBe('number')
    expect(validateField(mileage, -1)).toBe('min')
    expect(validateField(mileage, 98000)).toBeNull()
    expect(validateField({ key: 'x.y', type: 'text', pattern: '^[A-Z]+$', minLength: 2 }, 'a')).toBe('minLength')
    expect(validateField({ key: 'x.y', type: 'text', pattern: '^[A-Z]+$' }, 'ab')).toBe('pattern')
  })
})

describe('customer list rules', () => {
  const people = [
    { id: '1', name: 'João Silva', phone: '(48) 98408-7801', email: null, taxId: null, address: null, open: 2, late: 1, owed: null },
    { id: '2', name: 'Ana', phone: '+5511900000001', email: 'ana@x.com', taxId: null, address: null, open: 1, late: 0, owed: null },
    { id: '3', name: '3M Peças', phone: null, email: null, taxId: null, address: null, open: 0, late: 0, owed: null },
    { id: '4', name: 'Álvaro', phone: null, email: null, taxId: null, address: null, open: 0, late: 0, owed: null },
  ]
  test('search ignores accents and compares phones by digits', () => {
    expect(customerMatches(people[0]!, 'joao')).toBe(true)
    expect(customerMatches(people[0]!, '984087')).toBe(true)
    expect(customerMatches(people[1]!, 'joao')).toBe(false)
  })
  test('groups by initial without accent, "#" last', () => {
    expect(groupByInitial(people).map((g) => g.initial)).toEqual(['A', 'J', '#'])
    expect(groupByInitial(people)[0]!.rows.map((r) => r.name)).toEqual(['Álvaro', 'Ana'])
  })
  test('late wins over open', () => {
    expect(badgeOf(people[0]!)).toEqual({ kind: 'late', count: 1 })
    expect(badgeOf(people[1]!)).toEqual({ kind: 'open', count: 1 })
    expect(badgeOf(people[2]!)).toBeNull()
  })
  test('"Cadastrar" from the search: digits become the phone; hidden for an existing name', () => {
    expect(draftFromSearch('(48) 9999-0000')).toEqual({ name: '', phone: '(48) 9999-0000' })
    expect(draftFromSearch('Bia')).toEqual({ name: 'Bia', phone: '' })
    expect(canOfferCreate(people, 'joão silva')).toBe(false)
    expect(canOfferCreate(people, 'João')).toBe(true)
  })
  test('repeated phone in any format, without the ninth digit', () => {
    expect(findByPhone(people, '4884087801', 'BR')?.id).toBe('1')
    expect(findByPhone(people, '11 90000-0001', 'BR')?.id).toBe('2')
    expect(findByPhone(people, '11 3333-0000', 'BR')).toBeNull()
  })
})

describe('device rules', () => {
  const devices: DeviceRow[] = [
    { id: 'a', name: 'Uno', serial: 'ABC-1D23', manufacturer: 'Fiat', category: 'Carro', status: null, photo: null, nextMaintenanceDate: null },
    { id: 'b', name: 'Uno', serial: 'XYZ9876', manufacturer: 'Fiat', category: 'Carro', status: null, photo: null, nextMaintenanceDate: null },
    { id: 'c', name: 'Ônix', serial: null, manufacturer: 'Chevrolet', category: null, status: null, photo: null, nextMaintenanceDate: null },
  ]
  test('plate from 3 characters, without hyphen or case', () => {
    expect(plateMatches(devices, 'ab')).toEqual([])
    expect(plateMatches(devices, 'abc1').map((d) => d.id)).toEqual(['a'])
    expect(plateMatches(devices, 'abc 1d23').map((d) => d.id)).toEqual(['a'])
  })
  test('device search by model, brand and serial, without accents', () => {
    expect(deviceMatches(devices[2]!, 'onix')).toBe(true)
    expect(deviceMatches(devices[0]!, 'abc1d23')).toBe(true)
    expect(deviceMatches(devices[0]!, 'chev')).toBe(false)
  })
  test('model suggestions by count, distinct, by model or brand', () => {
    expect(modelSuggestions(devices, 'fiat')).toEqual([{ name: 'Uno', manufacturer: 'Fiat', category: 'Carro', count: 2 }])
    expect(modelSuggestions(devices, '')).toEqual([])
  })
  test('serial: required only without model; pattern of the segment', () => {
    expect(serialError('', '')).toBe('required')
    expect(serialError('', 'Uno')).toBeNull()
    expect(serialError('abc1234', '', '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$')).toBeNull()
    expect(serialError('12', '', '^[A-Z]{3}')).toBe('pattern')
  })
  test('Brazilian plate with or without hyphen', () => {
    expect(isBrazilianPlate('ABC-1D23')).toBe(true)
    expect(isBrazilianPlate('abc1234')).toBe(true)
    expect(isBrazilianPlate('Uno 2015')).toBe(false)
  })
  test('six months ahead, last day of a shorter month', () => {
    expect(addMonths(new Date(2026, 7, 31), 6)).toEqual(new Date(2027, 1, 28))
    expect(addMonths(new Date(2026, 10, 3), 6)).toEqual(new Date(2027, 4, 3))
  })
})

describe('spreadsheet import', () => {
  test('CSV with semicolon, quotes and BOM', () => {
    expect(parseCsv('﻿Nome;Celular\n"Silva; João";(48) 98408-7801\n\nAna;')).toEqual([
      ['Nome', 'Celular'],
      ['Silva; João', '(48) 98408-7801'],
      ['Ana', ''],
    ])
    expect(parseCsv('a,b\n1,2')).toEqual([['a', 'b'], ['1', '2']])
  })
  test('guesses columns once each', () => {
    expect(guessFields(['Nome do cliente', 'WhatsApp', 'E-mail', 'Endereço', 'CPF', 'Obs', 'Telefone 2'])).toEqual(['name', 'phone', 'email', 'address', 'taxId', '', ''])
  })
  test('review: no name, bad CPF, phone of a customer, phone twice in the file', () => {
    const rows = [
      ['Rita', '(47) 90000-1101', ''],
      ['', '(47) 90000-1106', ''],
      ['Paulo', '', '111.111.111-11'],
      ['Ana 2', '11 90000-0001', ''],
      ['Rita F.', '47 90000-1101', ''],
    ]
    const review = reviewRows(rows, ['name', 'phone', 'taxId'], [{ name: 'Ana', phone: '+5511900000001' }], 'BR')
    expect(review.map((r) => r.state)).toEqual(['ok', 'noName', 'badTaxId', 'duplicate', 'repeated'])
    expect(review[3]!.clash).toBe('Ana')
    expect(review[4]!.clash).toBe('2')
    expect(importPayload(review)).toEqual([{ name: 'Rita', phone: '(47) 90000-1101' }])
  })
  test('XLSX: shared strings and inline cells of the first sheet', async () => {
    const xlsx = readFileSync(resolve(process.cwd(), 'e2e/fixtures/clientes.xlsx'))
    const rows = await parseXlsx(xlsx.buffer.slice(xlsx.byteOffset, xlsx.byteOffset + xlsx.byteLength))
    expect(rows[0]).toEqual(['Nome', 'Telefone', 'E-mail'])
    expect(rows[1]).toEqual(['Planilha Um', '(47) 90000-2201', 'um@exemplo.com'])
  })
})

describe('lista por Recentes', () => {
  test('última movimentação primeiro; sem data no fim, por nome', () => {
    const people = [
      { name: 'Bia', lastActivity: null },
      { name: 'Ana', lastActivity: '2026-11-01T10:00:00.000Z' },
      { name: 'Caio', lastActivity: '2026-11-09T08:00:00.000Z' },
      { name: 'Alex' },
      { name: 'Davi', lastActivity: '2026-11-01T10:00:00.000Z' },
    ]
    expect([...people].sort(byRecent).map((p) => p.name)).toEqual(['Caio', 'Ana', 'Davi', 'Alex', 'Bia'])
  })
})

describe('listas curtas da tela do cliente (customer.detail.devices, customer.detail.orders)', () => {
  const list = (n: number) => Array.from({ length: n }, (_, i) => ({ id: `d${i}`, name: `Carro ${i}`, serial: `ABC${String(i).padStart(4, '0')}` }))

  test('até 5 itens: tudo aparece e não tem "Ver todos"', () => {
    const view = shortList(list(5), false, '', deviceMatches)
    expect(view.shown).toHaveLength(5)
    expect(view.canOpen).toBe(false)
    expect(view.searchable).toBe(false)
  })

  test('mais de 5: mostra os 5 primeiros e abre o resto no lugar', () => {
    const items = list(8)
    const closed = shortList(items, false, '', deviceMatches)
    expect(closed.shown.map((d) => d.id)).toEqual(['d0', 'd1', 'd2', 'd3', 'd4'])
    expect(closed.canOpen).toBe(true)
    const open = shortList(items, true, '', deviceMatches)
    expect(open.shown).toHaveLength(8)
    expect(open.searchable).toBe(false)
  })

  test('busca só com a lista aberta e mais de 10 itens, pela placa', () => {
    const items = list(12)
    expect(shortList(items, false, 'ABC0011', deviceMatches).searchable).toBe(false)
    const open = shortList(items, true, 'abc-0011', deviceMatches)
    expect(open.searchable).toBe(true)
    expect(open.shown.map((d) => d.id)).toEqual(['d11'])
  })

  test('OS pelo número', () => {
    expect(orderNumberMatches({ number: 1234 }, 'OS 123')).toBe(true)
    expect(orderNumberMatches({ number: 1234 }, '99')).toBe(false)
    expect(orderNumberMatches({ number: 1234 }, 'abc')).toBe(false)
  })
})
