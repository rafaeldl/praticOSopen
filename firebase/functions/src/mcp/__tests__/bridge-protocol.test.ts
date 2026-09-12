import {
  classifyMessage,
  isAcknowledgedHostRequest,
  buildHostRequestReply,
} from '../../../widgets/src/bridge-protocol';

describe('bridge-protocol: classifyMessage', () => {
  it('classifies a response whose id matches a pending request', () => {
    const isPending = (id: number) => id === 7;
    const result = classifyMessage({ jsonrpc: '2.0', id: 7, result: { ok: true } }, isPending);

    expect(result).toEqual({ kind: 'response', id: 7 });
  });

  it('classifies an error response the same way (id matches, no method)', () => {
    const isPending = (id: number) => id === 3;
    const result = classifyMessage({ jsonrpc: '2.0', id: 3, error: { code: -1 } }, isPending);

    expect(result).toEqual({ kind: 'response', id: 3 });
  });

  it('does NOT classify a host request as a response even when its id collides with a pending id', () => {
    // Both the View and the host mint ids from their own independent
    // counters starting at 1, so a host `ping` can carry the same numeric
    // id as one of our still-pending tools/call requests. Before this fix,
    // "id matches pending" alone was enough to resolve that pending
    // request's promise with `undefined` — which made a successful write
    // look like a failure to the card. The presence of `method` is what
    // must veto that.
    const isPending = (id: number) => id === 1;
    const result = classifyMessage({ jsonrpc: '2.0', id: 1, method: 'ping' }, isPending);

    expect(result).not.toEqual(expect.objectContaining({ kind: 'response' }));
    expect(result).toEqual({ kind: 'hostRequest', id: 1, method: 'ping', params: undefined });
  });

  it('classifies `ping` as a hostRequest', () => {
    const result = classifyMessage({ jsonrpc: '2.0', id: 5, method: 'ping' }, () => false);

    expect(result).toEqual({ kind: 'hostRequest', id: 5, method: 'ping', params: undefined });
  });

  it('classifies `ui/resource-teardown` as a hostRequest, carrying params', () => {
    const result = classifyMessage(
      { jsonrpc: '2.0', id: 9, method: 'ui/resource-teardown', params: { reason: 'closed' } },
      () => false,
    );

    expect(result).toEqual({
      kind: 'hostRequest',
      id: 9,
      method: 'ui/resource-teardown',
      params: { reason: 'closed' },
    });
  });

  it('routes `ui/notifications/tool-result` as a notification (no id)', () => {
    const result = classifyMessage(
      { jsonrpc: '2.0', method: 'ui/notifications/tool-result', params: { order: { number: 42 } } },
      () => false,
    );

    expect(result).toEqual({
      kind: 'notification',
      method: 'ui/notifications/tool-result',
      params: { order: { number: 42 } },
    });
  });

  it('ignores a message with the wrong jsonrpc version', () => {
    expect(classifyMessage({ jsonrpc: '1.0', id: 1, result: {} }, () => true)).toEqual({ kind: 'ignore' });
  });

  it('ignores null/undefined messages', () => {
    expect(classifyMessage(null, () => true)).toEqual({ kind: 'ignore' });
    expect(classifyMessage(undefined, () => true)).toEqual({ kind: 'ignore' });
  });

  it('ignores a message with no method and an id that is not pending', () => {
    const result = classifyMessage({ jsonrpc: '2.0', id: 99, result: {} }, () => false);
    expect(result).toEqual({ kind: 'ignore' });
  });
});

describe('bridge-protocol: isAcknowledgedHostRequest', () => {
  it('acknowledges ping and ui/resource-teardown', () => {
    expect(isAcknowledgedHostRequest('ping')).toBe(true);
    expect(isAcknowledgedHostRequest('ui/resource-teardown')).toBe(true);
  });

  it('does not acknowledge unrelated methods', () => {
    expect(isAcknowledgedHostRequest('ui/notifications/tool-result')).toBe(false);
    expect(isAcknowledgedHostRequest('tools/call')).toBe(false);
  });
});

describe('bridge-protocol: buildHostRequestReply', () => {
  it('builds an empty-result JSON-RPC reply for the given id', () => {
    expect(buildHostRequestReply(9)).toEqual({ jsonrpc: '2.0', id: 9, result: {} });
  });
});
