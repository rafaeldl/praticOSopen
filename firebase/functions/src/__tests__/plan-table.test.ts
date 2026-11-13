/**
 * The plan table (docs/plans/plans.json, #722) is the only place with the
 * numbers. The generated file must match it, and everything the server
 * derives (PLAN_LIMITS, AI_REQUESTS_PER_MONTH) must come from it. The app and
 * the web run the same comparison (test/models/plan_table_test.dart,
 * firebase/webapp/tests/plan-table.test.ts).
 */
import { readFileSync } from 'fs';
import * as path from 'path';
import { PLAN_IDS, PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION } from '../services/plan-table.generated';
import { PLAN_LIMITS, getPlanLimits } from '../services/subscription-plans';
import { AI_REQUESTS_PER_MONTH } from '../services/ai/ai-quota.service';

const table = JSON.parse(readFileSync(path.join(__dirname, '../../../../docs/plans/plans.json'), 'utf8'));
const current = table.versions[table.currentVersion].plans;

describe('plan table', () => {
  it('the generated file is the JSON (run node scripts/plan-table.mjs)', () => {
    expect(PLAN_TABLE_CURRENT_VERSION).toBe(table.currentVersion);
    expect(PLAN_IDS).toEqual(table.plans);
    const rows = Object.fromEntries(
      Object.entries<any>(table.versions).map(([version, entry]) => [version, entry.plans]),
    );
    expect(PLAN_TABLES).toEqual(rows);
  });

  it.each(PLAN_IDS)('%s: stored limits come from the table', (plan) => {
    const row = current[plan];
    expect(PLAN_LIMITS[plan]).toEqual({
      ordersPerMonth: row.ordersPerMonth,
      photosPerMonth: row.photosPerMonth,
      formTemplates: row.formTemplates,
      users: row.users,
      pdfWatermark: row.pdfWatermark,
    });
    expect(getPlanLimits(plan)).toEqual(PLAN_LIMITS[plan]);
  });

  it.each(PLAN_IDS)('%s: AI requests per month come from the table', (plan) => {
    expect(AI_REQUESTS_PER_MONTH[plan]).toBe(current[plan].aiPerMonth);
  });
});
