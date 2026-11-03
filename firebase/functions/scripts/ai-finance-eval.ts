/**
 * Runs the order assistant's real prompt and parser against the real models,
 * on phrases that must or must not become money and status actions
 * (docs/superpowers/specs/2026-11-02-ia-financeiro-os-design.md §8).
 *
 * GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/ai-finance-eval.ts
 *   --providers gemini,claude   which models (default both)
 *   --runs 2                    repeats per phrase (default 1)
 *   --extra <file.json>         more cases, for phrases that cannot be public
 *   --only <prefix,prefix>      only the cases whose id starts with one of these
 *   --out <file.json>           saves every answer
 *
 * Unseen phrases live in ai-finance-eval-holdout.json and, once those were used
 * for tuning, ai-finance-eval-final.json: tune the prompt on the
 * main set, then run those once (--extra ... --only pt-h,en-h,es-h). The server
 * sends these requests to Claude; Gemini runs here only to compare.
 *
 * Costs real calls and does not touch Firestore. Exits 1 when a target fails.
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { ClaudeClient } from '../src/services/ai/claude.client';
import { VertexGeminiClient } from '../src/services/ai/gemini.client';
import type { LlmProviderClient } from '../src/services/ai/llm.client';
import {
  buildSystemPrompt,
  buildUserText,
  LLM_RESPONSE_SCHEMA_WITH_ACTIONS,
  parseLlmDraft,
  toActions,
} from '../src/services/ai/order-assist.service';

/** Every case runs on this day, so "ontem" has one right answer. */
const TODAY = '2026-11-02 (Monday)';
const CONCURRENCY = 4;
const DEFAULT_LINES = [{ name: 'Revisão geral', value: 400 }];
const CATALOG = {
  services: [{ id: 's1', name: 'Troca de óleo', value: 150 }, { id: 's2', name: 'Limpeza', value: 200 }],
  products: [{ id: 'p1', name: 'Filtro de óleo', value: 50 }],
};

interface Expected {
  payment?: { kind: string; value?: number | null; method?: string; paidDate?: string };
  discount?: { kind: string; value: number };
  status?: string;
}

interface EvalCase {
  id: string;
  lang: string;
  text: string;
  tag?: 'future' | 'itemPrice';
  expect: Expected;
  alt?: Expected[];
  addedLines?: number;
  lines?: Array<{ name: string; value: number }>;
}

interface Outcome {
  provider: string;
  id: string;
  text: string;
  tag?: string;
  ok: boolean;
  falsePayment: boolean;
  reason?: string;
  actions?: unknown;
  raw?: string;
}

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

/** Normalized shape, so an absent part and a null one compare equal. */
function shape(actions: Expected | null | undefined): string {
  const p = actions?.payment;
  return JSON.stringify({
    payment: p
      ? { kind: p.kind, value: p.kind === 'full' ? null : p.value ?? null, method: p.method ?? null, paidDate: p.paidDate ?? null }
      : null,
    discount: actions?.discount ? { kind: actions.discount.kind, value: actions.discount.value } : null,
    status: actions?.status ?? null,
  });
}

async function runCase(provider: string, client: LlmProviderClient, c: EvalCase): Promise<Outcome> {
  const base = { provider, id: c.id, text: c.text, tag: c.tag };
  const input = { text: c.text, locale: c.lang, order: { services: c.lines ?? DEFAULT_LINES, products: [] } };
  try {
    const raw = await client.generateJson({
      systemPrompt: buildSystemPrompt(c.lang, undefined, TODAY, { financeActions: true }),
      userText: buildUserText(input as never, CATALOG),
      media: [],
      responseSchema: LLM_RESPONSE_SCHEMA_WITH_ACTIONS,
    });
    const draft = parseLlmDraft(raw);
    const actions = toActions(draft.actions, TODAY.slice(0, 10)) as Expected | null;
    const accepted = [c.expect, ...(c.alt ?? [])].map(shape);
    const actionsOk = accepted.includes(shape(actions));
    const added = (draft.operations ?? []).filter((o) => o.action === 'add').length;
    const linesOk = c.addedLines === undefined || added === c.addedLines;
    const reason = !actionsOk ? 'actions' : !linesOk ? `lines ${added}` : undefined;
    return { ...base, ok: actionsOk && linesOk, falsePayment: !c.expect.payment && !!actions?.payment, reason, actions, raw };
  } catch (error) {
    return { ...base, ok: false, falsePayment: false, reason: `error: ${(error as Error).message}` };
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

function percent(part: number, whole: number): string {
  return whole === 0 ? '-' : `${((part / whole) * 100).toFixed(1)}%`;
}

async function main(): Promise<void> {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  const providers = (arg('providers') ?? 'gemini,claude').split(',');
  const runs = Number(arg('runs') ?? 1);
  const clients: Record<string, LlmProviderClient> = { gemini: new VertexGeminiClient(), claude: new ClaudeClient() };
  const load = (file: string): EvalCase[] => JSON.parse(fs.readFileSync(file, 'utf8'));
  const extra = arg('extra');
  const only = arg('only')?.split(',');
  const cases = [...load(path.join(__dirname, 'ai-finance-eval-cases.json')), ...(extra ? load(extra) : [])].filter(
    (c) => !only || only.some((prefix) => c.id.startsWith(prefix)),
  );

  const outcomes: Outcome[] = [];
  for (const provider of providers) {
    const jobs = Array.from({ length: runs }, () => cases).flat();
    outcomes.push(...(await pool(jobs, (c) => runCase(provider, clients[provider], c))));
  }

  let failed = false;
  for (const provider of providers) {
    const mine = outcomes.filter((o) => o.provider === provider);
    const count = (tag: string) => mine.filter((o) => o.tag === tag && o.falsePayment).length;
    const ok = mine.filter((o) => o.ok).length;
    const errors = mine.filter((o) => o.reason?.startsWith('error')).length;
    const met = count('future') === 0 && count('itemPrice') === 0 && ok / mine.length >= 0.95 && errors === 0;
    failed = failed || !met;
    console.log(`\n${provider}: ${met ? 'PASSED' : 'FAILED'}`);
    console.log(`  right: ${ok}/${mine.length} (${percent(ok, mine.length)}), target 95%`);
    console.log(`  future or negative became payment: ${count('future')}, target 0`);
    console.log(`  item price became payment: ${count('itemPrice')}, target 0`);
    console.log(`  call errors: ${errors}`);
    for (const miss of mine.filter((o) => !o.ok)) {
      console.log(`  x ${miss.id} "${miss.text}" [${miss.reason}] ${JSON.stringify(miss.actions ?? null)}`);
    }
  }

  const out = arg('out');
  if (out) fs.writeFileSync(out, JSON.stringify(outcomes, null, 2));
  process.exit(failed ? 1 : 0);
}

void main();
