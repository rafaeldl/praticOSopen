/**
 * Recurring contracts on the server (docs/CONTRACTS_SERVER_JOB.md): the same
 * generation the app runs when it opens (contract-generation.ts), run by the
 * nightly job and by POST /v1/app/contracts/generate-due.
 *
 * Idempotency: each order is generated in one transaction that reads the
 * template, checks it is still due, and writes the order under a
 * deterministic id (template + due date) together with the advanced
 * `contract`. The job, the route and a retry running at the same time
 * produce one order. Old app versions generate without a transaction and
 * with a random id: that race is measured in contract-concurrency.emulator.test.ts.
 */

import { db, getRootCollection, getTenantCollection, runTransaction } from './firestore.service';
import {
  advanceContract,
  buildContractOrder,
  contractOrderId,
  shouldGenerate,
  wallClockOf,
  type ContractData,
} from './contract-generation';

type Json = Record<string, unknown>;

export type GenerationOutcome = 'generated' | 'already_generated' | 'not_due';

export interface TemplateResult {
  templateId: string;
  outcome: GenerationOutcome;
  orderId?: string;
}

export interface CompanyGenerationResult {
  /** False when the company has recurring contracts off (`useContracts`). */
  contractsOn: boolean;
  generated: number;
  /** Due date already had its order (a rewound template): only advanced. */
  alreadyGenerated: number;
  errors: number;
  results: TemplateResult[];
}

export interface GenerateOptions {
  /** Generation time. The job passes its scheduled time, so runs are exactly a day apart. */
  now: Date;
  /** Only templates created by this user (consultant and technician, like the app's query). */
  createdById?: string | null;
}

function companyAggr(companyId: string, data: Json): Json {
  return { id: companyId, name: data.name ?? null, country: data.country ?? null };
}

/**
 * Generates the order of one template if it is due at `now`, in a
 * transaction. A due date whose order already exists (the template was
 * rewound by a stale full save) only advances the template.
 */
export async function generateForTemplate(
  companyId: string,
  templateId: string,
  company: Json,
  now: Date,
): Promise<TemplateResult> {
  const orders = getTenantCollection(companyId, 'orders');
  const templateRef = orders.doc(templateId);
  const wallNow = wallClockOf(now);

  return runTransaction(async (tx) => {
    const snapshot = await tx.get(templateRef);
    const template = snapshot.exists ? (snapshot.data() as Json) : undefined;
    const contract = template?.contract as ContractData | undefined;
    if (!template || template.isContract !== true || !shouldGenerate(contract, wallNow)) {
      return { templateId, outcome: 'not_due' as const };
    }

    const orderId = contractOrderId(templateId, contract!.nextDueDate);
    const orderRef = orders.doc(orderId);
    const existing = await tx.get(orderRef);

    if (!existing.exists) {
      tx.set(orderRef, buildContractOrder(template, templateId, company, wallNow));
    }
    const advance = advanceContract(contract!, wallNow);
    const update: Json = {
      'contract.lastGeneratedDate': advance.lastGeneratedDate,
      'contract.nextDueDate': advance.nextDueDate,
      // A due date generated before keeps the count it already has.
      'contract.generatedCount': existing.exists ? (contract!.generatedCount ?? 0) : advance.generatedCount,
    };
    if (advance.active === false) update['contract.active'] = false;
    tx.update(templateRef, update);

    return { templateId, outcome: existing.exists ? 'already_generated' : 'generated', orderId };
  });
}

/**
 * Due orders of one company. Off unless the company has `useContracts`
 * (the app checks the same flag before generating). A failing template is
 * logged and skipped.
 */
export async function generateDueOrders(companyId: string, options: GenerateOptions): Promise<CompanyGenerationResult> {
  const result: CompanyGenerationResult = { contractsOn: false, generated: 0, alreadyGenerated: 0, errors: 0, results: [] };
  const companySnap = await getRootCollection('companies').doc(companyId).get();
  const companyData = companySnap.exists ? (companySnap.data() as Json) : undefined;
  if (companyData?.useContracts !== true) return result;
  result.contractsOn = true;

  let query: FirebaseFirestore.Query = getTenantCollection(companyId, 'orders').where('isContract', '==', true);
  if (options.createdById) query = query.where('createdBy.id', '==', options.createdById);
  const snapshot = await query.get();

  const wallNow = wallClockOf(options.now);
  const company = companyAggr(companyId, companyData);
  for (const doc of snapshot.docs) {
    // Cheap filter on the query result; the transaction checks again on fresh data.
    if (!shouldGenerate((doc.data() as Json).contract as ContractData | undefined, wallNow)) continue;
    try {
      const item = await generateForTemplate(companyId, doc.id, company, options.now);
      result.results.push(item);
      if (item.outcome === 'generated') result.generated++;
      if (item.outcome === 'already_generated') result.alreadyGenerated++;
    } catch (error) {
      result.errors++;
      console.error('[Contracts] Generation failed', {
        companyId,
        templateId: doc.id,
        error: error instanceof Error ? error.message : 'unknown',
      });
    }
  }
  return result;
}

const COMPANY_CONCURRENCY = 5;

/** Every company with `useContracts`. Used by the nightly job. */
export async function generateAllDueOrders(
  now: Date,
): Promise<{ companies: number; generated: number; alreadyGenerated: number; errors: number }> {
  const snapshot = await getRootCollection('companies').where('useContracts', '==', true).get();
  const ids = snapshot.docs.map((doc) => doc.id);
  const totals = { companies: ids.length, generated: 0, alreadyGenerated: 0, errors: 0 };
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < ids.length) {
      const companyId = ids[next++];
      try {
        const result = await generateDueOrders(companyId, { now });
        totals.generated += result.generated;
        totals.alreadyGenerated += result.alreadyGenerated;
        totals.errors += result.errors;
      } catch (error) {
        totals.errors++;
        console.error('[Contracts] Company failed', {
          companyId,
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(COMPANY_CONCURRENCY, ids.length) }, worker));
  return totals;
}

/**
 * Global switch of the nightly job: `config/contracts.jobEnabled == true`.
 * Off by default, because old app versions generate the same orders with a
 * random id (docs/CONTRACTS_SERVER_JOB.md, "Ligar o job").
 */
export async function isContractsJobEnabled(): Promise<boolean> {
  const snap = await db.collection('config').doc('contracts').get();
  return snap.exists && snap.get('jobEnabled') === true;
}

/**
 * Switch of POST /v1/app/contracts/generate-due: `config/contracts.routeEnabled == true`.
 * Off by default, for the same reason as the job: until the app stops
 * generating on its own, the web never generates (docs/CONTRACTS_SERVER_JOB.md).
 */
export async function isContractsRouteEnabled(): Promise<boolean> {
  const snap = await db.collection('config').doc('contracts').get();
  return snap.exists && snap.get('routeEnabled') === true;
}
