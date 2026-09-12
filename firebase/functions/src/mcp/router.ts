import { NextFunction, Request, Response, Router } from 'express';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { AuthenticatedRequest } from '../models/types';
import { mcpAuth } from './auth';
import { buildMcpServer } from './server';

const router: Router = Router();

// The connector endpoint must never be cached by the Hosting CDN. Set at the
// top of the router chain, before mcpAuth, so it also lands on the 401
// mcpAuth returns for an invalid/expired token — not only on a successful
// tool call. `no-transform` is included alongside `no-store` because the
// SDK's own SSE responses rely on it; `no-store` alone doesn't imply it.
//
// This is one of two complementary mechanisms: a `/mcp/**` entry in
// firebase.json's hosting.headers sets the same directive at the CDN edge,
// covering requests that never reach this function at all (e.g. the 429 the
// rate limiter in src/index.ts returns before the router is even mounted).
export function noStoreHeader(_req: Request, res: Response, next: NextFunction): void {
  res.setHeader('Cache-Control', 'no-store, no-transform');
  next();
}

// The SDK's transport (via @hono/node-server) calls res.writeHead(status,
// headers) with its own 'Cache-Control: no-cache, no-transform' for SSE
// responses. Per Node's writeHead/setHeader precedence rules, a header
// passed to writeHead() wins over one set earlier via setHeader(), which
// would silently overwrite the value noStoreHeader just set. Strip
// Cache-Control from writeHead's headers so our setHeader value is the one
// that actually ships.
export function preserveCacheControl(_req: Request, res: Response, next: NextFunction): void {
  const originalWriteHead = res.writeHead.bind(res);
  res.writeHead = ((statusCode: number, arg2?: unknown, arg3?: unknown) => {
    const headers = (typeof arg2 === 'string' ? arg3 : arg2) as
      | Record<string, unknown>
      | undefined;
    if (headers) {
      for (const key of Object.keys(headers)) {
        if (key.toLowerCase() === 'cache-control') {
          delete headers[key];
        }
      }
    }
    return typeof arg2 === 'string'
      ? originalWriteHead(statusCode, arg2, headers as never)
      : originalWriteHead(statusCode, headers as never);
  }) as typeof res.writeHead;
  next();
}

router.use(noStoreHeader, preserveCacheControl);

router.post(
  '/t/:token',
  mcpAuth,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const server = buildMcpServer(req);
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: undefined, // stateless
      });

      res.on('close', () => {
        void transport.close();
        void server.close();
      });

      await server.connect(transport);
      // The SDK's `req.auth` (AuthInfo, for OAuth) collides structurally with
      // this app's own `req.auth` shape (used by mcpAuth). We don't rely on
      // the SDK's auth handling here, so the cast is safe.
      await transport.handleRequest(req as any, res, req.body);
    } catch (error) {
      // Express 4 does not forward a rejected async handler to error
      // middleware, so without this catch a throw here (e.g. a malformed
      // tool schema registered in buildMcpServer) hangs the request until
      // the bridge timeout and raises an unhandled rejection. Log only the
      // error — never req.path/req.params, which carry the connection token.
      console.error('mcp handler error:', error);
      if (!res.headersSent) {
        res.status(500).json({
          jsonrpc: '2.0',
          error: { code: -32603, message: 'Internal server error' },
          id: null,
        });
      } else {
        res.end();
      }
    }
  },
);

export default router;
