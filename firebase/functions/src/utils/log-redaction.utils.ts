import type { IncomingHttpHeaders } from 'http';

/**
 * Redacts the MCP connector token from a request path before it reaches the
 * logs. The token travels in the URL (`/mcp/t/{token}`), so any log line
 * that echoes `req.path` verbatim would leak it.
 *
 * `req.path` is not percent-decoded by Express (only `req.params` is), so a
 * pattern matched against the token's expected `mcp_` + hex shape can be
 * bypassed by percent-encoding a character in the token (e.g. `%6dcp_...`
 * decodes to `mcp_...` for routing purposes but never matches that literal
 * text in `req.path`). Matching unconditionally on the `/t/<segment>`
 * position instead of on the token's shape closes that gap — and any future
 * token format — at once.
 *
 * Express also routes case-insensitively by default (`/MCP/t/...` reaches the
 * same router), so every pattern here is matched with the `i` flag.
 */
export function redactMcpTokenFromPath(path: string): string {
  return path.replace(/(\/mcp\/t\/)[^/]+/i, '$1***');
}

/**
 * Redacts every URL segment that carries a bearer-like credential before
 * `req.path` reaches the logs:
 * - `/mcp/t/{token}` — MCP connector token;
 * - `/public/orders/{token}` — share link token (`ST_<uuid>`), which alone
 *   grants access to the order, its customer and approve/reject actions;
 * - `.../share/{token}` — the same share token on the revoke routes
 *   (`/v1/orders`, `/v1/app/orders`, `/bot/orders`);
 * - `/v1/app/invites/{token}` and `/bot/invite/{code}` — invite code
 *   (`INV_...`), which lets whoever holds it join the company. The literal
 *   sibling routes (`pending`, `create`, `accept`, `list`) stay readable.
 *
 * Same rules as redactMcpTokenFromPath(): match by position, never by token
 * shape, and case-insensitively.
 */
export function redactSensitivePath(path: string): string {
  return redactMcpTokenFromPath(path)
    .replace(/(\/public\/orders\/)[^/]+/i, '$1***')
    .replace(/(\/share\/)[^/]+/i, '$1***')
    .replace(/(\/v1\/app\/invites\/)(?!pending(\/|$))[^/]+/i, '$1***')
    .replace(/(\/bot\/invite\/)(?!(create|accept|list)(\/|$))[^/]+/i, '$1***');
}

type LoggableHeaders = {
  'x-api-key'?: string;
  'x-api-secret'?: string;
  'x-whatsapp-number'?: string;
  'authorization'?: string;
  'content-type'?: string;
};

const REDACTED = '[REDACTED]';

/**
 * A phone / WhatsApp number identifies a person (personal data under LGPD).
 * Keeping only the last 4 digits is enough to correlate log lines while
 * debugging. Takes the first value of a repeated header.
 */
export function maskPhoneForLog(value: string | string[] | null | undefined): string {
  const first = Array.isArray(value) ? value[0] : value;
  if (!first) return 'missing';
  const digits = first.replace(/\D/g, '');
  return digits.length > 4 ? `***${digits.slice(-4)}` : '***';
}

/**
 * Link (`LT_`), registration (`RG_`), invite (`INV_`) and share (`ST_`) tokens
 * are bearer credentials: whoever reads one from the logs can use it. Only the
 * type prefix is kept, which is what debugging needs; anything without a
 * recognizable prefix (e.g. an FCM registration token) is fully masked.
 */
export function maskTokenForLog(value: unknown): string {
  if (value === null || value === undefined || value === '') return 'missing';
  if (typeof value !== 'string') return '***';
  const prefix = /^[A-Z]{2,4}_/.exec(value);
  return prefix ? `${prefix[0]}***` : '***';
}

/**
 * Picks the headers the request logger prints, with credentials removed:
 * `x-api-key` / `x-api-secret` (API Core key pair, or the bot key) and the
 * bearer token only reveal whether they were sent; the WhatsApp number is
 * masked. Headers that were not sent stay `undefined` (dropped by JSON).
 */
export function buildLoggableHeaders(headers: IncomingHttpHeaders): LoggableHeaders {
  const whatsappNumber = headers['x-whatsapp-number'];
  return {
    'x-api-key': headers['x-api-key'] ? REDACTED : undefined,
    'x-api-secret': headers['x-api-secret'] ? REDACTED : undefined,
    'x-whatsapp-number': whatsappNumber ? maskPhoneForLog(whatsappNumber) : undefined,
    'authorization': headers['authorization'] ? 'Bearer [HIDDEN]' : undefined,
    'content-type': headers['content-type'],
  };
}

/**
 * Whether the app-wide request logger in index.ts is allowed to print a
 * request/response payload (query, body and response) for this path.
 *
 * - `/mcp/**`: every MCP `tools/call` body — and the order/customer detail
 *   many tool responses return — can carry end-customer personal data:
 *   phone, email, address (create_entity), free-text comment bodies
 *   (add_order_comment), customer names and addresses embedded in an order.
 *   `mcp/tools/write.ts`'s `auditWrite()` allowlists only a handful of
 *   identifiers specifically so that data never reaches Cloud Logging; a
 *   logger that dumps the raw body or the raw response elsewhere would defeat
 *   that allowlist entirely. See docs/MCP_INTEGRATION.md, which states these
 *   fields never reach the log.
 * - `/public/**`: unauthenticated magic-link routes. Bodies are customer free
 *   text (comments, rejection reason, rating comment) and responses carry the
 *   order, company contact data and the comment thread.
 * - `.../share` and `.../share/{token}`: share link management. Responses
 *   return the share token and its URL, which would leak through `RESULT`
 *   even with the path redacted.
 *
 * Every other path keeps logging its payload as before. Matched
 * case-insensitively because Express routes that way.
 */
export function shouldLogPayload(path: string): boolean {
  return !/^\/(mcp|public)(\/|$)|\/share(\/|$)/i.test(path);
}

/**
 * Whether the request logger may print query, body and response for this
 * request. Only ever in the local Functions emulator: in production nearly
 * every route carries a credential or end-customer personal data in its
 * payload — link/invite tokens in `/bot/link` and `/bot/invite/accept`
 * bodies, invite tokens in invite responses, phone/email in `/v1/customers`
 * queries, customer and order data in most bot/API responses. Even in the
 * emulator, shouldLogPayload()'s always-sensitive routes stay skipped.
 */
export function isPayloadLoggingEnabled(
  path: string,
  env: NodeJS.ProcessEnv = process.env
): boolean {
  return env.FUNCTIONS_EMULATOR === 'true' && shouldLogPayload(path);
}
