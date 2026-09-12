import { redactMcpTokenFromPath } from './log-redaction.utils';

describe('redactMcpTokenFromPath', () => {
  it('redacts a normal mcp_ token', () => {
    const result = redactMcpTokenFromPath('/mcp/t/mcp_aabbccdd112233');
    expect(result).toBe('/mcp/t/***');
    expect(result).not.toContain('mcp_aabbccdd112233');
  });

  it('redacts a percent-encoded token that would decode to a valid mcp_ shape', () => {
    // '%6d' decodes to 'm', so this path's params.token would come out as
    // 'mcp_aaaa' after Express decodes it for routing — but req.path itself
    // is never percent-decoded. A fix that only matched the literal
    // 'mcp_' + hex shape would miss this.
    const path = '/mcp/t/%6dcp_aaaabbbbcccc';
    const result = redactMcpTokenFromPath(path);

    expect(result).toBe('/mcp/t/***');
    expect(result).not.toContain('%6dcp_aaaabbbbcccc');
    expect(result).not.toContain('mcp_');
  });

  it('redacts an arbitrary/future token shape, not just mcp_ + hex', () => {
    const result = redactMcpTokenFromPath('/mcp/t/some-future-token-format');
    expect(result).toBe('/mcp/t/***');
  });

  it('leaves unrelated paths untouched', () => {
    expect(redactMcpTokenFromPath('/bot/summary/today')).toBe('/bot/summary/today');
    expect(redactMcpTokenFromPath('/health')).toBe('/health');
  });
});
