const create = jest.fn();

jest.mock('@anthropic-ai/sdk', () => {
  class APIError extends Error {
    constructor(public status: number) {
      super('api error');
    }
  }
  const Anthropic = jest.fn().mockImplementation(() => ({ beta: { messages: { create } } }));
  Object.assign(Anthropic, { APIError });
  return { __esModule: true, default: Anthropic };
});

import Anthropic from '@anthropic-ai/sdk';
import { ClaudeClient } from '../claude.client';
import { LlmRequest, LlmUnavailableError } from '../llm.client';

const request: LlmRequest = {
  systemPrompt: 'system',
  userText: 'capô 500',
  media: [{ mimeType: 'image/jpeg', data: 'abc' }],
  responseSchema: { type: 'object', additionalProperties: false, properties: {} },
};

function answer(text: string, stop_reason = 'end_turn') {
  return { stop_reason, content: [{ type: 'thinking', thinking: '' }, { type: 'text', text }] };
}

beforeEach(() => create.mockReset());

describe('ClaudeClient', () => {
  it('sends system, image, text and the JSON schema, and returns the text', async () => {
    create.mockResolvedValue(answer('{"items":[]}'));
    const client = new ClaudeClient(() => 'sk-test', 'claude-sonnet-5-5', 'low');

    await expect(client.generateJson(request)).resolves.toBe('{"items":[]}');

    const body = create.mock.calls[0][0];
    expect(body.model).toBe('claude-sonnet-5-5');
    expect(body.system).toBe('system');
    expect(body.fallbacks).toBe('default');
    expect(body.output_config).toEqual({
      effort: 'low',
      format: { type: 'json_schema', schema: request.responseSchema },
    });
    expect(body.messages[0].content).toEqual([
      { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: 'abc' } },
      { type: 'text', text: 'capô 500' },
    ]);
  });

  it('reads images only', () => {
    const client = new ClaudeClient(() => 'sk-test');
    expect(client.supportsMedia('image/png')).toBe(true);
    expect(client.supportsMedia('audio/mp4')).toBe(false);
  });

  it('fails as unavailable without a key, on refusal, truncation and API errors', async () => {
    await expect(new ClaudeClient(() => undefined).generateJson(request)).rejects.toBeInstanceOf(LlmUnavailableError);

    const client = new ClaudeClient(() => 'sk-test');
    create.mockResolvedValueOnce(answer('', 'refusal'));
    await expect(client.generateJson(request)).rejects.toThrow('model declined');
    create.mockResolvedValueOnce(answer('{"items"', 'max_tokens'));
    await expect(client.generateJson(request)).rejects.toThrow('truncated');
    create.mockRejectedValueOnce(new (Anthropic as unknown as { APIError: new (s: number) => Error }).APIError(529));
    await expect(client.generateJson(request)).rejects.toThrow('HTTP 529');
  });
});
