// Import from 'zod/v3', not 'zod'. The installed zod@3.25 exports v4 at the
// top level, while @modelcontextprotocol/sdk@1.30 expects zod/v3 types; the
// mismatch fails the build with TS2589 as soon as a tool has an inputSchema.
import { z } from 'zod/v3';
import { McpToolContext } from '../types';
import { callRoute } from '../bridge';
import { formatOrder } from '../format/order';

import botOrdersRoutes from '../../routes/bot/orders.routes';
import botOrdersManagementRoutes from '../../routes/bot/orders-management.routes';
import botCommentsRoutes from '../../routes/bot/comments.routes';
import botEntitiesRoutes from '../../routes/bot/entities.routes';

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

function ok(text: string) {
  return { content: [{ type: 'text' as const, text }] };
}

function fail(body: any) {
  const message = body?.error?.message ?? 'Request failed';
  return { content: [{ type: 'text' as const, text: message }], isError: true };
}

// Every mutation handler in orders-management.routes.ts and orders.routes.ts
// responds via bot-response.utils.ts's buildOrderDetail(), whose return shape
// is `{ order: OrderDetail, formatContext }` (see OrderDetailResponse in
// src/utils/bot-response.utils.ts). Route handlers then do one of:
//   res.json({ success: true, data: detail })                        (update_order, add_order_item)
//   res.json({ success: true, data: { ...detail, updated: true } })  (create_order upsert path)
//   res.json({ success: true, data: { ...detail, previousStatus, newStatus } }) (update_order_status)
// In every case `data.order` is the OrderDetail — there is no other shape to
// guess between, so the unwrap below is exact, not a fallback chain.
function orderResult(body: any) {
  return ok(formatOrder(body.data.order));
}

// The audit log must never carry end-customer personal data (phone, email,
// address) or free text (comment bodies, item/customer descriptions) — those
// belong to the company's customers, not to us, and Cloud Logging has its own
// retention/access rules that were never meant for that data. So this builds
// an explicit allowlist of identifiers instead of logging `args` wholesale:
// a field added to a tool's input later is excluded by default, not leaked
// by default.
function auditWrite(ctx: McpToolContext, tool: string, args: Record<string, unknown>): void {
  const allowed: Record<string, unknown> = {};

  if (typeof args.orderNumber === 'number') allowed.orderNumber = args.orderNumber;
  if (typeof args.type === 'string') allowed.type = args.type;
  if (typeof args.customerId === 'string') allowed.customerId = args.customerId;
  if (typeof args.serviceId === 'string') allowed.serviceId = args.serviceId;
  if (typeof args.productId === 'string') allowed.productId = args.productId;
  if (typeof args.deviceId === 'string') allowed.deviceId = args.deviceId;

  // add_order_item identifies its catalog item as `itemId` + `type`, rather
  // than serviceId/productId directly — resolve it into the same identifier
  // fields so the log stays consistent across tools.
  if (typeof args.itemId === 'string') {
    if (args.type === 'service') allowed.serviceId = args.itemId;
    else if (args.type === 'product') allowed.productId = args.itemId;
  }

  console.log(
    JSON.stringify({
      event: 'mcp_write',
      tool,
      origin: 'mcp',
      companyId: ctx.req.auth?.companyId,
      userId: ctx.req.auth?.userId,
      ...allowed,
    }),
  );
}

