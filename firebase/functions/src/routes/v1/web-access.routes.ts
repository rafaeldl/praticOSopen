/**
 * Web app access list. Mounted at /v1/app/web-access of `api`.
 *
 * GET /  →  { success: true, data: { allowed: boolean } }
 * Header: Authorization: Bearer {Firebase ID token}. No X-Company-Id: a person
 * without a company (just invited, say) must get an answer too, so this route
 * checks the token itself instead of bearerAuth.
 *
 * Reads config/webApp (server only; firestore.rules deny the client):
 *   { open: boolean, allowedEmailHashes: string[] }  — SHA-256 hex of the
 *   lowercase, trimmed e-mail, so the list never stores addresses.
 * Closed by default: no document, no e-mail or an unverified e-mail is denied.
 * This only gates the web screens; data stays protected by the rules and the API.
 */

import { createHash } from 'crypto';
import { Router, Request, Response } from 'express';
import rateLimit from 'express-rate-limit';

export interface WebAccessToken {
  uid: string;
  email?: string;
  email_verified?: boolean;
}

export interface WebAccessConfig {
  open?: unknown;
  allowedEmailHashes?: unknown;
}

export interface WebAccessRouterOptions {
  verifyIdToken: (token: string) => Promise<WebAccessToken>;
  readConfig: () => Promise<WebAccessConfig | null>;
  /** How long one read of config/webApp is reused. A change reaches everyone within this time. */
  cacheMs?: number;
  now?: () => number;
}

/**
 * The local Emulator Suite (FUNCTIONS_EMULATOR is never set in Cloud Functions)
 * has no req.ip, so every caller shares one counter: the web E2E suite logs in
 * hundreds of times a minute and got 429 on random tests.
 */
export function skipWebAccessLimit(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.FUNCTIONS_EMULATOR === 'true';
}

/**
 * Every web start asks once, before anything else, so it has its own limit
 * instead of spending the shared apiCoreLimiter budget of the same IP (a
 * workshop with several computers shares one).
 */
const webAccessLimiter = rateLimit({
  skip: () => skipWebAccessLimit(),
  windowMs: 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  // Same key as apiCoreLimiter in index.ts; the emulator has no req.ip.
  keyGenerator: (req: Request) => req.ip || 'unknown',
  validate: { ip: false },
  message: { success: false, error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later' } },
});

export function hashEmail(email: string): string {
  return createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

export function isWebAccessAllowed(token: WebAccessToken, config: WebAccessConfig | null): boolean {
  if (!config) return false;
  if (config.open === true) return true;
  if (!token.email || token.email_verified !== true) return false;
  const hashes = Array.isArray(config.allowedEmailHashes) ? config.allowedEmailHashes : [];
  return hashes.includes(hashEmail(token.email));
}

export function createWebAccessRouter(options: WebAccessRouterOptions): Router {
  const router: Router = Router();
  const cacheMs = options.cacheMs ?? 30_000;
  const now = options.now ?? Date.now;
  let cached: { at: number; config: WebAccessConfig | null } | null = null;

  async function readConfig(): Promise<WebAccessConfig | null> {
    if (cached && now() - cached.at < cacheMs) return cached.config;
    const config = await options.readConfig();
    cached = { at: now(), config };
    return config;
  }

  router.get('/', webAccessLimiter, async (req: Request, res: Response) => {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Bearer token is required' } });
      return;
    }

    let token: WebAccessToken;
    try {
      token = await options.verifyIdToken(header.slice('Bearer '.length).trim());
    } catch (error) {
      const expired = (error as { code?: string })?.code === 'auth/id-token-expired';
      res.status(401).json({
        success: false,
        error: { code: expired ? 'TOKEN_EXPIRED' : 'UNAUTHORIZED', message: 'Invalid token' },
      });
      return;
    }

    try {
      const allowed = isWebAccessAllowed(token, await readConfig());
      res.set('Cache-Control', 'private, no-store');
      res.json({ success: true, data: { allowed } });
    } catch (error) {
      console.error('[WebAccess] Could not read config/webApp', error);
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Unexpected error' } });
    }
  });

  return router;
}
