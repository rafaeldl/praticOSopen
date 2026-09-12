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

  it('nao vaza dado do cliente que o card nao desenha (telefone, foto)', () => {
    const order: OrderDetail = {
      number: 7734,
      status: 'progress',
      customer: { name: 'Cliente Improvavel', phone: '+55 11 91234-5678' },
      device: { name: 'iPhone 12', serial: 'ABC123' },
      devices: [{ name: 'iPhone 12', serial: 'ABC123' }],
      deviceCount: 1,
      services: [{ name: 'Troca de tela', value: 350, deviceId: 'dev-1' }],
      products: [{ name: 'Pelicula', quantity: 1, value: 40, deviceId: 'dev-1' }],
      total: 390,
      discount: 0,
      paidAmount: 0,
      dueDate: '2026-09-20',
      scheduledDate: '2026-09-15',
      createdAt: '2026-09-12T10:00:00Z',
      rating: undefined,
      photosCount: 3,
      mainPhotoUrl: 'https://storage.googleapis.com/praticos/tenants/comp1/orders/7734/photos/main.jpg',
      shareUrl: 'https://praticos.web.app/q/tok123',
    };

    const result = withOrderCard(order, 'OS #7734 — Em andamento');
    const serialized = JSON.stringify(result.structuredContent);

    expect(serialized).not.toContain('91234-5678');
    expect(serialized).not.toContain('storage.googleapis.com');
    expect(serialized).not.toContain('mainPhotoUrl');
    expect(serialized).not.toContain('phone');

    expect(result.structuredContent).toEqual({
      order: {
        number: 7734,
        status: 'progress',
        total: 390,
        shareUrl: 'https://praticos.web.app/q/tok123',
        customer: { name: 'Cliente Improvavel' },
        devices: [{ name: 'iPhone 12', serial: 'ABC123' }],
        services: [{ name: 'Troca de tela', value: 350 }],
        products: [{ name: 'Pelicula', value: 40, quantity: 1 }],
      },
    });
  });
});
