/**
 * Provider-neutral LLM client used by the AI assistant (docs/AI_ORDER_ASSIST.md).
 *
 * Callers build one [LlmRequest] (system prompt, user text, photos/audio and a
 * standard JSON Schema for the answer) and get back the raw JSON text. Each
 * provider adapts the request to its own API:
 * - `gemini` → [VertexGeminiClient] (gemini.client.ts), Vertex AI in São Paulo
 * - `claude` → [ClaudeClient] (claude.client.ts), Anthropic API
 *
 * [LlmRouter] picks the provider per request: `request.provider` (from
 * `companies/{cid}/settings/ai.provider`), else `AI_PROVIDER`, else `gemini`.
 * A provider that can't read a part (Claude has no audio input) hands the
 * request to the default provider instead of failing.
 *
 * Tests inject a fake [LlmClient]; the real clients never run in unit tests.
 */

export const LLM_PROVIDERS = ['gemini', 'claude'] as const;
export type LlmProvider = (typeof LLM_PROVIDERS)[number];

export function isLlmProvider(value: unknown): value is LlmProvider {
  return typeof value === 'string' && (LLM_PROVIDERS as readonly string[]).includes(value);
}

export interface LlmInlinePart {
  mimeType: string;
  /** Base64 without the data: prefix. */
  data: string;
}

/**
 * JSON Schema subset understood by every provider: object/array/string/number,
 * `enum`, `required`, `additionalProperties: false` and nullable as
 * `type: ['number', 'null']`. No numeric/string constraints.
 */
export type JsonSchema = Record<string, unknown>;

export interface LlmRequest {
  systemPrompt: string;
  userText: string;
  media: LlmInlinePart[];
  /** Schema the answer must follow. */
  responseSchema: JsonSchema;
  /** Preferred provider; the router falls back to the default when unset. */
  provider?: LlmProvider;
}

export interface LlmClient {
  /** Returns the raw JSON text produced by the model. */
  generateJson(request: LlmRequest): Promise<string>;
}

/** A concrete provider: knows which media types it can read. */
export interface LlmProviderClient extends LlmClient {
  supportsMedia(mimeType: string): boolean;
}

export class LlmUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'LlmUnavailableError';
  }
}

export function defaultProvider(env: NodeJS.ProcessEnv = process.env): LlmProvider {
  return isLlmProvider(env.AI_PROVIDER) ? env.AI_PROVIDER : 'gemini';
}

export class LlmRouter implements LlmClient {
  constructor(
    private readonly clients: Partial<Record<LlmProvider, () => LlmProviderClient>>,
    private readonly fallback: LlmProvider = defaultProvider(),
  ) {}

  /** Provider that will answer [request] (exposed for tests and logs). */
  resolve(request: LlmRequest): LlmProvider {
    const wanted = request.provider ?? this.fallback;
    const client = this.clients[wanted]?.();
    if (!client) return this.fallback;
    const readsAll = request.media.every((m) => client.supportsMedia(m.mimeType));
    return readsAll ? wanted : this.fallback;
  }

  async generateJson(request: LlmRequest): Promise<string> {
    const provider = this.resolve(request);
    const client = this.clients[provider]?.();
    if (!client) throw new LlmUnavailableError(`provider ${provider} not configured`);
    return client.generateJson(request);
  }
}
