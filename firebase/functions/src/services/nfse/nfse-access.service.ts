/**
 * Who gets the NFS-e direct (docs/NFSE_DIRECT.md, "Quem tem a nota").
 *
 * The nota comes with the paid plans (Starter, Pro, Business) and the
 * courtesy (`source: 'grace'`), for companies in Brazil. Free has no nota.
 * The app, the web and the routes keep reading the same key,
 * `settings/payments.nfseDirectEnabled`; this service turns it on and off
 * from the plan and records why in `nfseDirectSource`:
 * - 'plan': turned on (or off) here, follows the plan;
 * - 'manual' or missing with the key on: set by hand (the pilot), never touched.
 * A key set off by hand with `nfseDirectSource: 'manual'` is not turned on either.
 */

import { db, getRootCollection } from '../firestore.service';
import { effectivePlan } from '../plan-limits.service';
import { currentPlanRows, PAID_PLANS_BY_RANK } from '../subscription-plans';

type Json = Record<string, unknown>;

export type NfseDirectSource = 'plan' | 'manual';

/** Brazil: `country` BR, or no country (old companies, like companyLanguage). */
export function isBrazilianCompany(country: unknown): boolean {
  if (country === undefined || country === null || country === '') return true;
  return typeof country === 'string' && country.trim().toUpperCase() === 'BR';
}

/** The plan in force gives the nota (nfseCnpjs not 0 in the table): Brazil and a paid plan or the courtesy. */
export function planGivesNfse(company: Json | null | undefined, now: Date): boolean {
  if (!company) return false;
  if (!isBrazilianCompany(company.country)) return false;
  return currentPlanRows()[effectivePlan(company.subscription as Json | undefined, now)].nfseCnpjs !== 0;
}

/** The key was set by hand: on without the 'plan' source, or with the 'manual' source. */
export function isManual(payments: Json | null | undefined): boolean {
  if (!payments) return false;
  if (payments.nfseDirectSource === 'manual') return true;
  return payments.nfseDirectEnabled === true && payments.nfseDirectSource !== 'plan';
}

/**
 * Fields to merge into settings/payments, or null when nothing changes.
 * Never touches a key set by hand.
 */
export function nfseAccessUpdate(payments: Json | null | undefined, entitled: boolean, now: Date): Json | null {
  if (isManual(payments)) return null;
  const enabled = payments?.nfseDirectEnabled === true;
  if (enabled === entitled) return null;
  return {
    nfseDirectEnabled: entitled,
    nfseDirectSource: 'plan' satisfies NfseDirectSource,
    nfseDirectUpdatedAt: now.toISOString(),
  };
}

/**
 * Fields of the company that decide the nota. The company document is written
 * often (counters, updatedAt): the trigger only acts when one of these changes.
 */
export function nfseAccessKey(company: Json | null | undefined): string | null {
  if (!company) return null;
  const subscription = (company.subscription ?? {}) as Json;
  return JSON.stringify([
    company.country ?? null,
    subscription.plan ?? null,
    subscription.status ?? null,
    subscription.source ?? null,
    subscription.expiresAt ?? null,
  ]);
}

export type NfseAccessResult = 'enabled' | 'disabled' | 'unchanged' | 'manual' | 'company_not_found';

function paymentsRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection('settings').doc('payments');
}

/**
 * Brings the key of one company in line with its plan. `company` is the
 * company data when the caller already has it (the trigger).
 */
export async function syncNfseAccess(
  companyId: string,
  options: { company?: Json | null; now?: Date; dryRun?: boolean } = {},
): Promise<NfseAccessResult> {
  const now = options.now ?? new Date();
  let company = options.company;
  if (company === undefined) {
    const snapshot = await getRootCollection('companies').doc(companyId).get();
    company = snapshot.exists ? (snapshot.data() as Json) : null;
  }
  if (!company) return 'company_not_found';

  const ref = paymentsRef(companyId);
  const payments = ((await ref.get()).data() ?? null) as Json | null;
  if (isManual(payments)) return 'manual';
  const update = nfseAccessUpdate(payments, planGivesNfse(company, now), now);
  if (!update) return 'unchanged';
  if (!options.dryRun) await ref.set(update, { merge: true });
  const result = update.nfseDirectEnabled ? 'enabled' : 'disabled';
  console.log(`[NfseAccess] Company ${companyId}: ${result}${options.dryRun ? ' (dry run)' : ''}`);
  return result;
}

/** Trigger body (companies/{companyId} written): acts only when plan or country changed. */
export async function handleCompanyWrittenNfseAccess(
  companyId: string,
  before: Json | undefined,
  after: Json | undefined,
  now: Date = new Date(),
): Promise<NfseAccessResult | 'skipped'> {
  if (!after) return 'skipped';
  if (before && nfseAccessKey(before) === nfseAccessKey(after)) return 'skipped';
  return syncNfseAccess(companyId, { company: after, now });
}

export interface ReconcileResult {
  enabled: string[];
  disabled: string[];
  manual: number;
  checked: number;
  errors: number;
}

/**
 * Every company that may need a change: on a paid plan (may need the key on)
 * or with the key on (may need it off, e.g. the plan ran out without a write).
 * Used by the daily job (backstop of the trigger) and the initial load script.
 */
export async function reconcileNfseAccess(
  now: Date = new Date(),
  options: { dryRun?: boolean } = {},
): Promise<ReconcileResult> {
  const ids = new Set<string>();
  const paid = await getRootCollection('companies').where('subscription.plan', 'in', PAID_PLANS_BY_RANK).get();
  for (const doc of paid.docs) ids.add(doc.id);
  const on = await db.collectionGroup('settings').where('nfseDirectEnabled', '==', true).get();
  for (const doc of on.docs) {
    // companies/{companyId}/settings/payments
    const [root, companyId, , id] = doc.ref.path.split('/');
    if (root === 'companies' && id === 'payments' && companyId) ids.add(companyId);
  }

  const result: ReconcileResult = { enabled: [], disabled: [], manual: 0, checked: ids.size, errors: 0 };
  for (const companyId of [...ids].sort()) {
    try {
      const outcome = await syncNfseAccess(companyId, { now, dryRun: options.dryRun });
      if (outcome === 'enabled') result.enabled.push(companyId);
      else if (outcome === 'disabled') result.disabled.push(companyId);
      else if (outcome === 'manual') result.manual++;
    } catch (error) {
      result.errors++;
      console.error('[NfseAccess] Sync failed', {
        companyId,
        error: error instanceof Error ? error.message : 'unknown',
      });
    }
  }
  console.log(
    `[NfseAccess] Reconcile${options.dryRun ? ' (dry run)' : ''}: checked=${result.checked} ` +
      `enabled=${result.enabled.length} disabled=${result.disabled.length} manual=${result.manual} errors=${result.errors}`,
  );
  return result;
}
