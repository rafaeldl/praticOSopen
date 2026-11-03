/**
 * First access on the web (docs/ONBOARDING.md, docs/WEB_APP.md): after the
 * browser creates the company with the same writes as the app, the segment's
 * checklists and, on "Criar meu PraticOS", its sample data come from here, the
 * server version of the app's BootstrapService (bootstrap-server.service.ts).
 * Nothing is taken from the request but the choice of samples and the language:
 * segment, specialties, names and country come from the company document.
 */

import { db } from './firestore.service';
import { executeServerBootstrap, syncCompanyFormsFromSegment } from './bootstrap-server.service';

export const ONBOARDING_LOCALES = ['pt-BR', 'en-US', 'es-ES'] as const;
export type OnboardingLocale = (typeof ONBOARDING_LOCALES)[number];

export class OnboardingSeedError extends Error {
  constructor(public code: 'NOT_FOUND' | 'NO_SEGMENT', public status: number) {
    super(code);
  }
}

/**
 * Specialties used for checklists and samples (OnboardingBusiness.seedSubspecialties):
 * the picked ones; with none picked in a segment that has specialties, all of them,
 * because the segment's `_default` samples may not exist.
 */
export function seedSubspecialties(picked: unknown, segmentSubspecialties: unknown): string[] {
  const chosen = Array.isArray(picked) ? picked.filter((id): id is string => typeof id === 'string' && !!id) : [];
  if (chosen.length) return chosen;
  if (!Array.isArray(segmentSubspecialties)) return [];
  return segmentSubspecialties
    .map((entry) => (entry && typeof entry === 'object' ? (entry as { id?: unknown }).id : null))
    .filter((id): id is string => typeof id === 'string' && !!id);
}

export interface OnboardingSeedResult {
  services: number;
  products: number;
  devices: number;
  customers: number;
  orders: number;
}

export async function seedOnboardingCompany(params: {
  companyId: string;
  userId: string;
  withSamples: boolean;
  locale: OnboardingLocale;
  now?: Date;
}): Promise<OnboardingSeedResult> {
  const { companyId, userId, withSamples, locale, now = new Date() } = params;
  const companySnap = await db.collection('companies').doc(companyId).get();
  if (!companySnap.exists) throw new OnboardingSeedError('NOT_FOUND', 404);
  const company = companySnap.data() ?? {};
  const segmentId = typeof company.segment === 'string' ? company.segment : '';
  if (!segmentId) throw new OnboardingSeedError('NO_SEGMENT', 400);

  const [segmentSnap, userSnap] = await Promise.all([
    db.collection('segments').doc(segmentId).get(),
    db.collection('users').doc(userId).get(),
  ]);
  const subspecialties = seedSubspecialties(company.subspecialties, segmentSnap.data()?.subspecialties);
  const userName = userSnap.data()?.name;
  const userAggr = { id: userId, name: typeof userName === 'string' ? userName : '' };
  const companyAggr = {
    id: companyId,
    name: typeof company.name === 'string' ? company.name : '',
    country: typeof company.country === 'string' ? company.country : undefined,
  };

  // Checklists always, with or without samples (onboarding.seed.checklists).
  await syncCompanyFormsFromSegment({ companyId, segmentId, subspecialties, userAggr, locale });
  const result: OnboardingSeedResult = { services: 0, products: 0, devices: 0, customers: 0, orders: 0 };
  if (!withSamples) return result;

  const bootstrap = await executeServerBootstrap({
    companyId,
    segmentId,
    subspecialties,
    userAggr,
    companyAggr,
    locale,
    syncForms: false,
    now,
  });
  return {
    services: bootstrap.createdServices.length,
    products: bootstrap.createdProducts.length,
    devices: bootstrap.createdDevices.length,
    customers: bootstrap.createdCustomers.length,
    orders: bootstrap.createdOrders.length,
  };
}
