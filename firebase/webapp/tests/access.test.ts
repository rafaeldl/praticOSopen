import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test, vi } from 'vitest'
import { decideAccess, type AccessContext } from '../src/lib/access'
import { appRoleOf, hasAnyPermission, roleHasPermission } from '../src/lib/permissions'
import { companyEntryName, pickCompany, resolveCompanies, shouldRefreshForStale, staleCompanyIds } from '../src/lib/session'
import { ROLE_PERMISSIONS } from '../src/generated/permissions'
import { NAV } from '../src/navigation'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const member = (role: string, useFinancial?: boolean): AccessContext => ({
  signedIn: true,
  companyId: 'c1',
  role,
  useFinancial,
  webAccess: 'allowed',
})

describe('permissions match the contract', () => {
  const contract = JSON.parse(
    readFileSync(resolve(process.cwd(), '../functions/src/__tests__/rbac/app-permissions.json'), 'utf8'),
  ) as { roles: Record<string, string[]>; financialPermissions: string[] }

  test('generated matrix equals the JSON', () => {
    expect(ROLE_PERMISSIONS).toEqual(contract.roles)
  })

  test('owner reads as admin and unknown roles get nothing', () => {
    expect(appRoleOf('owner')).toBe('admin')
    expect(appRoleOf('toString')).toBeNull()
    expect(appRoleOf('__proto__')).toBeNull()
    expect(roleHasPermission('constructor', 'viewPrices')).toBe(false)
    expect(appRoleOf('user')).toBeNull()
    expect(roleHasPermission('hacker', 'viewPrices')).toBe(false)
    expect(roleHasPermission(null, 'viewPrices')).toBe(false)
  })

  test('financial permissions go away when the company turned values off', () => {
    expect(roleHasPermission('admin', 'viewPrices', false)).toBe(false)
    expect(roleHasPermission('admin', 'manageUsers', false)).toBe(true)
    expect(roleHasPermission('admin', 'viewPrices', undefined)).toBe(true)
  })
})

describe('route decisions', () => {
  const finance = { kind: 'member', anyOf: ['viewFinancialReports'] } as const

  test('a route with no declaration is denied', () => {
    expect(decideAccess(undefined, member('admin'))).toBe('forbidden')
  })

  test('public is open, the rest asks for sign-in', () => {
    const anonymous: AccessContext = { signedIn: false, companyId: null, role: null }
    expect(decideAccess({ kind: 'public' }, anonymous)).toBe('allow')
    expect(decideAccess({ kind: 'signedIn' }, anonymous)).toBe('login')
    expect(decideAccess(finance, anonymous)).toBe('login')
  })

  test('no company goes to the explanation', () => {
    const none: AccessContext = { signedIn: true, companyId: null, role: null, webAccess: 'allowed' }
    expect(decideAccess(finance, none)).toBe('noCompany')
    expect(decideAccess({ kind: 'signedIn' }, none)).toBe('allow')
  })

  test.each(['unknown', 'denied', 'error'] as const)('access list %s keeps everything closed', (webAccess) => {
    const context = { ...member('owner'), webAccess }
    expect(decideAccess(finance, context)).toBe('notAllowed')
    expect(decideAccess({ kind: 'signedIn' }, context)).toBe('notAllowed')
    expect(decideAccess({ kind: 'outsideList' }, context)).toBe('allow')
    expect(decideAccess({ kind: 'public' }, context)).toBe('allow')
  })

  test('several companies and none chosen asks first', () => {
    expect(decideAccess(finance, { ...member('owner'), needsCompanyChoice: true })).toBe('chooseCompany')
    expect(decideAccess({ kind: 'signedIn' }, { ...member('owner'), needsCompanyChoice: true })).toBe('allow')
  })

  test.each([
    ['owner', true],
    ['admin', true],
    ['manager', true],
    ['supervisor', false],
    ['consultant', false],
    ['technician', false],
  ])('finance for %s: %s', (role, allowed) => {
    expect(decideAccess(finance, member(role))).toBe(allowed ? 'allow' : 'forbidden')
  })

  test('values off closes finance even for the owner', () => {
    expect(decideAccess(finance, member('owner', false))).toBe('forbidden')
  })
})

