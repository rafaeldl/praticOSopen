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

  it('declara color-scheme claro/escuro e cor de texto com fallback', async () => {
    let read: (() => Promise<any>) | undefined;
    registerOrderCardResource({ registerResource: (_n: string, _u: string, _c: unknown, cb: () => Promise<any>) => (read = cb) });
    const html: string = (await read!()).contents[0].text;
    const head = html.slice(0, html.indexOf('<script>'));

    expect(head).toContain('color-scheme: light dark');
    expect(head).toMatch(/--color-text-primary:/);
    expect(head).toMatch(/color: var\(--color-text-primary\)/);
  });

  it('nao estica html/body/#root na altura do frame (quebraria o size-changed)', async () => {
    let read: (() => Promise<any>) | undefined;
    registerOrderCardResource({ registerResource: (_n: string, _u: string, _c: unknown, cb: () => Promise<any>) => (read = cb) });
    const html: string = (await read!()).contents[0].text;
    const head = html.slice(0, html.indexOf('<script>'));

    expect(head).not.toMatch(/height\s*:\s*100%/);
    expect(head).not.toMatch(/100vh/);
  });

  it('declara CSP e dominio do widget no resource (lista e leitura)', async () => {
    let config: any;
    let read: (() => Promise<any>) | undefined;
    registerOrderCardResource({
      registerResource: (_n: string, _u: string, c: unknown, cb: () => Promise<any>) => {
        config = c;
        read = cb;
      },
    });
    const content = (await read!()).contents[0];

    for (const meta of [config._meta, content._meta]) {
      expect(meta.ui.csp).toEqual({
        connectDomains: [],
        resourceDomains: ['https://storage.googleapis.com'],
      });
      expect(meta['openai/widgetCSP']).toEqual({
        connect_domains: [],
        resource_domains: ['https://storage.googleapis.com'],
      });
      expect(meta['openai/widgetDomain']).toBe('https://praticos.web.app');
    }
  });

  it('mantem o texto completo junto do card', () => {
    const order: Pick<OrderDetail, 'number'> = { number: 42 };
    const result = withOrderCard(order, 'OS #42 — Em andamento');

    expect(result.content[0].text).toBe('OS #42 — Em andamento');
    expect(result.structuredContent).toEqual({ order: { number: 42 } });
  });

  it('nao vaza dado do cliente que o card nao desenha (telefone, rota interna do bot)', () => {
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
      mainPhotoUrl: '/bot/orders/7734/photos/main.jpg',
      coverPhotoUrl: 'https://storage.googleapis.com/praticos/tenants/comp1/orders/7734/photos/main.jpg',
      shareUrl: 'https://praticos.web.app/q/tok123',
    };

    const result = withOrderCard(order, 'OS #7734 — Em andamento');
    const serialized = JSON.stringify(result.structuredContent);

    expect(serialized).not.toContain('91234-5678');
    expect(serialized).not.toContain('mainPhotoUrl');
    expect(serialized).not.toContain('phone');

    expect(result.structuredContent).toEqual({
      order: {
        number: 7734,
        status: 'progress',
        total: 390,
        shareUrl: 'https://praticos.web.app/q/tok123',
        coverPhotoUrl: 'https://storage.googleapis.com/praticos/tenants/comp1/orders/7734/photos/main.jpg',
        photosCount: 3,
        customer: { name: 'Cliente Improvavel' },
        devices: [{ name: 'iPhone 12', serial: 'ABC123' }],
        services: [{ name: 'Troca de tela', value: 350 }],
        products: [{ name: 'Pelicula', value: 40, quantity: 1 }],
      },
    });
  });
});
