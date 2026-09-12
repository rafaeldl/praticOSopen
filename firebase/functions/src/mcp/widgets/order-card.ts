import { OrderDetail } from '../../utils/bot-response.utils';
import { ORDER_CARD_BUNDLE } from './bundle';

export const ORDER_CARD_URI = 'ui://praticos/order-card';

// MCP Apps requires exactly this mime type (spec ext-apps 2026-01-26, l.268).
export const ORDER_CARD_MIME = 'text/html;profile=mcp-app';

const HTML = `<!doctype html>
<html>
  <head><meta charset="utf-8" /></head>
  <body style="margin:0">
    <div id="root"></div>
    <script>${ORDER_CARD_BUNDLE}</script>
  </body>
</html>`;

export function registerOrderCardResource(server: any): void {
  server.registerResource(
    'order-card',
    ORDER_CARD_URI,
    { title: 'Card da ordem de serviço', mimeType: ORDER_CARD_MIME },
    async () => ({
      contents: [{ uri: ORDER_CARD_URI, mimeType: ORDER_CARD_MIME, text: HTML }],
    }),
  );
}

/**
 * Tool _meta linking an order tool to the card.
 *
 * `ui.resourceUri` is the MCP Apps standard and works in ChatGPT and Claude.
 * `openai/outputTemplate` is ChatGPT's compatibility alias, kept alongside for
 * older ChatGPT runtimes. `ui.visibility` is deliberately omitted: its default,
 * ["model", "app"], keeps the tool callable by both the model and the card.
 */
export function orderCardMeta(): Record<string, unknown> {
  return {
    ui: { resourceUri: ORDER_CARD_URI },
    'openai/outputTemplate': ORDER_CARD_URI,
  };
}

export interface OrderCardData {
  number?: number;
  status?: string;
  total?: number;
  shareUrl?: string | null;
  customer?: { name?: string };
  devices?: { name?: string; serial?: string }[];
  services?: { name?: string; value?: number }[];
  products?: { name?: string; value?: number; quantity?: number }[];
}

/**
 * Projects an order down to only the fields the card draws.
 *
 * `structuredContent` is not part of the model's context per the MCP Apps
 * spec, but some hosts forward it anyway — so an `OrderDetail` passed
 * through unfiltered would leak `customer.phone`, `mainPhotoUrl` and any
 * other field on the record to that host. This builds a brand new object
 * field by field (never copies `order` and deletes keys), so a field added
 * to `OrderDetail` later is excluded by default instead of leaked by
 * default. `shareUrl` is kept: Task 11 uses it for a "copy customer link"
 * button on the card.
 */
function toCardData(order: unknown): OrderCardData {
  const o = (order ?? {}) as Partial<OrderDetail> & Record<string, unknown>;

  const data: OrderCardData = {
    number: o.number as number | undefined,
    status: o.status as string | undefined,
    total: o.total as number | undefined,
    shareUrl: o.shareUrl as string | null | undefined,
  };

  if (o.customer && typeof o.customer === 'object') {
    const customer = o.customer as { name?: string };
    data.customer = { name: customer.name };
  }

  if (Array.isArray(o.devices)) {
    data.devices = (o.devices as { name?: string; serial?: string }[]).map((d) => ({
      name: d?.name,
      serial: d?.serial,
    }));
  }

  if (Array.isArray(o.services)) {
    data.services = (o.services as { name?: string; value?: number }[]).map((s) => ({
      name: s?.name,
      value: s?.value,
    }));
  }

  if (Array.isArray(o.products)) {
    data.products = (o.products as { name?: string; value?: number; quantity?: number }[]).map(
      (p) => ({ name: p?.name, value: p?.value, quantity: p?.quantity }),
    );
  }

  return data;
}

/**
 * Wraps an order tool result. The text must stand on its own: a host without
 * MCP Apps support shows only the text.
 */
export function withOrderCard(order: unknown, text: string) {
  return {
    content: [{ type: 'text' as const, text }],
    structuredContent: { order: toCardData(order) },
    _meta: orderCardMeta(),
  };
}
