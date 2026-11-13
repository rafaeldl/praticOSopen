jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { resetPaidPlansCache } from '../plan-limits.service';
import { checkCompanyPlanFeature, planFeatureError, requiredPlanFor } from '../plan-features.service';
import { currentPlanRows } from '../subscription-plans';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

describe('plan features', () => {
  beforeEach(() => {
    fake.reset();
    resetPaidPlansCache();
  });

  it('every gated feature of the table has a plan to move to', () => {
    const rows = currentPlanRows();
    for (const feature of rows.business.features) expect(requiredPlanFor(feature)).not.toBeNull();
    expect(requiredPlanFor('workStages')).toBe('pro');
    expect(requiredPlanFor('mcp')).toBe('business');
    expect(requiredPlanFor('charges')).toBe('starter');
  });

  it('switch off: allowed without reading the company', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'free' } });
    await expect(checkCompanyPlanFeature('c1', 'contracts')).resolves.toMatchObject({ allowed: true });
  });

  it('switch on: the plan of the company decides', async () => {
    fake.seed('config/paidPlans', { enabled: true });
    fake.seed('companies/free', { subscription: { plan: 'free' } });
    fake.seed('companies/pro', { subscription: { plan: 'pro', status: 'active', tableVersion: '2' } });
    fake.seed('companies/none', { name: 'Sem assinatura' });
    await expect(checkCompanyPlanFeature('free', 'contracts')).resolves.toMatchObject({ allowed: false, plan: 'free', requiredPlan: 'pro' });
    await expect(checkCompanyPlanFeature('none', 'charges')).resolves.toMatchObject({ allowed: false, requiredPlan: 'starter' });
    await expect(checkCompanyPlanFeature('pro', 'contracts')).resolves.toMatchObject({ allowed: true, plan: 'pro' });
    await expect(checkCompanyPlanFeature('pro', 'api')).resolves.toMatchObject({ allowed: false, requiredPlan: 'business' });
  });

  it('402 body names the feature and the plan that has it', () => {
    expect(planFeatureError({ allowed: false, feature: 'tvMode', plan: 'starter', requiredPlan: 'pro' }).error).toEqual({
      code: 'PLAN_FEATURE',
      message: 'Feature tvMode is not in the starter plan',
      feature: 'tvMode',
      plan: 'starter',
      requiredPlan: 'pro',
    });
  });
});
