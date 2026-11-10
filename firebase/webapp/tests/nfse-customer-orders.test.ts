// "Emitir uma nota com várias OS" (nfse.orders.pick): the customer's orders come
// newest first, 50 at a time. Before, 500 came in Firestore's own order, so a
// customer with 1.600 orders missed most of the recent ones.
import { beforeEach, describe, expect, test, vi } from 'vitest'

const ordersPage = vi.fn()
vi.mock('../src/lib/orders-query', () => ({ ordersPage: (...args: unknown[]) => ordersPage(...args) }))
vi.mock('../src/lib/firebase', () => ({ firestoreLite: vi.fn(), firestoreClient: vi.fn() }))
vi.mock('../src/lib/session', () => ({ session: { companyId: 'company-1' }, api: vi.fn() }))

const { customerOrdersForNfse, NFSE_ORDERS_PAGE } = await import('../src/lib/nfse/data')

const row = (n: number) => ({ id: `order-${n}`, number: n, status: 'done', createdAt: `2026-11-${String(n % 28 + 1).padStart(2, '0')}T10:00:00`, services: [{ value: 100 }] })

describe('customerOrdersForNfse', () => {
  beforeEach(() => ordersPage.mockReset())

  test('reads one page of the customer, newest first, in pages of 50', async () => {
    ordersPage.mockResolvedValue([row(3), row(2)])
    const page = await customerOrdersForNfse('customer-1')
    expect(NFSE_ORDERS_PAGE).toBe(50)
    expect(ordersPage).toHaveBeenCalledWith({ companyId: 'company-1', createdBy: null, where: [['customer.id', '==', 'customer-1']] }, 50, undefined)
    expect(page.orders.map((o) => o.number)).toEqual([3, 2])
    expect(page.hasMore).toBe(false)
  })

  test('a full page means there may be more, and the next page starts after its last row', async () => {
    const first = Array.from({ length: 50 }, (_, i) => row(100 - i))
    ordersPage.mockResolvedValueOnce(first)
    const page = await customerOrdersForNfse('customer-1')
    expect(page.hasMore).toBe(true)
    expect(page.last).toEqual(first[49])

    ordersPage.mockResolvedValueOnce([row(50)])
    const next = await customerOrdersForNfse('customer-1', page.last)
    expect(ordersPage).toHaveBeenLastCalledWith(expect.anything(), 50, first[49])
    expect(next.orders.map((o) => o.number)).toEqual([50])
    expect(next.hasMore).toBe(false)
  })
})
