import { describe, expect, test } from 'vitest'
import { canChangeCatalogPrice, catalogPriceOffer } from '../src/lib/orders/catalog-price'
import type { OrderLine } from '../src/lib/orders/model'
import { roleHasPermission, type Permission } from '../src/lib/permissions'

const line: OrderLine = { id: 'l1', kind: 'service', catalogId: 's1', name: 'Troca de óleo', value: 120 }
const item = { id: 's1', value: 120 as number | null, version: 'v1' }

describe('"Mudar o preço no Catálogo?" after a new price on the order (#588)', () => {
  test('a new price on a catalog line offers the catalog, with what the person saw', () => {
    expect(catalogPriceOffer(line, 150, item, true)).toEqual({ kind: 'service', id: 's1', name: 'Troca de óleo', from: 120, to: 150, version: 'v1' })
  })

  test('price not touched, same as the catalog, or a loose line: no question', () => {
    expect(catalogPriceOffer(line, undefined, item, true)).toBeNull()
    expect(catalogPriceOffer({ ...line, value: 150 }, 120, item, true)).toBeNull()
    expect(catalogPriceOffer(line, 120.001, item, true)).toBeNull()
    expect(catalogPriceOffer({ ...line, catalogId: undefined }, 150, item, true)).toBeNull()
    expect(catalogPriceOffer(line, null, item, true)).toBeNull()
  })

  test('item gone, price hidden from this person or not allowed: no question', () => {
    expect(catalogPriceOffer(line, 150, null, true)).toBeNull()
    expect(catalogPriceOffer(line, 150, { id: 's1', version: 'v1' }, true)).toBeNull()
    expect(catalogPriceOffer(line, 150, item, false)).toBeNull()
  })

  test('catalog item without price ("sem valor") is offered too', () => {
    expect(catalogPriceOffer(line, 150, { ...item, value: null }, true)?.from).toBeNull()
  })

  test('only who edits the catalog of that kind and sees prices (permission matrix)', () => {
    const as = (role: string) => (permission: Permission) => roleHasPermission(role, permission)
    expect(canChangeCatalogPrice('service', as('admin'))).toBe(true)
    expect(canChangeCatalogPrice('product', as('owner'))).toBe(true)
    for (const role of ['manager', 'supervisor', 'consultant', 'technician']) {
      expect(canChangeCatalogPrice('service', as(role))).toBe(false)
      expect(canChangeCatalogPrice('product', as(role))).toBe(false)
    }
    expect(canChangeCatalogPrice('service', (permission) => roleHasPermission('admin', permission, false))).toBe(false)
  })
})
