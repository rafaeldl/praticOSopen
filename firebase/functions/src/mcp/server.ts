import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { AuthenticatedRequest } from '../models/types';
import { registerReadTools } from './tools/read';

export function buildMcpServer(req: AuthenticatedRequest): McpServer {
  const server = new McpServer({
    name: 'praticos',
    version: '1.0.0',
  });

  registerReadTools(server, { req });

  return server;
}
