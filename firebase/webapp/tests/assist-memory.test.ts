// The assistant corrects what it put itself and remembers what was said (issue #631).
import { describe, expect, it } from 'vitest'
import { assistContext, customerStep, forget, localMinute, normalizeDraft, remember, replacedDevice, savedOrderFill } from '@/lib/orders/assist-draft'

const draft = (over: Record<string, unknown>) => normalizeDraft(over)
const base = {
  hasCustomer: false,
  devices: [] as { id?: string | null; serial?: string | null }[],
  canRegisterCustomers: true,
  canRegisterDevices: true,
  hasRequestField: true,
  request: '',
}

describe('history of the screen', () => {
  it('keeps the last 3 messages, up to 500 characters each', () => {
    let history: string[] = []
    for (const said of ['a', 'b', '  ', 'c', 'd']) history = remember(history, said)
    expect(history).toEqual(['b', 'c', 'd'])
    expect(remember([], 'x'.repeat(600))[0]).toHaveLength(500)
  })

  it('Desfazer takes the undone message out', () => {
    expect(forget(['a', 'b', 'c'], 'b')).toEqual(['a', 'c'])
    expect(forget(['a', 'b'], 'z')).toEqual(['a', 'b'])
    expect(forget(['a'], '')).toEqual(['a'])
  })
})

describe('context sent with the message', () => {
  it('never the customer name; vehicles with name and plate; who filled each field', () => {
    const context = assistContext({
      customer: { chosen: true, fromAi: true },
      devices: [{ name: 'Gol', serial: 'ABC1234', fromAi: true }, { name: ' ', serial: null, fromAi: false }],
      request: { text: ' Barulho ', fromAi: false },
      due: { date: '2026-11-09T18:00', fromAi: true },
      pending: ['customer'],
    })
    expect(context).toEqual({
      customer: { chosen: true, fromAi: true },
      devices: [{ name: 'Gol', serial: 'ABC1234', fromAi: true }, { fromAi: false }],
      request: { text: 'Barulho', fromAi: false },
      due: { date: '2026-11-09T18:00', fromAi: true },
      pending: ['customer'],
    })
    expect(JSON.stringify(context)).not.toContain('name":"Juliana')
  })

  it('leaves out what the order does not have', () => {
    const context = assistContext({ customer: { chosen: false, fromAi: false }, devices: [], request: { text: '', fromAi: false }, due: { date: '', fromAi: false }, pending: [] })
    expect(context).toEqual({ customer: { chosen: false, fromAi: false } })
  })

  it('a saved date goes as the local minute the screen shows', () => {
    const local = new Date(2026, 10, 9, 18, 0)
    expect(localMinute(local.toISOString())).toBe('2026-11-09T18:00')
    expect(localMinute(null)).toBe('')
  })
})

describe('correcting what the assistant put', () => {
  it('replaces only a vehicle the assistant put', () => {
    const d = draft({ device: { match: null, guess: { serial: 'ABC1D23' }, alternatives: [], replaces: 0 } })
    expect(replacedDevice(d, [{ fromAi: true }])).toBe(0)
    expect(replacedDevice(d, [{ fromAi: false }])).toBeNull()
    expect(replacedDevice(draft({ device: { match: null, guess: { serial: 'X' }, alternatives: [] } }), [{ fromAi: true }])).toBeNull()
  })

  it('a customer the assistant put counts as none (the caller passes hasCustomer false)', () => {
    const d = draft({ customer: { match: { id: 'c2', name: 'Pedro' }, guess: { name: 'Pedro' }, alternatives: [] } })
    expect(customerStep(d, { hasCustomer: false, isNew: true, canRegister: true }).kind).toBe('match')
    expect(customerStep(d, { hasCustomer: true, isNew: true, canRegister: true }).kind).toBe('none')
  })

  it('rewrites the request only when it is still the assistant one', () => {
    const d = draft({ notes: 'Barulho no freio' })
    expect(savedOrderFill(d, { ...base, request: 'Barulho na suspensão', requestFromAi: true }).request).toBe('Barulho no freio')
    expect(savedOrderFill(d, { ...base, request: 'Barulho na suspensão' }).request).toBeNull()
    expect(savedOrderFill(d, { ...base, request: 'Barulho no freio', requestFromAi: true }).request).toBeNull()
  })
})
