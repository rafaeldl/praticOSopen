import { formatOrder, formatOrderList, formatOrderPhotos, truncate } from '../format/order';
import { formatSummary, formatRevenue, formatSearchResult, formatEntityList, formatPendingItems } from '../format/list';
import type { TodaySummaryData } from '../../services/analytics.service';
import type { RevenueMetrics, PendingOrder, OrderStatus, PendingItems } from '../../models/types';
import type { OrderDetail } from '../../utils/bot-response.utils';
import type { CustomerResult, DeviceResult, CatalogResult } from '../../routes/bot/unified-search.routes';

// Test fixtures with proper types from real API responses
const orderDetail: OrderDetail = {
  number: 42,
  status: 'progress' as OrderStatus,
  customer: { name: 'João Silva', phone: '11999999999' },
  device: null,
  devices: [{ name: 'Fiat Uno', serial: 'ABC1D23' }],
  deviceCount: 1,
  services: [{ name: 'Troca de óleo', value: 150, deviceId: null }],
  products: [{ name: 'Filtro', quantity: 2, value: 40, deviceId: null }],
  total: 230,
  discount: 0,
  paidAmount: 0,
  dueDate: undefined,
  scheduledDate: undefined,
  createdAt: '2026-09-12T10:00:00Z',
  rating: undefined,
  photosCount: 1,
  mainPhotoUrl: 'https://example.com/photo.jpg',
  shareUrl: 'https://praticos.web.app/q/ST_x',
};

const todaySummary: TodaySummaryData = {
  totalOrders: 10,
  toApprove: 3,
  dueToday: 2,
  unpaidAmount: 500,
  revenue: 1200,
  ordersCreatedToday: 5,
};

const revenueMetrics: RevenueMetrics = {
  total: 12500,
  paid: 9000,
  unpaid: 3500,
  discount: 0,
};

const pendingOrder: PendingOrder = {
  id: 'order-1',
  number: 42,
  customer: { id: 'cust-1', name: 'João Silva', phone: '11999999999' },
  device: { id: 'dev-1', name: 'Fiat Uno', serial: 'ABC1D23' },
  total: 230,
  remainingBalance: 100,
  dueDate: '2026-09-15',
  createdAt: '2026-09-12T10:00:00Z',
};

const pendingItems: PendingItems = {
  toApprove: [
    { ...pendingOrder, number: 1, total: 100, remainingBalance: 100 },
    { ...pendingOrder, number: 2, total: 200, remainingBalance: 50 },
  ],
  dueToday: [
    { ...pendingOrder, number: 3, total: 150, remainingBalance: 75, dueDate: '2026-09-12' },
  ],
  unpaid: [
    { ...pendingOrder, number: 4, total: 300, remainingBalance: 300 },
    { ...pendingOrder, number: 5, total: 250, remainingBalance: 250 },
    { ...pendingOrder, number: 6, total: 180, remainingBalance: 180 },
  ],
  overdue: [
    { ...pendingOrder, number: 7, total: 500, remainingBalance: 500, daysOverdue: 5 },
  ],
};

const customerResult: CustomerResult = {
  exact: { id: 'c1', name: 'João Silva', phone: '11999999999' },
  suggestions: [],
  available: null,
};

const deviceResult: DeviceResult = {
  exact: null,
  suggestions: [],
  available: [
    { id: 'd1', name: 'Fiat Uno', serial: 'ABC123' },
    { id: 'd2', name: 'Honda Civic', serial: 'DEF456' },
  ],
};

const catalogResult: CatalogResult = {
  results: [],
  available: [
    { id: 's1', name: 'Troca de óleo', value: 150 },
    { id: 's2', name: 'Limpeza', value: 100 },
  ],
};

