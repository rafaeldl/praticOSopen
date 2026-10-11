/**
 * Whether the magic link page may show prices, totals, payments and charges.
 *
 * The api sends `showValues: false` when the company turned off
 * "Valores e cobrança" (`Company.useFinancial == false`). An older api that
 * does not send the field keeps showing values, as before.
 */
export function showsValues(data: { showValues?: unknown } | null | undefined): boolean {
  return data?.showValues !== false
}
