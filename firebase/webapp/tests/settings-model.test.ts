import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test } from 'vitest'
import { ROLE_PERMISSIONS } from '../src/generated/permissions'
import {
  accountApiBase,
  companyFields,
  companyProblems,
  countryOptions,
  daysLeft,
  displayRole,
  findDuplicateInvite,
  inviteBody,
  inviteExpiry,
  inviteProblems,
  isEmail,
  isWebsite,
  leavesNoAdmin,
  normalizeInviteCode,
  PERMISSION_GROUPS,
  PERMISSION_LABEL,
  permissionCell,
  planSummary,
  regionCodes,
  sortMembers,
  usageLevel,
  validityDays,
  type InviteInput,
} from '../src/lib/settings/model'

const NOW = new Date('2026-11-03T12:00:00Z')
const input = (fields: Partial<InviteInput>): InviteInput => ({ name: '', email: '', phone: '', role: 'technician', ...fields })

describe('team', () => {
  test('you first, then by name; empty or unknown role reads as technician; owner as admin', () => {
    const members = [
      { userId: 'b', name: 'Bruno', role: 'admin' },
      { userId: 'me', name: 'Zeca', role: 'technician' },
      { userId: 'a', name: 'ana', role: '' },
    ]
    expect(sortMembers(members, 'me').map((member) => member.userId)).toEqual(['me', 'a', 'b'])
    expect(displayRole('')).toBe('technician')
    expect(displayRole('hacker')).toBe('technician')
    expect(displayRole('owner')).toBe('admin')
  })

  test('days left: expired is -1, today is 0, an invite without expiresAt lasts 7 days from createdAt', () => {
    expect(daysLeft(new Date('2026-11-01T00:00:00Z'), NOW)).toBe(-1)
    expect(daysLeft(new Date('2026-11-03T20:00:00Z'), NOW)).toBe(0)
    expect(daysLeft(new Date('2026-11-06T13:00:00Z'), NOW)).toBe(3)
    expect(inviteExpiry({ createdAt: '2026-11-01T12:00:00Z' })?.toISOString()).toBe('2026-11-08T12:00:00.000Z')
    expect(inviteExpiry({})).toBeNull()
    expect(daysLeft(null, NOW)).toBeNull()
  })

  test('validity comes from the server answer, never a fixed number', () => {
    expect(validityDays(NOW, '2026-11-10T12:00:00Z')).toBe(7)
    expect(validityDays(NOW, '2026-11-17T12:00:00Z')).toBe(14)
    expect(validityDays(NOW, undefined)).toBeNull()
  })

  test('invite needs e-mail or WhatsApp; a real e-mail; 10 to 15 digits', () => {
    expect(inviteProblems(input({}))).toEqual(['contact'])
    expect(inviteProblems(input({ email: 'a@b' }))).toEqual(['email'])
    expect(inviteProblems(input({ email: 'ana@oficina.test' }))).toEqual([])
    expect(inviteProblems(input({ phone: '1199' }))).toEqual(['phone'])
    expect(inviteProblems(input({ phone: '(11) 99999-0000' }))).toEqual([])
    expect(isEmail('a b@c.com')).toBe(false)
  })

  test('the invite body: lower-case e-mail, digits only, empty fields left out', () => {
    expect(inviteBody(input({ name: ' Ana ', email: ' ANA@Oficina.TEST ', phone: '(11) 99999-0000', role: 'admin' }))).toEqual({
      name: 'Ana',
      email: 'ana@oficina.test',
      phone: '11999990000',
      role: 'admin',
    })
    expect(inviteBody(input({ email: 'x@y.test' }))).toEqual({ email: 'x@y.test', role: 'technician' })
  })

  test('duplicate by e-mail (any case) or phone (with or without country code)', () => {
    const invites = [
      { token: 'A', email: 'ana@oficina.test', role: 'technician' },
      { token: 'B', phone: '5511999990000', role: 'technician' },
    ]
    expect(findDuplicateInvite(invites, input({ email: 'ANA@oficina.test' }))?.token).toBe('A')
    expect(findDuplicateInvite(invites, input({ phone: '(11) 99999-0000' }))?.token).toBe('B')
    expect(findDuplicateInvite(invites, input({ email: 'bia@oficina.test' }))).toBeNull()
  })

  test('nobody removes or demotes the last administrator; the owner counts as one', () => {
    const members = [
      { userId: 'o', name: 'Dona', role: 'owner' },
      { userId: 'a', name: 'Admin', role: 'admin' },
      { userId: 't', name: 'Tec', role: 'technician' },
    ]
    expect(leavesNoAdmin(members, 'o', 'a', null)).toBe(false)
    expect(leavesNoAdmin([members[1]!, members[2]!], null, 'a', 'technician')).toBe(true)
    expect(leavesNoAdmin([members[1]!, members[2]!], null, 'a', 'admin')).toBe(false)
    expect(leavesNoAdmin([members[1]!, members[2]!], null, 't', null)).toBe(false)
  })
})

