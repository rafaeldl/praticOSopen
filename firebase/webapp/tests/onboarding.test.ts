import { describe, expect, it } from 'vitest'
import {
  activeSegments,
  businessFields,
  businessName,
  countryFor,
  localeTag,
  nameMissing,
  orderedPick,
  pickName,
  segmentName,
  subspecialtyName,
  termsFor,
  toSegment,
} from '@/lib/onboarding/model'
import { initials } from '@/lib/initials'

const automotive = toSegment('automotive', {
  name: 'Mecânica',
  nameI18n: { 'pt-BR': 'Mecânica', 'en-US': 'Auto repair', 'es-ES': 'Mecánica' },
  icon: '🚗',
  fieldService: false,
  subspecialties: [
    { id: 'mechanical', name: { 'pt-BR': 'Mecânica geral', 'en-US': 'General' } },
    { id: 'bodywork', name: 'Funilaria' },
    { id: 'bikes', name: 'Motos', nameI18n: { 'en-US': 'Motorcycles' } },
    { name: 'sem id' },
  ],
  defaultTermsOfService: { 'pt-BR': 'Garantia de 90 dias', 'en-US': '90-day warranty' },
})

describe('first access (onboarding_service.dart)', () => {
  it('reads the segment like OnboardingSegment.fromMap', () => {
    expect(automotive.subspecialties.map((sub) => sub.id)).toEqual(['mechanical', 'bodywork', 'bikes'])
    expect(subspecialtyName(automotive.subspecialties[2]!, 'en-US')).toBe('Motorcycles')
    expect(automotive.subspecialties[1]!.names).toEqual({ 'pt-BR': 'Funilaria' })
    expect(automotive.fieldServiceDefault).toBe(false)
    expect(automotive.useFinancialDefault).toBe(true)
    expect(toSegment('x', {}).name).toBe('x')
  })

  it('lists only active segments, by name', () => {
    const list = activeSegments([
      { id: 'b', data: { name: 'Refrigeração', active: true } },
      { id: 'off', data: { name: 'Antigo', active: false } },
      { id: 'a', data: { name: 'Eletrônica', active: true } },
      { id: 'none', data: { name: 'Sem campo' } },
    ])
    expect(list.map((segment) => segment.id)).toEqual(['a', 'b'])
  })

  it('names by full tag, then language, then en-US', () => {
    expect(segmentName(automotive, 'en-US')).toBe('Auto repair')
    expect(pickName({ 'es-AR': 'Uno', 'en-US': 'One' }, 'es-ES')).toBe('Uno')
    expect(pickName({ 'en-US': 'One' }, 'pt-BR')).toBe('One')
    expect(pickName({}, 'pt-BR')).toBeNull()
  })

  it('language tags and country of the new company', () => {
    expect(localeTag('pt')).toBe('pt-BR')
    expect(localeTag('es')).toBe('es-ES')
    expect(localeTag('fr')).toBe('en-US')
    expect(countryFor(['pt-PT', 'pt'], 'pt')).toBe('PT')
    expect(countryFor(['es'], 'es')).toBe('ES')
    expect(countryFor([], 'pt')).toBe('BR')
    expect(termsFor(automotive, 'es-ES')).toBe('Garantia de 90 dias')
  })

  it('blank name falls back to the person, and is only missing without one', () => {
    expect(businessName('  ', 'Fábio Dono')).toBe('Fábio Dono')
    expect(businessName(' Oficina ', 'Fábio')).toBe('Oficina')
    expect(nameMissing('', null)).toBe(true)
    expect(nameMissing('', 'Fábio')).toBe(false)
  })

  it('writes what applyBusiness writes', () => {
    expect(businessFields({ segment: automotive, subspecialties: [], name: '', phone: ' ', useFinancial: false }, 'Fábio')).toEqual({
      name: 'Fábio',
      segment: 'automotive',
      subspecialties: null,
      fieldService: false,
      useScheduling: true,
      useFinancial: false,
    })
    expect(businessFields({ segment: automotive, subspecialties: ['bodywork'], name: 'Oficina', phone: '(11) 3333-4444', useFinancial: true }, null)).toMatchObject({
      phone: '(11) 3333-4444',
      subspecialties: ['bodywork'],
    })
  })

  it('initials of the company: first and last words, without connectors', () => {
    expect(initials('Oficina do Zé')).toBe('OZ')
    expect(initials('  refrigeração   silva e filhos ')).toBe('RF')
    expect(initials('Ana')).toBe('A')
    expect(initials('de da')).toBe('')
    expect(initials(null)).toBe('')
    expect(initials('Élio & Cia')).toBe('ÉC')
  })

  it('keeps the segment order of the picked specialties', () => {
    expect(orderedPick(automotive, new Set(['bodywork', 'mechanical']))).toEqual(['mechanical', 'bodywork'])
  })
})