describe('every route declares access', () => {
  test('router table', async () => {
    const { routes } = await import('../src/router')
    expect(routes.length).toBeGreaterThan(5)
    for (const route of routes) expect(route.meta?.access, String(route.path)).toBeDefined()
  })

  test('every permission named in navigation exists for some role', () => {
    for (const entry of NAV) {
      expect(entry.access.anyOf.length).toBeGreaterThan(0)
      expect(Object.keys(ROLE_PERMISSIONS).some((role) => hasAnyPermission(role, entry.access.anyOf))).toBe(true)
    }
  })
})

describe('session companies', () => {
  const entries = [
    { company: { id: 'a', name: 'Alfa' }, role: 'admin' },
    { company: { id: 'b', name: 'Beta' }, role: 'admin' },
  ]

  test('only what the claim confirms counts, and the claim gives the role', () => {
    expect(resolveCompanies(entries, { b: 'technician' })).toEqual([{ id: 'b', name: 'Beta', role: 'technician' }])
  })

  test('claim without an entry still counts, the rules accept it', () => {
    expect(resolveCompanies([], { z: 'admin' })).toEqual([{ id: 'z', name: '', role: 'admin' }])
  })

  test('junk in the document is ignored', () => {
    expect(resolveCompanies('nope', {})).toEqual([])
    expect(resolveCompanies([null, { company: {} }], {})).toEqual([])
  })

  test('a listed company missing from the claim means a stale token', () => {
    expect(staleCompanyIds(entries, { a: 'admin' })).toEqual(['b'])
    expect(staleCompanyIds(entries, { a: 'admin', b: 'admin' })).toEqual([])
    expect(staleCompanyIds(undefined, {})).toEqual([])
  })

  test('refresh once per missing set, not on every start', () => {
    expect(shouldRefreshForStale(['b'], null)).toBe(true)
    expect(shouldRefreshForStale(['b'], 'b')).toBe(false)
    expect(shouldRefreshForStale(['b', 'c'], 'b')).toBe(true)
    expect(shouldRefreshForStale([], null)).toBe(false)
  })

  test('picks the saved company only while it is still valid', () => {
    const list = resolveCompanies(entries, { a: 'admin', b: 'admin' })
    expect(pickCompany(list, 'b')).toBe('b')
    expect(pickCompany(list, 'gone')).toBe('a')
    expect(pickCompany([], 'a')).toBeNull()
  })
})

describe('sign-in helpers', () => {
  test('a redirect that comes back refused by the server says so, other errors name the provider', async () => {
    const { redirectErrorOf, SIGNUP_BLOCKED } = await import('../src/lib/session')
    expect(redirectErrorOf('google', { code: 'auth/admin-restricted-operation' })).toBe(SIGNUP_BLOCKED)
    expect(redirectErrorOf('apple', { code: 'auth/internal-error', message: 'BLOCKING_FUNCTION_ERROR_RESPONSE' })).toBe(SIGNUP_BLOCKED)
    expect(redirectErrorOf('apple', { code: 'auth/network-request-failed' })).toBe('apple')
  })

  test('company guess from the claim follows the saved choice', async () => {
    const { guessCompany } = await import('../src/lib/session')
    expect(guessCompany({ a: 'admin', b: 'owner' }, 'b')).toBe('b')
    expect(guessCompany({ a: 'admin' }, 'gone')).toBe('a')
    expect(guessCompany({}, null)).toBeNull()
  })

  test('e-mail errors use the app texts', async () => {
    const { emailErrorKey } = await import('../src/lib/auth-errors')
    expect(emailErrorKey('auth/invalid-credential')).toBe('emailLoginWrongCredentials')
    expect(emailErrorKey('auth/too-many-requests')).toBe('emailLoginTooManyAttempts')
    expect(emailErrorKey('auth/whatever')).toBe('emailLoginGenericError')
  })
})

