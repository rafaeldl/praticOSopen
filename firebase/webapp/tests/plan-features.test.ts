// Features of each plan on the web (#724): the gate over the session's company
// (lib/plan-feature-gate.ts), the 402 PLAN_FEATURE of the server, the notice and
// the role picker. Off while the switch (config/paidPlans) is off.
import { flushPromises, mount } from '@vue/test-utils'
import { beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { setLocale, t } from '../src/i18n'

const { session } = vi.hoisted(() => ({ session: { companyId: 'c1', role: 'owner' as string | null, company: null as Record<string, unknown> | null } }))
vi.mock('../src/lib/session', async () => {
  const { reactive: make } = await import('vue')
  const state = make(session)
  return { session: state, api: vi.fn(), can: () => true }
})
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(), storageClient: vi.fn() }))

import PlanFeatureNotice from '../src/components/PlanFeatureNotice.vue'
import RoleChoice from '../src/components/settings/RoleChoice.vue'
import { ApiError, createApi } from '../src/lib/api'
import { ensurePlanFeature, handlePlanFeatureError, planFeatureCheck, planNotice, watchPlanSwitch } from '../src/lib/plan-feature-gate'
import { PLAN_FEATURE_NAME, checkPlanFeature, planFeatureRefusal, requiredPlanFor } from '../src/lib/plan-features'
import { loadLimitsSwitch, resetLimitsSwitch } from '../src/lib/plan-limits'
import { session as mocked } from '../src/lib/session'
import type { AssignableRole } from '../src/lib/settings/model'

const stubs = { RouterLink: { props: ['to'], template: '<a :data-to="JSON.stringify(to)"><slot /></a>' } }

async function switchTo(on: boolean) {
  resetLimitsSwitch()
  await loadLimitsSwitch(async () => on)
  await watchPlanSwitch()
}

function companyOn(plan: string | null) {
  mocked.company = plan === null ? {} : { subscription: { plan, status: 'active' } }
}

beforeAll(() => setLocale('pt'))
beforeEach(async () => {
  planNotice.open = null
  mocked.role = 'owner'
  companyOn('free')
  await switchTo(true)
})

describe('checkPlanFeature', () => {
  test('every feature the web names has a name and a plan that has it', () => {
    for (const feature of Object.keys(PLAN_FEATURE_NAME)) expect(requiredPlanFor(feature)).not.toBeNull()
  })

  test('a stored limit never opens a feature: only the plan does', () => {
    const subscription = { plan: 'free', limits: { ordersPerMonth: -1, users: -1 } }
    expect(checkPlanFeature({ subscription, feature: 'teamRoles', enforced: true, now: new Date() }).allowed).toBe(false)
  })
})

describe('the gate over the session', () => {
  test('switch off: everything allowed, nothing opens', async () => {
    await switchTo(false)
    expect(planFeatureCheck('bulkActions').allowed).toBe(true)
    expect(ensurePlanFeature('bulkActions')).toBe(true)
    expect(planNotice.open).toBeNull()
  })

  test('company not loaded yet: allowed (the server decides)', () => {
    mocked.company = null
    expect(planFeatureCheck('workStages').allowed).toBe(true)
  })

  test('Free with the switch on: Pro feature closed, the notice opens with the plan to move to', () => {
    expect(ensurePlanFeature('workStages')).toBe(false)
    expect(planNotice.open).toEqual({ feature: 'workStages', requiredPlan: 'pro' })
  })

  test('Pro has stages, not bulk actions', () => {
    companyOn('pro')
    expect(planFeatureCheck('workStages').allowed).toBe(true)
    expect(planFeatureCheck('bulkActions')).toMatchObject({ allowed: false, requiredPlan: 'business' })
  })
})

