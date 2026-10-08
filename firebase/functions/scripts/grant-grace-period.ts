/**
 * Launch grace period: 60 days of Pro (source 'grace') for every company that
 * does not have an active paid store subscription. Keeps `usage`; companies
 * already in grace are skipped, so re-running never extends it.
 * Spec: docs/superpowers/specs/2026-10-07-paid-plans-iap-design.md §5.3.
 * Prints aggregate counts only (no company names or ids: the repo is public).
 *
 * Emulator (dry-run unless --apply):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=praticos-app \
 *     npm run subscriptions:grace -- --apply
 *
 * Production (Application Default Credentials). Dry-run unless --apply;
 * --project is required:
 *   npm run subscriptions:grace -- --project=praticos
 *   npm run subscriptions:grace -- --project=praticos --apply [--days=60]
 */

import * as admin from 'firebase-admin';
import { buildGraceSubscription } from '../src/services/subscription-plans';
import type { Subscription } from '../src/models/types';

export interface Args {
  apply: boolean;
  days: number;
  project?: string;
}

export const USAGE = 'Usage: grant-grace-period.ts [--dry-run | --apply] [--days=60] [--project=<projectId>]';

const DAY_MS = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 400;

export function parseArgs(argv: string[]): Args {
  let apply = false;
  let dryRun = false;
  let days = 60;
  let project: string | undefined;
  for (const arg of argv) {
    if (arg === '--apply') {
      apply = true;
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--days=')) {
      const value = Number(arg.slice('--days='.length));
      if (!Number.isInteger(value) || value < 1 || value > 365) {
        throw new Error('--days must be an integer between 1 and 365');
      }
      days = value;
    } else if (arg.startsWith('--project=')) {
      project = arg.slice('--project='.length);
      if (!project) throw new Error('--project requires a value');
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (apply && dryRun) throw new Error('--apply and --dry-run are mutually exclusive');
  return { apply, days, project };
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
    return { projectId: args.project || env.GCLOUD_PROJECT || 'praticos-app', emulator, write: args.apply };
  }
  if (!args.project) {
    throw new Error('refusing to target production: pass --project=<projectId> (and --apply to write)');
  }
  return { projectId: args.project, emulator, write: args.apply };
}

export function graceExpiry(now: Date, days: number): Date {
  return new Date(now.getTime() + days * DAY_MS);
}

export type GracePlan =
  | { action: 'grant'; update: Record<string, unknown> }
  | { action: 'skip_paid' }
  | { action: 'skip_grace' };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

/** What to write for one company (`existing` = current `subscription` field). */
export function planGrace(existing: unknown, expiresAt: Date, now: Date): GracePlan {
  const current = isPlainObject(existing) ? (existing as unknown as Subscription) : undefined;
  if (current?.source === 'grace') return { action: 'skip_grace' };

  const grace = buildGraceSubscription(current, expiresAt, now);
  if (!grace) return { action: 'skip_paid' };

  const nowIso = now.toISOString();
  if (!current) {
    return { action: 'grant', update: { subscription: { ...grace, updatedAt: nowIso }, updatedAt: nowIso } };
  }
  return {
    action: 'grant',
    update: {
      'subscription.plan': grace.plan,
      'subscription.status': grace.status,
      'subscription.source': grace.source,
      'subscription.store': grace.store ?? null,
      'subscription.expiresAt': grace.expiresAt,
      'subscription.limits': grace.limits,
      'subscription.updatedAt': nowIso,
      updatedAt: nowIso,
      ...(current.usage ? {} : { 'subscription.usage': grace.usage }),
    },
  };
}

export interface GraceSummary {
  total: number;
  grant: number;
  skipPaid: number;
  skipGrace: number;
}

export function summarize(plans: GracePlan[]): GraceSummary {
  return {
    total: plans.length,
    grant: plans.filter((p) => p.action === 'grant').length,
    skipPaid: plans.filter((p) => p.action === 'skip_paid').length,
    skipGrace: plans.filter((p) => p.action === 'skip_grace').length,
  };
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

  const now = new Date();
  const expiresAt = graceExpiry(now, args.days);
  console.log(`Target: ${target.projectId} (${target.emulator ? 'EMULATOR' : 'PRODUCTION'})`);
  console.log(
    `Grace:  Pro until ${expiresAt.toISOString()} (${args.days} days)` +
      (target.write ? '' : ' [dry-run, nothing will be written]'),
  );

  admin.initializeApp({ projectId: target.projectId });
  const db = admin.firestore();
  const snapshot = await db.collection('companies').get();
  const plans = snapshot.docs.map((doc) => ({
    ref: doc.ref,
    plan: planGrace(doc.get('subscription'), expiresAt, now),
  }));

  const summary = summarize(plans.map((p) => p.plan));
  console.log(`Companies:                 ${summary.total}`);
  console.log(`Grant grace:               ${summary.grant}`);
  console.log(`Skip (paid subscription):  ${summary.skipPaid}`);
  console.log(`Skip (already in grace):   ${summary.skipGrace}`);

  if (!target.write) {
    console.log('Nothing written. Add --apply to write.');
    return;
  }

  let batch = db.batch();
  let pending = 0;
  let written = 0;
  for (const { ref, plan } of plans) {
    if (plan.action !== 'grant') continue;
    batch.update(ref, plan.update as FirebaseFirestore.UpdateData<FirebaseFirestore.DocumentData>);
    pending++;
    written++;
    if (pending === BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  console.log(`Written: ${written}`);
}

if (require.main === module) {
  main().catch((error: unknown) => {
    console.error(`Failed: ${error instanceof Error ? error.message : String(error)}`);
    process.exit(1);
  });
}
