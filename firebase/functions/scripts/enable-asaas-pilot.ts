/**
 * Enable (or disable) the Asaas pilot for one or more companies.
 * Merges companies/{companyId}/settings/payments.asaasEnabled. The app only shows
 * Integrações > Asaas when this flag is true; users can never set it themselves.
 * Never touches asaasConnected/credentials of a doc that already exists.
 *
 * Emulator (writes by default):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=praticos-app \
 *     npm run asaas:pilot -- --company test_company_001
 *
 * Production (Application Default Credentials). Without --yes it only prints the
 * plan (dry-run); writing requires an explicit --project and --yes:
 *   npm run asaas:pilot -- --project praticos --company <id> [--company <id2>]
 *   npm run asaas:pilot -- --project praticos --company <id> --yes
 *   npm run asaas:pilot -- --project praticos --company <id> --disable --yes
 */

import * as admin from 'firebase-admin';

export interface Args {
  companyIds: string[];
  dryRun: boolean;
  disable: boolean;
  yes: boolean;
  project?: string;
}

export const USAGE =
  'Usage: enable-asaas-pilot.ts --company <id> [--company <id>...] [--dry-run] [--disable] [--project <projectId> --yes]';

export function parseArgs(argv: string[]): Args {
  const companyIds: string[] = [];
  let project: string | undefined;
  const flags = ['--dry-run', '--disable', '--yes'];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--company' || argv[i] === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new Error(`${argv[i]} requires a value`);
      if (argv[i] === '--company') companyIds.push(value);
      else project = value;
      i++;
    } else if (!flags.includes(argv[i])) {
      throw new Error(`unknown argument: ${argv[i]}`);
    }
  }
  if (companyIds.length === 0) throw new Error('at least one --company is required');
  return {
    companyIds,
    dryRun: argv.includes('--dry-run'),
    disable: argv.includes('--disable'),
    yes: argv.includes('--yes'),
    project,
  };
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

export function buildUpdate(exists: boolean, disable: boolean): Record<string, boolean> {
  const asaasEnabled = !disable;
  return exists ? { asaasEnabled } : { asaasEnabled, asaasConnected: false };
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

  console.log(`Target:    ${target.projectId} (${target.emulator ? 'EMULATOR' : 'PRODUCTION'})`);
  console.log(`Companies: ${args.companyIds.join(', ')}`);
  console.log(`Action:    ${args.disable ? 'DISABLE' : 'ENABLE'} asaasEnabled${target.write ? '' : ' [dry-run, nothing will be written]'}`);

  admin.initializeApp({ projectId: target.projectId });
  const db = admin.firestore();

  // Validate every company first so a typo does not leave a partial run.
  const plans: { id: string; ref: FirebaseFirestore.DocumentReference; update: Record<string, boolean> }[] = [];
  for (const id of args.companyIds) {
    const companyRef = db.collection('companies').doc(id);
    const company = await companyRef.get();
    if (!company.exists) {
      console.error(`Company ${id} not found`);
      process.exit(1);
    }
    const ref = companyRef.collection('settings').doc('payments');
    const current = await ref.get();
    const update = buildUpdate(current.exists, args.disable);
    console.log(`- ${company.get('name') ?? '(no name)'} (${id})`);
    console.log(`  before: ${JSON.stringify(current.exists ? current.data() : null)}`);
    console.log(`  merge:  ${JSON.stringify(update)}`);
    plans.push({ id, ref, update });
  }

  if (!target.write) {
    console.log('Nothing written.' + (!target.emulator && !args.yes ? ' Add --yes to apply.' : ''));
    return;
  }

  for (const plan of plans) {
    await plan.ref.set(plan.update, { merge: true });
    console.log(`  after (${plan.id}): ${JSON.stringify((await plan.ref.get()).data())}`);
  }
  console.log(args.disable ? 'Asaas pilot DISABLED' : 'Asaas pilot ENABLED');
}

if (require.main === module) {
  main().catch((error: unknown) => {
    console.error(`Failed: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
  });
}
