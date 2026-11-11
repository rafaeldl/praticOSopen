/**
 * Production wiring of [FormPhotoDeps]: the same switches and quota as the
 * order, with a model of its own.
 *
 * The checklist photo has its own variables so it can change model without
 * touching the order (docs/AI_ORDER_ASSIST.md, "Foto do checklist"):
 * - AI_FORM_PHOTO_PROVIDER         gemini | claude; unset = the company's provider
 * - AI_FORM_PHOTO_GEMINI_MODEL     unset = AI_GEMINI_MODEL (the order's)
 * - AI_FORM_PHOTO_VERTEX_LOCATION  unset = AI_VERTEX_LOCATION (São Paulo)
 * - AI_FORM_PHOTO_GEMINI_THINKING  minimal | low | medium | high; Gemini 3 only
 *
 * Unset, everything follows the order: the photo stays in São Paulo. `global`
 * (Gemini 3.8 Flash) is more accurate but sends the photo out of Brazil.
 */

import { getAiSettings, releaseAiRequest, reserveAiRequest } from './ai-quota.service';
import { ClaudeClient } from './claude.client';
import { VertexGeminiClient, type GeminiThinkingLevel } from './gemini.client';
import { LlmRouter, isLlmProvider, type LlmProvider } from './llm.client';
import type { FormPhotoDeps } from './form-photo.service';

const THINKING_LEVELS: readonly GeminiThinkingLevel[] = ['minimal', 'low', 'medium', 'high'];

export interface FormPhotoModelConfig {
  provider?: LlmProvider;
  /** Undefined = the order's model and region (VertexGeminiClient defaults). */
  geminiModel?: string;
  vertexLocation?: string;
  thinkingLevel?: GeminiThinkingLevel;
}

export function formPhotoModelConfig(env: NodeJS.ProcessEnv = process.env): FormPhotoModelConfig {
  const thinking = env.AI_FORM_PHOTO_GEMINI_THINKING as GeminiThinkingLevel | undefined;
  return {
    provider: isLlmProvider(env.AI_FORM_PHOTO_PROVIDER) ? env.AI_FORM_PHOTO_PROVIDER : undefined,
    geminiModel: env.AI_FORM_PHOTO_GEMINI_MODEL || undefined,
    vertexLocation: env.AI_FORM_PHOTO_VERTEX_LOCATION || undefined,
    thinkingLevel: thinking && THINKING_LEVELS.includes(thinking) ? thinking : undefined,
  };
}

let llm: LlmRouter | undefined;
let gemini: VertexGeminiClient | undefined;
let claude: ClaudeClient | undefined;

export function defaultFormPhotoDeps(): FormPhotoDeps {
  const config = formPhotoModelConfig();
  llm ??= new LlmRouter({
    gemini: () => (gemini ??= new VertexGeminiClient(config.geminiModel, config.vertexLocation, config.thinkingLevel)),
    claude: () => (claude ??= new ClaudeClient()),
  });
  return {
    llm,
    provider: config.provider,
    getSettings: getAiSettings,
    reserve: (companyId, settings) => reserveAiRequest(companyId, settings),
    release: releaseAiRequest,
  };
}
