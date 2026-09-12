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

/**
 * Wraps an order tool result. The text must stand on its own: a host without
 * MCP Apps support shows only the text.
 */
export function withOrderCard(order: unknown, text: string) {
  return {
    content: [{ type: 'text' as const, text }],
    structuredContent: { order },
    _meta: orderCardMeta(),
  };
}
