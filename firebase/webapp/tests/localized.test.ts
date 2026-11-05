import { describe, expect, it } from 'vitest'
import { localizedMap, localizedNames, localizedText, pickLocalized } from '@/lib/localized'
import { localName, toSegmentOption } from '@/lib/settings/model'
import { subspecialtyName, toSegment } from '@/lib/onboarding/model'

const MAP = { 'pt-BR': 'Oficina Mecânica', 'en-US': 'Auto Repair Shop', 'es-ES': 'Taller Mecánico' }

describe('localized names from segments/*', () => {
  it('reads a map, the same map as JSON text and a plain text', () => {
    expect(localizedMap(MAP)).toEqual(MAP)
    expect(localizedMap(JSON.stringify(MAP))).toEqual(MAP)
    expect(localizedMap('Lava Car')).toEqual({ 'pt-BR': 'Lava Car' })
    expect(localizedMap('{não é json')).toEqual({ 'pt-BR': '{não é json' })
    expect(localizedMap(null)).toEqual({})
    expect(localizedMap(42)).toEqual({})
  })

  it('picks the locale, then the language, then pt-BR, then the first key', () => {
    expect(pickLocalized(MAP, 'en-US')).toBe('Auto Repair Shop')
    expect(pickLocalized(MAP, 'es')).toBe('Taller Mecánico')
    expect(pickLocalized({ 'pt-BR': 'Funilaria' }, 'en-US')).toBe('Funilaria')
    expect(pickLocalized({ fr: 'Carrosserie' }, 'en-US')).toBe('Carrosserie')
    expect(pickLocalized({}, 'pt-BR')).toBeNull()
    expect(localizedText(JSON.stringify(MAP), 'pt-BR', 'id')).toBe('Oficina Mecânica')
    expect(localizedText(undefined, 'pt-BR', 'id')).toBe('id')
  })

  it('nameI18n wins over name', () => {
    expect(localizedNames('Lava Car', { 'en-US': 'Car Wash' })).toEqual({ 'pt-BR': 'Lava Car', 'en-US': 'Car Wash' })
  })

  it('settings never show an object or JSON for a subspecialty (Especialidades)', () => {
    const segment = toSegmentOption('automotive', {
      name: 'Automotivo',
      subspecialties: [
        { id: 'mechanic', name: MAP },
        { id: 'wash', name: JSON.stringify({ 'pt-BR': 'Lava Car', 'en-US': 'Car Wash' }) },
        { id: 'body', name: 'Funilaria e Pintura' },
      ],
    })
    const shown = segment.subspecialties.map((sub) => localName(sub, 'pt'))
    expect(shown).toEqual(['Oficina Mecânica', 'Lava Car', 'Funilaria e Pintura'])
    expect(segment.subspecialties.map((sub) => localName(sub, 'en'))).toEqual(['Auto Repair Shop', 'Car Wash', 'Funilaria e Pintura'])
    for (const text of shown) expect(typeof text).toBe('string')
    expect(segment.subspecialties.every((sub) => typeof sub.name === 'string')).toBe(true)
  })

  it('a segment name stored as a map shows in the language', () => {
    const segment = toSegmentOption('automotive', { name: MAP })
    expect(segment.name).toBe('Oficina Mecânica')
    expect(localName(segment, 'es')).toBe('Taller Mecánico')
  })

  it('onboarding reads the JSON shape too', () => {
    const segment = toSegment('automotive', { name: JSON.stringify(MAP), subspecialties: [{ id: 'wash', name: JSON.stringify(MAP) }] })
    expect(segment.name).toBe('Oficina Mecânica')
    expect(subspecialtyName(segment.subspecialties[0]!, 'en-US')).toBe('Auto Repair Shop')
  })
})
