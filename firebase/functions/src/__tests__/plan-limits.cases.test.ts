/**
 * Runs docs/web-app/contract-cases/plan-limits.json against plan-limits.service
 * (the same check as FeatureGateService). The Dart side is
 * test/contract/plan_limits_cases_test.dart. File listed in COVERED of
 * contract-cases.test.ts.
 */
import { readFileSync } from 'fs';
import * as path from 'path';
import { checkPlanLimit, shouldShowPdfWatermark, type PlanResource } from '../services/plan-limits.service';

const LANG = 'functions';
const doc = JSON.parse(readFileSync(path.join(__dirname, '../../../../docs/web-app/contract-cases/plan-limits.json'), 'utf8'));
const want = (c: any): any => ({ ...(c.correct ?? c.expect), ...c.divergesIn?.[LANG] });
const DAY_MS = 24 * 60 * 60 * 1000;

function subscriptionOf(given: any, now: Date) {
  if (given.subscription === null) return null;
  return given.expiresInDays === undefined
    ? given.subscription
    : { ...given.subscription, expiresAt: new Date(now.getTime() + given.expiresInDays * DAY_MS).toISOString() };
}

describe('plan-limits', () => {
  it('runs in functions', () => expect(doc.runsIn).toContain(LANG));

  for (const c of doc.cases) {
    it(c.id, () => {
      const { given } = c;
      const now = new Date();
      const subscription = subscriptionOf(given, now);
      if (given.kind === 'watermark') {
        expect({ watermark: shouldShowPdfWatermark(subscription, given.paidPlansEnabled, now) }).toEqual(want(c));
        return;
      }
      const result = checkPlanLimit({
        subscription,
        resource: given.resource as PlanResource,
        usage: given.usage,
        adding: given.adding,
        lastMonthUsage: given.lastMonthUsage,
        enforced: given.paidPlansEnabled,
        now,
      });
      const expected = want(c);
      const got: Record<string, unknown> = { ...result };
      expect(Object.fromEntries(Object.keys(expected).map((key) => [key, got[key]]))).toEqual(expected);
    });
  }
});