export function registerWriteTools(server: any, ctx: McpToolContext): void {
  server.registerTool(
    'create_order',
    {
      title: 'Criar ordem de serviço',
      description:
        'Creates a service order. customerId, deviceId/deviceIds, serviceId and productId MUST come from a previous search call — never invent them. status defaults to quote if omitted (accepts quote, approved or progress only — use update_order_status to move it further). Returns the created order with its customer share link.',
      inputSchema: {
        customerId: z.string(),
        deviceId: z.string().optional(),
        deviceIds: z.array(z.string()).optional(),
        services: z
          .array(
            z.object({
              serviceId: z.string(),
              value: z.number().min(0).optional(),
              description: z.string().max(500).optional(),
            }),
          )
          .optional(),
        products: z
          .array(
            z.object({
              productId: z.string(),
              quantity: z.number().min(1).optional(),
              value: z.number().min(0).optional(),
              description: z.string().max(500).optional(),
            }),
          )
          .optional(),
        scheduledDate: z.string().optional(),
        dueDate: z.string().optional(),
        status: z.enum(['quote', 'approved', 'progress']).optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: false },
    },
    async (args: Record<string, unknown>) => {
      auditWrite(ctx, 'create_order', args);

      // POST orders-management.routes -> /full. Deliberately never forwards an
      // `id` field: the route treats a body with `id` as an upsert onto an
      // existing order, which a tool named "create" must not silently do.
      // update_order already covers editing.
      const result = await callRoute(botOrdersManagementRoutes, {
        method: 'POST',
        path: '/full',
        body: args,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return orderResult(result.body);
    },
  );

  server.registerTool(
    'update_order_status',
    {
      title: 'Mudar status da OS',
      description:
        'Changes the status of a service order (approved, progress, done or canceled). Only valid state transitions are accepted. When moving to done, offer the customer share link to the user.',
      inputSchema: {
        orderNumber: z.number(),
        status: z.enum(['approved', 'progress', 'done', 'canceled']),
      },
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
    },
    async (args: { orderNumber: number; status: string }) => {
      auditWrite(ctx, 'update_order_status', args);

      // PATCH /:number/status lives in orders.routes.ts, NOT
      // orders-management.routes.ts — the two routers are otherwise easy to
      // confuse since both mount under /bot/orders.
      const result = await callRoute(botOrdersRoutes, {
        method: 'PATCH',
        path: `/${args.orderNumber}/status`,
        body: { status: args.status },
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return orderResult(result.body);
    },
  );

  server.registerTool(
    'update_order',
    {
      title: 'Atualizar OS',
      description:
        'Updates the due date, scheduled date or assignee of a service order. At least one field besides orderNumber is required — calling with only orderNumber returns an error. Dates in ISO 8601. Pass null to clear a field.',
      inputSchema: {
        orderNumber: z.number(),
        scheduledDate: z.string().nullable().optional(),
        dueDate: z.string().nullable().optional(),
        assignedTo: z.string().nullable().optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
    },
    async (args: Record<string, unknown>) => {
      auditWrite(ctx, 'update_order', args);

      const { orderNumber, ...patch } = args as { orderNumber: number };
      const result = await callRoute(botOrdersManagementRoutes, {
        method: 'PATCH',
        path: `/${orderNumber}`,
        body: patch,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return orderResult(result.body);
    },
  );

  server.registerTool(
    'add_order_item',
    {
      title: 'Adicionar item à OS',
      description:
        'Adds a service or a product to an existing order. itemId MUST come from a previous search call. quantity applies to products only (minimum 1, default 1 if omitted).',
      inputSchema: {
        orderNumber: z.number(),
        type: z.enum(['service', 'product']),
        itemId: z.string(),
        value: z.number().min(0).optional(),
        quantity: z.number().min(1).optional(),
        description: z.string().max(500).optional(),
        deviceId: z.string().optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: false },
    },
    async (args: {
      orderNumber: number;
      type: 'service' | 'product';
      itemId: string;
      value?: number;
      quantity?: number;
      description?: string;
      deviceId?: string;
    }) => {
      auditWrite(ctx, 'add_order_item', args);

      const isService = args.type === 'service';
      const body: Record<string, unknown> = isService
        ? { serviceId: args.itemId }
        : { productId: args.itemId, quantity: args.quantity };

      if (args.value !== undefined) body.value = args.value;
      if (args.description) body.description = args.description;
      if (args.deviceId) body.deviceId = args.deviceId;

      // POST orders-management.routes -> /:number/services or /:number/products.
      const result = await callRoute(botOrdersManagementRoutes, {
        method: 'POST',
        path: `/${args.orderNumber}/${isService ? 'services' : 'products'}`,
        body,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return orderResult(result.body);
    },
  );

  server.registerTool(
    'add_order_comment',
    {
      title: 'Comentar na OS',
      description:
        'Adds a note to a service order (1 to 2000 characters). Internal by default; set isInternal to false to make it visible to the customer on the share link.',
      inputSchema: {
        orderNumber: z.number(),
        text: z.string().min(1).max(2000),
        isInternal: z.boolean().optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: false },
    },
    async (args: { orderNumber: number; text: string; isInternal?: boolean }) => {
      auditWrite(ctx, 'add_order_comment', args);

      // POST comments.routes -> /:number/comments. Response is a comment
      // record ({ id, text, authorType, authorName, isInternal, createdAt }),
      // not an OrderDetail — unrelated shape to the other five tools, so this
      // doesn't reuse orderResult().
      const result = await callRoute(botCommentsRoutes, {
        method: 'POST',
        path: `/${args.orderNumber}/comments`,
        body: { text: args.text, isInternal: args.isInternal ?? true },
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);
      return ok(`Comentário adicionado à OS #${args.orderNumber}.`);
    },
  );

  server.registerTool(
    'create_entity',
    {
      title: 'Cadastrar cliente, dispositivo, serviço ou produto',
      description:
        "Creates a new record. Call search first to make sure it does not already exist — duplicates are the most common mistake here. Required fields depend on type: customer needs only name (phone, email, address optional); device needs name AND serial (manufacturer, category, description optional); service and product need name AND value.",
      inputSchema: {
        type: z.enum(ENTITY_TYPES),
        name: z.string(),
        phone: z.string().optional(),
        email: z.string().optional(),
        address: z.string().optional(),
        serial: z.string().optional(),
        manufacturer: z.string().optional(),
        category: z.string().optional(),
        description: z.string().optional(),
        value: z.number().optional(),
      },
      annotations: { readOnlyHint: false, destructiveHint: false },
    },
    async (args: { type: EntityType } & Record<string, unknown>) => {
      auditWrite(ctx, 'create_entity', args);

      const { type, ...fields } = args;

      // POST entities.routes -> /entities/{customers|devices|services|products}.
      const result = await callRoute(botEntitiesRoutes, {
        method: 'POST',
        path: `/${ENTITY_PATHS[type]}`,
        body: fields,
        source: ctx.req,
      });

      if (result.status >= 400) return fail(result.body);

      // All four create handlers respond { success, data: {id, name, ...},
      // message: '<Localized "Name" cadastrado>' } — data is never nested
      // further. Prefer the route's own message; it already names the record.
      const created = result.body.data;
      const message =
        typeof result.body.message === 'string'
          ? result.body.message
          : `Cadastrado: ${created?.name ?? created?.id}`;
      return ok(message);
    },
  );
}
