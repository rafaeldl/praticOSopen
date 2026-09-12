import { OrderDetail } from '../../utils/bot-response.utils';
import {
  ORDER_CARD_MIME,
  ORDER_CARD_URI,
  orderCardMeta,
  registerOrderCardResource,
  withOrderCard,
} from '../widgets/order-card';

describe('order card (MCP Apps)', () => {
  it('liga a tool ao resource pelo campo padrao do MCP Apps', () => {
    const meta = orderCardMeta() as { ui: { resourceUri: string } };
    expect(meta.ui.resourceUri).toBe(ORDER_CARD_URI);
  });

  it('mantem o alias do ChatGPT apontando para o mesmo resource', () => {
    expect(orderCardMeta()['openai/outputTemplate']).toBe(ORDER_CARD_URI);
  });

  it('nao declara visibility, para a tool continuar disponivel ao modelo', () => {
    const meta = orderCardMeta() as { ui: Record<string, unknown> };
    expect(meta.ui.visibility).toBeUndefined();
    expect(orderCardMeta()['openai/widgetAccessible']).toBeUndefined();
  });

  it('registra o resource com o mime obrigatorio e o bundle embutido', async () => {
    let read: (() => Promise<any>) | undefined;
    const fakeServer = {
      registerResource: (_name: string, uri: string, _config: unknown, cb: () => Promise<any>) => {
        expect(uri).toBe(ORDER_CARD_URI);
        read = cb;
      },
    };

    registerOrderCardResource(fakeServer);
    const result = await read!();

    expect(ORDER_CARD_MIME).toBe('text/html;profile=mcp-app');
    expect(result.contents[0].mimeType).toBe(ORDER_CARD_MIME);
    expect(result.contents[0].text).toContain('<div id="root">');
  });

  it('mantem o texto completo junto do card', () => {
    const order: Pick<OrderDetail, 'number'> = { number: 42 };
    const result = withOrderCard(order, 'OS #42 — Em andamento');

    expect(result.content[0].text).toBe('OS #42 — Em andamento');
    expect(result.structuredContent).toEqual({ order: { number: 42 } });
  });
});
