// Web analytics (auth.analytics.events, nav.tabs.analytics-names, order.ai.funnel,
// share.analytics): the app's event names and parameters, nothing before consent,
// nothing after a "no" and never a name, phone or e-mail.
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import type { AnalyticsSink, UserIdentity } from '@/lib/analytics'

type Sent = { name: string; params: Record<string, string | number> }

function fakeSink() {
  const events: Sent[] = []
  const users: (UserIdentity | null)[] = []
  const pages: string[] = []
  let stopped = false
  const sink: AnalyticsSink = {
    event: (name, params) => events.push({ name, params }),
    identify: (user) => users.push(user),
    page: (path) => pages.push(path),
    stop: () => (stopped = true),
  }
  return { sink, events, users, pages, stopped: () => stopped }
}

async function fresh() {
  vi.resetModules()
  return import('@/lib/analytics')
}

beforeEach(() => {
  localStorage.clear()
  vi.stubEnv('VITE_FIREBASE_MEASUREMENT_ID', 'G-TEST')
  vi.stubEnv('VITE_FIREBASE_APP_ID', '1:1:web:test')
})
afterEach(() => vi.unstubAllEnvs())

describe('consent', () => {
  test('without a measurement id analytics is off and asks nothing', async () => {
    vi.stubEnv('VITE_FIREBASE_MEASUREMENT_ID', '')
    const a = await fresh()
    expect(a.analyticsAvailable()).toBe(false)
    expect(a.needsConsent()).toBe(false)
    const fake = fakeSink()
    a.setConsent('granted')
    const load = vi.fn(async () => fake.sink)
    await a.startAnalytics(load)
    expect(load).not.toHaveBeenCalled()
  })

  test('before the answer nothing downloads; a yes sends what waited, in order', async () => {
    const a = await fresh()
    expect(a.needsConsent()).toBe(true)
    const fake = fakeSink()
    const load = vi.fn(async () => fake.sink)
    a.logLogin('email', true)
    a.logScreenView('home', '/')
    await a.startAnalytics(load)
    expect(load).not.toHaveBeenCalled()

    a.setConsent('granted')
    expect(a.needsConsent()).toBe(false)
    await a.startAnalytics(load)
    expect(load).toHaveBeenCalledTimes(1)
    expect(fake.events.map((e) => e.name)).toEqual(['login', 'screen_view'])
    a.logShare('clipboard')
    expect(fake.events.at(-1)).toEqual({ name: 'share', params: { method: 'clipboard', content_type: 'order', item_id: '' } })
  })

  test('a no drops what waited, never downloads and stops a running client', async () => {
    const a = await fresh()
    const fake = fakeSink()
    const load = vi.fn(async () => fake.sink)
    a.logLogin('google')
    a.setConsent('denied')
    await a.startAnalytics(load)
    a.logShare('whatsapp')
    expect(load).not.toHaveBeenCalled()
    expect(localStorage.getItem('praticos.analyticsConsent')).toBe('denied')

    // Yes in Configurações, then no again: the client stops and nothing more leaves.
    a.setConsent('granted')
    await a.startAnalytics(load)
    expect(fake.events).toEqual([])
    a.logShare('sheet')
    a.setConsent('denied')
    a.logShare('sheet')
    expect(fake.stopped()).toBe(true)
    expect(fake.events.map((e) => e.params.method)).toEqual(['sheet'])
  })

  test('the answer is remembered in this browser', async () => {
    localStorage.setItem('praticos.analyticsConsent', 'granted')
    const a = await fresh()
    expect(a.analyticsState.consent).toBe('granted')
    expect(a.needsConsent()).toBe(false)
  })

  test('a client that fails to load (blocked) leaves the app going', async () => {
    localStorage.setItem('praticos.analyticsConsent', 'granted')
    const a = await fresh()
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    await expect(a.startAnalytics(async () => Promise.reject(new Error('blocked')))).resolves.toBeUndefined()
    expect(() => a.logShare('sheet')).not.toThrow()
  })
})

