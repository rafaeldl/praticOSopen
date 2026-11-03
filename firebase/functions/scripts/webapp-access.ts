/**
 * Who can open the web app (docs/WEB_APP.md, "Lista de acesso").
 * Writes config/webApp { open, allowedEmailHashes }. Only the SHA-256 of each
 * e-mail is stored, never the address.
 *
 *   npm run webapp:access -- --email pessoa@exemplo.com --project <projectId>
 *   npm run webapp:access -- --email pessoa@exemplo.com --remove --project <projectId>
 *   npm run webapp:access -- --show --project <projectId>
 *   npm run webapp:access -- --open | --close --project <projectId>
 *
 * A real project must be named with --project; nothing has a default. On the
 * emulator (FIRESTORE_EMULATOR_HOST set) it uses the emulator's project.
 * --dry-run prints the change without writing.
 */

import * as admin from 'firebase-admin';
import { hashEmail } from '../src/routes/v1/web-access.routes';

export interface Args {
  emails: string[];
  remove: boolean;
  open?: boolean;
  show: boolean;
  project?: string;
  dryRun: boolean;
}

export const USAGE =
  'Usage: webapp-access.ts (--email <e-mail>... [--remove] | --open | --close | --show) --project <projectId> [--dry-run]';

export function parseArgs(argv: string[]): Args {
  const args: Args = { emails: [], remove: false, show: false, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === '--remove') args.remove = true;
    else if (flag === '--show') args.show = true;
    else if (flag === '--dry-run') args.dryRun = true;
    else if (flag === '--open' || flag === '--close') {
      if (args.open !== undefined) throw new Error('use --open or --close, not both');
      args.open = flag === '--open';
    } else if (flag === '--email' || flag === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new Error(`${flag} requires a value`);
      i++;
      if (flag === '--email') {
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())) throw new Error(`not an e-mail: ${value}`);
        args.emails.push(value.trim().toLowerCase());
      } else args.project = value;
    } else throw new Error(`unknown argument: ${flag}`);
  }
  const actions = [args.emails.length > 0, args.open !== undefined, args.show].filter(Boolean).length;
  if (actions !== 1) throw new Error('pick one: --email, --open/--close or --show');
  if (args.remove && !args.emails.length) throw new Error('--remove goes with --email');
  return args;
}

export function resolveProject(args: Args, env: NodeJS.ProcessEnv): { projectId: string; emulator: boolean } {
  const emulator = !!env.FIRESTORE_EMULATOR_HOST;
  if (emulator) return { projectId: args.project || env.GCLOUD_PROJECT || 'demo-praticos', emulator };
  if (!args.project) throw new Error('refusing to guess a project: pass --project <projectId>');
  return { projectId: args.project, emulator };
}

export interface WebAppConfig {
  open: boolean;
  allowedEmailHashes: string[];
}

/** Next state of config/webApp. A missing document is closed and empty. */
export function nextConfig(current: Partial<WebAppConfig> | null, args: Args): WebAppConfig {
  const hashes = new Set(Array.isArray(current?.allowedEmailHashes) ? current.allowedEmailHashes : []);
  for (const email of args.emails) {
    if (args.remove) hashes.delete(hashEmail(email));
    else hashes.add(hashEmail(email));
  }
  return {
    open: args.open ?? current?.open === true,
    allowedEmailHashes: [...hashes].sort(),
  };
}

async function main(): Promise<void> {
  let args: Args;
  let target: { projectId: string; emulator: boolean };
  try {
    args = parseArgs(process.argv.slice(2));
    target = resolveProject(args, process.env);
  } catch (error) {
    console.error(`${error instanceof Error ? error.message : String(error)}\n${USAGE}`);
    process.exit(1);
  }

  admin.initializeApp({ projectId: target.projectId });
  const ref = admin.firestore().collection('config').doc('webApp');
  const current = ((await ref.get()).data() ?? null) as Partial<WebAppConfig> | null;
  console.log(`Target: ${target.projectId} (${target.emulator ? 'EMULATOR' : 'REAL PROJECT'})`);
  console.log(`Now: open=${current?.open === true}, ${current?.allowedEmailHashes?.length ?? 0} e-mail(s) allowed`);
  if (args.show) return;

  const next = nextConfig(current, args);
  console.log(`After: open=${next.open}, ${next.allowedEmailHashes.length} e-mail(s) allowed`);
  if (args.dryRun) {
    console.log('Dry run: nothing written.');
    return;
  }
  await ref.set({ ...next, updatedAt: new Date().toISOString() });
  console.log('Saved config/webApp.');
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
