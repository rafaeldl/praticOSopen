/**
 * Runs messages in sequence on one order against the real models, with the
 * real prompt, parser and runOrderAssist (issue #631): the screen keeps the
 * last 3 messages and sends what the order has, and a field the assistant put
 * may be corrected while one the person set never changes. The order here is
 * a simulation of the app's _applyDraft with those rules.
 *
 * GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/ai-memory-eval.ts
 *   --providers gemini,claude   which models (default both)
 *   --runs 2                    repeats per scenario (default 1)
 *   --only <prefix,prefix>      only the scenarios whose id starts with one of these
 *   --out <file.json>           saves every step
 *   EVAL_DEBUG=1                prints each model answer
 *
 * Targets: 0 duplicated lines, every correction applied, nothing the person
 * set replaced. Costs real calls; does not touch Firestore. Exits 1 when a
 * target fails. Fictional names and plates only (the repository is public).
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import { ClaudeClient } from '../src/services/ai/claude.client';
import { VertexGeminiClient } from '../src/services/ai/gemini.client';
import type { LlmProviderClient } from '../src/services/ai/llm.client';
import {
  normalizeName,
  runOrderAssist,
  todayLabel,
  type CompanyCatalog,
  type OrderAssistContext,
  type OrderAssistInput,
  type OrderDraft,
} from '../src/services/ai/order-assist.service';

const CONCURRENCY = 4;
const CATALOG: CompanyCatalog = {
  services: [
    { id: 's1', name: 'Troca de óleo', value: 150 },
    { id: 's2', name: 'Alinhamento', value: 100 },
    { id: 's3', name: 'Balanceamento', value: 80 },
    { id: 's4', name: 'Limpeza', value: 200 },
  ],
  products: [
    { id: 'p1', name: 'Filtro de óleo', value: 50 },
    { id: 'p2', name: 'Óleo', value: 40 },
  ],
};

// ─── Simulated order ──────────────────────────────────────────────────────

interface Line { kind: 'service' | 'product'; name: string; description?: string | null; value: number | null; quantity: number }
interface Field<T> { value: T; fromAi: boolean }
interface State {
  customer: Field<string> | null;
  devices: Field<{ name?: string; serial?: string }>[];
  request: Field<string> | null;
  due: Field<string> | null;
  lines: Line[];
  history: string[];
}

const plate = (s?: string | null) => (s ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');

function contextOf(state: State): OrderAssistContext {
  return {
    customer: { chosen: !!state.customer, fromAi: !!state.customer?.fromAi },
    ...(state.devices.length
      ? {
          devices: state.devices.map((d) => ({
            ...(d.value.name ? { name: d.value.name } : {}),
            ...(d.value.serial ? { serial: d.value.serial } : {}),
            fromAi: d.fromAi,
          })),
        }
      : {}),
    ...(state.request ? { request: { text: state.request.value, fromAi: state.request.fromAi } } : {}),
    ...(state.due ? { due: { date: state.due.value, fromAi: state.due.fromAi } } : {}),
  };
}

/** The app's rules: changes on the lines sent, a field only when blank or put by the assistant. */
function apply(draft: OrderDraft, state: State): void {
  const sent = { service: state.lines.filter((l) => l.kind === 'service'), product: state.lines.filter((l) => l.kind === 'product') };
  const removed = new Set<Line>();
  for (const change of draft.changes) {
    const line = change.line ? sent[change.line.kind][change.line.index] : undefined;
    if (!line) continue; // ambiguous: the app asks
    if (change.action === 'remove') removed.add(line);
    else {
      if (change.value !== undefined) line.value = change.value;
      if (change.quantity !== undefined) line.quantity = change.quantity;
      if (change.description !== undefined) line.description = change.description;
    }
  }
  state.lines = state.lines.filter((l) => !removed.has(l));
  const name = draft.customer?.match?.name ?? draft.customer?.guess?.name;
  if (name && (!state.customer || state.customer.fromAi)) state.customer = { value: name, fromAi: true };
  const d = draft.device;
  if (d?.guess) {
    const device = { name: d.guess.name, serial: d.guess.serial };
    const target = d.replaces !== undefined ? state.devices[d.replaces] : undefined;
    if (target?.fromAi) state.devices[d.replaces as number] = { value: device, fromAi: true };
    else if (!device.serial || !state.devices.some((x) => plate(x.value.serial) === plate(device.serial))) {
      state.devices.push({ value: device, fromAi: true });
    }
  }
  for (const item of draft.items) {
    state.lines.push({ kind: item.kind, name: item.name, description: item.description, value: item.value, quantity: item.quantity });
  }
  if (draft.notes && (!state.request || state.request.fromAi)) state.request = { value: draft.notes, fromAi: true };
  if (draft.dueDate && (!state.due || state.due.fromAi)) state.due = { value: draft.dueDate, fromAi: true };
}

