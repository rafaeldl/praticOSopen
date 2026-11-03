/**
 * What of an order leaves the server (contract visibility.json): a field list,
 * not the raw document, so nothing new leaks by accident. Without
 * `viewPrices` (technician, supervisor, or "Valores e cobrança" off) no money
 * goes out in any field: totals, line values, line totals, the catalog price
 * inside a line, payments, payment status and payment receipts.
 */
import { orderVersion } from './order-version';
import type { Order, OrderProduct, OrderService } from '../models/types';
import { calculateRemainingBalance } from './order.service';
import { locateLines, productLineTotal, transactionIds } from './order-items';
import { timestampToDate } from '../utils/date.utils';

type Json = Record<string, unknown>;

const iso = (value: unknown): string | null =>
  timestampToDate(value as string | undefined)?.toISOString() ?? null;

/**
 * Visit and delivery dates. The app writes them as local time without a zone
 * (Dart toIso8601String); read on the server they would turn into UTC and move
 * by the company's offset. That text goes out as it is, for the client to place
 * in the company's zone; a Timestamp or text with a zone goes out as UTC ISO.
 */
const ZONELESS = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?$/;
const wallTime = (value: unknown): string | null =>
  typeof value === 'string' && ZONELESS.test(value) ? value : iso(value);

function compact(value: Json): Json {
  return Object.fromEntries(Object.entries(value).filter(([, v]) => v !== undefined));
}

function catalogAggr(aggr: { id?: string; name?: string; photo?: string | null; value?: number | null } | undefined, showPrices: boolean): Json | undefined {
  if (!aggr) return undefined;
  return compact({ id: aggr.id, name: aggr.name, photo: aggr.photo ?? undefined, value: showPrices ? aggr.value ?? null : undefined });
}

function projectLines(order: Order, showPrices: boolean): { services: Json[]; products: Json[] } {
  const services: Json[] = [];
  const products: Json[] = [];
  for (const { kind, line, itemId } of locateLines(order)) {
    const base = {
      id: itemId,
      description: line.description,
      photo: line.photo,
      deviceId: line.deviceId ?? undefined,
      value: showPrices ? line.value ?? null : undefined,
    };
    if (kind === 'service') {
      services.push(compact({ ...base, service: catalogAggr((line as OrderService).service, showPrices) }));
    } else {
      const product = line as OrderProduct;
      products.push(compact({
        ...base,
        product: catalogAggr(product.product, showPrices),
        quantity: product.quantity,
        total: showPrices ? productLineTotal(product) : undefined,
      }));
    }
  }
  return { services, products };
}

function money(order: Order): Json {
  return {
    total: order.total ?? 0,
    discount: order.discount ?? 0,
    paidAmount: order.paidAmount ?? 0,
    remainingBalance: calculateRemainingBalance(order),
    payment: order.payment ?? null,
    paid: order.paid === true,
    lastPaymentAt: order.lastPaymentAt,
  };
}

/** One row of GET /orders. */
export function projectOrderSummary(order: Order, showPrices: boolean): Json {
  return compact({
    id: order.id,
    number: order.number,
    customer: order.customer,
    device: order.device ?? undefined,
    devices: order.devices,
    status: order.status,
    onHold: order.onHold,
    assignedTo: order.assignedTo ?? undefined,
    // Who created it decides what consultant and technician may change (agenda, board).
    createdBy: order.createdBy ?? undefined,
    dueDate: wallTime(order.dueDate) ?? undefined,
    scheduledDate: wallTime(order.scheduledDate) ?? undefined,
    createdAt: iso(order.createdAt) ?? undefined,
    updatedAt: iso(order.updatedAt) ?? undefined,
    // Opaque: sent back as expectedUpdatedAt without any conversion (order-version.ts).
    version: orderVersion(order.updatedAt) ?? undefined,
    ...(showPrices
      ? { total: order.total ?? 0, paidAmount: order.paidAmount ?? 0, payment: order.payment ?? null, paid: order.paid === true }
      : {}),
  });
}

/** GET /orders/:id and every write response that returns the order. */
export function projectOrder(order: Order, showPrices: boolean): Json {
  const { services, products } = projectLines(order, showPrices);
  const ids = transactionIds(order.transactions);
  return compact({
    id: order.id,
    number: order.number,
    customer: order.customer,
    device: order.device ?? undefined,
    devices: order.devices,
    services,
    products,
    photos: order.photos,
    status: order.status,
    onHold: order.onHold,
    assignedTo: order.assignedTo ?? null,
    rating: order.rating,
    dueDate: wallTime(order.dueDate),
    scheduledDate: wallTime(order.scheduledDate),
    completedAt: order.completedAt,
    createdAt: iso(order.createdAt),
    createdBy: order.createdBy,
    updatedAt: iso(order.updatedAt),
    version: orderVersion(order.updatedAt),
    ...(showPrices
      ? {
        ...money(order),
        transactions: (order.transactions ?? []).map((t, i) => ({ ...t, id: ids[i] })),
        documents: (order.documents ?? []).filter((d) => d.type === 'receipt'),
      }
      : {}),
  });
}
