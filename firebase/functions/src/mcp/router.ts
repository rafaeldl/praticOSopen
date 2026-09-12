import { Router, Response } from 'express';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { AuthenticatedRequest } from '../models/types';
import { mcpAuth } from './auth';
import { buildMcpServer } from './server';

const router: Router = Router();

router.post(
  '/t/:token',
  mcpAuth,
  async (req: AuthenticatedRequest, res: Response) => {
    // The connector endpoint must never be cached by the Hosting CDN.
    res.setHeader('Cache-Control', 'no-store');

    // The SDK's transport (via @hono/node-server) calls res.writeHead(status,
    // headers) with its own 'Cache-Control: no-cache, no-transform' for SSE
    // responses. Per Node's writeHead/setHeader precedence rules, a header
    // passed to writeHead() wins over one set via setHeader(), which would
    // silently overwrite the 'no-store' header above. Strip it from
    // writeHead's headers so our setHeader value is the one that ships.
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
    // this app's own `req.auth` shape (used by mcpAuth). We don't rely on the
    // SDK's auth handling here, so the cast is safe.
    await transport.handleRequest(req as any, res, req.body);
  },
);

export default router;
