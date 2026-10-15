/**
 * Turns the AI assistant on or off, per company or for every company
 * (docs/AI_ORDER_ASSIST.md, "Ligar e desligar").
 *
 * - Per company: merges companies/{id}/settings/ai. A field set here wins over
 *   the global switch. `follow` deletes the company's `enabled`/`provider` so
 *   it goes back to following config/ai (keeps monthlyLimit).
 * - Global (--all): merges config/ai { enabledForAll, defaultProvider }.
 * The Function reads config/ai at most once a minute, so a global change takes
 * up to a minute to reach every instance. No deploy and no app release needed.
 *
 *   npm run ai -- show   --project praticos [--company <id>]
 *   npm run ai -- on     --project praticos --company <id> [--provider claude] [--limit 50] --yes
 *   npm run ai -- off    --project praticos --company <id> --yes
 *   npm run ai -- follow --project praticos --company <id> --yes
 *   npm run ai -- on     --project praticos --all [--provider claude] --yes
 *   npm run ai -- off    --project praticos --all --yes
 *
 * Without --yes it only prints the plan (dry-run). Production needs an explicit
 * --project. On the emulator (FIRESTORE_EMULATOR_HOST set) it writes by default.
 */

import * as admin from 'firebase-admin';

export const ACTIONS = ['show', 'on', 'off', 'follow'] as const;
export type Action = (typeof ACTIONS)[number];
export const PROVIDERS = ['gemini', 'claude'] as const;
export type Provider = (typeof PROVIDERS)[number];

export interface Args {
  action: Action;
  companyIds: string[];
  all: boolean;
  provider?: Provider;
  limit?: number;
  project?: string;
  dryRun: boolean;
  yes: boolean;
}

export const USAGE =
  'Usage: ai-settings.ts <show|on|off|follow> (--company <id>... | --all) ' +
  '[--provider gemini|claude] [--limit <n>] [--dry-run] [--project <projectId> --yes]';

export function parseArgs(argv: string[]): Args {
  const [action, ...rest] = argv;
  if (!(ACTIONS as readonly string[]).includes(action ?? '')) throw new Error(`unknown action: ${action ?? '(none)'}`);
  const args: Args = { action: action as Action, companyIds: [], all: false, dryRun: false, yes: false };
  for (let i = 0; i < rest.length; i++) {
    const flag = rest[i];
    if (flag === '--all') args.all = true;
    else if (flag === '--yes') args.yes = true;
    else if (flag === '--dry-run') args.dryRun = true;
    else if (['--company', '--project', '--provider', '--limit'].includes(flag)) {
      const value = rest[i + 1];
      if (!value || value.startsWith('--')) throw new Error(`${flag} requires a value`);
      i++;
      if (flag === '--company') args.companyIds.push(value);
      else if (flag === '--project') args.project = value;
      else if (flag === '--provider') {
        if (!(PROVIDERS as readonly string[]).includes(value)) throw new Error(`unknown provider: ${value}`);
        args.provider = value as Provider;
      } else {
        const limit = Number(value);
        if (!Number.isInteger(limit) || limit < -1) throw new Error('--limit must be an integer >= -1 (-1 = unlimited)');
        args.limit = limit;
      }
    } else {
      throw new Error(`unknown argument: ${flag}`);
    }
  }
  if (args.all && args.companyIds.length > 0) throw new Error('use --all or --company, not both');
  if (args.action !== 'show' && !args.all && args.companyIds.length === 0) {
    throw new Error('pass --company <id> or --all');
  }
  if (args.all && args.action === 'follow') throw new Error('follow is per company');
  if (args.all && args.limit !== undefined) throw new Error('--limit is per company');
  if (args.action !== 'on' && (args.provider || args.limit !== undefined)) {
    throw new Error('--provider and --limit only go with on');
  }
  return args;
}

export interface Target {
  projectId: string;
  emulator: boolean;
  /** True when this run may write. */
  write: boolean;
}

/** Decides where to write and whether writing is allowed. Throws on unsafe setups. */
export function resolveTarget(args: Args, env: NodeJS.ProcessEnv): Target {
  const emulator = !!env.FIRESTORE_EMULATOR_HOST;
  if (emulator) {
    return { projectId: args.project || env.GCLOUD_PROJECT || 'praticos-app', emulator, write: !args.dryRun };
  }
  if (!args.project) {
    throw new Error('refusing to target production: pass --project <projectId> (and --yes to write)');
  }
  return { projectId: args.project, emulator, write: args.yes && !args.dryRun };
}

/** What to merge into config/ai (--all). */
export function buildGlobalUpdate(args: Args): Record<string, unknown> {
  return {
    enabledForAll: args.action === 'on',
    ...(args.provider ? { defaultProvider: args.provider } : {}),
  };
}

/** What to merge into companies/{id}/settings/ai. `null` = delete the field. */
export function buildCompanyUpdate(args: Args): Record<string, unknown> {
  if (args.action === 'follow') return { enabled: null, provider: null };
  return {
    enabled: args.action === 'on',
    ...(args.provider ? { provider: args.provider } : {}),
    ...(args.limit !== undefined ? { monthlyLimit: args.limit } : {}),
  };
}

function toFirestore(update: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(update).map(([k, v]) => [k, v === null ? admin.firestore.FieldValue.delete() : v]),
  );
}

async function main(): Promise<void> {
  let args: Args;
  let target: Target;
  try {
    args = parseArgs(process.argv.slice(2));
    target = resolveTarget(args, process.env);
  } catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${USAGE}`);
    process.exit(1);
  }

  admin.initializeApp({ projectId: target.projectId });
  const db = admin.firestore();
  const globalRef = db.collection('config').doc('ai');
  console.log(`Target: ${target.projectId} (${target.emulator ? 'EMULATOR' : 'PRODUCTION'})`);
  console.log(`config/ai: ${JSON.stringify((await globalRef.get()).data() ?? null)}`);

  const plans: { label: string; ref: FirebaseFirestore.DocumentReference; update: Record<string, unknown> }[] = [];
  if (args.all && args.action !== 'show') {
    plans.push({ label: 'config/ai (every company)', ref: globalRef, update: buildGlobalUpdate(args) });
  }
  // Validate every company first so a typo does not leave a partial run.
  for (const id of args.companyIds) {
    const company = await db.collection('companies').doc(id).get();
    if (!company.exists) {
      console.error(`Company ${id} not found`);
      process.exit(1);
    }
    const ref = company.ref.collection('settings').doc('ai');
    console.log(`- ${company.get('name') ?? '(no name)'} (${id}) settings/ai: ${JSON.stringify((await ref.get()).data() ?? null)}`);
    if (args.action !== 'show') plans.push({ label: id, ref, update: buildCompanyUpdate(args) });
  }

  if (plans.length === 0) return;
  for (const plan of plans) console.log(`merge into ${plan.label}: ${JSON.stringify(plan.update)}`);
  if (!target.write) {
    console.log('Nothing written.' + (!target.emulator && !args.yes ? ' Add --yes to apply.' : ''));
    return;
  }
  for (const plan of plans) {
    await plan.ref.set(toFirestore(plan.update), { merge: true });
    console.log(`after (${plan.label}): ${JSON.stringify((await plan.ref.get()).data() ?? null)}`);
  }
  if (args.all) console.log('Global change reaches every Function instance within a minute.');
}

if (require.main === module) {
  main().catch((error: unknown) => {
    console.error(`Failed: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
  });
}
