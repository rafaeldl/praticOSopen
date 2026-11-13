// The plan table (docs/plans/plans.json, #722) is the only place with the numbers.
// src/generated/plan-table.ts comes from it in `npm run gen`, and what the web
// derives (planLimits, the Plano and Equipe screens, the checklist limit) reads it.
// The app and the server run the same comparison (test/models/plan_table_test.dart,
// firebase/functions/src/__tests__/plan-table.test.ts).
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test } from 'vitest'
import { PLAN_IDS, PLAN_TABLES, PLAN_TABLES_IN_FORCE, PLAN_TABLE_CURRENT_VERSION, PLAN_TABLE_LEGACY_VERSION } from '../src/generated/plan-table'
import { loadLimitsSwitch, orderMonthKey, tableVersionOf, ordersUsage, planLimits, planLimitsEnforced, previousMonthKey, resetLimitsSwitch } from '../src/lib/plan-limits'
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
    expect(PLAN_TABLE_LEGACY_VERSION).toBe(table.legacyVersion)
  })

  test('an older version is in force as the more generous of it and the current one (#726)', () => {
    const more = (a: number, b: number) => (a === -1 || b === -1 ? -1 : Math.max(a, b))
    expect(PLAN_TABLES_IN_FORCE[table.currentVersion]).toEqual(current)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    for (const [version, entry] of Object.entries<any>(table.versions)) {
      if (version === table.currentVersion) continue
      for (const plan of PLAN_IDS) {
        const old = entry.plans[plan]
        const now = current[plan]
        const row = PLAN_TABLES_IN_FORCE[version]![plan]
        for (const field of ['ordersPerMonth', 'users', 'photosPerMonth', 'formTemplates', 'nfseCnpjs', 'aiPerMonth', 'aiPerDay'] as const) {
          expect([plan, field, row[field]]).toEqual([plan, field, more(old[field], now[field])])
        }
        expect(row.ownChecklists).toBe(old.ownChecklists || now.ownChecklists)
        expect(row.overageAllowed).toBe(old.overageAllowed || now.overageAllowed)
        expect(row.pdfWatermark).toBe(old.pdfWatermark && now.pdfWatermark)
        // A version without a feature list allowed every feature: it keeps none (no gate).
        const features = old.features.length === 0 ? [] : [...new Set([...old.features, ...now.features])]
        expect([...row.features].sort()).toEqual(features.sort())
      }
    }
  })

  test('a paid subscription without tableVersion, the courtesy too, keeps its old table; Free follows the new one (#726)', () => {
    expect(tableVersionOf({ plan: 'starter', source: 'store' })).toBe('1')
    expect(tableVersionOf({ plan: 'pro', source: 'grace' })).toBe('1')
    expect(tableVersionOf({ plan: 'free' })).toBe('2')
    expect(tableVersionOf({ plan: 'starter', tableVersion: '2' })).toBe('2')
    expect(tableVersionOf({ plan: 'starter', tableVersion: '99' })).toBe('2')
    expect(planSummary({ plan: 'starter', source: 'store' }, NOW).limits).toMatchObject({ users: 3, ordersPerMonth: -1, photosPerMonth: -1, formTemplates: -1 })
  })

  test.each(PLAN_IDS)('%s: Plano, Equipe and checklists read the table', (plan) => {
    const row = current[plan]
    const limits = { ordersPerMonth: row.ordersPerMonth, photosPerMonth: row.photosPerMonth, formTemplates: row.formTemplates, users: row.users, pdfWatermark: row.pdfWatermark }
    expect(planLimits(plan)).toEqual(limits)
    expect(planSummary({ plan, tableVersion: table.currentVersion }, NOW).limits).toEqual(limits)
    expect(planLimit({ plan, tableVersion: table.currentVersion }, NOW)).toBe(row.formTemplates)
  })
})

describe('the switch (config/paidPlans)', () => {
  test('read once; off when it cannot be read', async () => {
    resetLimitsSwitch()
    expect(planLimitsEnforced()).toBe(false)
    expect(await loadLimitsSwitch(async () => true)).toBe(true)
    expect(planLimitsEnforced()).toBe(true)
    expect(await loadLimitsSwitch(async () => false)).toBe(true) // same answer for the page
    resetLimitsSwitch()
    expect(await loadLimitsSwitch(async () => { throw new Error('offline') })).toBe(false)
    resetLimitsSwitch()
  })
})

describe('orders of the month', () => {
  test('turn by themselves, São Paulo calendar', () => {
    const usage = { ordersMonth: '2026-11', ordersThisMonth: 12, ordersLastMonth: 4 }
    expect(orderMonthKey(new Date('2026-12-01T02:59:00Z'))).toBe('2026-11')
    expect(previousMonthKey('2027-01')).toBe('2026-12')
    expect(ordersUsage(usage, NOW)).toEqual({ thisMonth: 12, lastMonth: 4 })
    expect(ordersUsage(usage, new Date('2026-12-05T12:00:00Z'))).toEqual({ thisMonth: 0, lastMonth: 12 })
    expect(ordersUsage(usage, new Date('2027-01-05T12:00:00Z'))).toEqual({ thisMonth: 0, lastMonth: 0 })
  })
})
