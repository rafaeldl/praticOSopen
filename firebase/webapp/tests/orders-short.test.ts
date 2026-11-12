import { beforeEach, describe, expect, test, vi } from 'vitest'

// "61 Ordem de Serviço" on the Financeiro: a count needs the segment's plural word.
const labels: Record<string, string> = {}
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn() }))
vi.mock('../src/lib/segments', async (original) => ({
  ...(await original<typeof import('../src/lib/segments')>()),
  segmentLabels: () => labels,
}))

const { ordersShort } = await import('../src/lib/orders/text')

describe('ordersShort', () => {
  beforeEach(() => {
    for (const key of Object.keys(labels)) delete labels[key]
  })

  test('segment words: singular for 0 and 1, plural above', () => {
    labels['service_order._entity'] = 'Ordem de Serviço'
    labels['service_order._entity_plural'] = 'Ordens de Serviço'
    expect(ordersShort(0)).toBe('Ordem de Serviço')
    expect(ordersShort(1)).toBe('Ordem de Serviço')
    expect(ordersShort(61)).toBe('Ordens de Serviço')
  })

  test('without a plural word the singular stays (never an empty text)', () => {
    labels['service_order._entity'] = 'Contrato'
    expect(ordersShort(3)).toBe('Contrato')
  })
})