describe('formatOrder', () => {
  it('inclui número, cliente e total', () => {
    const text = formatOrder(orderDetail);
    expect(text).toContain('OS #42');
    expect(text).toContain('João Silva');
    expect(text).toContain('230');
  });

  it('traduz o status para português', () => {
    expect(formatOrder(orderDetail)).toContain('Em andamento');
  });

  it('inclui o link de compartilhamento quando existe', () => {
    expect(formatOrder(orderDetail)).toContain('https://praticos.web.app/q/ST_x');
  });

  it('não quebra quando a OS não tem dispositivo', () => {
    const text = formatOrder({ ...orderDetail, devices: [] });
    expect(text).toContain('OS #42');
  });

  it('traduz status quote para Orçamento', () => {
    const text = formatOrder({ ...orderDetail, status: 'quote' as OrderStatus });
    expect(text).toContain('Orçamento');
  });

  it('inclui a foto de capa e contagem quando existirem', () => {
    const text = formatOrder({
      ...orderDetail,
      coverPhotoUrl: 'https://storage.googleapis.com/bucket/photo1.jpg',
      photosCount: 3,
    });
    expect(text).toContain('Foto de capa: https://storage.googleapis.com/bucket/photo1.jpg');
    expect(text).toContain('Fotos anexadas: 3 (use `list_order_photos` para ver todas)');
  });
});

describe('formatOrderPhotos', () => {
  it('avisa quando não há fotos', () => {
    expect(formatOrderPhotos([])).toContain('Nenhuma foto anexada a esta OS.');
    expect(formatOrderPhotos(null as any)).toContain('Nenhuma foto anexada a esta OS.');
  });

  it('formata lista de fotos com ID, URL e descrição', () => {
    const photos = [
      {
        id: 'photo-1',
        url: 'https://storage.googleapis.com/test/photo-1.jpg',
        description: 'Dano na lateral direita',
        createdBy: 'Carlos',
      },
      {
        id: 'photo-2',
        url: 'https://storage.googleapis.com/test/photo-2.jpg',
        createdBy: 'Carlos',
      },
    ];
    const text = formatOrderPhotos(photos);
    expect(text).toContain('Fotos da OS (2):');
    expect(text).toContain('**Foto `photo-1`** — Dano na lateral direita (por Carlos): https://storage.googleapis.com/test/photo-1.jpg');
    expect(text).toContain('**Foto `photo-2`** (por Carlos): https://storage.googleapis.com/test/photo-2.jpg');
  });
});

describe('formatOrderList', () => {
  it('gera uma linha por OS', () => {
    const text = formatOrderList([orderDetail, { ...orderDetail, number: 43 }]);
    expect(text).toContain('#42');
    expect(text).toContain('#43');
  });

  it('avisa quando o estado é vazio', () => {
    expect(formatOrderList([])).toContain('Nenhuma OS');
  });

  it('formata pending orders corretamente', () => {
    const text = formatOrderList([pendingOrder as any, pendingOrder as any]);
    expect(text).toContain('#42');
    expect(text).toContain('João Silva');
  });

  it('mostra omitted count', () => {
    const text = formatOrderList([orderDetail], 5);
    expect(text).toContain('+5 não exibidas');
  });
});

describe('truncate', () => {
  it('corta no limite e informa o que sobrou', () => {
    const result = truncate([1, 2, 3, 4, 5], 3);
    expect(result.items).toEqual([1, 2, 3]);
    expect(result.omitted).toBe(2);
  });

  it('não corta quando cabe', () => {
    const result = truncate([1, 2], 3);
    expect(result.omitted).toBe(0);
  });
});

describe('formatSummary', () => {
  it('mostra os campos do dia corretamente', () => {
    const text = formatSummary(todaySummary);
    expect(text).toContain('5');
    expect(text).toContain('1.200');
    expect(text).toContain('Resumo de hoje');
  });
});

describe('formatRevenue', () => {
  it('mostra o faturamento do período com unpaid', () => {
    const text = formatRevenue(revenueMetrics);
    expect(text).toContain('12.500');
    expect(text).toContain('9.000');
    expect(text).toContain('3.500');
  });
});

