/**
 * The plan table (docs/plans/plans.json, #722) is the only place with the
 * numbers. The generated file must match it, and everything the server
 * derives (PLAN_LIMITS, AI_REQUESTS_PER_MONTH) must come from it. The app and
 * the web run the same comparison (test/models/plan_table_test.dart,
 * firebase/webapp/tests/plan-table.test.ts).
 */
import { readFileSync } from 'fs';
import * as path from 'path';
import {
  PLAN_IDS,
  PLAN_TABLES,
  PLAN_TABLES_IN_FORCE,
  PLAN_TABLE_CURRENT_VERSION,
  PLAN_TABLE_LEGACY_VERSION,
} from '../services/plan-table.generated';
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
    expect(PLAN_TABLE_LEGACY_VERSION).toBe(table.legacyVersion);
  });

  it('an older version is in force as the more generous of it and the current one (#726)', () => {
    const more = (a: number, b: number) => (a === -1 || b === -1 ? -1 : Math.max(a, b));
    expect(PLAN_TABLES_IN_FORCE[table.currentVersion]).toEqual(current);
    for (const [version, entry] of Object.entries<any>(table.versions)) {
      if (version === table.currentVersion) continue;
      for (const plan of PLAN_IDS) {
        const old = entry.plans[plan];
        const now = current[plan];
        const row = PLAN_TABLES_IN_FORCE[version][plan];
        for (const field of ['ordersPerMonth', 'users', 'photosPerMonth', 'formTemplates', 'nfseCnpjs', 'aiPerMonth', 'aiPerDay']) {
          expect([version, plan, field, (row as any)[field]]).toEqual([version, plan, field, more(old[field], now[field])]);
        }
        expect(row.ownChecklists).toBe(old.ownChecklists || now.ownChecklists);
        expect(row.overageAllowed).toBe(old.overageAllowed || now.overageAllowed);
        expect(row.pdfWatermark).toBe(old.pdfWatermark && now.pdfWatermark);
        // A version without a feature list allowed every feature: it keeps none (no gate).
        const features = old.features.length === 0 ? [] : [...new Set([...old.features, ...now.features])];
        expect([...row.features].sort()).toEqual(features.sort());
      }
    }
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
