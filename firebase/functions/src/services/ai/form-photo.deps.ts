/**
 * Production wiring of [FormPhotoDeps]: the same switches and quota as the
 * order, with a model of its own.
 *
 * Decided by Rafael (2026-11-11, #701): Gemini 3.8 Flash in `global` with
 * thinking low. It read 78/80 photos in #686 with no wrong answer given as
 * certain; the order's Gemini 2.5 in São Paulo gave 6. Gemini 3.8 doesn't
 * exist in São Paulo, so the photo is processed by Google outside Brazil
 * (privacy policy, "Assistente de IA"). The order keeps its own model.
 *
 * Variables (docs/AI_ORDER_ASSIST.md, "Foto do checklist"), separate from the order's:
 * - AI_FORM_PHOTO_PROVIDER         gemini (default) | claude | company (= the company's provider)
 * - AI_FORM_PHOTO_GEMINI_MODEL     default gemini-3.8-flash
 * - AI_FORM_PHOTO_VERTEX_LOCATION  default global
 * - AI_FORM_PHOTO_GEMINI_THINKING  minimal | low (default) | medium | high | off (off = the
 *   Gemini client's own rule: nothing on Gemini 2.5, which rejects the field)
 */

import { getAiSettings, releaseAiRequest, reserveAiRequest } from './ai-quota.service';
import { ClaudeClient } from './claude.client';
import { VertexGeminiClient, type GeminiThinkingLevel } from './gemini.client';
import { LlmRouter, isLlmProvider, type LlmProvider } from './llm.client';
import type { FormPhotoDeps } from './form-photo.service';

export const FORM_PHOTO_GEMINI_MODEL = 'gemini-3.8-flash';
export const FORM_PHOTO_VERTEX_LOCATION = 'global';
export const FORM_PHOTO_THINKING: GeminiThinkingLevel = 'low';

const THINKING_LEVELS: readonly GeminiThinkingLevel[] = ['minimal', 'low', 'medium', 'high'];

export interface FormPhotoModelConfig {
  /** Undefined = the company's provider, like the order. */
  provider?: LlmProvider;
  geminiModel: string;
  vertexLocation: string;
  /** Undefined = not sent (Gemini 2.5 rejects it). */
  thinkingLevel?: GeminiThinkingLevel;
}

export function formPhotoModelConfig(env: NodeJS.ProcessEnv = process.env): FormPhotoModelConfig {
  const provider = env.AI_FORM_PHOTO_PROVIDER;
  const thinking = env.AI_FORM_PHOTO_GEMINI_THINKING as GeminiThinkingLevel | 'off' | undefined;
  return {
    provider: provider === 'company' ? undefined : isLlmProvider(provider) ? provider : 'gemini',
    geminiModel: env.AI_FORM_PHOTO_GEMINI_MODEL || FORM_PHOTO_GEMINI_MODEL,
    vertexLocation: env.AI_FORM_PHOTO_VERTEX_LOCATION || FORM_PHOTO_VERTEX_LOCATION,
    thinkingLevel:
      thinking === 'off' ? undefined : thinking && THINKING_LEVELS.includes(thinking) ? thinking : FORM_PHOTO_THINKING,
  };
}

let llm: LlmRouter | undefined;
let gemini: VertexGeminiClient | undefined;
let claude: ClaudeClient | undefined;

export function defaultFormPhotoDeps(): FormPhotoDeps {
  const config = formPhotoModelConfig();
  llm ??= new LlmRouter(
    {
      gemini: () => (gemini ??= new VertexGeminiClient(config.geminiModel, config.vertexLocation, config.thinkingLevel)),
      claude: () => (claude ??= new ClaudeClient()),
    },
    // A part Claude can't read falls back to Gemini, which reads every image type.
    'gemini',
  );
  return {
    llm,
    provider: config.provider,
    getSettings: getAiSettings,
    reserve: (companyId, settings) => reserveAiRequest(companyId, settings),
    release: releaseAiRequest,
  };
}
