/**
 * Claude on the Anthropic API (docs/AI_ORDER_ASSIST.md).
 *
 * - Key: Secret Manager secret `ANTHROPIC_API_KEY`, bound to the `api` function.
 * - AI_CLAUDE_MODEL  (default claude-sonnet-5-5)
 * - AI_CLAUDE_EFFORT (default low: short extraction, latency matters more than depth)
 *
 * Structured outputs (`output_config.format`) keep the answer on the shared
 * schema. Server-side fallback (`fallbacks: 'default'`) re-runs a request the
 * model declines on another model inside the same call. Claude reads images,
 * not audio: the router sends audio requests to the default provider.
 */

import Anthropic from '@anthropic-ai/sdk';
import type { JsonSchema, LlmProviderClient, LlmRequest } from './llm.client';
import { LlmUnavailableError } from './llm.client';

const DEFAULT_MODEL = 'claude-sonnet-5-5';
const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max'] as const;
type Effort = (typeof EFFORTS)[number];
const TIMEOUT_MS = 45_000;
const MAX_TOKENS = 8_000;
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'] as const;
type ImageType = (typeof IMAGE_TYPES)[number];

function isImageType(mimeType: string): mimeType is ImageType {
  return (IMAGE_TYPES as readonly string[]).includes(mimeType);
}

function effortFromEnv(): Effort {
  const value = process.env.AI_CLAUDE_EFFORT;
  return (EFFORTS as readonly string[]).includes(value ?? '') ? (value as Effort) : 'low';
}

export class ClaudeClient implements LlmProviderClient {
  private client?: Anthropic;

  constructor(
    private readonly apiKey: () => string | undefined = () => process.env.ANTHROPIC_API_KEY,
    private readonly model = process.env.AI_CLAUDE_MODEL || DEFAULT_MODEL,
    private readonly effort: Effort = effortFromEnv(),
  ) {}

  supportsMedia(mimeType: string): boolean {
    return isImageType(mimeType);
  }

  private sdk(): Anthropic {
    if (this.client) return this.client;
    const apiKey = this.apiKey();
    if (!apiKey) throw new LlmUnavailableError('missing ANTHROPIC_API_KEY');
    this.client = new Anthropic({ apiKey, timeout: TIMEOUT_MS, maxRetries: 1 });
    return this.client;
  }

  async generateJson(request: LlmRequest): Promise<string> {
    const images = request.media.flatMap((m) =>
      isImageType(m.mimeType)
        ? [{ type: 'image' as const, source: { type: 'base64' as const, media_type: m.mimeType, data: m.data } }]
        : [],
    );
    if (images.length !== request.media.length) throw new LlmUnavailableError('unsupported media for Claude');

    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await this.sdk().beta.messages.create({
        model: this.model,
        max_tokens: MAX_TOKENS,
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        system: request.systemPrompt,
        output_config: {
          effort: this.effort,
          format: { type: 'json_schema', schema: request.responseSchema as JsonSchema },
        },
        messages: [{ role: 'user', content: [...images, { type: 'text', text: request.userText }] }],
      });
    } catch (error) {
      if (error instanceof LlmUnavailableError) throw error;
      // Never log the body or message: it may echo the user's text.
      const status = error instanceof Anthropic.APIError ? error.status : undefined;
      throw new LlmUnavailableError(`model request failed${status ? ` (HTTP ${status})` : ''}`);
    }

    if (response.stop_reason === 'refusal') throw new LlmUnavailableError('model declined');
    if (response.stop_reason === 'max_tokens') throw new LlmUnavailableError('model answer truncated');
    const text = response.content.map((b) => (b.type === 'text' ? b.text : '')).join('');
    if (!text) throw new LlmUnavailableError('empty model answer');
    return text;
  }
}
