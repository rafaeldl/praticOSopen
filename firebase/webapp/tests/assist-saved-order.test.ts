// The assistant on an order already saved (issue #630): vehicle, customer and
// request, with the app's rules for a saved order.
import { describe, expect, it } from 'vitest'
import { normalizeDraft, savedOrderFill } from '@/lib/orders/assist-draft'

const draft = (over: Record<string, unknown>) => normalizeDraft(over)
const base = {
  hasCustomer: false,
  devices: [] as { id?: string | null; serial?: string | null }[],
  canRegisterCustomers: true,
  canRegisterDevices: true,
  hasRequestField: true,
  request: '',
}

describe('order.ai on a saved order', () => {
  it('puts a registered vehicle found by the plate', () => {
    const fill = savedOrderFill(draft({ device: { match: { id: 'd1', name: 'Gol', serial: 'ABC1234' }, guess: null, alternatives: [] } }), base)
    expect(fill.device).toEqual({ kind: 'match', device: { id: 'd1', name: 'Gol', serial: 'ABC1234' } })
  })

  it('does not add a vehicle the order already has', () => {
    const fill = savedOrderFill(draft({ device: { match: { id: 'd1', name: 'Gol' }, guess: null, alternatives: [] } }), { ...base, devices: [{ id: 'd1' }] })
    expect(fill.device.kind).toBe('none')
  })

  it('an unknown plate asks (one tap registers), never registers on its own', () => {
    const fill = savedOrderFill(draft({ device: { match: null, guess: { serial: 'xyz9z99' }, alternatives: [] } }), base)
    expect(fill.device).toMatchObject({ kind: 'ask', label: 'XYZ9Z99', device: { serial: 'XYZ9Z99' } })
  })

  it('a known plate already in the order does nothing', () => {
    const fill = savedOrderFill(draft({ device: { match: null, guess: { serial: 'ABC-1234' }, alternatives: [] } }), { ...base, devices: [{ id: 'd1', serial: 'abc1234' }] })
    expect(fill.device.kind).toBe('none')
  })

  it('customer only when the order has none; a new name asks', () => {
    const match = draft({ customer: { match: { id: 'c1', name: 'Ana' }, guess: null, alternatives: [] } })
    expect(savedOrderFill(match, base).customer).toEqual({ kind: 'match', customer: { id: 'c1', name: 'Ana' } })
    expect(savedOrderFill(match, { ...base, hasCustomer: true }).customer.kind).toBe('none')
    const unknown = draft({ customer: { match: null, guess: { name: 'Juliana' }, alternatives: [] } })
    expect(savedOrderFill(unknown, base).customer).toMatchObject({ kind: 'ask', name: 'Juliana', options: [] })
  })

  it('request only into a blank field of the segment', () => {
    const said = draft({ notes: ' Barulho no freio ' })
    expect(savedOrderFill(said, base).request).toBe('Barulho no freio')
    expect(savedOrderFill(said, { ...base, request: 'Revisão' }).request).toBeNull()
    expect(savedOrderFill(said, { ...base, hasRequestField: false }).request).toBeNull()
    expect(savedOrderFill(draft({}), base).request).toBeNull()
  })
})