describe('permissions table', () => {
  test('every permission of the contract is in exactly one group and has a label', () => {
    const contract = JSON.parse(readFileSync(resolve(process.cwd(), '../functions/src/__tests__/rbac/app-permissions.json'), 'utf8')) as { roles: Record<string, string[]> }
    const all = [...new Set(Object.values(contract.roles).flat())].sort()
    const grouped = PERMISSION_GROUPS.flatMap((group) => group.permissions)
    expect([...grouped].sort()).toEqual(all)
    expect(new Set(grouped).size).toBe(grouped.length)
    expect(Object.keys(PERMISSION_LABEL).sort()).toEqual(all)
  })

  test('cells follow the generated matrix; money is "off" when the company turned it off', () => {
    for (const [role, permissions] of Object.entries(ROLE_PERMISSIONS)) {
      expect(permissionCell(role as keyof typeof ROLE_PERMISSIONS, permissions[0] as never, true)).toBe('yes')
    }
    expect(permissionCell('technician', 'viewPrices', true)).toBe('no')
    expect(permissionCell('manager', 'viewPrices', true)).toBe('yes')
    expect(permissionCell('manager', 'viewPrices', false)).toBe('off')
    expect(permissionCell('admin', 'manageUsers', false)).toBe('yes')
  })
})

describe('plan', () => {
  test('free without a subscription, with the server counters and the plan limits', () => {
    const plan = planSummary(undefined, NOW)
    expect(plan.plan).toBe('free')
    expect(plan.state).toBe('free')
    expect(plan.limits).toEqual({ photosPerMonth: 30, formTemplates: 1, users: 1 })
    expect(plan.usage).toEqual({ users: 1, photos: 0, checklists: 0 })
  })

  test('period: courtesy, renews, valid until, payment issue; expired is Free with Free limits', () => {
    const future = '2026-12-01T00:00:00Z'
    expect(planSummary({ plan: 'pro', source: 'grace', expiresAt: future }, NOW).state).toBe('courtesy')
    expect(planSummary({ plan: 'pro', source: 'store', status: 'active', expiresAt: future }, NOW).state).toBe('renewsOn')
    expect(planSummary({ plan: 'pro', status: 'cancelled', expiresAt: future }, NOW).state).toBe('endsOn')
    expect(planSummary({ plan: 'pro', status: 'past_due', expiresAt: future }, NOW).state).toBe('paymentIssue')
    const expired = planSummary({ plan: 'pro', expiresAt: '2026-10-01T00:00:00Z', limits: { users: 50 } }, NOW)
    expect(expired.plan).toBe('free')
    expect(expired.limits.users).toBe(1)
    expect(planSummary({ plan: 'starter', limits: { collaborators: 4 }, usage: { usersActive: 3, photosThisMonth: 12, formTemplatesActive: 2 } }, NOW)).toMatchObject({
      limits: { users: 4, photosPerMonth: 200, formTemplates: 3 },
      usage: { users: 3, photos: 12, checklists: 2 },
    })
  })

  test('levels: no limit, ok, near from 80%, at the limit', () => {
    expect(usageLevel(10, -1)).toBe('unlimited')
    expect(usageLevel(1, 5)).toBe('ok')
    expect(usageLevel(4, 5)).toBe('near')
    expect(usageLevel(5, 5)).toBe('atLimit')
    expect(usageLevel(6, 5)).toBe('atLimit')
  })
})

describe('company', () => {
  test('name required, real e-mail and site; empty fields saved as null', () => {
    const data = { name: ' ', phone: '', address: '', email: 'x', site: 'nota site', country: '' }
    expect(companyProblems(data)).toEqual(['name', 'email', 'site'])
    expect(isWebsite('www.oficina.com.br')).toBe(true)
    expect(isWebsite('https://oficina.test')).toBe(true)
    expect(isWebsite('oficina')).toBe(false)
    expect(companyFields({ name: ' Alfa ', phone: '', address: ' Rua 1 ', email: '', site: '', country: 'BR' })).toEqual({
      name: 'Alfa',
      phone: null,
      address: 'Rua 1',
      email: null,
      site: null,
      country: 'BR',
    })
  })

  test('countries: the common ones first, then every other by its name in the language', () => {
    const codes = regionCodes()
    expect(codes.length).toBeGreaterThan(200)
    const pt = countryOptions('pt', codes)
    expect(pt.slice(0, 5).map((item) => item.code)).toEqual(['BR', 'US', 'PT', 'ES', 'MX'])
    expect(pt.find((item) => item.code === 'DE')?.name).toBe('Alemanha')
    expect(countryOptions('en', codes).find((item) => item.code === 'DE')?.name).toBe('Germany')
    expect(countryOptions('es', codes).find((item) => item.code === 'DE')?.name).toBe('Alemania')
  })
})

describe('account', () => {
  test('the account API is the accountApi function next to api', () => {
    expect(accountApiBase('https://x.test/project/southamerica-east1/api')).toBe('https://x.test/project/southamerica-east1/accountApi')
    expect(accountApiBase('http://127.0.0.1:15001/demo-praticos/southamerica-east1/api')).toBe('http://127.0.0.1:15001/demo-praticos/southamerica-east1/accountApi')
  })

  test('invite code: upper case, INV_ in front when missing', () => {
    expect(normalizeInviteCode(' abc123 ')).toBe('INV_ABC123')
    expect(normalizeInviteCode('inv_xyz')).toBe('INV_XYZ')
    expect(normalizeInviteCode('')).toBe('')
  })
})
