import { describe, expect, test } from 'vitest'
import { formatPhone } from '../src/lib/phone'

describe('formatPhone (usuarios-pr515 #16)', () => {
  test.each([
    ['+5511990000001', '(11) 99000-0001'],
    ['+551133334444', '(11) 3333-4444'],
    ['5511990000001', '(11) 99000-0001'],
  ])('%s reads as %s', (raw, shown) => {
    expect(formatPhone(raw)).toBe(shown)
  })

  test('another country or an odd number is shown as saved', () => {
    expect(formatPhone('+14155550100')).toBe('+14155550100')
    expect(formatPhone('1234')).toBe('1234')
    expect(formatPhone(null)).toBe('')
  })
})
