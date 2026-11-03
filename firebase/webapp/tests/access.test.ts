import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test, vi } from 'vitest'
import { decideAccess, type AccessContext } from '../src/lib/access'
import { appRoleOf, hasAnyPermission, roleHasPermission } from '../src/lib/permissions'
import { pickCompany, resolveCompanies, tokenIsStale } from '../src/lib/session'
import { ROLE_PERMISSIONS } from '../src/generated/permissions'
import { NAV } from '../src/navigation'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const member = (role: string, useFinancial?: boolean): AccessContext => ({ signedIn: true, companyId: 'c1', role, useFinancial })

describe('permissions match the contract', () => {
  const contract = JSON.parse(
    readFileSync(resolve(process.cwd(), '../functions/src/__tests__/rbac/app-permissions.json'), 'utf8'),
  ) as { roles: Record<string, string[]>; financialPermissions: string[] }

  test('generated matrix equals the JSON', () => {
    expect(ROLE_PERMISSIONS).toEqual(contract.roles)
  })

  test('owner reads as admin and unknown roles get nothing', () => {
    expect(appRoleOf('owner')).toBe('admin')
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
    expect(decideAccess(finance, { signedIn: true, companyId: null, role: null })).toBe('noCompany')
    expect(decideAccess({ kind: 'signedIn' }, { signedIn: true, companyId: null, role: null })).toBe('allow')
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
    expect(tokenIsStale(entries, { a: 'admin' })).toBe(true)
    expect(tokenIsStale(entries, { a: 'admin', b: 'admin' })).toBe(false)
    expect(tokenIsStale(undefined, {})).toBe(false)
  })

  test('picks the saved company only while it is still valid', () => {
    const list = resolveCompanies(entries, { a: 'admin', b: 'admin' })
    expect(pickCompany(list, 'b')).toBe('b')
    expect(pickCompany(list, 'gone')).toBe('a')
    expect(pickCompany([], 'a')).toBeNull()
  })
})
