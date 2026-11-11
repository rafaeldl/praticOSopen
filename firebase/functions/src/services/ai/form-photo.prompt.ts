/**
 * Prompt, answer schema and parser for "the AI reads the checklist photo"
 * (docs/superpowers/specs/2026-11-10-checklist-ia-foto-design.md §7).
 *
 * The model gets one photo plus the question it belongs to and returns the
 * answer (only when the photo shows it), a one-sentence note saying what it
 * saw and where, and a flag when the photo can't be read.
 *
 * Not wired to a route yet: scripts/checklist-photo-eval.ts measures it on
 * real photos first (#686); the route is #687.
 */

import type { FormItemType } from '../../models/types';
import type { JsonSchema } from './llm.client';

export interface FormPhotoQuestion {
  label: string;
  type: FormItemType;
  options?: string[];
}

export interface FormPhotoInput {
  question: FormPhotoQuestion;
  /** "Veículo", "Fiat Uno 2015": helps read the right dashboard. */
  device?: { category?: string; name?: string };
  segment?: string;
  locale?: 'pt' | 'en' | 'es';
  lastReading?: { value: number; unit?: string };
}

export const PHOTO_ISSUES = ['dark', 'blurry', 'off_target'] as const;
export type PhotoIssue = (typeof PHOTO_ISSUES)[number];

export interface FormPhotoResult {
  answer?: string | number | boolean | string[];
  note?: string;
  optionNotes?: Array<{ option: string; text: string }>;
  photoNote?: string;
  photoIssue?: PhotoIssue;
  confident: boolean;
}

const LANGUAGE: Record<string, string> = { pt: 'Brazilian Portuguese', en: 'English', es: 'Spanish' };

/**
 * `strict` asks for an answer only when sure. `read` tells the model that a
 * clear reading counts as sure even when the photo is not perfect (Claude is
 * too cautious with `strict`, #686).
 */
export type FormPhotoPromptVariant = 'strict' | 'read';

const UNSURE_LINE: Record<FormPhotoPromptVariant, string> = {
  strict: '   - If a digit or character is unreadable, or you are unsure, set confident to false and leave answer null.',
  read: [
    '   - If you can read every digit or character, answer with confident true, even when the photo is slightly blurry, angled or has glare.',
    '   - Set confident to false and leave answer null only when a digit or character is hidden, cut off or you would have to guess it.',
  ].join('\n'),
};

export function buildFormPhotoSystemPrompt(locale: string = 'pt', variant: FormPhotoPromptVariant = 'strict'): string {
  const language = LANGUAGE[locale] ?? LANGUAGE.pt;
  return [
    'You help a service technician fill in a checklist. You get ONE photo and the checklist question it was taken for.',
    'Do two things:',
    '1. answer: answer the question ONLY when the photo clearly shows the answer.',
    '   - number: digits exactly as shown (odometer, hour meter, page counter). Ignore trip meters, clocks, temperature and speed. Never round or guess a hidden digit.',
    '   - select: exactly one of the given options, copied verbatim. checklist: the options that apply, copied verbatim.',
    '   - boolean: true or false. text: copy codes (serial number, model, part number) character by character, keeping letters, digits and dashes.',
    UNSURE_LINE[variant],
    '2. note: one short sentence on what you see that matters for the question, saying WHERE (side, front/rear, left/right of the vehicle or item, near which part) and size when visible, e.g. "Amassado na porta traseira esquerda, perto da maçaneta". Leave it null when there is nothing worth noting.',
    '   For a checklist question, optionNotes holds one sentence per option that has damage or remarks.',
    'photoNote: anything relevant in the photo that the question did not ask about (e.g. a warning light on the dashboard). Null otherwise.',
    'photoIssue: "dark", "blurry" or "off_target" (the photo does not show what the question asks) when that stops you from answering; "none" otherwise.',
    'Left and right are from the point of view of someone sitting in the vehicle (driver side is left in Brazil).',
    'Never write names, phone numbers, license plates or faces that appear in the photo.',
    `Write note, optionNotes and photoNote in ${language}. Return only the JSON.`,
  ].join('\n');
}