describe('formatSearchResult', () => {
  it('formata resultados de busca com exact match', () => {
    const result = { customer: customerResult };
    const text = formatSearchResult(result);
    expect(text).toContain('customer');
    expect(text).toContain('João Silva');
  });

  it('mostra available como alternativas quando não há exact/suggestions', () => {
    const result = { device: deviceResult };
    const text = formatSearchResult(result);
    expect(text).toContain('d1');
    expect(text).toContain('Fiat Uno');
    expect(text).toContain('(alternativas)');
  });

  it('avisa quando nada é encontrado', () => {
    const result = {};
    expect(formatSearchResult(result)).toContain('Nada encontrado');
  });

  it('trunca resultados em 20 por tipo', () => {
    const items = Array.from({ length: 30 }, (_, i) => ({
      id: `id-${i}`,
      name: `Item ${i}`,
    }));
    const result: Record<string, CatalogResult> = {
      service: {
        results: items,
        available: null,
      },
    };
    const text = formatSearchResult(result);
    expect(text).toContain('+10');
  });

  it('respeita limite customizado até 50', () => {
    const items = Array.from({ length: 60 }, (_, i) => ({
      id: `id-${i}`,
      name: `Item ${i}`,
    }));
    const result: Record<string, CatalogResult> = {
      service: {
        results: items,
        available: null,
      },
    };
    const text = formatSearchResult(result, 50);
    expect(text).toContain('+10');
  });

  it('limita máximo em 50 mesmo se passar valor maior', () => {
    const items = Array.from({ length: 100 }, (_, i) => ({
      id: `id-${i}`,
      name: `Item ${i}`,
    }));
    const result: Record<string, CatalogResult> = {
      service: {
        results: items,
        available: null,
      },
    };
    const text = formatSearchResult(result, 100);
    expect(text).toContain('+50');
  });

  it('usa catalogResult typed fixture', () => {
    const result = { service: catalogResult };
    const text = formatSearchResult(result);
    expect(text).toContain('(alternativas)');
    expect(text).toContain('Troca de óleo');
  });
});

describe('formatEntityList', () => {
  it('formata lista de entidades simples', () => {
    const items = [
      { id: 's1', name: 'Troca de óleo', value: 150 },
      { id: 's2', name: 'Limpeza', value: 100 },
    ];
    const text = formatEntityList('serviço', items);
    expect(text).toContain('s1');
    expect(text).toContain('Troca de óleo');
    expect(text).toContain('150');
  });

  it('mostra serial para dispositivos', () => {
    const items = [{ id: 'd1', name: 'Fiat Uno', serial: 'ABC123' }];
    const text = formatEntityList('dispositivo', items);
    expect(text).toContain('ABC123');
  });

  it('avisa quando a lista está vazia', () => {
    expect(formatEntityList('serviço', [])).toContain('Nenhum registro');
  });

  it('mostra omitted count', () => {
    const text = formatEntityList('serviço', [{ id: 's1', name: 'Serviço' }], 5);
    expect(text).toContain('+5 não exibidos');
  });
});

describe('formatPendingItems', () => {
  it('formata cada bucket de items pendentes', () => {
    const text = formatPendingItems(pendingItems);
    expect(text).toContain('Aguardando aprovação');
    expect(text).toContain('Vence hoje');
    expect(text).toContain('Não pago');
    expect(text).toContain('Vencido');
  });

  it('mostra orders em cada bucket', () => {
    const text = formatPendingItems(pendingItems);
    expect(text).toContain('#1');
    expect(text).toContain('#3');
    expect(text).toContain('#4');
    expect(text).toContain('#7');
  });

  it('omite buckets vazios', () => {
    const empty: PendingItems = {
      toApprove: [],
      dueToday: [],
      unpaid: [pendingOrder],
      overdue: [],
    };
    const text = formatPendingItems(empty);
    expect(text).toContain('Não pago');
    expect(text).not.toContain('Aguardando aprovação');
  });

  it('trunca em 20 items por bucket', () => {
    const manyOrders = Array.from({ length: 25 }, (_, i) => ({
      ...pendingOrder,
      number: i + 100,
    }));
    const text = formatPendingItems({
      toApprove: manyOrders,
      dueToday: [],
      unpaid: [],
      overdue: [],
    });
    expect(text).toContain('+5');
  });

  it('avisa quando nenhum item pendente', () => {
    const empty: PendingItems = {
      toApprove: [],
      dueToday: [],
      unpaid: [],
      overdue: [],
    };
    expect(formatPendingItems(empty)).toContain('Nenhum item pendente');
  });

  it('mostra dispositivo singular corretamente', () => {
    const text = formatPendingItems(pendingItems);
    expect(text).toContain('Fiat Uno');
  });
});
