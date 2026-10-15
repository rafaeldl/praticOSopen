/**
 * Splitting one payment over several orders, in whole cents. Same rule as
 * the app (`lib/utils/payment_allocation.dart`, `allocatePayment`): the
 * caller passes the orders oldest first and each order gets at most what is
 * open on it.
 */

export interface OpenBalance {
  orderId: string;
  orderNumber?: number | null;
  /** What is still open on the order (never negative). */
  open: number;
}

export interface Allocation {
  orderId: string;
  orderNumber?: number | null;
  amount: number;
}

export function toCents(value: number): number {
  return Math.round((Number(value) || 0) * 100);
}

export function fromCents(cents: number): number {
  return cents / 100;
}

/** Sum of the open balances, rounded to cents. */
export function totalOpen(balances: Array<{ open: number }>): number {
  return fromCents(balances.reduce((sum, b) => sum + Math.max(0, toCents(b.open)), 0));
}

/**
 * Splits `amount` over `balances` in the given order, each capped at its
 * open balance. Orders that get nothing are left out; what goes beyond the
 * total open is not allocated (callers reject overpayment first).
 */
export function allocateOldestFirst(balances: OpenBalance[], amount: number): Allocation[] {
  let left = toCents(amount);
  const result: Allocation[] = [];
  for (const balance of balances) {
    if (left <= 0) break;
    const open = toCents(balance.open);
    if (open <= 0) continue;
    const share = Math.min(open, left);
    result.push({ orderId: balance.orderId, orderNumber: balance.orderNumber ?? null, amount: fromCents(share) });
    left -= share;
  }
  return result;
}

/**
 * Spreads what the customer actually paid (`value`) over the stored
 * allocations of a charge:
 *
 * - same total: the stored allocations, as they are;
 * - less (e.g. a discount on Asaas): oldest first, each order capped at its
 *   stored share;
 * - more (interest/fine after the due date): every order gets its share and
 *   the extra goes to the last order, so no money is left out.
 *
 * Returns one entry per stored allocation (amount can be 0 when less was paid).
 */
export function spreadPayment(allocations: Allocation[], value: number): Allocation[] {
  const valueCents = toCents(value);
  const totalCents = allocations.reduce((sum, a) => sum + toCents(a.amount), 0);
  if (allocations.length === 0) return [];
  if (valueCents === totalCents) return allocations.map((a) => ({ ...a, amount: fromCents(toCents(a.amount)) }));

  if (valueCents > totalCents) {
    const extra = valueCents - totalCents;
    return allocations.map((a, i) => ({
      ...a,
      amount: fromCents(toCents(a.amount) + (i === allocations.length - 1 ? extra : 0)),
    }));
  }

  let left = Math.max(0, valueCents);
  return allocations.map((a) => {
    const share = Math.min(toCents(a.amount), left);
    left -= share;
    return { ...a, amount: fromCents(share) };
  });
}

/**
 * Spreads what the customer actually paid (`value`) over the orders of a
 * charge, capped at what each order still owes NOW (`open`, same order as
 * `allocations`; null = order not found). The stored allocations can be stale
 * (an order paid outside Asaas after the link was created), so:
 *
 * 1. oldest first, each order gets its stored share, at most its open amount;
 * 2. what is left goes to the orders still owing, oldest first;
 * 3. anything beyond the total open (interest/fine, overpayment) goes to the
 *    last order that exists, reported as `excess`.
 *
 * Returns one entry per stored allocation (amount can be 0).
 */
export function spreadPaymentOverOpen(
  allocations: Allocation[],
  open: Array<number | null>,
  value: number,
): { shares: Allocation[]; excess: number } {
  let left = Math.max(0, toCents(value));
  const openCents = allocations.map((_, i) => (open[i] === null || open[i] === undefined ? 0 : Math.max(0, toCents(open[i] as number))));
  const cents = allocations.map(() => 0);

  allocations.forEach((a, i) => {
    const share = Math.min(Math.max(0, toCents(a.amount)), openCents[i], left);
    cents[i] += share;
    left -= share;
  });
  allocations.forEach((_, i) => {
    const share = Math.min(openCents[i] - cents[i], left);
    if (share <= 0) return;
    cents[i] += share;
    left -= share;
  });

  const excess = left;
  if (excess > 0 && allocations.length > 0) {
    let target = allocations.length - 1;
    for (let i = allocations.length - 1; i >= 0; i--) {
      if (open[i] !== null && open[i] !== undefined) {
        target = i;
        break;
      }
    }
    cents[target] += excess;
  }
  return {
    shares: allocations.map((a, i) => ({ ...a, amount: fromCents(cents[i]) })),
    excess: fromCents(excess),
  };
}
