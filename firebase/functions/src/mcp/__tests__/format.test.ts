import { formatOrder, formatOrderList, truncate } from '../format/order';
import { formatSummary, formatRevenue } from '../format/list';

const order = {
  number: 42,
  status: 'progress',
  customer: { name: 'João Silva' },
  devices: [{ name: 'Fiat Uno', serial: 'ABC1D23' }],
  services: [{ name: 'Troca de óleo', value: 150 }],
  products: [{ name: 'Filtro', quantity: 2, value: 40 }],
  total: 230,
  shareUrl: 'https://praticos.web.app/q/ST_x',
};

describe('formatOrder', () => {
  it('inclui número, cliente e total', () => {
    const text = formatOrder(order);
    expect(text).toContain('OS #42');
    expect(text).toContain('João Silva');
    expect(text).toContain('230');
  });

  it('traduz o status para português', () => {
    expect(formatOrder(order)).toContain('Em andamento');
  });

  it('inclui o link de compartilhamento quando existe', () => {
    expect(formatOrder(order)).toContain('https://praticos.web.app/q/ST_x');
  });

  it('não quebra quando a OS não tem dispositivo', () => {
    const text = formatOrder({ ...order, devices: [] });
    expect(text).toContain('OS #42');
  });
});

describe('formatOrderList', () => {
  it('gera uma linha por OS', () => {
    const text = formatOrderList([order, { ...order, number: 43 }]);
    expect(text).toContain('#42');
    expect(text).toContain('#43');
  });

  it('avisa quando o estado é vazio', () => {
    expect(formatOrderList([])).toContain('Nenhuma OS');
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
  it('mostra os três números do dia', () => {
    const text = formatSummary({ newOrders: 3, completedOrders: 2, revenue: 500 });
    expect(text).toContain('3');
    expect(text).toContain('2');
    expect(text).toContain('500');
  });
});

describe('formatRevenue', () => {
  it('mostra o total do período', () => {
    const text = formatRevenue({ total: 12500, paid: 9000, pending: 3500 });
    expect(text).toContain('12.500');
  });
});
