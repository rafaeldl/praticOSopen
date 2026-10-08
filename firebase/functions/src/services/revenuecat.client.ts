/**
 * Minimal RevenueCat REST client (API v1, native fetch).
 * Only GET /v1/subscribers/{app_user_id}, used as the authoritative state of a
 * company's subscription (app_user_id = companyId). Requires the secret API
 * key (sk_...). Errors never include the key.
 */

const RC_API_BASE = 'https://api.revenuecat.com/v1';
const TIMEOUT_MS = 10_000;

export interface RcEntitlement {
  expires_date: string | null;
  product_identifier: string;
  store?: string;
}

export interface RcSubscription {
  unsubscribe_detected_at: string | null;
  billing_issues_detected_at: string | null;
  grace_period_expires_date?: string | null;
  store: string;
  expires_date: string | null;
}

export interface RcSubscriber {
  entitlements: Record<string, RcEntitlement>;
  subscriptions: Record<string, RcSubscription>;
  original_app_user_id?: string;
}

export async function fetchSubscriber(
  appUserId: string,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<RcSubscriber> {
  const response = await fetchImpl(`${RC_API_BASE}/subscribers/${encodeURIComponent(appUserId)}`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) {
    throw new Error(`RevenueCat GET /subscribers failed: HTTP ${response.status}`);
  }
  const body = (await response.json()) as { subscriber?: Partial<RcSubscriber> } | null;
  const subscriber = body?.subscriber;
  if (!subscriber) {
    throw new Error('RevenueCat GET /subscribers returned no subscriber');
  }
  return {
    entitlements: subscriber.entitlements ?? {},
    subscriptions: subscriber.subscriptions ?? {},
    original_app_user_id: subscriber.original_app_user_id,
  };
}
