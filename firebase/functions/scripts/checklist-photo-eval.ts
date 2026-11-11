/**
 * Measures how well the models read checklist photos before the route exists
 * (#686, docs/superpowers/specs/2026-11-10-checklist-ia-foto-design.md §9 step 2):
 * odometer, fuel, serial number, damage location, printer/inverter display and
 * phone screen.
 *
 * The photos and the right answers stay OUT of the repository (it is public):
 *
 *   <dir>/cases.json   [{ id, photo, kind, question, device?, expect }]
 *   <dir>/<photo>      JPEG/PNG/WebP, already reduced like the app does
 *                      (macOS: sips -Z 1600 -s format jpeg in.heic --out x.jpg)
 *
 * expect.answer is the right answer (null when the photo can't show it and the
 * model should abstain); expect.alt lists other accepted answers;
 * expect.noteMentions is a list of word groups the note must hit, one word of
 * each group (e.g. [["porta"], ["traseira", "de trás"], ["esquerda"]]).
 *
 * GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/checklist-photo-eval.ts --dir <dir>
 *   --providers gemini,claude      default both
 *   --gemini-model gemini-3.8-flash --gemini-location global --gemini-thinking low
 *   --claude-model claude-sonnet-5-5 --claude-effort low --claude-fallback off
 *   --prompt strict|read           prompt variant (form-photo.prompt.ts)
 *   --max-edge 1568                shrink photos to this long edge first (macOS sips)
 *   --price-in 2 --price-out 10    US$ per million tokens: adds cost per 1,000 photos
 *   --runs 1                       repeats per photo
 *   --only km,fuel                 only these kinds
 *   --out <file.json>              every answer and latency (keep it outside the repo)
 *
 * Costs real calls, writes nothing to Firestore. Prints only aggregate numbers
 * and case ids, never the photo.
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import { execFileSync } from 'child_process';
import * as os from 'os';
import * as path from 'path';
import { ClaudeClient } from '../src/services/ai/claude.client';
import {
  buildFormPhotoSystemPrompt,
  buildFormPhotoUserText,
  type FormPhotoPromptVariant,
  formPhotoResponseSchema,
  parseFormPhotoResult,
  type FormPhotoInput,
  type FormPhotoResult,
} from '../src/services/ai/form-photo.prompt';
import { VertexGeminiClient, type GeminiThinkingLevel } from '../src/services/ai/gemini.client';
import type { LlmProviderClient } from '../src/services/ai/llm.client';

const CONCURRENCY = 3;
const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
const MIME: Record<string, string> = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

type Answer = string | number | boolean | string[] | null;

interface EvalCase extends FormPhotoInput {
  id: string;
  photo: string;
  /** km, fuel, serial, damage, display, screen… — the row of the table. */
  kind: string;
  expect: { answer?: Answer; alt?: Answer[]; noteMentions?: string[][] };
}

type AnswerVerdict = 'right' | 'wrong' | 'abstained' | 'n/a';

