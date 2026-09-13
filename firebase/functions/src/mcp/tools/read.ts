// Import from the 'zod/v3' subpath, not the top-level 'zod' export: the SDK's
// registerTool types (server/zod-compat.ts) structurally match against
// `zod/v3`'s ZodTypeAny. With zod 3.25.x, the top-level 'zod' export no
// longer aligns with that type closely enough, and TS blows up with
// "TS2589: Type instantiation is excessively deep and possibly infinite" the
// moment inputSchema has any non-empty shape. Verified with an isolated
// tsc repro against this repo's installed zod (3.25.76) and SDK (1.30.0).
import { z } from 'zod/v3';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { McpToolContext } from '../types';
import { callRoute } from '../bridge';
import { formatOrder, formatOrderList, formatOrderPhotos, truncate } from '../format/order';
import { orderCardMeta, withOrderCard } from '../widgets/order-card';
import {
  formatSummary,
  formatRevenue,
  formatPendingItems,
  formatSearchResult,
  formatEntityList,
} from '../format/list';

import unifiedSearchRoutes from '../../routes/bot/unified-search.routes';
import botOrdersRoutes from '../../routes/bot/orders.routes';
import botOrdersManagementRoutes from '../../routes/bot/orders-management.routes';
import botPhotosRoutes from '../../routes/bot/photos.routes';
import summaryRoutes from '../../routes/bot/summary.routes';
import botAnalyticsRoutes from '../../routes/bot/analytics.routes';
import botEntitiesRoutes from '../../routes/bot/entities.routes';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;

function clampLimit(limit?: number): number {
  if (!limit || limit < 1) return DEFAULT_LIMIT;
  return Math.min(limit, MAX_LIMIT);
}

function ok(text: string) {
  return { content: [{ type: 'text' as const, text }] };
}

function fail(body: any) {
  const message = body?.error?.message ?? 'Request failed';
  return { content: [{ type: 'text' as const, text: message }], isError: true };
}

const ENTITY_TYPES = ['customer', 'device', 'service', 'product'] as const;
type EntityType = (typeof ENTITY_TYPES)[number];

// botEntitiesRoutes is mounted at '/bot' (index.ts), not '/bot/entities', so
// the router's own paths carry the 'entities/' segment.
const ENTITY_PATHS: Record<EntityType, string> = {
  customer: 'entities/customers',
  device: 'entities/devices',
  service: 'entities/services',
  product: 'entities/products',
};

