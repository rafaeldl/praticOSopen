/**
 * Gemini on Vertex AI with the function's own service account (Application
 * Default Credentials): there is no API key to store. The project needs the
 * Vertex AI API enabled and the runtime service account with
 * `roles/aiplatform.user` (see docs/AI_ORDER_ASSIST.md).
 *
 * Model and region come from environment variables:
 * - AI_GEMINI_MODEL    (default gemini-2.5-flash)
 * - AI_VERTEX_LOCATION (default southamerica-east1, São Paulo — dados ficam no Brasil)
 */

import * as admin from 'firebase-admin';
import type { JsonSchema, LlmProviderClient, LlmRequest } from './llm.client';
import { LlmUnavailableError } from './llm.client';

const DEFAULT_MODEL = 'gemini-2.5-flash';
const DEFAULT_LOCATION = 'southamerica-east1';
const TIMEOUT_MS = 45_000;

function projectId(): string | undefined {
  return process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || admin.app().options.projectId;
}

/**
 * Converts the shared JSON Schema to Gemini's responseSchema (OpenAPI subset):
 * upper-case types, `nullable` instead of a `null` type, no
 * `additionalProperties`.
 */
export function toGeminiSchema(schema: JsonSchema): JsonSchema {
  const out: JsonSchema = {};
  const rawType = schema.type;
  const types = Array.isArray(rawType) ? rawType : rawType !== undefined ? [rawType] : [];
  const concrete = types.filter((t) => t !== 'null');
  if (concrete.length > 0) out.type = String(concrete[0]).toUpperCase();
  if (types.includes('null')) out.nullable = true;
  if (schema.enum) out.enum = schema.enum;
  if (schema.properties) {
    out.properties = Object.fromEntries(
      Object.entries(schema.properties as Record<string, JsonSchema>).map(([k, v]) => [k, toGeminiSchema(v)]),
    );
  }
  if (schema.items) out.items = toGeminiSchema(schema.items as JsonSchema);
  if (schema.required) out.required = schema.required;
  return out;
}

export class VertexGeminiClient implements LlmProviderClient {
  constructor(
    private readonly model = process.env.AI_GEMINI_MODEL || DEFAULT_MODEL,
    private readonly location = process.env.AI_VERTEX_LOCATION || DEFAULT_LOCATION,
  ) {}

  supportsMedia(mimeType: string): boolean {
    return mimeType.startsWith('image/') || mimeType.startsWith('audio/');
  }

  async generateJson(request: LlmRequest): Promise<string> {
    const project = projectId();
    if (!project) throw new LlmUnavailableError('missing project id');

    let token: string;
    try {
      token = (await admin.credential.applicationDefault().getAccessToken()).access_token;
    } catch {
      throw new LlmUnavailableError('no credentials for Vertex AI');
    }

    const host = this.location === 'global' ? 'aiplatform.googleapis.com' : `${this.location}-aiplatform.googleapis.com`;
    const url =
      `https://${host}/v1/projects/${project}/locations/${this.location}` +
      `/publishers/google/models/${this.model}:generateContent`;

    const body = {
      systemInstruction: { parts: [{ text: request.systemPrompt }] },
      contents: [
        {
          role: 'user',
          parts: [
            { text: request.userText },
            ...request.media.map((m) => ({ inlineData: { mimeType: m.mimeType, data: m.data } })),
          ],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: 'application/json',
        responseSchema: toGeminiSchema(request.responseSchema),
      },
    };

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch {
      throw new LlmUnavailableError('model request failed');
    } finally {
      clearTimeout(timer);
    }

    if (!response.ok) {
      // Never log the body: it may echo the user's audio transcript.
      throw new LlmUnavailableError(`model returned HTTP ${response.status}`);
    }
    const json = (await response.json()) as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
    if (!text) throw new LlmUnavailableError('empty model answer');
    return text;
  }
}
