import {
  buildLoggableHeaders,
  isPayloadLoggingEnabled,
  redactMcpTokenFromPath,
  redactSensitivePath,
  shouldLogPayload,
} from './log-redaction.utils';

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

  it('redacts when the mount path uses a different case (Express routes case-insensitively)', () => {
    expect(redactMcpTokenFromPath('/MCP/T/mcp_aabbccdd112233')).toBe('/MCP/T/***');
  });

  it('leaves unrelated paths untouched', () => {
    expect(redactMcpTokenFromPath('/bot/summary/today')).toBe('/bot/summary/today');
    expect(redactMcpTokenFromPath('/health')).toBe('/health');
  });
});

describe('redactSensitivePath', () => {
  const shareToken = 'ST_3f2b1c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

  it('still redacts the MCP token', () => {
    expect(redactSensitivePath('/mcp/t/mcp_aabbccdd112233')).toBe('/mcp/t/***');
  });

  it('redacts the share token on every public order route', () => {
    for (const suffix of ['', '/', '/approve', '/reject', '/comments', '/rating']) {
      const result = redactSensitivePath(`/public/orders/${shareToken}${suffix}`);
      expect(result).toBe(`/public/orders/***${suffix}`);
      expect(result).not.toContain('ST_');
    }
  });

  it('redacts a percent-encoded or unexpected-shape public token (matches by position, not shape)', () => {
    expect(redactSensitivePath('/public/orders/%53T_abc/approve')).toBe('/public/orders/***/approve');
    expect(redactSensitivePath('/public/orders/whatever')).toBe('/public/orders/***');
  });

  it('redacts a public token when the mount path uses a different case', () => {
    const result = redactSensitivePath(`/Public/ORDERS/${shareToken}`);
    expect(result).toBe('/Public/ORDERS/***');
    expect(result).not.toContain('ST_');
  });

  it('redacts the share token on the revoke routes (API key, app and bot)', () => {
    expect(redactSensitivePath(`/v1/orders/order123/share/${shareToken}`)).toBe('/v1/orders/order123/share/***');
    expect(redactSensitivePath(`/v1/app/orders/order123/share/${shareToken}`)).toBe('/v1/app/orders/order123/share/***');
    expect(redactSensitivePath(`/bot/orders/42/share/${shareToken}`)).toBe('/bot/orders/42/share/***');
  });

  it('keeps the non-secret parts of share routes readable', () => {
    expect(redactSensitivePath('/v1/orders/order123/share')).toBe('/v1/orders/order123/share');
    expect(redactSensitivePath('/bot/orders/42/share')).toBe('/bot/orders/42/share');
    expect(redactSensitivePath('/public/orders')).toBe('/public/orders');
  });

  it('redacts the invite token on the app invite routes', () => {
    expect(redactSensitivePath('/v1/app/invites/INV_AB12CD34')).toBe('/v1/app/invites/***');
    expect(redactSensitivePath('/v1/app/invites/INV_AB12CD34/accept')).toBe('/v1/app/invites/***/accept');
    expect(redactSensitivePath('/V1/APP/Invites/INV_AB12CD34')).toBe('/V1/APP/Invites/***');
  });

  it('keeps the literal /pending invite route readable', () => {
    expect(redactSensitivePath('/v1/app/invites/pending')).toBe('/v1/app/invites/pending');
    expect(redactSensitivePath('/v1/app/invites')).toBe('/v1/app/invites');
    // Only the exact literal is spared — a token that merely starts with it is not.
    expect(redactSensitivePath('/v1/app/invites/pendingXYZ')).toBe('/v1/app/invites/***');
  });

  it('redacts the invite code on the bot invite delete route, keeping literal routes readable', () => {
    expect(redactSensitivePath('/bot/invite/INV_AB12CD34')).toBe('/bot/invite/***');
    for (const literal of ['create', 'accept', 'list']) {
      expect(redactSensitivePath(`/bot/invite/${literal}`)).toBe(`/bot/invite/${literal}`);
    }
  });

  it('leaves unrelated paths untouched', () => {
    expect(redactSensitivePath('/bot/summary/today')).toBe('/bot/summary/today');
    expect(redactSensitivePath('/v1/orders/order123')).toBe('/v1/orders/order123');
    expect(redactSensitivePath('/health')).toBe('/health');
  });
});

