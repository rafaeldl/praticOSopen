import {
  buildFormPhotoSystemPrompt,
  buildFormPhotoUserText,
  formPhotoResponseSchema,
  parseFormPhotoResult,
  type FormPhotoQuestion,
} from '../form-photo.prompt';
import { toGeminiSchema } from '../gemini.client';

const fuel: FormPhotoQuestion = { label: 'Nível de combustível', type: 'select', options: ['Reserva', '1/4', '1/2', '3/4', 'Cheio'] };
const km: FormPhotoQuestion = { label: 'Quilometragem', type: 'number' };
const damage: FormPhotoQuestion = { label: 'Onde tem dano?', type: 'checklist', options: ['Porta', 'Para-choque', 'Capô'] };

describe('buildFormPhotoUserText', () => {
  it('sends the question, its options, the item and the last reading', () => {
    const text = buildFormPhotoUserText({
      question: fuel,
      device: { category: 'Veículo', name: 'Fiat Uno 2015' },
      lastReading: { value: 102000, unit: 'km' },
    });
    expect(text).toContain('Question: Nível de combustível');
    expect(text).toContain('Options: "Reserva", "1/4", "1/2", "3/4", "Cheio"');
    expect(text).toContain('Item: Veículo - Fiat Uno 2015');
    expect(text).toContain('Last reading for this item: 102000 km');
  });
});

describe('buildFormPhotoSystemPrompt', () => {
  it('asks for an answer only when sure, or when every digit is readable with the read variant', () => {
    expect(buildFormPhotoSystemPrompt('pt')).toContain('or you are unsure, set confident to false');
    const read = buildFormPhotoSystemPrompt('pt', 'read');
    expect(read).toContain('If you can read every digit or character, answer with confident true');
    expect(read).not.toContain('or you are unsure');
  });
});

describe('formPhotoResponseSchema', () => {
  it('types the answer by question type and stays inside the Gemini subset', () => {
    expect((formPhotoResponseSchema(km).properties as Record<string, unknown>).answer).toEqual({ type: ['number', 'null'] });
    const gemini = toGeminiSchema(formPhotoResponseSchema(damage)) as { properties: Record<string, unknown> };
    expect(gemini.properties.answer).toEqual({ type: 'ARRAY', nullable: true, items: { type: 'STRING' } });
    expect(gemini.properties.photoIssue).toEqual({ type: 'STRING', enum: ['none', 'dark', 'blurry', 'off_target'] });
  });
});

describe('parseFormPhotoResult', () => {
  it('keeps an option answer, matching case-insensitively', () => {
    const raw = JSON.stringify({ answer: '1/4 ', note: null, optionNotes: [], photoNote: null, photoIssue: 'none', confident: true });
    expect(parseFormPhotoResult(raw, fuel)).toEqual({ answer: '1/4', confident: true });
  });

  it('drops an answer outside the options', () => {
    const raw = JSON.stringify({ answer: '1/8', note: 'Ponteiro perto da reserva', photoIssue: 'none', confident: true });
    expect(parseFormPhotoResult(raw, fuel)).toEqual({ note: 'Ponteiro perto da reserva', confident: true });
  });

  it('drops the answer but keeps the note when the model is not confident', () => {
    const raw = JSON.stringify({ answer: 98000, note: 'Último dígito ilegível', photoIssue: 'blurry', confident: false });
    expect(parseFormPhotoResult(raw, km)).toEqual({ note: 'Último dígito ilegível', photoIssue: 'blurry', confident: false });
  });

  it('reads a number written with thousand separators', () => {
    const raw = JSON.stringify({ answer: '98.213', confident: true });
    expect(parseFormPhotoResult(raw, km).answer).toBe(98213);
  });

  it('keeps only known options in a checklist answer and its notes', () => {
    const raw = JSON.stringify({
      answer: ['porta', 'Teto', 'Porta'],
      optionNotes: [
        { option: 'Porta', text: 'Amassado perto da maçaneta' },
        { option: 'Teto', text: 'Risco' },
      ],
      confident: true,
    });
    expect(parseFormPhotoResult(raw, damage)).toEqual({
      answer: ['Porta'],
      optionNotes: [{ option: 'Porta', text: 'Amassado perto da maçaneta' }],
      confident: true,
    });
  });

  it('treats invalid JSON as an unconfident empty result', () => {
    expect(parseFormPhotoResult('not json', km)).toEqual({ confident: false });
  });
});
