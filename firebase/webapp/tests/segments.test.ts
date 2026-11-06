import { describe, expect, test, vi } from 'vitest'
import { buildLabels, fieldLabel, productWord, resolveLabel } from '../src/lib/segments'
import type { MessageKey } from '../src/generated/message-keys'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn() }))

const translate = (key: MessageKey) => `i18n:${key}`

describe('label priority', () => {
  test('segment label first', () => {
    expect(resolveLabel('device._entity', { 'device._entity': 'Veículo' }, translate)).toBe('Veículo')
  })

  test('then i18n', () => {
    expect(resolveLabel('device._entity', {}, translate)).toBe('i18n:device')
  })

  test('then English, then the key', () => {
    expect(resolveLabel('other.key', {}, translate, 'Other')).toBe('Other')
    expect(resolveLabel('other.key', {}, translate)).toBe('other.key')
  })
})

describe('labels of a segment', () => {
  test('field label falls back like CustomField.getLabel', () => {
    const field = { key: 'k', labels: { 'pt-BR': 'Veículo', 'en-US': 'Vehicle' } }
    expect(fieldLabel(field, 'en-US')).toBe('Vehicle')
    expect(fieldLabel(field, 'en')).toBe('Vehicle')
    expect(fieldLabel(field, 'es')).toBe('Veículo')
    expect(fieldLabel({ key: 'k' }, 'pt')).toBeNull()
  })

  test('the segment overrides global', () => {
    const global = { customFields: [{ key: 'a', labels: { 'pt-BR': 'Global' } }, { key: 'b', labels: { 'pt-BR': 'Só global' } }] }
    const segment = { customFields: [{ key: 'a', labels: { 'pt-BR': 'Segmento' } }] }
    expect(buildLabels([global, segment], 'pt')).toEqual({ a: 'Segmento', b: 'Só global' })
  })

  test('missing documents are fine', () => {
    expect(buildLabels([null, undefined, {}], 'pt')).toEqual({})
  })
})

describe('product word in order texts', () => {
  test('the segment name, lower case, or the workshop word', () => {
    expect(productWord('peça', { 'product._entity': 'Licença' })).toBe('licença')
    expect(productWord('peça', {})).toBe('peça')
  })
})
