import { createHash, timingSafeEqual } from 'crypto';
import type { Request, RequestHandler } from 'express';
import rateLimit from 'express-rate-limit';

/**
 * Rate limiting for `/public/orders` (magic links).
 *
 * Two kinds of caller reach these routes:
 *
 * - Browsers (`hosting/src/js/order-view.js`, and the approve/reject/comment/
 *   rating calls in `web/composables/useOrderApi.ts`) call the function URL
 *   directly, so `req.ip` is the visitor (see trust-proxy.utils.ts) and a
 *   per-IP limit is right.
 * - The Nuxt SSR (Cloud Run service `praticos-web`,
 *   `web/server/api/orders/[token].get.ts`) loads the order server-side for
 *   every `/q/{token}` page view. Measured in production on 2026-09-15, those
 *   requests arrive with `X-Forwarded-For: <praticos-web egress IP>` and
 *   user-agent `node` — the same IP for every visitor, and a client-sent
 *   `X-Forwarded-For` isn't passed along. A per-IP limit therefore puts every
 *   `/q/` page view into one bucket: a busy minute, or anyone opening
 *   `/q/<anything>` 30 times, returns 429 to every customer.
 *
 * The SSR identifies itself with a shared secret (Secret Manager
 * `SSR_API_SECRET`) in the `X-Praticos-SSR-Secret` header — nothing a visitor
 * sends can produce it. Trusted SSR requests skip the per-IP limit and are
 * limited per share token instead, plus an aggregate fuse that counts only
 * failed responses (e.g. 401 for made-up tokens), so a flood of invented
 * tokens through `/q/` is bounded without real page views ever tripping it.
 *
 * With no secret configured nothing is trusted: everyone gets the per-IP limit.
 * Counters live in memory, per function instance.
 */
export const SSR_SECRET_HEADER = 'x-praticos-ssr-secret';

const WINDOW_MS = 60 * 1000;

const RATE_LIMIT_MESSAGE = {
  success: false,
  error: {
    code: 'RATE_LIMIT_EXCEEDED',
    message: 'Too many requests, please try again later',
  },
};

export interface PublicOrdersLimits {
  /** Requests per IP per minute for direct (browser) callers */
  ipMax: number;
  /** SSR requests per share token per minute */
  tokenMax: number;
  /** Failed SSR requests per minute, across all tokens */
  failedFuseMax: number;
}

const DEFAULT_LIMITS: PublicOrdersLimits = {
  ipMax: 30,
  tokenMax: 30,
  failedFuseMax: 300,
};

export function isTrustedSsrRequest(req: Request, secret: string | undefined): boolean {
  const sent = req.headers[SSR_SECRET_HEADER];
  if (!secret || typeof sent !== 'string' || !sent) return false;
  // Compare fixed-length digests so neither content nor length leaks via timing
  const sentDigest = createHash('sha256').update(sent).digest();
  const secretDigest = createHash('sha256').update(secret).digest();
  return timingSafeEqual(sentDigest, secretDigest);
}

function shareTokenFromPath(path: string): string {
  const match = path.match(/^\/([^/]+)/);
  return match ? match[1] : '';
}

/**
 * Limiters to mount in front of the public orders routes, in order.
 * `getSecret` is read per request (Firebase secrets are only available at runtime).
 */
export function createPublicOrdersLimiters(
  getSecret: () => string | undefined,
  limits: PublicOrdersLimits = DEFAULT_LIMITS,
): RequestHandler[] {
  const isSsr = (req: Request) => isTrustedSsrRequest(req, getSecret());

  const ipLimiter = rateLimit({
    windowMs: WINDOW_MS,
    max: limits.ipMax,
    message: RATE_LIMIT_MESSAGE,
    skip: isSsr,
    keyGenerator: (req: Request) => req.ip || 'unknown',
  });

  const ssrTokenLimiter = rateLimit({
    windowMs: WINDOW_MS,
    max: limits.tokenMax,
    message: RATE_LIMIT_MESSAGE,
    skip: (req: Request) => !isSsr(req),
    keyGenerator: (req: Request) => `ssr-token:${shareTokenFromPath(req.path)}`,
  });

  const ssrFailedFuse = rateLimit({
    windowMs: WINDOW_MS,
    max: limits.failedFuseMax,
    message: RATE_LIMIT_MESSAGE,
    skip: (req: Request) => !isSsr(req),
    skipSuccessfulRequests: true,
    keyGenerator: () => 'ssr-failed',
  });

  return [ipLimiter, ssrTokenLimiter, ssrFailedFuse];
}
