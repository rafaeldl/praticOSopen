import type { Express } from 'express';

/**
 * Number of trusted proxy hops in front of the `api` function.
 *
 * Most routes are called on the function's own URL (`*.cloudfunctions.net/api`
 * or the `*.run.app` URL). Cloud Functions v2 runs on Cloud Run, where
 * Google's front end appends the real client IP as the right-most
 * `X-Forwarded-For` entry, keeping any value the client sent to the left of
 * it. Trusting exactly one hop makes `req.ip` the right-most entry, so a
 * client-forged `X-Forwarded-For` is ignored.
 *
 * The exception is `/mcp/**`, which `firebase.json` rewrites from Firebase
 * Hosting to this function. Measured in production on 2026-09-15, those
 * requests arrive as `X-Forwarded-For: <client>, <Hosting edge>`, so `req.ip`
 * there is a Google edge IP that changes on every request, not the client.
 * Don't key a limiter on `req.ip` for a Hosting-rewritten route, and don't
 * raise this number for one: the function's own URL serves the same routes,
 * and there the second entry from the right is client-controlled. See the MCP
 * rate limiting comment in src/index.ts.
 *
 * Google's own Cloud Run + express-rate-limit sample uses the same value:
 * https://github.com/GoogleCloudPlatform/nodejs-docs-samples/pull/3586
 *
 * Never use `true`: it trusts the left-most (client-controlled) entry and lets
 * anyone bypass IP-based rate limiting. If a load balancer is ever placed in
 * front of the function, or another Hosting rewrite points at it, this must be
 * re-measured.
 */
export const TRUST_PROXY_HOPS = 1;

export function configureTrustProxy(app: Express): void {
  app.set('trust proxy', TRUST_PROXY_HOPS);
}
