import { describe, expect, test, vi } from 'vitest'
import { legacyRequest, readRequest, REQUEST_KEY, requestField, withRequest } from '../src/lib/orders/request'
import type { FormField } from '../src/lib/segment-fields'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn() }))

const field: FormField = { key: REQUEST_KEY, type: 'textarea', labels: { 'pt-BR': 'Observação' } }
const other: FormField = { key: 'service_order.mileageIn', type: 'number' }

describe('the segment request field (order.request.edit)', () => {
  test('found only when the segment has service_order.observation', () => {
    expect(requestField([other, field])).toBe(field)
    expect(requestField([other])).toBeUndefined()
  })

  test('reads the field name, then the old full key, like customFieldValue', () => {
    expect(readRequest({ observation: '  barulho  ' }, field)).toBe('barulho')
    expect(readRequest({ [REQUEST_KEY]: 'antigo' }, field)).toBe('antigo')
    expect(readRequest(undefined, field)).toBe('')
    expect(readRequest({ observation: 12 }, field)).toBe('12')
  })

  test('writes like applyCustomFieldValue: by field name, old key dropped, other fields kept', () => {
    expect(withRequest({ mileageIn: 10, [REQUEST_KEY]: 'velho' }, field, ' freio ')).toEqual({ mileageIn: 10, observation: 'freio' })
    expect(withRequest(null, field, 'freio')).toEqual({ observation: 'freio' })
  })

  test('empty text takes the field out, and an empty map is saved as null', () => {
    expect(withRequest({ observation: 'x', mileageIn: 1 }, field, '  ')).toEqual({ mileageIn: 1 })
    expect(withRequest({ observation: 'x' }, field, '')).toBeNull()
  })
})

describe('requests saved as a comment by the old web Nova OS', () => {
  const order = { createdAt: '2026-11-01T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' } }
  const old = { text: 'Barulho ao frear', source: 'web', isInternal: true, author: { userId: 'u1' }, createdAt: '2026-11-01T10:00:02.000Z' }

  test('the first comment, internal, from the web, by who created the order, right after it', () => {
    expect(legacyRequest(order, [old])).toBe('Barulho ao frear')
  })

  test('only the earliest comment counts', () => {
    const earlier = { ...old, text: 'Outro', source: 'app', createdAt: '2026-11-01T10:00:01.000Z' }
    expect(legacyRequest(order, [old, earlier])).toBe('')
  })

  test('a comment written later, by someone else, from the app or visible to the customer is not the request', () => {
    expect(legacyRequest(order, [{ ...old, createdAt: '2026-11-01T11:00:00.000Z' }])).toBe('')
    expect(legacyRequest(order, [{ ...old, author: { userId: 'u2' } }])).toBe('')
    expect(legacyRequest(order, [{ ...old, source: 'app' }])).toBe('')
    expect(legacyRequest(order, [{ ...old, isInternal: false }])).toBe('')
    expect(legacyRequest(order, [{ ...old, deleted: true }])).toBe('')
  })

  test('nothing to read is fine', () => {
    expect(legacyRequest(order, [])).toBe('')
    expect(legacyRequest({}, [old])).toBe('')
  })
})
