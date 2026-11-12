// The plan table (docs/plans/plans.json, #722) is the only place with the numbers.
// src/generated/plan-table.ts comes from it in `npm run gen`, and what the web
// derives (planLimits, the Plano and Equipe screens, the checklist limit) reads it.
// The app and the server run the same comparison (test/models/plan_table_test.dart,
// firebase/functions/src/__tests__/plan-table.test.ts).
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test } from 'vitest'
import { PLAN_IDS, PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION } from '../src/generated/plan-table'
import { planLimits } from '../src/lib/plan-limits'
import { planSummary } from '../src/lib/settings/model'
import { planLimit } from '../src/lib/forms/model'

const table = JSON.parse(readFileSync(resolve(process.cwd(), '../../docs/plans/plans.json'), 'utf8'))
const current = table.versions[table.currentVersion].plans
const NOW = new Date('2026-11-12T12:00:00Z')

describe('plan table', () => {
  test('the generated file is the JSON', () => {
    expect(PLAN_TABLE_CURRENT_VERSION).toBe(table.currentVersion)
    expect(PLAN_IDS).toEqual(table.plans)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    expect(PLAN_TABLES).toEqual(Object.fromEntries(Object.entries<any>(table.versions).map(([v, entry]) => [v, entry.plans])))
  })

  test.each(PLAN_IDS)('%s: Plano, Equipe and checklists read the table', (plan) => {
    const row = current[plan]
    const limits = { photosPerMonth: row.photosPerMonth, formTemplates: row.formTemplates, users: row.users, pdfWatermark: row.pdfWatermark }
    expect(planLimits(plan)).toEqual(limits)
    expect(planSummary({ plan }, NOW).limits).toEqual(limits)
    expect(planLimit({ plan }, NOW)).toBe(row.formTemplates)
  })
})