describe('web access memory', () => {
  test('a yes lasts 12 hours, a no is not remembered as yes', async () => {
    const { ALLOWED_TTL_MS, rememberAccess, rememberedAccess } = await import('../src/lib/web-access')
    rememberAccess('u1', true, 1000)
    expect(rememberedAccess('u1', 1000 + ALLOWED_TTL_MS - 1)).toBe(true)
    expect(rememberedAccess('u1', 1000 + ALLOWED_TTL_MS)).toBe(false)
    rememberAccess('u1', false, 2000)
    expect(rememberedAccess('u1', 2001)).toBe(false)
    expect(rememberedAccess('other', 2001)).toBe(false)
  })

  test('only allowed: true opens', async () => {
    const { fetchWebAccess } = await import('../src/lib/web-access')
    await expect(fetchWebAccess(async () => ({ allowed: true }))).resolves.toBe(true)
    await expect(fetchWebAccess(async () => ({}))).resolves.toBe(false)
    await expect(fetchWebAccess(async () => { throw new Error('down') })).rejects.toThrow('down')
  })
})

describe('invites', () => {
  test('expired or broken invites are dropped', async () => {
    const { toInvite } = await import('../src/lib/invites')
    const now = new Date('2026-11-01T00:00:00Z')
    expect(toInvite('t', { company: { id: 'c', name: 'C' }, role: 'technician', expiresAt: '2026-12-01T00:00:00Z' }, now)).toMatchObject({
      token: 't',
      companyId: 'c',
      role: 'technician',
    })
    expect(toInvite('t', { company: { id: 'c' }, expiresAt: '2026-10-01T00:00:00Z' }, now)).toBeNull()
    expect(toInvite('t', { role: 'admin' }, now)).toBeNull()
  })
})

describe('values before the company loads', () => {
  test('money stays hidden while the company document is missing', async () => {
    const { can, effectiveUseFinancial, session } = await import('../src/lib/session')
    Object.assign(session, { role: 'owner', companyId: 'c1', company: null })
    expect(effectiveUseFinancial()).toBe(false)
    expect(can('viewPrices')).toBe(false)
    expect(can('manageUsers')).toBe(true)
    session.company = { name: 'X' }
    expect(can('viewPrices')).toBe(true)
    session.company = { useFinancial: false }
    expect(can('viewPrices')).toBe(false)
    Object.assign(session, { role: null, companyId: null, company: null })
  })
})

describe('closing the panel', () => {
  test('goes back only when the list is right behind', async () => {
    const { closeGoesBack } = await import('../src/lib/route-layer')
    expect(closeGoesBack('/orders', '/orders')).toBe(true)
    expect(closeGoesBack('/orders?status=done', '/orders?status=done')).toBe(true)
    expect(closeGoesBack('/dev/components', '/orders')).toBe(false)
    expect(closeGoesBack(null, '/orders')).toBe(false)
  })
})

describe('warm-up of the API on the login screen', () => {
  test('one plain GET without credentials, once per page, errors ignored', async () => {
    const { warmUpApi } = await import('../src/lib/web-access')
    const calls: [string, RequestInit | undefined][] = []
    const request = (async (url: string, init?: RequestInit) => {
      calls.push([url, init])
      throw new Error('offline')
    }) as unknown as typeof fetch
    warmUpApi('https://api.test', request)
    warmUpApi('https://api.test', request)
    await Promise.resolve()
    expect(calls).toEqual([['https://api.test/v1/app/web-access', { credentials: 'omit' }]])
  })
})

describe('company name in the menu (#612)', () => {
  const entry = { id: 'a', name: 'Rafael Laurindo', role: 'owner' }
  test('the current company uses its own document, not the copy in the user', () => {
    expect(companyEntryName(entry, { name: 'Rafsoft' }, 'a')).toBe('Rafsoft')
  })
  test('other companies, or no name yet, keep the copy', () => {
    expect(companyEntryName(entry, { name: 'Rafsoft' }, 'b')).toBe('Rafael Laurindo')
    expect(companyEntryName(entry, { name: '  ' }, 'a')).toBe('Rafael Laurindo')
    expect(companyEntryName(entry, null, 'a')).toBe('Rafael Laurindo')
  })
})
