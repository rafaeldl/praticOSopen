/**
 * Money rounding shared by every server path (orders, receipts, Asaas).
 * Same rule as the app's OrderPaymentMath.roundMoney (Dart `roundToDouble`):
 * half a cent goes away from zero on both sides (-0.125 → -0.13), which
 * `Math.round` does not do for negatives (contract case round-money.json).
 */
export function roundMoney(value: number): number {
  const rounded = (Math.sign(value) * Math.round(Math.abs(value) * 100)) / 100;
  // -0 compares equal but serializes and `toBe`s differently: always plain 0.
  return rounded === 0 ? 0 : rounded;
}

/** Half a cent: money comparisons allow this slack (same as the app's centTolerance). */
export const CENT_TOLERANCE = 0.005;
