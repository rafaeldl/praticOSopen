// Dates read and shown in the company's zone, even when the computer is in
// another one (revisão do #521, M1, M2 e B2). Vitest runs in São Paulo; the
// company here is in Manaus (one hour behind).
import { afterEach, describe, expect, test } from 'vitest'
import { formatDayMonth, formatTime, toIsoDay } from '@/lib/format'
import { hasTime, isoOf, relativeDay } from '@/lib/orders/model'
import { dayKey, isOverdue } from '@/lib/rules/order-rules'
import { setZone, wallText } from '@/lib/zone'

afterEach(() => setZone(null))

describe('fuso da empresa fora do fuso do computador', () => {
  test('texto sem fuso do app é a hora da empresa', () => {
    setZone('America/Manaus')
    expect(isoOf('2031-03-10T09:30:00.000')).toBe('2031-03-10T13:30:00.000Z')
    expect(isoOf('2031-03-10T09:30:00.000Z')).toBe('2031-03-10T09:30:00.000Z')
  })

  test('hora, dia e "Dia todo" no fuso da empresa', () => {
    setZone('America/Manaus')
    expect(formatTime('2031-03-10T13:30:00.000Z', 'BR')).toBe('09:30')
    // 23:30 in Manaus is already the next day in São Paulo.
    expect(formatDayMonth('2031-03-11T03:30:00.000Z', 'BR')).toBe('10/03')
    expect(dayKey(new Date('2031-03-11T03:30:00.000Z'))).toBe(20310310)
    expect(toIsoDay(new Date('2031-03-11T03:30:00.000Z'))).toBe('2031-03-10')
    // Midnight in Manaus is "only the day".
    expect(hasTime('2031-03-10T04:00:00.000Z')).toBe(false)
    expect(hasTime('2031-03-10T03:00:00.000Z')).toBe(true)
    expect(relativeDay('2031-03-11T03:30:00.000Z', new Date('2031-03-10T15:00:00.000Z'))).toBe('today')
    expect(isOverdue('approved', '2031-03-10T04:30:00.000Z', new Date('2031-03-11T03:30:00.000Z'))).toBe(false)
  })

  test('o que o web grava: hora da empresa sem fuso, como o app', () => {
    setZone('America/Manaus')
    expect(wallText(new Date('2031-03-10T13:30:00.000Z'))).toBe('2031-03-10T09:30:00.000')
    setZone(null)
    expect(wallText(new Date('2031-04-01T00:00:00.000Z'))).toBe('2031-03-31T21:00:00.000')
  })
})
