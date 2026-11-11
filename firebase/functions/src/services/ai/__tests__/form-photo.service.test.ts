// form-photo.deps reads the quota from Firestore: never in a unit test.
jest.mock('../ai-quota.service', () => ({ getAiSettings: jest.fn(), reserveAiRequest: jest.fn(), releaseAiRequest: jest.fn() }));

import { formPhotoInputSchema, runFormPhoto, type FormPhotoDeps, type FormPhotoRequest } from '../form-photo.service';
import { formPhotoModelConfig } from '../form-photo.deps';
import { LlmUnavailableError } from '../llm.client';
import { OrderAssistError } from '../order-assist.service';

const PHOTO = { mimeType: 'image/jpeg' as const, data: 'aGVsbG8=' };
const fuel: FormPhotoRequest = {
  photo: PHOTO,
  question: { label: 'Nível de combustível', type: 'select', options: ['Reserva', '1/4', '1/2', '3/4', 'Cheio'] },
};
const km: FormPhotoRequest = {
  photo: PHOTO,
  question: { label: 'Quilometragem', type: 'number' },
  device: { category: 'Veículo', name: 'Fiat Uno 2015' },
  lastReading: { value: 102000, unit: 'km' },
};

function answer(fields: Record<string, unknown>): string {
  return JSON.stringify({ answer: null, note: null, optionNotes: [], photoNote: null, photoIssue: 'none', confident: true, ...fields });
}

