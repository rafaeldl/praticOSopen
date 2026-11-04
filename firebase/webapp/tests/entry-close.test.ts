// Entry rows closed in docs/web-app/parity-matrix.yaml: sign-up refused,
// reset e-mail, invite errors, the account's language, the first users/{uid},
// ratings and the company options as the app resolves them.
import { beforeEach, describe, expect, test } from 'vitest'
import { ApiError } from '../src/lib/api'
import { isSignupBlocked, resetEmailErrorKey } from '../src/lib/auth-errors'
import { featureOn } from '../src/lib/company-features'
import { inviteErrorKey } from '../src/lib/invites'
import { prefs } from '../src/lib/prefs'
import { averageScore, ratedOrders } from '../src/lib/settings/ratings'
import { applyAccountLanguage, languageOf, newUserDoc, preferredLanguageTag } from '../src/lib/user-profile'

describe('auth.signup.blocked', () => {
  test('the blocking function and closed sign-ups are a refused sign-up', () => {
    expect(isSignupBlocked({ code: 'auth/internal-error', message: 'HTTP Cloud Function returned an error: {"error":{"status":"PERMISSION_DENIED"}}' })).toBe(true)
    expect(isSignupBlocked({ code: 'auth/admin-restricted-operation', message: '' })).toBe(true)
  })
  test('any other failure keeps the provider sentence', () => {
    expect(isSignupBlocked({ code: 'auth/internal-error', message: 'network' })).toBe(false)
    expect(isSignupBlocked({ code: 'auth/popup-blocked' })).toBe(false)
    expect(isSignupBlocked(null)).toBe(false)
  })
})

describe('auth.email.forgot: the address before sending', () => {
  test.each([
    ['', 'emailLoginEmailRequired'],
    ['   ', 'emailLoginEmailRequired'],
    ['ana', 'emailLoginEmailInvalid'],
    ['ana@oficina', 'emailLoginEmailInvalid'],
    ['ana@oficina.com', null],
    [' ana@oficina.com.br ', null],
  ])('%j', (email, key) => expect(resetEmailErrorKey(email)).toBe(key))
})

describe('onboarding.invites.error-map: by the API code, never the text', () => {
  const error = (code: string, status: number) => new ApiError(code, status, 'web.error.generic')
  test.each([
    [error('EXPIRED', 400), 'inviteExpired'],
    [error('ALREADY_MEMBER', 409), 'web.account.alreadyMember'],
    [error('RATE_LIMIT_EXCEEDED', 429), 'emailLoginTooManyAttempts'],
    [error('FORBIDDEN', 403), 'web.account.inviteNotForYou'],
    [error('NETWORK', 0), 'networkError'],
    [error('NOT_FOUND', 404), 'web.account.inviteInvalid'],
    [error('INVALID_INVITE', 400), 'web.account.inviteInvalid'],
    [error('INTERNAL_ERROR', 500), 'web.error.generic'],
    [new Error('boom'), 'web.error.generic'],
  ])('%s', (cause, key) => expect(inviteErrorKey(cause)).toBe(key))
})

describe('reminders.language and auth.session.user-bootstrap', () => {
  beforeEach(() => {
    localStorage.clear()
    prefs.language = 'system'
  })
  test('any tag goes to one of the three languages, and back to the app codes', () => {
    expect(languageOf('pt-PT')).toBe('pt')
    expect(languageOf('es_MX')).toBe('es')
    expect(languageOf('fr-FR')).toBe('en')
    expect(languageOf('')).toBeNull()
    expect(preferredLanguageTag('es')).toBe('es-ES')
    expect(preferredLanguageTag('system')).toBeNull()
  })
  test('the account language applies once, only when nothing was picked in this browser', () => {
    applyAccountLanguage('es-ES')
    expect(prefs.language).toBe('es')
    applyAccountLanguage('en-US')
    expect(prefs.language).toBe('es')
  })
  test('a language picked here wins over the account', () => {
    prefs.language = 'pt'
    applyAccountLanguage('en-US')
    expect(prefs.language).toBe('pt')
  })
  test('the first users/{uid}: no company, the browser language, audit of the person', () => {
    const doc = newUserDoc({ uid: 'u1', name: 'Ana', email: 'ana@oficina.test' }, 'fr-FR', '2026-11-04T12:00:00.000Z')
    expect(doc).toEqual({
      id: 'u1',
      name: 'Ana',
      email: 'ana@oficina.test',
      companies: [],
      preferredLanguage: 'fr-FR',
      createdAt: '2026-11-04T12:00:00.000Z',
      createdBy: { id: 'u1', name: 'Ana' },
      updatedAt: '2026-11-04T12:00:00.000Z',
      updatedBy: { id: 'u1', name: 'Ana' },
    })
  })
})

describe('ratings.view', () => {
  const rows = [
    { id: 'a', data: { number: 160, customer: { name: 'Bruno' }, rating: { score: 5, comment: ' Ótimo ', createdAt: '2026-10-02T10:00:00Z' } } },
    { id: 'b', data: { number: 161, customer: { name: 'Carla' }, rating: { score: 4, customerName: 'Carla S.', createdAt: { seconds: 1793000000 } } } },
    { id: 'c', data: { number: 162, rating: { score: 0 } } },
    { id: 'd', data: { number: 163, rating: { score: 6 } } },
    { id: 'e', data: { number: 164 } },
  ]
  test('only scores 1 to 5, newest rating first, the typed name before the order customer', () => {
    const list = ratedOrders(rows)
    expect(list.map((order) => order.id)).toEqual(['b', 'a'])
    expect(list[0]).toMatchObject({ customerName: 'Carla S.', comment: '' })
    expect(list[1]).toMatchObject({ customerName: 'Bruno', comment: 'Ótimo', number: 160 })
  })
  test('average with one decimal; none is 0', () => {
    expect(averageScore(ratedOrders(rows))).toBe(4.5)
    expect(averageScore([])).toBe(0)
  })
})

describe('auth.gate.feature-defaults', () => {
  test('the company value wins', () => {
    expect(featureOn({ fieldService: false }, 'fieldService', true)).toBe(false)
    expect(featureOn({ useScheduling: false }, 'useScheduling')).toBe(false)
  })
  test('absent: segment, then the app default', () => {
    expect(featureOn({}, 'fieldService', false)).toBe(false)
    expect(featureOn({}, 'fieldService', null)).toBe(true)
    expect(featureOn(null, 'useScheduling')).toBe(true)
    expect(featureOn({}, 'useFinancial')).toBe(true)
    expect(featureOn({}, 'useContracts')).toBe(false)
    expect(featureOn({}, 'useDeviceManagement')).toBe(false)
  })
})
