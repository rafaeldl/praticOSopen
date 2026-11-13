/**
 * Runs docs/web-app/contract-cases/paid-plans-config.json against
 * paid-plans-config.ts. The app runs it in test/contract/paid_plans_config_cases_test.dart
 * and the web in tests/contract-cases.test.ts. File listed in COVERED of
 * contract-cases.test.ts.
 */
import { readFileSync } from 'fs';
import * as path from 'path';
import { freeLimitsNoticeDue, lastMonthCounts, paidPlansOnFor, parsePaidPlansConfig } from '../services/paid-plans-config';

const LANG = 'functions';
const doc = JSON.parse(readFileSync(path.join(__dirname, '../../../../docs/web-app/contract-cases/paid-plans-config.json'), 'utf8'));
const want = (c: any): any => ({ ...(c.correct ?? c.expect), ...c.divergesIn?.[LANG] });

describe('paid-plans-config', () => {
  it('runs in functions', () => expect(doc.runsIn).toContain(LANG));

  for (const c of doc.cases) {
    it(c.id, () => {
      const { given } = c;
      const config = parsePaidPlansConfig(given.config);
      if (given.kind === 'switch') {
        expect({ on: paidPlansOnFor(config, given.companyId) }).toEqual(want(c));
        return;
      }
      const now = new Date(given.now);
      if (given.kind === 'notice') {
        const notice = freeLimitsNoticeDue(config, given.isFree, now);
        expect(notice ? { due: true, daysLeft: notice.daysLeft } : { due: false }).toEqual(want(c));
        return;
      }
      expect({ counts: lastMonthCounts(config.limitsStartAt, now) }).toEqual(want(c));
    });
  }
});
