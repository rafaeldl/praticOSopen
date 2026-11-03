/**
 * Pure rules of the order's items and totals, the same as the app
 * (lib/utils/order_items.dart, OrderStore.updateTotal, OrderPaymentMath):
 *
 * - an item without a price (`value: null`) shows "sem valor" and is left out
 *   of the total; it is never stored as 0;
 * - a product line is worth its `total` when it has one, else value × quantity;
 * - order total = items − discount, rounded to cents, never below 0.
 *
 * Item and transaction ids: the app does not keep an `id` on lines and old
 * transactions have none, so a line without one gets a derived id from what
 * it is (kind, catalog item, description, amounts, device) plus its position
 * among identical lines. It stays the same when other lines come and go, and
 * stops matching when that line changes (the client then reloads).
 */
import { createHash } from 'crypto';
import type { Order, OrderProduct, OrderService, PaymentTransaction } from '../models/types';
import { roundMoney } from '../utils/money';

export type ItemKind = 'service' | 'product';

export interface LocatedLine {
  kind: ItemKind;
  index: number;
  itemId: string;
  derivedId: string;
  line: OrderService | OrderProduct;
}

const isPriced = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

/** Line total of a product, or null when it has no price. */
export function productLineTotal(product: Pick<OrderProduct, 'value' | 'quantity' | 'total'>): number | null {
  if (!isPriced(product.value)) return null;
  if (isPriced(product.total)) return product.total;
  return roundMoney(product.value * (product.quantity || 1));
}

/** Sum of the priced items and how many have no price. */
export function summarizeItems(
  services: ReadonlyArray<Pick<OrderService, 'value'>> = [],
  products: ReadonlyArray<Pick<OrderProduct, 'value' | 'quantity' | 'total'>> = [],
): { total: number; unpricedCount: number } {
  let total = 0;
  let unpricedCount = 0;
  for (const s of services) {
    if (isPriced(s.value)) total += s.value;
    else unpricedCount++;
  }
  for (const p of products) {
    const line = productLineTotal(p);
    if (line === null) unpricedCount++;
    else total += line;
  }
  return { total: roundMoney(total), unpricedCount };
}

/** items − discount, in cents, never negative. */
export function computeOrderTotal(order: Pick<Partial<Order>, 'services' | 'products' | 'discount'>): number {
  const { total } = summarizeItems(order.services ?? [], order.products ?? []);
  return Math.max(0, roundMoney(total - (Number(order.discount) || 0)));
}

function hash(parts: unknown[]): string {
  return createHash('sha256').update(JSON.stringify(parts)).digest('hex').slice(0, 20);
}

function lineSignature(kind: ItemKind, line: OrderService | OrderProduct): unknown[] {
  const catalog = kind === 'service' ? (line as OrderService).service : (line as OrderProduct).product;
  const product = line as OrderProduct;
  return [
    kind,
    catalog?.id ?? null,
    line.description ?? null,
    line.value ?? null,
    kind === 'product' ? product.quantity ?? null : null,
    kind === 'product' ? product.total ?? null : null,
    line.deviceId ?? null,
  ];
}

/** Every line of the order with its id (stored or derived), services first. */
export function locateLines(order: Pick<Partial<Order>, 'services' | 'products'>): LocatedLine[] {
  const seen = new Map<string, number>();
  const located: LocatedLine[] = [];
  const add = (kind: ItemKind, lines: Array<OrderService | OrderProduct>) => {
    lines.forEach((line, index) => {
      const signature = hash(lineSignature(kind, line));
      const occurrence = seen.get(signature) ?? 0;
      seen.set(signature, occurrence + 1);
      const derivedId = `legacy_${signature}_${occurrence}`;
      const stored = typeof line.id === 'string' && line.id ? line.id : null;
      located.push({ kind, index, line, itemId: stored ?? derivedId, derivedId });
    });
  };
  add('service', order.services ?? []);
  add('product', order.products ?? []);
  return located;
}

/**
 * The line with [itemId]. A line that got a stored id also answers to its
 * derived one (a client that loaded it before the id was written).
 */
export function findLine(order: Pick<Partial<Order>, 'services' | 'products'>, itemId: string): LocatedLine | null {
  return locateLines(order).find((entry) => entry.itemId === itemId || entry.derivedId === itemId) ?? null;
}

/** Id of a transaction: its own, or derived for old ones (same match as the app's sameTransaction). */
export function transactionIds(transactions: PaymentTransaction[] = []): string[] {
  const seen = new Map<string, number>();
  return transactions.map((t) => {
    if (typeof t.id === 'string' && t.id) return t.id;
    const created = typeof t.createdAt === 'string' ? t.createdAt : JSON.stringify(t.createdAt ?? null);
    const signature = hash([t.type, t.amount, created]);
    const occurrence = seen.get(signature) ?? 0;
    seen.set(signature, occurrence + 1);
    return `legacy_${signature}_${occurrence}`;
  });
}

export function findTransactionIndex(transactions: PaymentTransaction[] = [], transactionId: string): number {
  return transactionIds(transactions).indexOf(transactionId);
}
