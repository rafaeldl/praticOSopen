import { NextFunction, Request, Response } from 'express';

/**
 * Global (per instance) cap on requests whose token hasn't authenticated on
 * this instance recently — the ones that cost a Firestore lookup in mcpAuth
 * and can come from a flood of forged tokens.
 *
 * Why not an IP-keyed limiter: /mcp/** reaches the function through the
 * Firebase Hosting rewrite and has no trustworthy client IP (see the MCP rate
 * limiting comment in src/index.ts). Why not only the token-keyed limiter: an
 * attacker rotating forged tokens gets a fresh per-token budget each request.
 *
 * Tokens that authenticated recently skip the cap, so a flood of invalid
 * tokens exhausts the budget for unknown tokens only, and connected ChatGPT /
 * Claude clients keep working. The budget is spent when the request enters,
 * not when mcpAuth answers 401, so a client that disconnects before the
 * lookup finishes is still counted.
 *
 * State lives in memory, like express-rate-limit's default store: each Cloud
 * Run instance has its own budget and its own set of known tokens.
 */
export interface UnknownTokenGuardOptions {
  /** Length of the fixed window, in ms. */
  windowMs: number;
  /** Requests with an unknown token allowed per window, per instance. */
  maxUnknownPerWindow: number;
  /** How long a token stays known after it last authenticated, in ms. */
  knownTokenTtlMs: number;
  /** Upper bound on remembered tokens; the least recently authenticated goes first. */
  maxKnownTokens: number;
  now?: () => number;
}

export interface UnknownTokenGuard {
  /** Mount before mcpAuth. */
  limitUnknownTokens: (req: Request, res: Response, next: NextFunction) => void;
  /** Mount right after mcpAuth, so it only runs for tokens that authenticated. */
  rememberToken: (req: Request, res: Response, next: NextFunction) => void;
}

function tokenOf(req: Request): string | undefined {
  const token = req.params.token;
  return typeof token === 'string' && token ? token : undefined;
}

export function createUnknownTokenGuard(options: UnknownTokenGuardOptions): UnknownTokenGuard {
  const { windowMs, maxUnknownPerWindow, knownTokenTtlMs, maxKnownTokens, now = Date.now } = options;

  let windowStart = now();
  let unknownCount = 0;
  // Map iteration follows insertion order and rememberToken re-inserts on
  // every authentication, so the first key is the least recently used.
  const knownTokens = new Map<string, number>();

  const isKnown = (token: string, at: number): boolean => {
    const expiresAt = knownTokens.get(token);
    if (expiresAt === undefined) return false;
    if (expiresAt <= at) {
      knownTokens.delete(token);
      return false;
    }
    return true;
  };

  const limitUnknownTokens = (req: Request, res: Response, next: NextFunction): void => {
    const at = now();
    const token = tokenOf(req);

    if (token && isKnown(token, at)) {
      next();
      return;
    }

    if (at - windowStart >= windowMs) {
      windowStart = at;
      unknownCount = 0;
    }

    if (unknownCount >= maxUnknownPerWindow) {
      res.setHeader('Retry-After', String(Math.ceil((windowStart + windowMs - at) / 1000)));
      res.status(429).json({
        jsonrpc: '2.0',
        error: { code: -32000, message: 'Too many requests' },
        id: null,
      });
      return;
    }

    unknownCount += 1;
    next();
  };

  const rememberToken = (req: Request, _res: Response, next: NextFunction): void => {
    const token = tokenOf(req);
    if (!token) {
      next();
      return;
    }
    knownTokens.delete(token);
    knownTokens.set(token, now() + knownTokenTtlMs);
    if (knownTokens.size > maxKnownTokens) {
      const oldest = knownTokens.keys().next().value;
      if (oldest !== undefined) knownTokens.delete(oldest);
    }
    next();
  };

  return { limitUnknownTokens, rememberToken };
}