interface Outcome {
  provider: string;
  id: string;
  kind: string;
  ms: number;
  answer: AnswerVerdict;
  /** null when the case does not check the note. */
  note: boolean | null;
  error?: string;
  inputTokens?: number;
  outputTokens?: number;
  model?: string;
  result?: FormPhotoResult;
  raw?: string;
}

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function fold(value: string): string {
  return value.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

/** Serial numbers: case, spaces, dashes and an "SN"/"S/N" prefix don't count. */
function normalizeCode(value: string): string {
  return value.toUpperCase().replace(/^\s*(S\/N|SN|SERIAL|N[º°O]\.?\s*DE\s*S[EÉ]RIE)\s*[:#]?\s*/, '').replace(/[\s\-_.:/]/g, '');
}

function sameAnswer(got: FormPhotoResult['answer'], want: Answer, kind: string): boolean {
  if (got === undefined || want === null) return false;
  if (Array.isArray(want)) {
    return Array.isArray(got) && got.length === want.length && want.every((w) => got.some((g) => fold(g) === fold(w)));
  }
  if (typeof want === 'number') return Number(got) === want;
  if (typeof want === 'boolean') return got === want;
  if (typeof got !== 'string') return false;
  return kind === 'serial' || kind === 'plate_info' ? normalizeCode(got) === normalizeCode(want) : fold(got.trim()) === fold(want.trim());
}

export function judgeAnswer(c: EvalCase, result: FormPhotoResult): AnswerVerdict {
  if (!('answer' in c.expect)) return 'n/a';
  const want = c.expect.answer ?? null;
  if (result.answer === undefined) return want === null ? 'right' : 'abstained';
  if (want === null) return 'wrong';
  return [want, ...(c.expect.alt ?? [])].some((w) => sameAnswer(result.answer, w, c.kind)) ? 'right' : 'wrong';
}

export function judgeNote(c: EvalCase, result: FormPhotoResult): boolean | null {
  if (!c.expect.noteMentions?.length) return null;
  const text = fold([result.note, result.photoNote, ...(result.optionNotes ?? []).map((n) => `${n.option} ${n.text}`)].filter(Boolean).join(' '));
  return c.expect.noteMentions.every((group) => group.some((word) => text.includes(fold(word))));
}

let maxEdge: number | undefined;
let promptVariant: FormPhotoPromptVariant = 'strict';
const shrunkDir = fs.mkdtempSync(path.join(os.tmpdir(), 'photo-eval-'));

function loadPhoto(dir: string, c: EvalCase): { mimeType: string; data: string } {
  let file = path.resolve(dir, c.photo);
  if (maxEdge) {
    const shrunk = path.join(shrunkDir, `${c.id}.jpg`);
    if (!fs.existsSync(shrunk)) execFileSync('sips', ['-Z', String(maxEdge), '-s', 'format', 'jpeg', file, '--out', shrunk], { stdio: 'ignore' });
    file = shrunk;
  }
  const mimeType = MIME[path.extname(file).toLowerCase()];
  if (!mimeType) throw new Error(`${c.id}: convert ${path.extname(file)} to JPEG first`);
  const bytes = fs.readFileSync(file);
  if (bytes.length > MAX_PHOTO_BYTES) console.warn(`! ${c.id}: ${(bytes.length / 1e6).toFixed(1)} MB, the app sends up to 2 MB`);
  return { mimeType, data: bytes.toString('base64') };
}

async function runCase(provider: string, client: LlmProviderClient, dir: string, c: EvalCase): Promise<Outcome> {
  const base = { provider, id: c.id, kind: c.kind };
  const started = Date.now();
  const usage: Partial<Outcome> = {};
  try {
    const raw = await client.generateJson({
      onUsage: (u) => Object.assign(usage, u),
      systemPrompt: buildFormPhotoSystemPrompt(c.locale ?? 'pt', promptVariant),
      userText: buildFormPhotoUserText(c),
      media: [loadPhoto(dir, c)],
      responseSchema: formPhotoResponseSchema(c.question),
    });
    const ms = Date.now() - started;
    const result = parseFormPhotoResult(raw, c.question);
    return { ...base, ...usage, ms, answer: judgeAnswer(c, result), note: judgeNote(c, result), result, raw };
  } catch (error) {
    return { ...base, ...usage, ms: Date.now() - started, answer: 'n/a', note: null, error: (error as Error).message };
  }
}

async function pool<T, R>(items: T[], worker: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: CONCURRENCY }, async () => {
      while (next < items.length) results.push(await worker(items[next++]));
    }),
  );
  return results;
}

function quantile(values: number[], q: number): number {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))];
}

function ratio(part: number, whole: number): string {
  return whole === 0 ? '-' : `${part}/${whole} (${Math.round((part / whole) * 100)}%)`;
}

let priceIn: number | undefined;
let priceOut: number | undefined;

/** Mean tokens per photo and, with prices, US$ per 1,000 photos. */
function cost(mine: Outcome[]): string {
  const billed = mine.filter((o) => o.inputTokens !== undefined);
  if (!billed.length) return '- | - | -';
  const mean = (pick: (o: Outcome) => number) => billed.reduce((sum, o) => sum + pick(o), 0) / billed.length;
  const tokensIn = mean((o) => o.inputTokens ?? 0);
  const tokensOut = mean((o) => o.outputTokens ?? 0);
  const perThousand =
    priceIn !== undefined && priceOut !== undefined ? `US$ ${((tokensIn * priceIn + tokensOut * priceOut) / 1000).toFixed(2)}` : '-';
  return `${Math.round(tokensIn)} | ${Math.round(tokensOut)} | ${perThousand}`;
}