describe('the app names (AnalyticsService)', () => {
  async function granted() {
    localStorage.setItem('praticos.analyticsConsent', 'granted')
    const a = await fresh()
    const fake = fakeSink()
    await a.startAnalytics(async () => fake.sink)
    return { a, fake }
  }

  test('entry and first access', async () => {
    const { a, fake } = await granted()
    a.logEmailLoginOpened()
    a.logLogin('google', false)
    a.logLogin('email')
    a.logSignUp('apple')
    a.logTutorialBegin('setup')
    a.logCompanyCreated('co1', 'automotive')
    a.logTutorialComplete()
    a.logInviteAccepted('co2')
    expect(fake.events).toEqual([
      { name: 'email_login_opened', params: {} },
      { name: 'login', params: { method: 'google', has_company: 'false' } },
      { name: 'login', params: { method: 'email', has_company: 'true' } },
      { name: 'sign_up', params: { method: 'apple' } },
      { name: 'tutorial_begin', params: { variant: 'setup' } },
      { name: 'company_created', params: { company_id: 'co1', segment: 'automotive' } },
      { name: 'tutorial_complete', params: {} },
      { name: 'invite_accepted', params: { company_id: 'co2' } },
    ])
  })

  test('auth method from the providers, as getAuthMethod', async () => {
    const a = await fresh()
    expect(a.authMethod(['google.com'])).toBe('google')
    expect(a.authMethod(['apple.com'])).toBe('apple')
    expect(a.authMethod(['password'])).toBe('email')
    expect(a.authMethod(['phone'])).toBe('phone')
    expect(a.authMethod([])).toBe('unknown')
  })

  test('identifyUser: the uid and the company, never the e-mail', async () => {
    const { a, fake } = await granted()
    a.identifyUser({ userId: 'uid-1', companyId: 'co1', segment: 'hvac', userRole: 'admin' })
    a.clearUser()
    expect(fake.users).toEqual([{ userId: 'uid-1', companyId: 'co1', segment: 'hvac', userRole: 'admin' }, null])
  })

  test('identity set before the client is applied when it loads', async () => {
    localStorage.setItem('praticos.analyticsConsent', 'granted')
    const a = await fresh()
    a.identifyUser({ userId: 'uid-1', companyId: 'co1' })
    const fake = fakeSink()
    await a.startAnalytics(async () => fake.sink)
    expect(fake.users[0]).toEqual({ userId: 'uid-1', companyId: 'co1' })
  })

  test('screens: the tabs as TabRoutes, the rest as lib/routes.dart, the address without ids', async () => {
    const { a, fake } = await granted()
    expect(a.screenNameFor('home')).toBe('/home')
    expect(a.screenNameFor('schedule')).toBe('/agenda')
    expect(a.screenNameFor('finance')).toBe('/financial')
    expect(a.screenNameFor('customers')).toBe('/customer_list')
    expect(a.screenNameFor('team')).toBe('/collaborator_list')
    expect(a.screenNameFor('invoices')).toBe('/invoices')
    a.logScreenView('schedule', '/schedule')
    expect(fake.pages.at(-1)).toBe('/schedule')
    expect(fake.events.at(-1)).toEqual({ name: 'screen_view', params: { firebase_screen: '/agenda', firebase_screen_class: '/agenda' } })
  })

  test('share and payment', async () => {
    const { a, fake } = await granted()
    a.logShare('sheet', 'order')
    a.logShare('whatsapp')
    a.logPaymentAdded(150)
    a.logPaymentAdded()
    expect(fake.events).toEqual([
      { name: 'share', params: { method: 'sheet', content_type: 'order', item_id: '' } },
      { name: 'share', params: { method: 'whatsapp', content_type: 'order', item_id: '' } },
      { name: 'payment_added', params: { amount: 150 } },
      { name: 'payment_added', params: {} },
    ])
  })

  test('assistant funnel: input and result as order_screen_v2', async () => {
    const a = await fresh()
    expect(a.aiInput('troca de óleo', 0)).toBe('text')
    expect(a.aiInput('', 2)).toBe('photo')
    expect(a.aiInput('essa peça', 1)).toBe('photo_text')
    expect(a.aiResult({ errorCode: 'AI_QUOTA_EXCEEDED', failed: true })).toBe('quota')
    expect(a.aiResult({ errorCode: 'AI_DISABLED', failed: true })).toBe('error')
    expect(a.aiResult({ failed: true })).toBe('error')
    expect(a.aiResult({ filled: true, actions: true })).toBe('filled')
    expect(a.aiResult({ filled: false, actions: true })).toBe('actions')
    expect(a.aiResult({ filled: false })).toBe('nothing')
  })
})

describe('no personal data', () => {
  test('only the known keys leave; e-mails never do', async () => {
    localStorage.setItem('praticos.analyticsConsent', 'granted')
    const a = await fresh()
    const fake = fakeSink()
    await a.startAnalytics(async () => fake.sink)
    a.logEvent('share', { method: 'sheet', customer_name: 'Maria', phone: '11999990000', email: 'm@x.com', content_type: 'a@b.com' })
    expect(fake.events).toEqual([{ name: 'share', params: { method: 'sheet' } }])
    expect(a.cleanParams({ step: 'x'.repeat(300) }).step).toHaveLength(100)
  })
})
