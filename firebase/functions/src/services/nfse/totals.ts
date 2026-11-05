/**
 * Notas issued per emitter this year and this month (spec §5.7): notas of any
 * source (PraticOS, portal, other systems), minus canceled ones. Only the MEI
 * compares the year with its limit, and only to warn: never blocks.
 */

import type { FiscalEmitterTotals, FiscalRegime } from '../../models/nfse-direct.types';

export const DEFAULT_MEI_ANNUAL_LIMIT = 81_000;
/** Share of the limit from which the sheet warns. */
export const MEI_WARNING_SHARE = 0.8;

export interface TotalsInvoice {
  status: string;
  value: number;
  /** YYYY-MM-DD, in Brasília. */
  effectiveDate: string;
}

const COUNTED = ['authorized', 'cancellationDenied'];

const cents = (value: number) => Math.round((Number(value) || 0) * 100);

/** Year and month of [today] (YYYY-MM-DD in Brasília). */
export function emitterTotals(invoices: TotalsInvoice[], today: string): FiscalEmitterTotals {
  const year = Number(today.slice(0, 4));
  const month = Number(today.slice(5, 7));
  const monthKey = today.slice(0, 7);
  let yearCents = 0;
  let monthCents = 0;
  for (const invoice of invoices) {
    if (!COUNTED.includes(invoice.status)) continue;
    if (!invoice.effectiveDate?.startsWith(String(year))) continue;
    yearCents += cents(invoice.value);
    if (invoice.effectiveDate.startsWith(monthKey)) monthCents += cents(invoice.value);
  }
  return { year, yearValue: yearCents / 100, month, monthValue: monthCents / 100 };
}

export type MeiWarning = 'none' | 'near' | 'over';

/** "Com esta nota, o MEI passa de 80% / passa do teto do ano." Not for the Simples (decision 4). */
export function meiWarning(
  regime: FiscalRegime | null | undefined,
  totals: FiscalEmitterTotals | null | undefined,
  value: number,
  today: string,
  limit: number = DEFAULT_MEI_ANNUAL_LIMIT,
): MeiWarning {
  if (regime !== 'mei' || !(limit > 0)) return 'none';
  const sameYear = totals?.year === Number(today.slice(0, 4));
  const after = cents(sameYear ? totals!.yearValue : 0) + cents(value);
  if (after > cents(limit)) return 'over';
  if (after >= cents(limit * MEI_WARNING_SHARE)) return 'near';
  return 'none';
}
