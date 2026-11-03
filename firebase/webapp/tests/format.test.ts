import { describe, expect, test } from 'vitest'
import {
  currencySymbol,
  formatDate,
  formatDateLong,
  formatDateTime,
  formatMoney,
  formatMoneyInput,
  formatNumber,
  formatPercent,
  fromIsoDay,
  moneyDigits,
  parseMoney,
  toIsoDay,
} from '../src/lib/format'

// Intl uses narrow and non-breaking spaces depending on the ICU version.
const plain = (text: string) => text.replace(/[  ]/g, ' ')

describe('formats by company country, never by language', () => {
  test.each([
    ['BR', 'R$ 1.234,56'],
    ['US', '$1,234.56'],
    ['ES', '1234,56 €'],
    ['PT', '1234,56 €'],
    ['GB', '£1,234.56'],
    ['CL', '$1.235'],
  ])('%s money', (country, expected) => {
    expect(plain(formatMoney(1234.56, country))).toBe(expected)
  })

  test('unknown or missing country falls back to Brazil', () => {
    expect(plain(formatMoney(10, 'ZZ'))).toBe('R$ 10,00')
    expect(plain(formatMoney(10))).toBe('R$ 10,00')
    expect(plain(formatMoney(10, 'br'))).toBe('R$ 10,00')
  })

  test('nothing to show stays empty, it does not become zero', () => {
    expect(formatMoney(null, 'BR')).toBe('')
    expect(formatNumber(undefined, 'BR')).toBe('')
    expect(formatDate('not a date', 'BR')).toBe('')
    expect(formatDate(null, 'BR')).toBe('')
  })

  test('numbers', () => {
    expect(formatNumber(1234.5, 'BR')).toBe('1.234,5')
    expect(formatNumber(1234.5, 'US')).toBe('1,234.5')
  })

  test('percent takes the value as shown, 15.5 is 15,5%', () => {
    expect(formatPercent(15.5, 'BR')).toBe('15,5%')
    expect(formatPercent(15.5, 'US')).toBe('15.5%')
  })

  test('dates', () => {
    const day = new Date(2026, 0, 9, 14, 30)
    expect(formatDate(day, 'BR')).toBe('09/01/2026')
    expect(formatDate(day, 'US')).toBe('01/09/2026')
    expect(formatDateLong(day, 'BR')).toBe('9 de janeiro de 2026')
    expect(formatDateLong(day, 'US')).toBe('January 9, 2026')
    expect(plain(formatDateTime(day, 'BR'))).toBe('09/01/2026, 14:30')
  })

  test('symbol and decimal places', () => {
    expect(currencySymbol('BR')).toBe('R$')
    expect(currencySymbol('ES')).toBe('€')
    expect(moneyDigits('BR')).toBe(2)
    expect(moneyDigits('CL')).toBe(0)
  })
})

describe('parseMoney reads what was typed', () => {
  test.each([
    ['150', 'BR', 150],
    ['100', 'BR', 100],
    ['90', 'US', 90],
    ['150,5', 'BR', 150.5],
    ['150,50', 'BR', 150.5],
    ['1.500', 'BR', 1500],
    ['1.500,00', 'BR', 1500],
    ['1.234.567,89', 'BR', 1234567.89],
    ['12.50', 'BR', 12.5],
    ['R$ 1.234,56', 'BR', 1234.56],
    ['1,500', 'US', 1500],
    ['1,500.75', 'US', 1500.75],
    ['12,50', 'US', 12.5],
    ['1.250', 'US', 1.25],
    ['1 234,50', 'PT', 1234.5],
    ['1000', 'CL', 1000],
    ['0,99', 'BR', 0.99],
    [',5', 'BR', 0.5],
    ['-10,00', 'BR', -10],
  ])('%s in %s is %d', (text, country, value) => {
    expect(parseMoney(text, country)).toBe(value)
  })

  test.each(['', 'abc', '.', 'R$'])('"%s" is not a number', (text) => {
    expect(parseMoney(text, 'BR')).toBeNull()
  })

  test('every whole amount survives a round trip through the field', () => {
    for (const value of [0, 1, 90, 100, 150, 999, 1000, 1500, 12345]) {
      expect(parseMoney(formatMoneyInput(value, 'BR'), 'BR')).toBe(value)
    }
  })
})

describe('calendar day', () => {
  test('stays the same day in any time zone', () => {
    const day = fromIsoDay('2026-11-02') as Date
    expect(day.getDate()).toBe(2)
    expect(toIsoDay(day)).toBe('2026-11-02')
  })

  test('rejects what is not a day', () => {
    expect(fromIsoDay('02/11/2026')).toBeNull()
    expect(fromIsoDay(null)).toBeNull()
  })
})
