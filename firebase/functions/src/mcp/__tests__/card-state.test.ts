import {
  availableActions,
  applyStatusResult,
  writeFailed,
  WRITE_FAILED_MESSAGE,
  OrderData,
} from '../../../widgets/src/card-state';

function order(status: string, shareUrl?: string | null): OrderData {
  return { number: 42, status, total: 100, shareUrl: shareUrl ?? null };
}

describe('card-state: availableActions', () => {
  it.each([
    ['quote', { approve: true, markDone: true, copyLink: false }],
    ['approved', { approve: false, markDone: true, copyLink: false }],
    ['progress', { approve: false, markDone: true, copyLink: false }],
    ['done', { approve: false, markDone: false, copyLink: false }],
    ['canceled', { approve: false, markDone: false, copyLink: false }],
  ] as const)('sem shareUrl, status=%s', (status, expected) => {
    expect(availableActions(order(status))).toEqual(expected);
  });

  it.each([
    ['quote', { approve: true, markDone: true, copyLink: true }],
    ['approved', { approve: false, markDone: true, copyLink: true }],
    ['progress', { approve: false, markDone: true, copyLink: true }],
    ['done', { approve: false, markDone: false, copyLink: true }],
    ['canceled', { approve: false, markDone: false, copyLink: true }],
  ] as const)('com shareUrl, status=%s', (status, expected) => {
    expect(availableActions(order(status, 'https://praticos.web.app/q/tok123'))).toEqual(expected);
  });
});

describe('card-state: applyStatusResult', () => {
  it('aprovacao com sucesso e structuredContent.order atualiza o pedido e as acoes', () => {
    const current = order('quote'); // shareUrl: null
    // The server's returned order carries a shareUrl the current order does
    // not have — this only ends up on `outcome.order` if applyStatusResult
    // actually reads `structuredContent.order`, not if it falls back to
    // spreading `current` optimistically (that path could not invent a
    // shareUrl out of nothing). This is what the lock-proof below breaks.
    const returned = order('approved', 'https://praticos.web.app/q/tok123');
    const result = { structuredContent: { order: returned } };

    const outcome = applyStatusResult(current, result, 'approved');

    expect(outcome.order.status).toBe('approved');
    expect(outcome.order.shareUrl).toBe('https://praticos.web.app/q/tok123');
    expect(outcome.error).toBeFalsy();
    expect(availableActions(outcome.order)).toEqual({ approve: false, markDone: true, copyLink: true });
  });

  it('sucesso sem structuredContent.order aplica o status pedido de forma otimista', () => {
    const current = order('quote');
    const result = {};

    const outcome = applyStatusResult(current, result, 'approved');

    expect(outcome.order.status).toBe('approved');
    expect(outcome.error).toBeFalsy();
  });

  it('isError: true mantem o pedido intacto e mostra mensagem de erro', () => {
    const current = order('quote');
    const result = { isError: true, structuredContent: { order: order('approved') } };

    const outcome = applyStatusResult(current, result, 'approved');

    expect(outcome.order).toEqual(current);
    expect(outcome.error).toBe(true);
    expect(outcome.message).toBe(WRITE_FAILED_MESSAGE);
    // Failure must not remove any button the order's real status still allows.
    expect(availableActions(outcome.order)).toEqual(availableActions(current));
  });

  it('promise rejeitada (writeFailed) mantem o pedido intacto e mostra mensagem de erro', () => {
    const current = order('quote');

    const outcome = writeFailed(current);

    expect(outcome.order).toEqual(current);
    expect(outcome.error).toBe(true);
    expect(outcome.message).toBe(WRITE_FAILED_MESSAGE);
    expect(availableActions(outcome.order)).toEqual(availableActions(current));
  });
});
