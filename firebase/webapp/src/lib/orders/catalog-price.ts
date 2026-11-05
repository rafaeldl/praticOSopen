// "Mudar o preço no Catálogo?" after a new price on an order line (#588), same
// rule as the app (shouldOfferCatalogPrice in lib/screens/order/order_item_form.dart):
// only a line that came from the catalog, only when the price changed now and
// differs from the catalog, only for who may edit the catalog and see prices.
import type { Permission } from '@/lib/permissions'
import type { OrderLine } from './model'

export interface CatalogPriceOffer {
  kind: OrderLine['kind']
  id: string
  name: string
  /** Catalog price now; null: "sem valor". */
  from: number | null
  to: number
  /** What the person saw, so a save made meanwhile is not overwritten. */
  version: string | null
}

const cents = (value: number) => Math.round(value * 100)

/** May change the catalog price of this kind of line. */
export function canChangeCatalogPrice(kind: OrderLine['kind'], can: (permission: Permission) => boolean): boolean {
  return can('viewPrices') && can(kind === 'service' ? 'manageServices' : 'manageProducts')
}

/** Whether the line has a catalog item to ask about (before reading it). */
export function mayOfferCatalogPrice(line: OrderLine, to: number | null | undefined, allowed: boolean): to is number {
  return allowed && !!line.catalogId && typeof to === 'number'
}

/**
 * `to` is the patch value: undefined when the price was not touched.
 * `item` is the catalog item read now (null: gone from the catalog).
 */
export function catalogPriceOffer(
  line: OrderLine,
  to: number | null | undefined,
  item: { id: string; value?: number | null; version?: string | null } | null,
  allowed: boolean,
): CatalogPriceOffer | null {
  if (!mayOfferCatalogPrice(line, to, allowed) || !item || item.id !== line.catalogId) return null
  if (item.value === undefined) return null
  const from = item.value ?? null
  if (from !== null && cents(from) === cents(to)) return null
  return { kind: line.kind, id: item.id, name: line.name, from, to, version: item.version ?? null }
}
