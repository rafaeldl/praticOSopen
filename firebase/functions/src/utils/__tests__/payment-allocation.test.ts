import { allocateOldestFirst, spreadPayment, totalOpen } from '../payment-allocation';

describe('payment-allocation', () => {
  const balances = [
    { orderId: 'a', orderNumber: 1, open: 100 },
    { orderId: 'b', orderNumber: 2, open: 0 },
    { orderId: 'c', orderNumber: 3, open: 50.1 },
  ];

  it('soma o que está em aberto em centavos', () => {
    expect(totalOpen([{ open: 0.1 }, { open: 0.2 }])).toBe(0.3);
  });

  it('reparte da mais antiga para a mais nova, limitada ao aberto de cada OS', () => {
    expect(allocateOldestFirst(balances, 120)).toEqual([
      { orderId: 'a', orderNumber: 1, amount: 100 },
      { orderId: 'c', orderNumber: 3, amount: 20 },
    ]);
    expect(allocateOldestFirst(balances, 1000).reduce((s, a) => s + a.amount, 0)).toBe(150.1);
  });

  describe('spreadPayment', () => {
    const allocations = [
      { orderId: 'a', amount: 100 },
      { orderId: 'c', amount: 50 },
    ];

    it('mesmo total: como foi guardado', () => {
      expect(spreadPayment(allocations, 150).map((a) => a.amount)).toEqual([100, 50]);
    });

    it('pago a menos (desconto): da mais antiga, limitado à parte de cada OS', () => {
      expect(spreadPayment(allocations, 120).map((a) => a.amount)).toEqual([100, 20]);
      expect(spreadPayment(allocations, 80).map((a) => a.amount)).toEqual([80, 0]);
    });

    it('pago a mais (juros/multa): o que sobra vai para a última OS', () => {
      expect(spreadPayment(allocations, 153.37).map((a) => a.amount)).toEqual([100, 53.37]);
    });
  });
});
