// Notice to the Free companies that exist before config/paidPlans.limitsStartAt
// (decision of 2026-11-13): the gate (lib/plan-feature-gate.ts) and the block on Início.
// Also the per-company switch (companyIds, the demo account of the App Review).
import { mount } from '@vue/test-utils'
import { beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { setLocale } from '../src/i18n'

const { session } = vi.hoisted(() => ({ session: { companyId: 'c1', role: 'owner' as string | null, company: null as Record<string, unknown> | null } }))
vi.mock('../src/lib/session', async () => {
  const { reactive: make } = await import('vue')
  return { session: make(session), api: vi.fn(), can: () => true }
})
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(), storageClient: vi.fn() }))

import FreeLimitsNotice from '../src/components/FreeLimitsNotice.vue'
import { freeLimitsNotice, planFeatureCheck, watchPlanSwitch } from '../src/lib/plan-feature-gate'
import { loadLimitsSwitch, resetLimitsSwitch } from '../src/lib/plan-limits'
import { parsePaidPlansConfig } from '../src/lib/paid-plans-config'
import { session as mocked } from '../src/lib/session'

const START = new Date('2026-12-15T15:00:00.000Z')
const NOW = new Date('2026-12-05T15:00:00.000Z')
const stubs = { RouterLink: { props: ['to'], template: '<a :data-to="JSON.stringify(to)"><slot /></a>' } }

async function readConfig(data: Record<string, unknown>, companyId = 'c1') {
  resetLimitsSwitch()
  await loadLimitsSwitch(async () => parsePaidPlansConfig(data), companyId)
  await watchPlanSwitch()
}

beforeAll(() => setLocale('pt'))
beforeEach(() => {
  localStorage.clear()
  mocked.companyId = 'c1'
  mocked.role = 'owner'
  mocked.company = { subscription: { plan: 'free', status: 'active' } }
})

describe('freeLimitsNotice', () => {
  test('owner of a Free company, in the 15 days before the date', async () => {
    await readConfig({ limitsStartAt: START.toISOString() })
    expect(freeLimitsNotice(NOW)).toEqual({ startsAt: START, daysLeft: 10 })
  })

  test('nothing without the date, for a paid plan or for who cannot buy', async () => {
    await readConfig({})
    expect(freeLimitsNotice(NOW)).toBeNull()
    await readConfig({ limitsStartAt: START.toISOString() })
    mocked.company = { subscription: { plan: 'pro', status: 'active', tableVersion: '2' } }
    expect(freeLimitsNotice(NOW)).toBeNull()
    mocked.company = { subscription: { plan: 'free' } }
    mocked.role = 'technician'
    expect(freeLimitsNotice(NOW)).toBeNull()
  })
})

describe('companyIds', () => {
  test('turns the features on for the listed company only', async () => {
    await readConfig({ enabled: false, companyIds: ['demo'] }, 'demo')
    expect(planFeatureCheck('nfse').allowed).toBe(false)
    await readConfig({ enabled: false, companyIds: ['demo'] }, 'c1')
    expect(planFeatureCheck('nfse').allowed).toBe(true)
  })
})

describe('FreeLimitsNotice', () => {
  test('says the day and the work orders of Free; "Agora não" hides it for this date', async () => {
    vi.useFakeTimers({ now: NOW, toFake: ['Date'] })
    await readConfig({ limitsStartAt: START.toISOString() })
    const wrapper = mount(FreeLimitsNotice, { props: { country: 'BR' }, global: { stubs } })
    expect(wrapper.text()).toContain('A partir de 15/12/2026, o plano Free tem 10 OS por mês.')
    expect(wrapper.get('[data-testid="free-limits-see-plans"]').attributes('data-to')).toBe(JSON.stringify({ name: 'plan' }))
    await wrapper.get('[data-testid="free-limits-later"]').trigger('click')
    expect(wrapper.find('[data-testid="free-limits-notice"]').exists()).toBe(false)
    expect(mount(FreeLimitsNotice, { global: { stubs } }).find('[data-testid="free-limits-notice"]').exists()).toBe(false)
    vi.useRealTimers()
  })
})
