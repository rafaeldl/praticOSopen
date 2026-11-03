import type { Request, RequestHandler } from 'express';
import rateLimit from 'express-rate-limit';
import type { CorsOptions } from 'cors';

/**
 * Rate limiting for the app's API (`/v1/app/*`, `/user/*`: Firebase ID token).
 *
 * People of one company usually share one office IP, and the web app makes
 * more calls than the phone, so a per-IP limit would stop a whole team. The
 * limit is per authenticated user instead, which needs the verified token:
 * the user limiter goes after `bearerAuth` (a client-chosen value would give
 * a fresh budget per request). In front of `bearerAuth` a wide per-IP limit
 * still caps floods of made-up tokens before any verification.
 *
 * Counters live in memory, per function instance.
 */
const WINDOW_MS = 60 * 1000;

const RATE_LIMIT_MESSAGE = {
  success: false,
  error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later' },
};

export interface AppLimits {
  /** Requests per authenticated user per minute. */
  userMax: number;
  /** Requests per IP per minute before the token is checked (a whole office). */
  ipMax: number;
}

export const DEFAULT_APP_LIMITS: AppLimits = { userMax: 300, ipMax: 1500 };

/**
 * `[ipLimiter, userLimiter]`: mount the first before `bearerAuth` and the
 * second right after it.
 */
export function createAppLimiters(limits: AppLimits = DEFAULT_APP_LIMITS): { ipLimiter: RequestHandler; userLimiter: RequestHandler } {
  const ipLimiter = rateLimit({
    windowMs: WINDOW_MS,
    max: limits.ipMax,
    message: RATE_LIMIT_MESSAGE,
    keyGenerator: (req: Request) => req.ip || 'unknown',
  });
  const userLimiter = rateLimit({
    windowMs: WINDOW_MS,
    max: limits.userMax,
    message: RATE_LIMIT_MESSAGE,
    keyGenerator: (req: Request) => {
      const userId = (req as Request & { auth?: { userId?: string } }).auth?.userId;
      return userId ? `user:${userId}` : `ip:${req.ip || 'unknown'}`;
    },
  });
  return { ipLimiter, userLimiter };
}

/**
 * CORS of the `api` function. The web app sends the company in
 * `X-Company-Id` (checked by bearerAuth against the user's memberships).
 */
export const API_CORS_OPTIONS: CorsOptions = {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key', 'X-API-Secret', 'X-WhatsApp-Number', 'X-Company-Id'],
  credentials: true,
};