function row(label: string, mine: Outcome[]): string {
  const answered = mine.filter((o) => o.answer !== 'n/a');
  const count = (v: AnswerVerdict) => answered.filter((o) => o.answer === v).length;
  const notes = mine.filter((o) => o.note !== null);
  const ms = mine.filter((o) => !o.error).map((o) => o.ms);
  return [
    label,
    ratio(count('right'), answered.length),
    String(count('wrong')),
    String(count('abstained')),
    ratio(notes.filter((o) => o.note).length, notes.length),
    String(mine.filter((o) => o.error).length),
    `${(quantile(ms, 0.5) / 1000).toFixed(1)} s`,
    `${(quantile(ms, 0.9) / 1000).toFixed(1)} s`,
    cost(mine),
  ].join(' | ');
}

async function main(): Promise<void> {
  const dir = arg('dir');
  if (!dir) throw new Error('--dir <folder with cases.json> is required');
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  const providers = (arg('providers') ?? 'gemini,claude').split(',');
  const runs = Number(arg('runs') ?? 1);
  const only = arg('only')?.split(',');
  maxEdge = arg('max-edge') ? Number(arg('max-edge')) : undefined;
  promptVariant = (arg('prompt') ?? 'strict') as FormPhotoPromptVariant;
  priceIn = arg('price-in') ? Number(arg('price-in')) : undefined;
  priceOut = arg('price-out') ? Number(arg('price-out')) : undefined;
  const clients: Record<string, LlmProviderClient> = {
    gemini: new VertexGeminiClient(
      arg('gemini-model') ?? process.env.AI_GEMINI_MODEL ?? 'gemini-2.5-flash',
      arg('gemini-location') ?? process.env.AI_VERTEX_LOCATION ?? 'southamerica-east1',
      arg('gemini-thinking') as GeminiThinkingLevel | undefined,
    ),
    claude: new ClaudeClient(
      () => process.env.ANTHROPIC_API_KEY,
      arg('claude-model') ?? process.env.AI_CLAUDE_MODEL ?? 'claude-sonnet-5-5',
      (arg('claude-effort') ?? 'low') as 'low',
      arg('claude-fallback') !== 'off',
    ),
  };
  const cases = (JSON.parse(fs.readFileSync(path.join(dir, 'cases.json'), 'utf8')) as EvalCase[]).filter(
    (c) => !only || only.includes(c.kind),
  );

  const outcomes: Outcome[] = [];
  for (const provider of providers) {
    const jobs = Array.from({ length: runs }, () => cases).flat();
    outcomes.push(...(await pool(jobs, (c) => runCase(provider, clients[provider], dir, c))));
  }

  const kinds = Array.from(new Set(cases.map((c) => c.kind)));
  console.log('\nprovider | kind | answer right | wrong | abstained | note right | errors | p50 | p90 | tokens in | tokens out | per 1,000 photos');
  console.log('---|---|---|---|---|---|---|---|---|---|---|---');
  for (const provider of providers) {
    const mine = outcomes.filter((o) => o.provider === provider);
    for (const kind of kinds) console.log(`${provider} | ${row(kind, mine.filter((o) => o.kind === kind))}`);
    console.log(`${provider} | ${row('**all**', mine)}`);
  }
  for (const miss of outcomes.filter((o) => o.answer === 'wrong' || o.note === false || o.error)) {
    const why = miss.error ?? [miss.answer === 'wrong' ? 'answer' : '', miss.note === false ? 'note' : ''].filter(Boolean).join('+');
    console.log(`x ${miss.provider} ${miss.id} [${why}]`);
  }

  const models = Array.from(new Set(outcomes.map((o) => o.model).filter(Boolean)));
  if (models.length) console.log(`answered by: ${models.join(', ')}`);
  const out = arg('out');
  if (out) fs.writeFileSync(out, JSON.stringify(outcomes, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error((error as Error).message);
    process.exit(1);
  });
}
