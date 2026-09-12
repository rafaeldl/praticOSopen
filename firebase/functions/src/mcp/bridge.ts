import { Router } from 'express';
import { AuthenticatedRequest } from '../models/types';

export interface CallRouteOptions {
  method: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  path: string;
  body?: unknown;
  query?: Record<string, string>;
  source: AuthenticatedRequest;
}

export interface RouteResult {
  status: number;
  body: any;
}

// Safety net so a handler that never responds (bug, dangling promise, an
// async error thrown outside a try/catch) cannot hang an MCP tool call
// forever. Real /bot handlers always respond or call next(), so this should
// never fire in practice.
const RESPONSE_TIMEOUT_MS = 25000;

/**
 * Dispatches a call to an Express router in-process.
 *
 * The MCP tools reuse the /bot route handlers instead of reimplementing their
 * orchestration. This avoids a network hop and keeps a single source of truth
 * for business rules.
 */
export function callRoute(
  router: Router,
  options: CallRouteOptions,
): Promise<RouteResult> {
  return new Promise((resolve) => {
    let settled = false;
    const settle = (status: number, body: any) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ status, body });
    };

    const timer = setTimeout(() => {
      settle(504, {
        error: { code: 'GATEWAY_TIMEOUT', message: `No response for ${options.method} ${options.path}` },
      });
    }, RESPONSE_TIMEOUT_MS);
    // Don't let this timer keep the process (or a test run) alive.
    if (typeof (timer as any).unref === 'function') {
      (timer as any).unref();
    }

    const req: any = {
      method: options.method,
      url: options.path,
      originalUrl: options.path,
      baseUrl: '',
      path: options.path,
      params: {},
      query: options.query ?? {},
      body: options.body ?? {},
      headers: {},
      get: (name: string) => (name.toLowerCase() === 'host' ? 'praticos.web.app' : undefined),
      header: (name: string) => (name.toLowerCase() === 'host' ? 'praticos.web.app' : undefined),
      auth: options.source.auth,
      userContext: options.source.userContext,
    };

    const res: any = {
      statusCode: 200,
      headersSent: false,
      status(code: number) {
        this.statusCode = code;
        return this;
      },
      set() {
        return this;
      },
      setHeader() {
        return this;
      },
      json(payload: any) {
        this.headersSent = true;
        settle(this.statusCode, payload);
        return this;
      },
      send(payload: any) {
        this.headersSent = true;
        settle(this.statusCode, payload);
        return this;
      },
      end() {
        this.headersSent = true;
        settle(this.statusCode, undefined);
        return this;
      },
    };

    // next() reached means no route matched, or a handler errored.
    router(req, res, (err?: any) => {
      if (err) {
        settle(500, { error: { code: 'INTERNAL_ERROR', message: String(err?.message ?? err) } });
        return;
      }
      settle(404, { error: { code: 'NOT_FOUND', message: `No route for ${options.method} ${options.path}` } });
    });
  });
}
