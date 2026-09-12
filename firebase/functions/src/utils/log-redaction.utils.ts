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
