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
