/**
 * Runs docs/web-app/contract-cases/plan-features.json against
 * plan-features.service (the same check as FeatureGateService.checkFeature in
 * the app and src/lib/plan-features.ts on the web). File listed in COVERED of
 * contract-cases.test.ts.
 */
import { readFileSync } from 'fs';
import * as path from 'path';
import { checkPlanFeature, featureForRole } from '../services/plan-features.service';

const LANG = 'functions';
const doc = JSON.parse(readFileSync(path.join(__dirname, '../../../../docs/web-app/contract-cases/plan-features.json'), 'utf8'));
const DAY_MS = 24 * 60 * 60 * 1000;

describe('plan-features', () => {
  it('runs in functions', () => expect(doc.runsIn).toContain(LANG));

  for (const c of doc.cases) {
    it(c.id, () => {
      const { given } = c;
      if (given.kind === 'role') {
        expect({ feature: featureForRole(given.role) }).toEqual(c.expect);
        return;
      }
      const now = new Date();
      const subscription =
        given.subscription === null || given.expiresInDays === undefined
          ? given.subscription
          : { ...given.subscription, expiresAt: new Date(now.getTime() + given.expiresInDays * DAY_MS).toISOString() };
      const result = checkPlanFeature({ subscription, feature: given.feature, enforced: given.paidPlansEnabled, now });
      expect({ allowed: result.allowed, plan: result.plan, requiredPlan: result.requiredPlan }).toEqual(c.expect);
    });
  }
});
