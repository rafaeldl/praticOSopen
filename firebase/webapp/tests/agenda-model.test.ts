import { describe, expect, test } from 'vitest'
import {
  addMonths,
  affectsCustomer,
  companyZone,
  firstDayOfWeek,
  fromWall,
  hourSpan,
  isDay,
  layoutColumn,
  localInput,
  monthGrid,
  nudge,
  parseStored,
  placeVisits,
  queryRange,
  slotAt,
  snapMinutes,
  step,
  targetInstant,
  storedText,
  today,
  wallOf,
  weekOf,
} from '@/lib/agenda/model'

const SP = 'America/Sao_Paulo'

describe('fuso da empresa', () => {
  test('pelo país, ou o do navegador quando ele é do mesmo país', () => {
    expect(companyZone('BR', 'Europe/Lisbon')).toBe(SP)
    expect(companyZone('BR', 'America/Manaus')).toBe('America/Manaus')
    expect(companyZone('PT', 'America/Sao_Paulo')).toBe('Europe/Lisbon')
    expect(companyZone('us', 'America/Chicago')).toBe('America/Chicago')
    expect(companyZone(null, 'Europe/Madrid')).toBe('Europe/Madrid')
  })

  test('hora de parede ida e volta, também na troca de horário de verão', () => {
    const at = fromWall('2031-03-10', 9, 30, SP)
    expect(at.toISOString()).toBe('2031-03-10T12:30:00.000Z')
    expect(wallOf(at, SP)).toMatchObject({ day: '2031-03-10', hour: 9, minute: 30 })
    // Lisbon moves to summer time on the last Sunday of March.
    expect(fromWall('2031-03-30', 12, 0, 'Europe/Lisbon').toISOString()).toBe('2031-03-30T11:00:00.000Z')
    expect(fromWall('2031-03-29', 12, 0, 'Europe/Lisbon').toISOString()).toBe('2031-03-29T12:00:00.000Z')
  })

  test('texto sem fuso (app) é hora da empresa; com fuso (API) é o instante', () => {
    expect(parseStored('2031-03-10T09:30:00.000', SP)?.toISOString()).toBe('2031-03-10T12:30:00.000Z')
    expect(parseStored('2031-03-10T09:30:00.123456', SP)?.toISOString()).toBe('2031-03-10T12:30:00.000Z')
    expect(parseStored('2031-03-10T12:30:00.000Z', SP)?.toISOString()).toBe('2031-03-10T12:30:00.000Z')
    expect(parseStored({ seconds: 1930000000 }, SP)?.getTime()).toBe(1930000000000)
    expect(parseStored('', SP)).toBeNull()
    expect(parseStored('amanhã', SP)).toBeNull()
  })

  test('"hoje" é o dia da empresa, não o do computador', () => {
    // 01:00 UTC is still the day before in São Paulo.
    expect(today(SP, new Date('2031-03-11T01:00:00Z'))).toBe('2031-03-10')
  })
})

describe('dias', () => {
  test('semana começa no dia do país', () => {
    expect(firstDayOfWeek('BR', 'pt-BR')).toBe(0)
    expect(firstDayOfWeek('ES', 'es-ES')).toBe(1)
    expect(weekOf('2031-03-12', 0)).toEqual(['2031-03-09', '2031-03-10', '2031-03-11', '2031-03-12', '2031-03-13', '2031-03-14', '2031-03-15'])
    expect(weekOf('2031-03-09', 1)[0]).toBe('2031-03-03')
  })

  test('mês mantém o dia com limite; semana anda 7 dias', () => {
    expect(addMonths('2031-10-31', 1)).toBe('2031-11-30')
    expect(addMonths('2031-01-31', -2)).toBe('2030-11-30')
    expect(step('week', '2031-03-30', 1)).toBe('2031-04-06')
    expect(step('day', '2031-03-01', -1)).toBe('2031-02-28')
  })

  test('grade do mês com 6 semanas e a semana que cruza o mês inteira', () => {
    const grid = monthGrid('2031-04-15', 0)
    expect(grid).toHaveLength(42)
    expect(grid[0]).toBe('2031-03-30')
    expect(grid).toContain('2031-05-03')
  })

  test('intervalo pedido ao servidor folga 14 h de cada lado', () => {
    expect(queryRange(['2031-03-10'], SP)).toEqual({ startDate: '2031-03-09T13:00:00.000Z', endDate: '2031-03-11T17:00:00.000Z' })
  })

  test('dia válido', () => {
    expect(isDay('2031-02-28')).toBe(true)
    expect(isDay('2031-02-30')).toBe(false)
    expect(isDay('ontem')).toBe(false)
  })
})

