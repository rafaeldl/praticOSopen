/**
 * Initial load of the NFS-e direct for the paid plans (docs/NFSE_DIRECT.md,
 * "Quem tem a nota"): turns settings/payments.nfseDirectEnabled on for every
 * company in Brazil on a paid plan or the courtesy, and off where the plan
 * that turned it on has ended. A key set by hand is never touched. After this
 * the trigger onCompanyWrittenNfseAccess and the daily job keep it in line.
 *
 *   npm run nfse:plan-access -- --project <projectId> --dry-run
 *   npm run nfse:plan-access -- --project <projectId>
 *
 * A real project must be named with --project; nothing has a default. On the
 * emulator (FIRESTORE_EMULATOR_HOST set) it uses the emulator's project.
 */

import * as admin from 'firebase-admin';

export interface Args {
  project?: string;
  dryRun: boolean;
}

export const USAGE = 'Usage: nfse-plan-access.ts --project <projectId> [--dry-run]';

export function parseArgs(argv: string[]): Args {
  const args: Args = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === '--dry-run') args.dryRun = true;
    else if (flag === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new Error('--project requires a value');
      args.project = value;
      i++;
    } else throw new Error(`unknown argument: ${flag}`);
  }
  return args;
}

export function resolveProject(args: Args, env: NodeJS.ProcessEnv): { projectId: string; emulator: boolean } {
  const emulator = !!env.FIRESTORE_EMULATOR_HOST;
  if (emulator) return { projectId: args.project || env.GCLOUD_PROJECT || 'demo-praticos', emulator };
  if (!args.project) throw new Error('refusing to guess a project: pass --project <projectId>');
  return { projectId: args.project, emulator };
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
  // Loaded after initializeApp: firestore.service reads the default app.
  const { reconcileNfseAccess } = await import('../src/services/nfse/nfse-access.service');
  console.log(`Target: ${target.projectId} (${target.emulator ? 'EMULATOR' : 'REAL PROJECT'})${args.dryRun ? ' — dry run' : ''}`);
  const result = await reconcileNfseAccess(new Date(), { dryRun: args.dryRun });
  console.log(`Checked ${result.checked} companies.`);
  console.log(`Turn on (${result.enabled.length}): ${result.enabled.join(', ') || '-'}`);
  console.log(`Turn off (${result.disabled.length}): ${result.disabled.join(', ') || '-'}`);
  console.log(`Set by hand, kept: ${result.manual}. Errors: ${result.errors}.`);
  if (args.dryRun) console.log('Dry run: nothing written.');
  if (result.errors) process.exit(1);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
