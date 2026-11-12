/**
 * aiFormPhoto: one checklist photo + the question it was taken for → the
 * answer the photo shows and a short note (docs/AI_ORDER_ASSIST.md, "Foto do
 * checklist"; spec 2026-11-10-checklist-ia-foto-design §7).
 *
 * The function never writes the form. The app applies the answer, marks it
 * with ✦ and saves, like the order draft.
 *
 * - An answer outside the question's options is dropped, and so is any answer
 *   the model is not confident about (the note still goes back).
 * - Every photo read counts 1 in the monthly quota, a dark or blurry one too:
 *   the model was called. Only a call the model never answered is released.
 * - Privacy: the body has no customer name, phone or plate (strict schema);
 *   the device goes only as category and model name.
 */

import { z } from 'zod';
import type { LlmClient, LlmProvider } from './llm.client';
import { LlmUnavailableError } from './llm.client';
import type { AiSettings, QuotaReservation } from './ai-quota.service';
import { MAX_PHOTO_BYTES, OrderAssistError, base64Of } from './order-assist.service';
import {
  buildFormPhotoSystemPrompt,
  buildFormPhotoUserText,
  formPhotoResponseSchema,
  parseFormPhotoResult,
  type FormPhotoResult,
} from './form-photo.prompt';

export const MAX_QUESTION_OPTIONS = 50;

const FORM_ITEM_TYPES = ['text', 'number', 'select', 'checklist', 'photo_only', 'boolean'] as const;

export const formPhotoInputSchema = z
  .object({
    photo: z
      .object({
        mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
        data: base64Of(MAX_PHOTO_BYTES),
      })
      .strict(),
    /** The label as the person sees it and the template's original options. */
    question: z
      .object({
        label: z.string().trim().min(1).max(300),
        type: z.enum(FORM_ITEM_TYPES),
        options: z.array(z.string().trim().min(1).max(200)).max(MAX_QUESTION_OPTIONS).optional(),
      })
      .strict()
      .refine((q) => (q.type !== 'select' && q.type !== 'checklist') || (q.options?.length ?? 0) > 0, {
        message: 'select and checklist questions need their options',
      }),
    /** "Veículo", "Fiat Uno 2015". No plate or serial: the model doesn't need them. */
    device: z
      .object({
        category: z.string().trim().max(60).optional(),
        name: z.string().trim().max(120).optional(),
      })
      .strict()
      .optional(),
    segment: z.string().trim().max(60).optional(),
    locale: z.enum(['pt', 'en', 'es']).optional(),
    /** Only for a reading question (km, hours): helps to read the right meter. */
    lastReading: z
      .object({ value: z.number().finite().nonnegative(), unit: z.string().trim().max(20).optional() })
      .strict()
      .optional(),
  })
  .strict();

export type FormPhotoRequest = z.infer<typeof formPhotoInputSchema>;

export interface FormPhotoDeps {
  llm: LlmClient;
  getSettings(companyId: string): Promise<AiSettings | null>;
  reserve(companyId: string, settings: AiSettings | null): Promise<QuotaReservation>;
  release(companyId: string, monthKey: string, dayKey?: string): Promise<void>;
  /**
   * Provider for this route only (AI_FORM_PHOTO_PROVIDER). Wins over the
   * company's `provider`; unset = the company's, like the order.
   */
  provider?: LlmProvider;
}

export type FormPhotoAnswer = FormPhotoResult & { usage: { used: number; limit: number } };

export async function runFormPhoto(
  companyId: string,
  input: FormPhotoRequest,
  deps: FormPhotoDeps,
): Promise<FormPhotoAnswer> {
  const settings = await deps.getSettings(companyId);
  if (!settings?.enabled) {
    throw new OrderAssistError('AI_DISABLED', 'The assistant is not enabled for this company');
  }

  const reservation = await deps.reserve(companyId, settings);
  if (!reservation.ok) {
    throw new OrderAssistError('AI_QUOTA_EXCEEDED', reservation.period === 'day' ? 'Daily AI limit reached' : 'Monthly AI limit reached', {
      used: reservation.used,
      limit: reservation.limit,
      period: reservation.period,
    });
  }

  const { question } = input;
  let result: FormPhotoResult;
  try {
    const raw = await deps.llm.generateJson({
      systemPrompt: buildFormPhotoSystemPrompt(input.locale ?? 'pt'),
      userText: buildFormPhotoUserText(input),
      media: [{ mimeType: input.photo.mimeType, data: input.photo.data }],
      responseSchema: formPhotoResponseSchema(question),
      provider: deps.provider ?? settings.provider,
    });
    // Not JSON = the model gave nothing usable: same as not answering.
    try {
      JSON.parse(raw);
    } catch {
      throw new LlmUnavailableError('answer is not JSON');
    }
    result = parseFormPhotoResult(raw, question);
  } catch (error) {
    try {
      await deps.release(companyId, reservation.monthKey, reservation.dayKey);
    } catch {
      // Best effort: a failed release only costs the user one request.
    }
    if (error instanceof LlmUnavailableError) {
      throw new OrderAssistError('AI_UNAVAILABLE', 'The assistant could not answer now');
    }
    throw error;
  }

  return { ...result, usage: { used: reservation.used, limit: reservation.limit } };
}