export function registerReadTools(server: McpServer, ctx: McpToolContext): void {
  server.registerTool(
    'search',
    {
      title: 'Buscar cliente, dispositivo, serviço ou produto',
      description:
        'Resolves customers, devices, services and products into IDs. ALWAYS call this before create_order or add_order_item — the IDs returned here are the only valid ones. Accepts several terms at once; prefer one call with arrays over several calls.',
      inputSchema: {
        customer: z.union([z.string(), z.array(z.string())]).optional(),
        customerPhone: z.union([z.string(), z.array(z.string())]).optional(),
        device: z.union([z.string(), z.array(z.string())]).optional(),
        deviceSerial: z.union([z.string(), z.array(z.string())]).optional(),
        service: z.union([z.string(), z.array(z.string())]).optional(),
        product: z.union([z.string(), z.array(z.string())]).optional(),
      },
      annotations: { readOnlyHint: true },
    },
    async (args: Record<string, unknown>) => {
      // POST routes/bot/unified-search.routes -> /unified.
      // Response: { success, data: { customer?, device?, service?, product? } }.
      const result = await callRoute(unifiedSearchRoutes, {
        method: 'POST',
        path: '/unified',
        body: args,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(formatSearchResult(result.body.data));
    },
  );

  server.registerTool(
    'list_orders',
    {
      title: 'Listar ordens de serviço',
      description:
        'Lists service orders, optionally filtered by status. Use get_order for the full detail of a single one.',
      inputSchema: {
        status: z
          .enum(['quote', 'approved', 'progress', 'done', 'canceled'])
          .optional(),
        limit: z.number().optional(),
      },
      annotations: { readOnlyHint: true },
    },
    async (args: { status?: string; limit?: number }) => {
      const limit = clampLimit(args.limit);
      const query: Record<string, string> = { limit: String(limit) };
      if (args.status) query.status = args.status;

      // GET routes/bot/orders.routes -> /list.
      // Response: { success, data: { count, orders: [...] } }.
      const result = await callRoute(botOrdersRoutes, {
        method: 'GET',
        path: '/list',
        query,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);

      const orders: any[] = result.body.data.orders;
      const { items, omitted } = truncate(orders, limit);
      return ok(formatOrderList(items, omitted));
    },
  );

  server.registerTool(
    'get_order',
    {
      title: 'Detalhes da ordem de serviço',
      description:
        'Returns the full detail of one service order by its number: customer, devices, services, products, total and the customer share link.',
      inputSchema: { orderNumber: z.number() },
      annotations: { readOnlyHint: true },
      _meta: orderCardMeta(),
    },
    async (args: { orderNumber: number }) => {
      // GET routes/bot/orders-management.routes -> /:number/details
      // (NOT orders.routes — that router has no /:number/details route).
      // Response: { success, data: { order: OrderDetail, formatContext } }.
      const result = await callRoute(botOrdersManagementRoutes, {
        method: 'GET',
        path: `/${args.orderNumber}/details`,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      const order = result.body.data.order;
      return withOrderCard(order, formatOrder(order));
    },
  );

  server.registerTool(
    'get_today_summary',
    {
      title: 'Resumo do dia',
      description:
        "Returns today's summary: new orders, completed orders and revenue. Use when the user asks how the day is going.",
      inputSchema: {},
      annotations: { readOnlyHint: true },
    },
    async () => {
      // GET routes/bot/summary.routes -> /today.
      // Response: { success, data: { data: TodaySummaryData } } — summary.routes
      // wraps the service payload in a second `data` layer.
      const result = await callRoute(summaryRoutes, {
        method: 'GET',
        path: '/today',
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(formatSummary(result.body.data.data));
    },
  );

  server.registerTool(
    'get_pending_orders',
    {
      title: 'OS pendentes',
      description: 'Returns the service orders still open, grouped by status.',
      inputSchema: {},
      annotations: { readOnlyHint: true },
    },
    async () => {
      // GET routes/bot/summary.routes -> /pending.
      // Response: { success, data: { data: PendingItems } } — same double
      // `data` wrapping as /today. PendingItems is four arrays (toApprove,
      // dueToday, unpaid, overdue), not a single order list, so this uses
      // formatPendingItems rather than formatOrderList.
      const result = await callRoute(summaryRoutes, {
        method: 'GET',
        path: '/pending',
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(formatPendingItems(result.body.data.data));
    },
  );

  server.registerTool(
    'get_revenue',
    {
      title: 'Faturamento',
      description:
        'Returns revenue for a period: total, received and outstanding. Dates in YYYY-MM-DD. Without dates, returns the current month.',
      inputSchema: {
        startDate: z.string().optional(),
        endDate: z.string().optional(),
      },
      annotations: { readOnlyHint: true },
    },
    async (args: { startDate?: string; endDate?: string }) => {
      const query: Record<string, string> = {};
      if (args.startDate) query.startDate = args.startDate;
      if (args.endDate) query.endDate = args.endDate;

      // GET routes/bot/analytics.routes -> /financial.
      // Response: { success, data: { summary: { ..., revenue: RevenueMetrics, ... } } }.
      const result = await callRoute(botAnalyticsRoutes, {
        method: 'GET',
        path: '/financial',
        query,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(formatRevenue(result.body.data.summary.revenue));
    },
  );

  server.registerTool(
    'list_entities',
    {
      title: 'Listar cadastros',
      description:
        'Lists registered customers, devices, services or products. For resolving a specific name into an ID, prefer search.',
      inputSchema: {
        type: z.enum(ENTITY_TYPES),
        q: z.string().optional(),
        limit: z.number().optional(),
      },
      annotations: { readOnlyHint: true },
    },
    async (args: { type: EntityType; q?: string; limit?: number }) => {
      const limit = clampLimit(args.limit);
      const query: Record<string, string> = { limit: String(limit) };
      if (args.q) query.q = args.q;

      // GET routes/bot/entities.routes, mounted at '/bot' — its own paths
      // carry the 'entities/' segment (e.g. /entities/customers).
      // Response: { success, data: [...] } — data is the array directly,
      // not { data: { items: [...] } }.
      const result = await callRoute(botEntitiesRoutes, {
        method: 'GET',
        path: `/${ENTITY_PATHS[args.type]}`,
        query,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);

      const items: any[] = result.body.data;
      const { items: shown, omitted } = truncate(items, limit);
      return ok(formatEntityList(args.type, shown, omitted));
    },
  );

  server.registerTool(
    'list_order_photos',
    {
      title: 'Listar fotos da OS',
      description:
        'Lists all photos attached to a service order, including their direct URLs, upload date, author and descriptions.',
      inputSchema: { orderNumber: z.number() },
      annotations: { readOnlyHint: true },
    },
    async (args: { orderNumber: number }) => {
      // GET routes/bot/photos.routes -> /:number/photos.
      // Response: { success, data: { photos: [...], count } }.
      const result = await callRoute(botPhotosRoutes, {
        method: 'GET',
        path: `/${args.orderNumber}/photos`,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(formatOrderPhotos(result.body.data.photos));
    },
  );
}
