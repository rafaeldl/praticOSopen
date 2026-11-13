import { beforeEach, describe, expect, test } from 'vitest'
import { visibleNav } from '../src/navigation'
import { nfseOnFor, recordNfseAvailability } from '../src/lib/nfse/availability'

const everyone = () => true
const names = (nfse: boolean) => visibleNav(everyone, { nfse }).map((entry) => entry.name)

describe('Notas fiscais no menu', () => {
  beforeEach(() => recordNfseAvailability(null, false))

  test('só aparece com a nota ligada na empresa', () => {
    expect(names(false)).not.toContain('invoices')
    expect(names(true)).toContain('invoices')
    // The other entries do not depend on it.
    expect(names(false)).toEqual(names(true).filter((name) => name !== 'invoices'))
  })

  test('sem permissão não aparece nem com a nota ligada', () => {
    const list = visibleNav((anyOf) => !anyOf.includes('chargeOrder'), { nfse: true }).map((entry) => entry.name)
    expect(list).not.toContain('invoices')
  })

  test('vale para a empresa lida: outra empresa ou leitura ainda não feita esconde', () => {
    expect(nfseOnFor('a')).toBe(false)
    recordNfseAvailability('a', true)
    expect(nfseOnFor('a')).toBe(true)
    expect(nfseOnFor('b')).toBe(false)
    expect(nfseOnFor(null)).toBe(false)
    recordNfseAvailability('a', false)
    expect(nfseOnFor('a')).toBe(false)
  })
})
