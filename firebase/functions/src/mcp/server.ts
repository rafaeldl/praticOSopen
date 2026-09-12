import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { AuthenticatedRequest } from '../models/types';
import { callRoute } from './bridge';
import summaryRoutes from '../routes/bot/summary.routes';

export function buildMcpServer(req: AuthenticatedRequest): McpServer {
  const server = new McpServer({
    name: 'praticos',
    version: '1.0.0',
  });

  server.registerTool(
    'get_today_summary',
    {
      title: 'Resumo do dia',
      description:
        "Returns today's summary for the company: new orders, completed orders and revenue. Use it when the user asks how the day is going.",
      inputSchema: {},
      annotations: { readOnlyHint: true },
    },
    async () => {
      const result = await callRoute(summaryRoutes, {
        method: 'GET',
        path: '/today',
        source: req,
      });

      return {
        content: [{ type: 'text' as const, text: JSON.stringify(result.body) }],
      };
    },
  );

  return server;
}
