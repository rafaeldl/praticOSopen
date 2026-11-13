/**
 * RevenueCat promotional entitlements (API v1), used by the web checkout
 * (docs/WEB_CHECKOUT.md). Same auth as revenuecat.client.ts: the secret API
 * key (sk_...). Errors never include the key.
 *
 * - grant: POST /v1/subscribers/{id}/entitlements/{entitlement}/promotional
 *   with end_time_ms. RevenueCat treats a grant whose end is within 2 hours of
 *   an active promotional's end as a duplicate (harmless for repeated events).
 * - revoke: POST /v1/subscribers/{id}/entitlements/{entitlement}/revoke_promotionals
 *   (every promotional of that entitlement). RevenueCat answers 404 when there
 *   is no active promotional left (seen in the sandbox test: the refund on the
 *   web revokes, then Asaas' PAYMENT_REFUNDED revokes again); nothing to do.
 */

const RC_API_BASE = 'https://api.revenuecat.com/v1';
const TIMEOUT_MS = 10_000;

async function post(
  path: string,
  apiKey: string,
  body: unknown,
  fetchImpl: typeof fetch,
  okStatuses: readonly number[] = [],
): Promise<void> {
  const response = await fetchImpl(`${RC_API_BASE}${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(body ?? {}),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok && !okStatuses.includes(response.status)) {
    // Path without the app user id: only the action is logged.
    throw new Error(`RevenueCat ${path.split('/').pop()} failed: HTTP ${response.status}`);
  }
}

export function grantPromotional(
  appUserId: string,
  entitlement: string,
  endTimeMs: number,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const path = `/subscribers/${encodeURIComponent(appUserId)}/entitlements/${encodeURIComponent(entitlement)}/promotional`;
  return post(path, apiKey, { end_time_ms: endTimeMs }, fetchImpl);
}

export function revokePromotionals(
  appUserId: string,
  entitlement: string,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const path = `/subscribers/${encodeURIComponent(appUserId)}/entitlements/${encodeURIComponent(entitlement)}/revoke_promotionals`;
  return post(path, apiKey, {}, fetchImpl, [404]);
}
