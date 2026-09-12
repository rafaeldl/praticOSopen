import type { Express } from 'express';

/**
 * Number of trusted proxy hops in front of the `api` function.
 *
 * Clients call the function directly (`*.cloudfunctions.net/api` or the
 * `*.run.app` URL) — there is no Firebase Hosting rewrite to it. Cloud
 * Functions v2 runs on Cloud Run, where Google's front end appends the real
 * client IP as the right-most `X-Forwarded-For` entry, keeping any value the
 * client sent to the left of it. Trusting exactly one hop makes `req.ip` the
 * right-most entry, so a client-forged `X-Forwarded-For` is ignored.
 *
 * Google's own Cloud Run + express-rate-limit sample uses the same value:
 * https://github.com/GoogleCloudPlatform/nodejs-docs-samples/pull/3586
 *
 * Never use `true`: it trusts the left-most (client-controlled) entry and lets
 * anyone bypass IP-based rate limiting. If a load balancer or Hosting rewrite
 * is ever placed in front of the function, this number must be re-measured.
 */
export const TRUST_PROXY_HOPS = 1;

export function configureTrustProxy(app: Express): void {
  app.set('trust proxy', TRUST_PROXY_HOPS);
}
