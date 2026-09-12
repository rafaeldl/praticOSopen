import { formatOrder, formatOrderList, truncate } from '../format/order';
import { formatSummary, formatRevenue, formatSearchResult, formatEntityList } from '../format/list';
import type { TodaySummaryData } from '../../services/analytics.service';
import type { RevenueMetrics, PendingOrder, OrderStatus } from '../../models/types';

// Test fixtures with proper types from real API responses
const orderDetail = {
  number: 42,
  status: 'progress' as OrderStatus,
  customer: { name: 'João Silva', phone: '11999999999' },
  devices: [{ name: 'Fiat Uno', serial: 'ABC1D23' }],
  services: [{ name: 'Troca de óleo', value: 150, deviceId: null }],
  products: [{ name: 'Filtro', quantity: 2, value: 40, deviceId: null }],
  total: 230,
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
    const result = {
      customer: {
        exact: { id: 'c1', name: 'João Silva', phone: '11999999999' },
        suggestions: [],
        available: null,
      },
    };
    const text = formatSearchResult(result);
    expect(text).toContain('customer');
    expect(text).toContain('João Silva');
  });

  it('mostra available como alternativas quando não há exact/suggestions', () => {
    const result = {
      device: {
        exact: null,
        suggestions: [],
        available: [
          { id: 'd1', name: 'Fiat Uno', serial: 'ABC123' },
          { id: 'd2', name: 'Honda Civic', serial: 'DEF456' },
        ],
      },
    };
    const text = formatSearchResult(result);
    expect(text).toContain('d1');
    expect(text).toContain('Fiat Uno');
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
    const result = {
      service: {
        results: items,
        available: null,
      },
    };
    const text = formatSearchResult(result);
    expect(text).toContain('+10');
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