export function buildFormPhotoUserText(input: FormPhotoInput): string {
  const { question } = input;
  const lines = [`Question: ${question.label}`, `Answer type: ${question.type}`];
  if (question.options?.length) lines.push(`Options: ${question.options.map((o) => JSON.stringify(o)).join(', ')}`);
  if (input.device?.category || input.device?.name) {
    lines.push(`Item: ${[input.device.category, input.device.name].filter(Boolean).join(' - ')}`);
  }
  if (input.segment) lines.push(`Business: ${input.segment}`);
  if (input.lastReading) {
    lines.push(`Last reading for this item: ${input.lastReading.value}${input.lastReading.unit ? ` ${input.lastReading.unit}` : ''}`);
  }
  return lines.join('\n');
}

function answerSchema(question: FormPhotoQuestion): JsonSchema {
  switch (question.type) {
    case 'number':
      return { type: ['number', 'null'] };
    case 'boolean':
      return { type: ['boolean', 'null'] };
    case 'checklist':
      // No enum: Claude refuses an enum inside a nullable type; the parser filters.
      return { type: ['array', 'null'], items: { type: 'string' } };
    default:
      return { type: ['string', 'null'] };
  }
}

/** Shared JSON Schema (llm.client.ts subset) for the question's answer type. */
export function formPhotoResponseSchema(question: FormPhotoQuestion): JsonSchema {
  return {
    type: 'object',
    additionalProperties: false,
    properties: {
      answer: answerSchema(question),
      note: { type: ['string', 'null'] },
      optionNotes: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          properties: { option: { type: 'string' }, text: { type: 'string' } },
          required: ['option', 'text'],
        },
      },
      photoNote: { type: ['string', 'null'] },
      photoIssue: { type: 'string', enum: ['none', ...PHOTO_ISSUES] },
      confident: { type: 'boolean' },
    },
    required: ['answer', 'note', 'optionNotes', 'photoNote', 'photoIssue', 'confident'],
  };
}

function text(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

/** Matches an option ignoring case and surrounding spaces; returns the original. */
function matchOption(value: unknown, options: string[]): string | undefined {
  if (typeof value !== 'string') return undefined;
  const wanted = value.trim().toLocaleLowerCase();
  return options.find((o) => o.trim().toLocaleLowerCase() === wanted);
}

function parseAnswer(value: unknown, question: FormPhotoQuestion): FormPhotoResult['answer'] {
  const options = question.options ?? [];
  switch (question.type) {
    case 'number': {
      const n = typeof value === 'number' ? value : typeof value === 'string' ? Number(value.replace(/[^\d.,-]/g, '').replace(/[.,](?=\d{3}\b)/g, '').replace(',', '.')) : NaN;
      return Number.isFinite(n) ? n : undefined;
    }
    case 'boolean':
      return typeof value === 'boolean' ? value : undefined;
    case 'select':
      return matchOption(value, options);
    case 'checklist': {
      if (!Array.isArray(value)) return undefined;
      const picked = value.map((v) => matchOption(v, options)).filter((v): v is string => !!v);
      return picked.length ? Array.from(new Set(picked)) : undefined;
    }
    case 'photo_only':
      return undefined;
    default:
      return text(value);
  }
}

/**
 * Parses the model's JSON. Drops an answer outside the options, and any answer
 * when the model is not confident (the note still goes through).
 */
export function parseFormPhotoResult(raw: string, question: FormPhotoQuestion): FormPhotoResult {
  let json: Record<string, unknown>;
  try {
    json = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { confident: false };
  }
  const confident = json.confident === true;
  const result: FormPhotoResult = { confident };
  const answer = confident ? parseAnswer(json.answer, question) : undefined;
  if (answer !== undefined) result.answer = answer;
  const note = text(json.note);
  if (note) result.note = note;
  const photoNote = text(json.photoNote);
  if (photoNote) result.photoNote = photoNote;
  if ((PHOTO_ISSUES as readonly string[]).includes(json.photoIssue as string)) {
    result.photoIssue = json.photoIssue as PhotoIssue;
  }
  if (Array.isArray(json.optionNotes)) {
    const options = question.options ?? [];
    const notes = json.optionNotes.flatMap((n) => {
      const entry = n as { option?: unknown; text?: unknown };
      const option = matchOption(entry.option, options);
      const body = text(entry.text);
      return option && body ? [{ option, text: body }] : [];
    });
    if (notes.length) result.optionNotes = notes;
  }
  return result;
}