// ─── Scenarios ─────────────────────────────────────────────────────────────

interface Expect {
  /** Lines that must be there (catalog name), with value/quantity when given. */
  lines?: { name: string; value?: number; quantity?: number }[];
  /** Exactly this many lines. */
  lineCount?: number;
  devices?: { serial?: string; name?: string }[];
  customer?: string;
  /** Words the request must have (lowercase, no accents). */
  request?: string;
  /** "YYYY-MM-DD" the deadline starts with. */
  due?: string;
}
interface Step { text: string; expect?: Expect; correction?: boolean }
interface Scenario { id: string; start?: Partial<State>; steps: Step[] }

/** Next weekday after today (0 = Sunday), as the prompt says. */
function nextWeekday(weekday: number, from = todayLabel().slice(0, 10)): string {
  const date = new Date(`${from}T12:00:00Z`);
  do date.setUTCDate(date.getUTCDate() + 1);
  while (date.getUTCDay() !== weekday);
  return date.toISOString().slice(0, 10);
}
const tomorrow = (() => {
  const date = new Date(`${todayLabel().slice(0, 10)}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
})();

const user = <T>(value: T): Field<T> => ({ value, fromAi: false });

const SCENARIOS: Scenario[] = [
  {
    id: 'fix-plate',
    steps: [
      { text: 'Gol 2018 placa ABC1234, troca de óleo', expect: { devices: [{ serial: 'ABC1234' }] } },
      { text: 'não, a placa é ABC1D23', correction: true, expect: { devices: [{ serial: 'ABC1D23' }], lineCount: 1 } },
    ],
  },
  {
    id: 'fix-model',
    steps: [
      { text: 'é um Gol, faz o alinhamento', expect: { devices: [{ name: 'gol' }] } },
      { text: 'não, é um Corsa', correction: true, expect: { devices: [{ name: 'corsa' }], lineCount: 1 } },
    ],
  },
  {
    id: 'fix-plate-2',
    steps: [
      { text: 'Onix prata, placa DEF2G34, alinhamento e balanceamento', expect: { devices: [{ serial: 'DEF2G34' }], lineCount: 2 } },
      { text: 'a placa tá errada, é DEF2G35', correction: true, expect: { devices: [{ serial: 'DEF2G35' }], lineCount: 2 } },
    ],
  },
  {
    id: 'fix-due',
    steps: [
      { text: 'troca de óleo, pronto sexta', expect: { due: nextWeekday(5) } },
      { text: 'o prazo é segunda', correction: true, expect: { due: nextWeekday(1), lineCount: 1 } },
    ],
  },
  {
    id: 'fix-value',
    steps: [
      { text: 'troca de óleo 300', expect: { lines: [{ name: 'Troca de óleo', value: 300 }] } },
      { text: 'não, era 350', correction: true, expect: { lines: [{ name: 'Troca de óleo', value: 350 }], lineCount: 1 } },
    ],
  },
  {
    id: 'fix-quantity',
    steps: [
      { text: 'põe 2 litros de óleo', expect: { lines: [{ name: 'Óleo', quantity: 2 }] } },
      { text: 'não, são 4', correction: true, expect: { lines: [{ name: 'Óleo', quantity: 4 }], lineCount: 1 } },
    ],
  },
  {
    id: 'fix-customer',
    steps: [
      { text: 'OS da Joana Teste, troca de óleo', expect: { customer: 'joana' } },
      { text: 'não, o cliente é o Pedro Exemplo', correction: true, expect: { customer: 'pedro', lineCount: 1 } },
    ],
  },
  {
    id: 'fix-request',
    steps: [
      { text: 'barulho na suspensão, faz o alinhamento', expect: { request: 'suspens' } },
      { text: 'não, o barulho é no freio', correction: true, expect: { request: 'freio', lines: [{ name: 'Alinhamento' }] } },
    ],
  },
  {
    id: 'fix-due-2',
    steps: [
      { text: 'limpeza, entregar amanhã', expect: { due: tomorrow } },
      { text: 'errei, é pra quarta', correction: true, expect: { due: nextWeekday(3), lineCount: 1 } },
    ],
  },
  {
    id: 'same-value',
    steps: [
      { text: 'alinhamento 120', expect: { lines: [{ name: 'Alinhamento', value: 120 }] } },
      { text: 'e o balanceamento, o mesmo valor', correction: true, expect: { lines: [{ name: 'Alinhamento', value: 120 }, { name: 'Balanceamento', value: 120 }], lineCount: 2 } },
    ],
  },
  {
    id: 'no-repeat',
    steps: [
      { text: 'troca de óleo e filtro de óleo', expect: { lineCount: 2 } },
      { text: 'põe também uma limpeza', expect: { lineCount: 3 } },
      { text: 'e o balanceamento', expect: { lineCount: 4 } },
    ],
  },
  {
    id: 'four-steps',
    steps: [
      { text: 'troca de óleo 150', expect: { lineCount: 1 } },
      { text: 'filtro de óleo', expect: { lineCount: 2 } },
      { text: 'o filtro é 60', correction: true, expect: { lines: [{ name: 'Filtro de óleo', value: 60 }], lineCount: 2 } },
      { text: 'pronto amanhã', expect: { due: tomorrow, lineCount: 2 } },
    ],
  },
  {
    id: 'second-vehicle',
    steps: [
      { text: 'Gol placa ABC1234, alinhamento', expect: { devices: [{ serial: 'ABC1234' }] } },
      { text: 'e o outro carro, Uno placa XYZ9A88, faz o balanceamento', expect: { devices: [{ serial: 'ABC1234' }, { serial: 'XYZ9A88' }] } },
    ],
  },
  {
    id: 'user-customer',
    start: { customer: user('cliente escolhido') },
    steps: [{ text: 'é da Joana Teste, troca de óleo', expect: { customer: 'cliente escolhido', lineCount: 1 } }],
  },
  {
    id: 'user-device',
    start: { devices: [user({ name: 'Corsa', serial: 'MMM0099' })] },
    steps: [
      { text: 'troca de óleo', expect: { lineCount: 1 } },
      // Adding the plate as another vehicle is allowed; replacing the Corsa is not (userKept).
      { text: 'não, a placa é ABC1D23', expect: { lineCount: 1 } },
    ],
  },
  {
    id: 'user-due',
    start: { due: user(`${nextWeekday(5)}T18:00`) },
    steps: [{ text: 'o prazo é segunda, troca de óleo', expect: { due: nextWeekday(5), lineCount: 1 } }],
  },
  {
    id: 'user-request',
    start: { request: user('Cliente pediu revisão') },
    steps: [{ text: 'o barulho é na roda, faz o alinhamento', expect: { request: 'revisao', lineCount: 1 } }],
  },
  // Unseen when the prompt was tuned: run once with --only h- (no tuning on them).
  {
    id: 'h-plate',
    steps: [
      { text: 'Fiorino branca placa GHI3J45, troca de óleo e filtro', expect: { devices: [{ serial: 'GHI3J45' }], lineCount: 2 } },
      { text: 'opa, a placa certa é GHI3J46', correction: true, expect: { devices: [{ serial: 'GHI3J46' }], lineCount: 2 } },
    ],
  },
  {
    id: 'h-model',
    steps: [
      { text: 'HB20 placa JKL4M56, balanceamento', expect: { devices: [{ serial: 'JKL4M56' }] } },
      { text: 'não é HB20, é Creta', correction: true, expect: { devices: [{ name: 'creta' }], lineCount: 1 } },
    ],
  },
  {
    id: 'h-value-then-more',
    steps: [
      { text: 'limpeza 250', expect: { lines: [{ name: 'Limpeza', value: 250 }] } },
      { text: 'não, 280', correction: true, expect: { lines: [{ name: 'Limpeza', value: 280 }], lineCount: 1 } },
      { text: 'e põe um alinhamento também', expect: { lines: [{ name: 'Limpeza', value: 280 }], lineCount: 2 } },
    ],
  },
  {
    id: 'h-due',
    steps: [
      { text: 'troca de óleo pra segunda', expect: { due: nextWeekday(1) } },
      { text: 'não, ele quer na terça', correction: true, expect: { due: nextWeekday(2), lineCount: 1 } },
    ],
  },
  {
    id: 'h-same-for-other',
    steps: [
      { text: 'filtro de óleo 70', expect: { lines: [{ name: 'Filtro de óleo', value: 70 }] } },
      { text: 'o óleo também é 70', expect: { lines: [{ name: 'Filtro de óleo', value: 70 }, { name: 'Óleo', value: 70 }], lineCount: 2 } },
    ],
  },
  {
    id: 'h-customer',
    steps: [
      { text: 'cliente Marta Exemplo, limpeza', expect: { customer: 'marta' } },
      { text: 'errei o nome, é Marcia Exemplo', correction: true, expect: { customer: 'marcia', lineCount: 1 } },
    ],
  },
  {
    id: 'h-user-all',
    start: {
      customer: user('cliente escolhido'),
      devices: [user({ name: 'Strada', serial: 'NOP5Q67' })],
      request: user('Revisão completa'),
      due: user(`${nextWeekday(3)}T18:00`),
    },
    steps: [
      { text: 'é do Bruno Teste, o carro é um Toro, entregar sexta, o defeito é no ar', expect: { customer: 'cliente escolhido', request: 'revisao completa', due: nextWeekday(3) } },
      { text: 'põe uma limpeza', expect: { lineCount: 1 } },
    ],
  },
];

// ─── Checks ────────────────────────────────────────────────────────────────

const words = (s?: string | null) => normalizeName(s ?? '');

function duplicates(lines: Line[]): number {
  const keys = lines.map((l) => `${l.kind}|${words(l.name)}|${words(l.description)}`);
  return keys.length - new Set(keys).size;
}

function check(state: State, expect: Expect | undefined): string[] {
  if (!expect) return [];
  const misses: string[] = [];
  for (const want of expect.lines ?? []) {
    const line = state.lines.find((l) => words(l.name) === words(want.name));
    if (!line) misses.push(`no line ${want.name}`);
    else if (want.value !== undefined && line.value !== want.value) misses.push(`${want.name} value ${line.value}`);
    else if (want.quantity !== undefined && line.quantity !== want.quantity) misses.push(`${want.name} quantity ${line.quantity}`);
  }
  if (expect.lineCount !== undefined && state.lines.length !== expect.lineCount) misses.push(`lines ${state.lines.length}`);
  if (expect.devices) {
    if (state.devices.length !== expect.devices.length) misses.push(`devices ${state.devices.length}`);
    expect.devices.forEach((want, i) => {
      const got = state.devices[i]?.value;
      if (want.serial && plate(got?.serial) !== want.serial) misses.push(`device ${i + 1} serial ${got?.serial}`);
      if (want.name && !words(got?.name).includes(want.name)) misses.push(`device ${i + 1} name ${got?.name}`);
    });
  }
  if (expect.customer && !words(state.customer?.value).includes(expect.customer)) misses.push(`customer ${state.customer?.value}`);
  if (expect.request && !words(state.request?.value).includes(expect.request)) misses.push(`request ${state.request?.value}`);
  if (expect.due && !state.due?.value.startsWith(expect.due)) misses.push(`due ${state.due?.value}`);
  return misses;
}

/** What the person set at the start must be the same at the end. */
function userFieldsKept(start: Partial<State> | undefined, state: State): boolean {
  if (start?.customer && state.customer?.value !== start.customer.value) return false;
  if (start?.request && state.request?.value !== start.request.value) return false;
  if (start?.due && state.due?.value !== start.due.value) return false;
  for (const d of start?.devices ?? []) {
    if (!state.devices.some((x) => !x.fromAi && plate(x.value.serial) === plate(d.value.serial))) return false;
  }
  return true;
}

interface StepResult { text: string; misses: string[]; duplicates: number; correction: boolean; error?: string; draft?: unknown }
interface Outcome { provider: string; id: string; steps: StepResult[]; userKept: boolean; ms: number }

async function runScenario(provider: string, client: LlmProviderClient, scenario: Scenario): Promise<Outcome> {
  const state: State = {
    customer: null,
    devices: [],
    request: null,
    due: null,
    lines: [],
    history: [],
    ...JSON.parse(JSON.stringify(scenario.start ?? {})),
  };
  const deps = {
    llm: {
      // EVAL_DEBUG=1 prints what the model sent back.
      generateJson: async (request: Parameters<LlmProviderClient['generateJson']>[0]) => {
        const raw = await client.generateJson(request);
        if (process.env.EVAL_DEBUG) console.log(raw);
        return raw;
      },
    },
    getSettings: async () => ({ enabled: true }) as never,
    reserve: async () => ({ ok: true, used: 1, limit: 1000, monthKey: 'eval' }) as never,
    release: async () => undefined,
    loadCatalog: async () => CATALOG,
    findCustomers: async () => [],
    findDevices: async () => [],
    deviceLabel: async () => 'Veículo',
  };
  const started = Date.now();
  const steps: StepResult[] = [];
  for (const step of scenario.steps) {
    const input: OrderAssistInput = {
      text: step.text,
      locale: 'pt',
      order: {
        services: state.lines.filter((l) => l.kind === 'service').map((l) => ({ name: l.name, ...(l.description ? { description: l.description } : {}), value: l.value })),
        products: state.lines.filter((l) => l.kind === 'product').map((l) => ({ name: l.name, ...(l.description ? { description: l.description } : {}), value: l.value, quantity: l.quantity })),
      },
      ...(state.history.length ? { history: [...state.history] } : {}),
      context: contextOf(state),
    };
    try {
      const draft = await runOrderAssist('eval', input, deps as never);
      apply(draft, state);
      state.history = [...state.history, step.text.slice(0, 500)].slice(-3);
      steps.push({ text: step.text, misses: check(state, step.expect), duplicates: duplicates(state.lines), correction: !!step.correction, draft: { customer: draft.customer, device: draft.device, items: draft.items.map((i) => i.name), changes: draft.changes, notes: draft.notes, dueDate: draft.dueDate } });
    } catch (error) {
      steps.push({ text: step.text, misses: ['error'], duplicates: 0, correction: !!step.correction, error: (error as Error).message });
      break;
    }
  }
  return { provider, id: scenario.id, steps, userKept: userFieldsKept(scenario.start, state), ms: Date.now() - started };
}

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
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

async function main(): Promise<void> {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
  const providers = (arg('providers') ?? 'gemini,claude').split(',');
  const runs = Number(arg('runs') ?? 1);
  const only = arg('only')?.split(',');
  const clients: Record<string, LlmProviderClient> = { gemini: new VertexGeminiClient(), claude: new ClaudeClient() };
  const scenarios = SCENARIOS.filter((s) => !only || only.some((prefix) => s.id.startsWith(prefix)));

  const outcomes: Outcome[] = [];
  for (const provider of providers) {
    const jobs = Array.from({ length: runs }, () => scenarios).flat();
    outcomes.push(...(await pool(jobs, (s) => runScenario(provider, clients[provider], s))));
  }

  let failed = false;
  for (const provider of providers) {
    const mine = outcomes.filter((o) => o.provider === provider);
    const steps = mine.flatMap((o) => o.steps);
    const ok = steps.filter((s) => !s.misses.length).length;
    const corrections = steps.filter((s) => s.correction);
    const fixed = corrections.filter((s) => !s.misses.length).length;
    const dups = steps.reduce((n, s) => Math.max(n, s.duplicates), 0);
    const dupScenarios = mine.filter((o) => o.steps.some((s) => s.duplicates > 0)).length;
    const replaced = mine.filter((o) => !o.userKept).length;
    const errors = steps.filter((s) => s.error).length;
    const met = dupScenarios === 0 && fixed === corrections.length && replaced === 0 && errors === 0;
    failed = failed || !met;
    console.log(`\n${provider}: ${met ? 'PASSED' : 'FAILED'}`);
    console.log(`  steps right: ${ok}/${steps.length}`);
    console.log(`  corrections applied: ${fixed}/${corrections.length}, target all`);
    console.log(`  scenarios with a duplicated line: ${dupScenarios} (most in one order: ${dups}), target 0`);
    console.log(`  scenarios where something the person set changed: ${replaced}, target 0`);
    console.log(`  call errors: ${errors}`);
    for (const o of mine) {
      for (const s of o.steps.filter((x) => x.misses.length || x.duplicates)) {
        console.log(`  x ${o.id} "${s.text}" [${s.misses.join('; ')}${s.duplicates ? `; ${s.duplicates} duplicated` : ''}]${s.error ? ` ${s.error}` : ''}`);
      }
      if (!o.userKept) console.log(`  x ${o.id}: changed what the person set`);
    }
  }

  const out = arg('out');
  if (out) fs.writeFileSync(out, JSON.stringify(outcomes, null, 2));
  process.exit(failed ? 1 : 0);
}

void main();
