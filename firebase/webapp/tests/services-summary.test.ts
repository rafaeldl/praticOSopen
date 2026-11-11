// One line of the orders list: the same service shows once, with how many times
// ("5× pintura"). Same cases as test/utils/order_items_test.dart in the app.
import { describe, expect, it } from 'vitest'
import { normalizeOrder, servicesSummary } from '@/lib/orders/model'

const order = (names: (string | null)[]) =>
  normalizeOrder('o1', { services: names.map((name) => ({ service: name === null ? null : { id: name, name }, description: name === null ? 'Alinhamento' : null, value: 100 })) }, true)

describe('servicesSummary', () => {
  it('the same service shows once, with how many times', () => {
    expect(servicesSummary(order(['pintura', 'pintura', 'Pintura ', 'polimento +higienização', 'pintura']))).toBe('4× pintura, polimento +higienização')
  })
  it('different services keep their order; empty names are skipped', () => {
    expect(servicesSummary(order(['Troca de óleo', null, '  ']))).toBe('Troca de óleo, Alinhamento')
    expect(servicesSummary(order([]))).toBe('')
  })
})