describe('buildLoggableHeaders', () => {
  it('never prints the API key or secret, only whether they were sent', () => {
    const result = buildLoggableHeaders({
      'x-api-key': 'pk_live_supersecretkey',
      'x-api-secret': 'sk_live_supersecretvalue',
    });
    const serialized = JSON.stringify(result);

    expect(result['x-api-key']).toBe('[REDACTED]');
    expect(result['x-api-secret']).toBe('[REDACTED]');
    expect(serialized).not.toContain('supersecret');
  });

  it('masks the WhatsApp number down to its last 4 digits', () => {
    const result = buildLoggableHeaders({ 'x-whatsapp-number': '+5511987654321' });
    expect(result['x-whatsapp-number']).toBe('***4321');
    expect(JSON.stringify(result)).not.toContain('98765');
  });

  it('fully masks a WhatsApp number too short to keep a suffix', () => {
    expect(buildLoggableHeaders({ 'x-whatsapp-number': '1234' })['x-whatsapp-number']).toBe('***');
  });

  it('handles repeated headers (string[]) without leaking any value', () => {
    const result = buildLoggableHeaders({
      'x-api-key': ['key-one', 'key-two'],
      'x-whatsapp-number': ['+5511987654321', '+5511911112222'],
    });
    const serialized = JSON.stringify(result);

    expect(result['x-api-key']).toBe('[REDACTED]');
    expect(serialized).not.toContain('key-one');
    expect(serialized).not.toContain('key-two');
    expect(serialized).not.toContain('98765');
    expect(serialized).not.toContain('91111');
  });

  it('hides the bearer token and keeps content-type', () => {
    const result = buildLoggableHeaders({
      authorization: 'Bearer eyJhbGciOiJSUzI1NiJ9.payload.sig',
      'content-type': 'application/json',
    });

    expect(result.authorization).toBe('Bearer [HIDDEN]');
    expect(result['content-type']).toBe('application/json');
    expect(JSON.stringify(result)).not.toContain('eyJ');
  });

  it('omits headers that were not sent', () => {
    const result = buildLoggableHeaders({});
    expect(JSON.parse(JSON.stringify(result))).toEqual({});
  });
});

describe('shouldLogPayload', () => {
  it('disallows body/response logging for /mcp/t/<token>', () => {
    expect(shouldLogPayload('/mcp/t/mcp_aabbccdd112233')).toBe(false);
    expect(shouldLogPayload('/mcp/t/anything-at-all')).toBe(false);
  });

  it('disallows logging for the bare /mcp path too', () => {
    expect(shouldLogPayload('/mcp')).toBe(false);
  });

  it('disallows logging for /mcp regardless of case (Express routes case-insensitively)', () => {
    expect(shouldLogPayload('/MCP/t/mcp_aabbccdd112233')).toBe(false);
  });

  it('disallows logging for public magic-link routes (customer free text, order details)', () => {
    expect(shouldLogPayload('/public/orders/ST_abc')).toBe(false);
    expect(shouldLogPayload('/public/orders/ST_abc/comments')).toBe(false);
    expect(shouldLogPayload('/public/orders/ST_abc/reject')).toBe(false);
    expect(shouldLogPayload('/PUBLIC/orders/ST_abc/rating')).toBe(false);
  });

  it('disallows logging for share-link management routes, whose responses carry the token', () => {
    expect(shouldLogPayload('/v1/orders/order123/share')).toBe(false);
    expect(shouldLogPayload('/v1/app/orders/order123/share')).toBe(false);
    expect(shouldLogPayload('/bot/orders/42/share')).toBe(false);
    expect(shouldLogPayload('/bot/orders/42/share/ST_abc')).toBe(false);
  });

  it('keeps logging enabled for normal API paths', () => {
    expect(shouldLogPayload('/bot/summary/today')).toBe(true);
    expect(shouldLogPayload('/v1/orders')).toBe(true);
    expect(shouldLogPayload('/health')).toBe(true);
  });

  it('does not false-positive on a path that merely starts with the letters "mcp" or "public"', () => {
    expect(shouldLogPayload('/mcpxyz/whatever')).toBe(true);
    expect(shouldLogPayload('/publicity')).toBe(true);
    expect(shouldLogPayload('/v1/orders/order123/shared-notes')).toBe(true);
  });
});

describe('isPayloadLoggingEnabled', () => {
  const emulator = { FUNCTIONS_EMULATOR: 'true' };

  it('never logs payloads in production, on any route', () => {
    // Bot bodies carry LT_/INV_ tokens and phones, /v1/customers queries carry
    // phone/email, and most responses carry customer data.
    for (const path of ['/bot/link', '/bot/invite/accept', '/v1/customers', '/v1/app/invites/pending', '/bot/orders/42']) {
      expect(isPayloadLoggingEnabled(path, {})).toBe(false);
      expect(isPayloadLoggingEnabled(path, { FUNCTIONS_EMULATOR: 'false' })).toBe(false);
    }
  });

  it('logs payloads in the local emulator for ordinary routes', () => {
    expect(isPayloadLoggingEnabled('/bot/summary/today', emulator)).toBe(true);
    expect(isPayloadLoggingEnabled('/v1/orders', emulator)).toBe(true);
  });

  it('still skips the always-sensitive routes in the emulator', () => {
    expect(isPayloadLoggingEnabled('/mcp/t/mcp_aabbccdd112233', emulator)).toBe(false);
    expect(isPayloadLoggingEnabled('/public/orders/ST_abc', emulator)).toBe(false);
    expect(isPayloadLoggingEnabled('/bot/orders/42/share', emulator)).toBe(false);
  });
});