function fakeDeps(raw: string | Error, overrides: Partial<FormPhotoDeps> = {}): FormPhotoDeps {
  return {
    llm: { generateJson: raw instanceof Error ? jest.fn().mockRejectedValue(raw) : jest.fn().mockResolvedValue(raw) },
    getSettings: jest.fn().mockResolvedValue({ enabled: true }),
    reserve: jest.fn().mockResolvedValue({ ok: true, used: 4, limit: 10, monthKey: '2026-11' }),
    release: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

describe('runFormPhoto', () => {
  it('returns the answer, the note and this month\'s usage', async () => {
    const deps = fakeDeps(answer({ answer: 102345, note: 'Painel com luz de óleo acesa' }));
    const result = await runFormPhoto('c1', km, deps);
    expect(result).toEqual({ answer: 102345, note: 'Painel com luz de óleo acesa', confident: true, usage: { used: 4, limit: 10 } });
    const sent = (deps.llm.generateJson as jest.Mock).mock.calls[0][0];
    expect(sent.media).toEqual([PHOTO]);
    expect(sent.userText).toContain('Question: Quilometragem');
    expect(sent.userText).toContain('Last reading for this item: 102000 km');
    expect(deps.release).not.toHaveBeenCalled();
  });

  it('drops an answer outside the options, keeps the note', async () => {
    const deps = fakeDeps(answer({ answer: 'Meio tanque', note: 'Ponteiro no meio' }));
    const result = await runFormPhoto('c1', fuel, deps);
    expect(result).not.toHaveProperty('answer');
    expect(result.note).toBe('Ponteiro no meio');
  });

  it('returns the original option when the model changes the case', async () => {
    const result = await runFormPhoto('c1', fuel, fakeDeps(answer({ answer: 'cheio' })));
    expect(result.answer).toBe('Cheio');
  });

  it('confident false → no answer, only the note', async () => {
    const deps = fakeDeps(answer({ answer: 102345, confident: false, note: 'Último dígito encoberto' }));
    const result = await runFormPhoto('c1', km, deps);
    expect(result).toEqual({ confident: false, note: 'Último dígito encoberto', usage: { used: 4, limit: 10 } });
  });

  it('a dark photo counts too (the model was called)', async () => {
    const deps = fakeDeps(answer({ confident: false, photoIssue: 'dark' }));
    const result = await runFormPhoto('c1', km, deps);
    expect(result.photoIssue).toBe('dark');
    expect(deps.reserve).toHaveBeenCalledTimes(1);
    expect(deps.release).not.toHaveBeenCalled();
  });

  it('AI off → AI_DISABLED, nothing counted, no model call', async () => {
    const deps = fakeDeps(answer({}), { getSettings: jest.fn().mockResolvedValue({ enabled: false }) });
    await expect(runFormPhoto('c1', km, deps)).rejects.toMatchObject({ code: 'AI_DISABLED' });
    expect(deps.reserve).not.toHaveBeenCalled();
    expect(deps.llm.generateJson).not.toHaveBeenCalled();
  });

  it('quota full → AI_QUOTA_EXCEEDED with used/limit, no model call', async () => {
    const deps = fakeDeps(answer({}), {
      reserve: jest.fn().mockResolvedValue({ ok: false, used: 10, limit: 10, monthKey: '2026-11' }),
    });
    const error = await runFormPhoto('c1', km, deps).catch((e) => e);
    expect(error).toBeInstanceOf(OrderAssistError);
    expect(error).toMatchObject({ code: 'AI_QUOTA_EXCEEDED', details: { used: 10, limit: 10 } });
    expect(deps.llm.generateJson).not.toHaveBeenCalled();
  });

  it('model down or not JSON → AI_UNAVAILABLE and the request is given back', async () => {
    for (const raw of [new LlmUnavailableError('HTTP 503'), 'not json']) {
      const deps = fakeDeps(raw);
      await expect(runFormPhoto('c1', km, deps)).rejects.toMatchObject({ code: 'AI_UNAVAILABLE' });
      expect(deps.release).toHaveBeenCalledWith('c1', '2026-11');
    }
  });

  it('route provider wins over the company\'s; unset follows the company', async () => {
    const settings = jest.fn().mockResolvedValue({ enabled: true, provider: 'claude' });
    const own = fakeDeps(answer({}), { getSettings: settings, provider: 'gemini' });
    await runFormPhoto('c1', km, own);
    expect((own.llm.generateJson as jest.Mock).mock.calls[0][0].provider).toBe('gemini');
    const follows = fakeDeps(answer({}), { getSettings: settings });
    await runFormPhoto('c1', km, follows);
    expect((follows.llm.generateJson as jest.Mock).mock.calls[0][0].provider).toBe('claude');
  });
});

describe('formPhotoInputSchema', () => {
  const ok = (body: unknown) => formPhotoInputSchema.safeParse(body).success;

  it('accepts the app body', () => {
    expect(ok(km)).toBe(true);
    expect(ok({ ...fuel, segment: 'automotive', locale: 'pt' })).toBe(true);
  });

  it('rejects a bad photo', () => {
    expect(ok({ ...km, photo: { mimeType: 'image/jpeg', data: '%%%' } })).toBe(false);
    expect(ok({ ...km, photo: { mimeType: 'application/pdf', data: 'aGVsbG8=' } })).toBe(false);
    expect(ok({ ...km, photo: undefined })).toBe(false);
    const tooBig = 'A'.repeat(Math.ceil((2 * 1024 * 1024 + 10) / 3) * 4);
    expect(ok({ ...km, photo: { mimeType: 'image/jpeg', data: tooBig } })).toBe(false);
  });

  it('a select or checklist question needs its options', () => {
    expect(ok({ ...fuel, question: { label: 'Combustível', type: 'select' } })).toBe(false);
  });

  it('has no place for plate, phone, customer or company', () => {
    expect(ok({ ...km, device: { name: 'Uno', serial: 'ABC1D23' } })).toBe(false);
    expect(ok({ ...km, customer: { name: 'Ana', phone: '11999990000' } })).toBe(false);
    expect(ok({ ...km, companyId: 'other' })).toBe(false);
  });
});

describe('formPhotoModelConfig', () => {
  it('default: Gemini 3.8 Flash in global with thinking low (decided in #701), whatever the order uses', () => {
    expect(formPhotoModelConfig({ AI_GEMINI_MODEL: 'gemini-2.5-flash', AI_VERTEX_LOCATION: 'southamerica-east1', AI_PROVIDER: 'claude' })).toEqual({
      provider: 'gemini',
      geminiModel: 'gemini-3.8-flash',
      vertexLocation: 'global',
      thinkingLevel: 'low',
    });
  });

  it('reads its own variables', () => {
    expect(
      formPhotoModelConfig({
        AI_FORM_PHOTO_PROVIDER: 'claude',
        AI_FORM_PHOTO_GEMINI_MODEL: 'gemini-2.5-flash',
        AI_FORM_PHOTO_VERTEX_LOCATION: 'southamerica-east1',
        AI_FORM_PHOTO_GEMINI_THINKING: 'off',
      }),
    ).toEqual({ provider: 'claude', geminiModel: 'gemini-2.5-flash', vertexLocation: 'southamerica-east1', thinkingLevel: undefined });
  });

  it('company → follows the company provider; unknown values → defaults', () => {
    expect(formPhotoModelConfig({ AI_FORM_PHOTO_PROVIDER: 'company' }).provider).toBeUndefined();
    const config = formPhotoModelConfig({ AI_FORM_PHOTO_PROVIDER: 'openai', AI_FORM_PHOTO_GEMINI_THINKING: 'max' });
    expect(config.provider).toBe('gemini');
    expect(config.thinkingLevel).toBe('low');
  });
});