describe('402 PLAN_FEATURE', () => {
  const refusing = (body: unknown) =>
    createApi({ baseUrl: () => '', getToken: async () => 't', getCompanyId: () => 'c1', fetch: (async () => new Response(JSON.stringify(body), { status: 402 })) as typeof fetch })

  test('the client keeps feature, plan and requiredPlan of the refusal', async () => {
    const error = await refusing({ success: false, error: { code: 'PLAN_FEATURE', message: 'x', feature: 'mcp', plan: 'pro', requiredPlan: 'business' } })
      .request('/v1/app/integrations/tokens', { method: 'POST', body: {} })
      .catch((e: unknown) => e)
    expect(error).toBeInstanceOf(ApiError)
    expect(planFeatureRefusal(error)).toEqual({ allowed: false, feature: 'mcp', plan: 'pro', requiredPlan: 'business' })
    expect(handlePlanFeatureError(error)).toBe(true)
    expect(planNotice.open).toEqual({ feature: 'mcp', requiredPlan: 'business' })
  })

  test('any other error stays with the screen', () => {
    expect(handlePlanFeatureError(new ApiError('FORBIDDEN', 403, 'web.error.forbidden'))).toBe(false)
    expect(handlePlanFeatureError(new Error('x'))).toBe(false)
    expect(planNotice.open).toBeNull()
  })
})

describe('PlanFeatureNotice', () => {
  test('owner: the app words, the feature first, and the way to the Plan screen', () => {
    const wrapper = mount(PlanFeatureNotice, { props: { feature: 'contracts', role: 'owner' }, global: { stubs } })
    expect(wrapper.text()).toContain(t('planFeatureTitle', { plan: 'Pro' }))
    expect(wrapper.text()).toContain(`${t('planFeatureContracts')}. ${t('planFeatureBody', { plan: 'Pro' })}`)
    expect(wrapper.get('[data-testid="plan-feature-see-plan"]').attributes('data-to')).toContain('plan')
  })

  test('anyone else is told to ask the owner, with no link', () => {
    const wrapper = mount(PlanFeatureNotice, { props: { feature: 'mcp', role: 'technician' }, global: { stubs } })
    expect(wrapper.text()).toContain(`${t('planFeatureMcp')}. ${t('planFeatureAskOwner', { plan: 'Business' })}`)
    expect(wrapper.find('[data-testid="plan-feature-see-plan"]').exists()).toBe(false)
  })
})

describe('RoleChoice', () => {
  const pick = (modelValue: AssignableRole, keep?: string) =>
    mount(RoleChoice, {
      props: { legend: 'Papel', name: 'r', modelValue, keep, 'onUpdate:modelValue': vi.fn() },
      global: { stubs },
    })

  test('Free with the switch on: only admin; the others show "Plano Pro" and the notice', async () => {
    const wrapper = pick('technician')
    await flushPromises()
    expect(wrapper.get('[data-testid="role-admin"]').attributes('disabled')).toBeUndefined()
    for (const role of ['supervisor', 'manager', 'consultant', 'technician']) {
      expect(wrapper.get(`[data-testid="role-${role}"]`).attributes('disabled')).toBeDefined()
    }
    expect(wrapper.findAll('[data-testid="role-plan-badge"]')).toHaveLength(4)
    expect(wrapper.text()).toContain(t('planFeatureBadge', { plan: 'Pro' }))
    expect(wrapper.find('[data-testid="plan-feature-notice"]').exists()).toBe(true)
    // A new invite starts on a role the plan has.
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual(['admin'])
  })

  test('a member who already has a Pro role keeps it selectable', async () => {
    const wrapper = pick('technician', 'technician')
    await flushPromises()
    expect(wrapper.get('[data-testid="role-technician"]').attributes('disabled')).toBeUndefined()
    expect(wrapper.get('[data-testid="role-manager"]').attributes('disabled')).toBeDefined()
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
  })

  test('switch off or a Pro plan: every role, no badge, no notice', async () => {
    await switchTo(false)
    const off = pick('technician')
    await flushPromises()
    expect(off.findAll('[data-testid="role-plan-badge"]')).toHaveLength(0)
    expect(off.find('[data-testid="plan-feature-notice"]').exists()).toBe(false)

    await switchTo(true)
    companyOn('pro')
    const pro = pick('technician')
    await flushPromises()
    expect(pro.findAll('input:disabled')).toHaveLength(0)
  })
})

