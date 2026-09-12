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
 */
export function redactMcpTokenFromPath(path: string): string {
  return path.replace(/\/mcp\/t\/[^/]+/, '/mcp/t/***');
}

/**
 * Whether the app-wide request logger in index.ts is allowed to print a
 * request/response payload for this path.
 *
 * Every MCP `tools/call` body — and the order/customer detail many tool
 * responses return — can carry end-customer personal data: phone, email,
 * address (create_entity), free-text comment bodies (add_order_comment),
 * customer names and addresses embedded in an order. `mcp/tools/write.ts`'s
 * `auditWrite()` allowlists only a handful of identifiers specifically so
 * that data never reaches Cloud Logging; a logger that dumps the raw body
 * or the raw response elsewhere would defeat that allowlist entirely. See
 * docs/MCP_INTEGRATION.md, which states these fields never reach the log.
 *
 * Every other path keeps logging its payload as before — this only turns
 * the behavior off for `/mcp/**`.
 */
export function shouldLogPayload(path: string): boolean {
  return !/^\/mcp(\/|$)/.test(path);
}