describe('visitas', () => {
  const items = [
    { id: 'a', at: '2031-03-10T00:00:00.000' },
    { id: 'b', at: '2031-03-10T14:00:00.000Z' },
    { id: 'c', at: '2031-03-10T08:00:00.000' },
    { id: 'd', at: '2031-03-11T02:00:00.000Z' },
    { id: 'e', at: null },
  ]

  test('cada uma no dia da empresa, com hora primeiro e "Dia todo" no fim', () => {
    const days = placeVisits(items, (item) => item.at, SP)
    expect(days.get('2031-03-10')?.map((v) => v.item.id)).toEqual(['c', 'b', 'd', 'a'])
    expect(days.get('2031-03-10')?.find((v) => v.item.id === 'a')?.allDay).toBe(true)
    expect(days.get('2031-03-10')?.find((v) => v.item.id === 'd')).toMatchObject({ hour: 23, minute: 0 })
  })

  test('sem useScheduling tudo é "Dia todo"', () => {
    const days = placeVisits(items, (item) => item.at, SP, false)
    expect([...days.values()].flat().every((v) => v.allDay)).toBe(true)
  })

  test('grade de 7 a 19, aumentada para caber toda visita com hora', () => {
    const days = placeVisits(items, (item) => item.at, SP)
    expect(hourSpan(days.get('2031-03-10') ?? [])).toEqual({ start: 7, end: 24 })
    expect(hourSpan([])).toEqual({ start: 7, end: 19 })
  })

  test('soltar e teclado: meia em meia hora, dia mantém a hora', () => {
    expect(snapMinutes(9 * 60 + 14)).toBe(9 * 60)
    expect(snapMinutes(9 * 60 + 16)).toBe(9 * 60 + 30)
    expect(snapMinutes(-20)).toBe(0)
    expect(snapMinutes(24 * 60)).toBe(23 * 60 + 30)
    expect(nudge({ day: '2031-03-10', minutes: 540 }, 'ArrowUp')).toEqual({ day: '2031-03-10', minutes: 510 })
    expect(nudge({ day: '2031-03-10', minutes: 540 }, 'ArrowRight')).toEqual({ day: '2031-03-11', minutes: 540 })
    expect(nudge({ day: '2031-03-10', minutes: 0 }, 'ArrowUp')).toEqual({ day: '2031-03-10', minutes: 0 })
    expect(nudge({ day: '2031-03-10', minutes: null }, 'ArrowDown')).toEqual({ day: '2031-03-10', minutes: 480 })
    expect(targetInstant({ day: '2031-03-10', minutes: 570 }, SP).toISOString()).toBe('2031-03-10T12:30:00.000Z')
    expect(targetInstant({ day: '2031-03-10', minutes: null }, SP).toISOString()).toBe('2031-03-10T03:00:00.000Z')
  })

  test('grava como o app: hora da empresa sem fuso; 21h do último dia do mês e "Dia todo"', () => {
    expect(storedText({ day: '2031-03-31', minutes: 21 * 60 })).toBe('2031-03-31T21:00:00.000')
    expect(storedText({ day: '2031-03-10', minutes: null })).toBe('2031-03-10T00:00:00.000')
    expect(storedText({ day: '2031-03-10', minutes: 9 * 60 + 30 })).toBe('2031-03-10T09:30:00.000')
    // Read back on the same day and time.
    const days = placeVisits([{ at: storedText({ day: '2031-03-31', minutes: 21 * 60 }) }], (item) => item.at, SP)
    expect(days.get('2031-03-31')?.[0]).toMatchObject({ hour: 21, allDay: false })
  })

  test('pergunta antes só quando o cliente já contava com a data', () => {
    expect(affectsCustomer({ status: 'approved', customer: { id: 'c1' } }, true)).toBe(true)
    expect(affectsCustomer({ status: 'approved', customer: { id: 'c1' } }, false)).toBe(false)
    expect(affectsCustomer({ status: 'approved', customer: null }, true)).toBe(false)
    expect(affectsCustomer({ status: 'done', customer: { id: 'c1' } }, true)).toBe(false)
  })

  test('visitas que se cruzam dividem a largura; as outras ficam inteiras', () => {
    const days = placeVisits(
      [
        { id: 'a', at: '2031-03-10T09:00:00.000' },
        { id: 'b', at: '2031-03-10T09:30:00.000' },
        { id: 'c', at: '2031-03-10T11:00:00.000' },
        { id: 'd', at: '2031-03-10T00:00:00.000' },
      ],
      (item) => item.at,
      SP,
    )
    const layout = layoutColumn(days.get('2031-03-10') ?? [])
    const of = (id: string) => [...layout.entries()].find(([visit]) => visit.item.id === id)?.[1]
    expect(of('a')).toEqual({ lane: 0, lanes: 2 })
    expect(of('b')).toEqual({ lane: 1, lanes: 2 })
    expect(of('c')).toEqual({ lane: 0, lanes: 1 })
    expect(of('d')).toBeUndefined()
  })
})

describe('clicar num horário livre (agenda.slot-new-order)', () => {
  test('o clique cai na meia hora sob o ponteiro, dentro do dia', () => {
    expect(slotAt(14 * 60 + 20)).toBe(14 * 60)
    expect(slotAt(14 * 60 + 30)).toBe(14 * 60 + 30)
    expect(slotAt(14 * 60 + 59)).toBe(14 * 60 + 30)
    expect(slotAt(-5)).toBe(0)
    expect(slotAt(24 * 60 + 10)).toBe(23 * 60 + 30)
  })

  test('vira o valor do campo de data e hora da Nova OS; Dia todo é meia-noite', () => {
    expect(localInput({ day: '2031-03-12', minutes: 9 * 60 + 30 })).toBe('2031-03-12T09:30')
    expect(localInput({ day: '2031-03-12', minutes: null })).toBe('2031-03-12T00:00')
  })
})
