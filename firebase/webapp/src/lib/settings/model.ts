// Pure rules of the team, plan and company screens (fatia 07: equipe, empresa,
// plano). Tested in tests/settings-model.test.ts; nothing here reads Firebase.
import { localizedMap, localizedNames, pickLocalized } from '@/lib/localized'
import { FINANCIAL_PERMISSIONS, ROLE_PERMISSIONS } from '@/generated/permissions'
import type { MessageKey } from '@/generated/message-keys'
import { FORMAT_COUNTRIES } from '@/lib/format'
import type { AppRole, Permission } from '@/lib/permissions'
import { hasCountryZone } from '@/lib/zone'
import { whatsappUrl } from '@/lib/share'
import { checkPlanLimit, dateOf, effectiveLimits, effectivePlan, type PlanId, type SubscriptionLimits } from '@/lib/plan-limits'

// ── Roles ────────────────────────────────────────────────────────────────

/** Roles a person can be given, in the app's order (RolePermissions.availableRoles). */
export const ASSIGNABLE_ROLES = ['admin', 'supervisor', 'manager', 'consultant', 'technician'] as const
export type AssignableRole = (typeof ASSIGNABLE_ROLES)[number]

export const ROLE_LABEL: Record<AssignableRole, MessageKey> = {
  admin: 'roleAdmin',
  supervisor: 'roleSupervisor',
  manager: 'roleManager',
  consultant: 'roleConsultant',
  technician: 'roleTechnician',
}

/** "vê e muda tudo": the line under each role. */
export const ROLE_SHORT: Record<AssignableRole, MessageKey> = {
  admin: 'roleShortAdmin',
  supervisor: 'roleShortSupervisor',
  manager: 'roleShortManager',
  consultant: 'roleShortConsultant',
  technician: 'roleShortTechnician',
}

/** The long sentence under the invite's role. */
export const ROLE_DESCRIPTION: Record<AssignableRole, MessageKey> = {
  admin: 'roleDescAdmin',
  supervisor: 'roleDescSupervisor',
  manager: 'roleDescManager',
  consultant: 'roleDescConsultant',
  technician: 'roleDescTechnician',
}

/** A stored role as one of the five. Empty or unknown shows as technician, as in the app (team_view). */
export function displayRole(role: string | null | undefined): AssignableRole {
  if (role === 'owner') return 'admin'
  return (ASSIGNABLE_ROLES as readonly string[]).includes(role ?? '') ? (role as AssignableRole) : 'technician'
}

// ── Team ─────────────────────────────────────────────────────────────────

export interface Member {
  userId: string
  name: string
  role: string
}

export interface TeamInvite {
  token: string
  name?: string
  email?: string
  phone?: string
  role: string
  createdAt?: string
  expiresAt?: string
}

/** The signed-in person first, as "Você", then by name. */
export function sortMembers(members: Member[], selfId: string | null, collator = new Intl.Collator('pt', { sensitivity: 'base' })): Member[] {
  return [...members].sort((a, b) => {
    if (a.userId === selfId) return -1
    if (b.userId === selfId) return 1
    return collator.compare(a.name, b.name)
  })
}

const DAY = 86_400_000

/** Same as an old invite on the server: without expiresAt it lasts 7 days from createdAt. */
export function inviteExpiry(invite: Pick<TeamInvite, 'expiresAt' | 'createdAt'>): Date | null {
  const raw = invite.expiresAt ?? (invite.createdAt ? new Date(new Date(invite.createdAt).getTime() + 7 * DAY).toISOString() : undefined)
  if (!raw) return null
  const date = new Date(raw)
  return Number.isNaN(date.getTime()) ? null : date
}

/** Whole days left: null unknown, -1 expired, 0 ends today (team_view._daysLeft). */
export function daysLeft(expiry: Date | null, now: Date): number | null {
  if (!expiry) return null
  const diff = expiry.getTime() - now.getTime()
  if (diff < 0) return -1
  return Math.floor(diff / DAY)
}

export const isExpired = (invite: TeamInvite, now: Date): boolean => daysLeft(inviteExpiry(invite), now) === -1

/** Days an invite is valid, from the server's answer (never a number fixed here). */
export function validityDays(createdAt: Date, expiresAt: string | undefined): number | null {
  if (!expiresAt) return null
  const end = new Date(expiresAt)
  if (Number.isNaN(end.getTime())) return null
  return Math.max(1, Math.round((end.getTime() - createdAt.getTime()) / DAY))
}

export const inviteName = (invite: TeamInvite): string => invite.name || invite.email || invite.phone || ''

export const digitsOf = (phone: string): string => phone.replace(/\D/g, '')

/** A real address: something@something.tld, no spaces (the app only asks for "@"). */
export function isEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/.test(value.trim())
}

/** Empty is fine; otherwise 10 to 15 digits (invite_form.isValidPhone). */
export function isInvitePhone(value: string): boolean {
  const digits = digitsOf(value)
  return digits.length === 0 || (digits.length >= 10 && digits.length <= 15)
}

export interface InviteInput {
  name: string
  email: string
  phone: string
  role: AssignableRole
}

export type InviteProblem = 'contact' | 'email' | 'phone'

/** What blocks saving, in field order. */
export function inviteProblems(input: InviteInput): InviteProblem[] {
  const problems: InviteProblem[] = []
  const email = input.email.trim()
  const phone = input.phone.trim()
  if (!email && !phone) problems.push('contact')
  if (email && !isEmail(email)) problems.push('email')
  if (phone && !isInvitePhone(phone)) problems.push('phone')
  return problems
}

/** What goes to POST /v1/app/invites: e-mail in lower case, phone only digits, empty left out. */
export function inviteBody(input: InviteInput): { name?: string; email?: string; phone?: string; role: AssignableRole } {
  const name = input.name.trim()
  const email = input.email.trim().toLowerCase()
  const phone = digitsOf(input.phone)
  return { ...(name ? { name } : {}), ...(email ? { email } : {}), ...(phone ? { phone } : {}), role: input.role }
}

const lastDigits = (phone: string | undefined) => digitsOf(phone ?? '').slice(-10)

/** A pending invite to the same e-mail or phone (compared without country code, as invite_utils). */
export function findDuplicateInvite(invites: TeamInvite[], input: InviteInput): TeamInvite | null {
  const email = input.email.trim().toLowerCase()
  const phone = lastDigits(input.phone)
  return (
    invites.find(
      (invite) => (email && invite.email?.toLowerCase() === email) || (phone.length >= 10 && lastDigits(invite.phone) === phone),
    ) ?? null
  )
}

/** Changing this role (or removing the person) leaves the company without an administrator. */
export function leavesNoAdmin(members: Member[], ownerId: string | null, targetId: string, newRole: string | null): boolean {
  const admins = new Set(members.filter((member) => member.role === 'admin' || member.role === 'owner').map((member) => member.userId))
  if (ownerId) admins.add(ownerId)
  admins.delete(targetId)
  if (newRole === 'admin') admins.add(targetId)
  return admins.size === 0
}

/** WhatsApp link with the invite message: wa.me with the number (lib/phone whatsappNumber), or only the text. */
export function inviteWhatsAppUrl(message: string, number: string): string {
  return whatsappUrl(number, message)
}

// ── Permissions table ────────────────────────────────────────────────────

export interface PermissionGroup {
  label: MessageKey
  permissions: Permission[]
}

/** Every permission of app-permissions.json, grouped for the owner to read. */
export const PERMISSION_GROUPS: PermissionGroup[] = [
  { label: 'web.perm.group.orders', permissions: ['viewAllOrders', 'viewOwnOrders', 'viewAssignedOrders', 'createOrder', 'editOrder', 'executeOrder', 'assignOrder', 'attachPhotos', 'viewPhotos', 'fillForms'] },
  { label: 'web.perm.group.registers', permissions: ['viewCustomers', 'manageCustomers', 'viewDevices', 'manageDevices', 'viewServices', 'manageServices', 'viewProducts', 'manageProducts', 'manageForms'] },
  { label: 'web.perm.group.money', permissions: ['viewPrices', 'editPrices', 'chargeOrder', 'viewBilling', 'viewFinancialReports', 'viewDashboard', 'viewOperationalReports'] },
  { label: 'web.perm.group.company', permissions: ['manageUsers', 'manageRoles', 'manageCompany', 'manageSettings'] },
]

export const PERMISSION_LABEL: Record<Permission, MessageKey> = {
  viewAllOrders: 'web.perm.viewAllOrders',
  viewOwnOrders: 'web.perm.viewOwnOrders',
  viewAssignedOrders: 'web.perm.viewAssignedOrders',
  createOrder: 'web.perm.createOrder',
  editOrder: 'web.perm.editOrder',
  executeOrder: 'web.perm.executeOrder',
  assignOrder: 'web.perm.assignOrder',
  attachPhotos: 'web.perm.attachPhotos',
  viewPhotos: 'web.perm.viewPhotos',
  fillForms: 'web.perm.fillForms',
  viewCustomers: 'web.perm.viewCustomers',
  manageCustomers: 'web.perm.manageCustomers',
  viewDevices: 'web.perm.viewDevices',
  manageDevices: 'web.perm.manageDevices',
  viewServices: 'web.perm.viewServices',
  manageServices: 'web.perm.manageServices',
  viewProducts: 'web.perm.viewProducts',
  manageProducts: 'web.perm.manageProducts',
  manageForms: 'web.perm.manageForms',
  viewPrices: 'web.perm.viewPrices',
  editPrices: 'web.perm.editPrices',
  chargeOrder: 'web.perm.chargeOrder',
  viewBilling: 'web.perm.viewBilling',
  viewFinancialReports: 'web.perm.viewFinancialReports',
  viewDashboard: 'web.perm.viewDashboard',
  viewOperationalReports: 'web.perm.viewOperationalReports',
  manageUsers: 'web.perm.manageUsers',
  manageRoles: 'web.perm.manageRoles',
  manageCompany: 'web.perm.manageCompany',
  manageSettings: 'web.perm.manageSettings',
}

export type Cell = 'yes' | 'no' | 'off'

/** Yes, no, or "off": the role has it but "Valores e cobrança" is off. */
export function permissionCell(role: AppRole, permission: Permission, useFinancial: boolean): Cell {
  const has = (ROLE_PERMISSIONS[role] as readonly string[]).includes(permission)
  if (!has) return 'no'
  return !useFinancial && (FINANCIAL_PERMISSIONS as readonly string[]).includes(permission) ? 'off' : 'yes'
}

// ── Plan ─────────────────────────────────────────────────────────────────

export type { PlanId }

/** Product names: brand names, not translated (SubscriptionPlanName). */
export const PLAN_NAME: Record<PlanId, string> = { free: 'Free', starter: 'Starter', pro: 'Pro', business: 'Business' }

type Limits = SubscriptionLimits

export type PeriodState = 'free' | 'courtesy' | 'renewsOn' | 'endsOn' | 'paymentIssue'

export interface PlanSummary {
  plan: PlanId
  state: PeriodState
  expiresAt: Date | null
  usage: { users: number; photos: number; checklists: number }
  limits: Limits
  /** Passing people does not block (Business): talk to us. */
  overageAllowed: boolean
}

const record = (value: unknown): Record<string, unknown> => (value && typeof value === 'object' ? (value as Record<string, unknown>) : {})
const num = (value: unknown, fallback: number) => (typeof value === 'number' && Number.isFinite(value) ? value : fallback)

/** companies/{id}.subscription read like Subscription (app): plan in force, period, limits and usage. */
export function planSummary(subscription: unknown, now: Date): PlanSummary {
  const sub = record(subscription)
  const expiresAt = dateOf(sub.expiresAt)
  const plan = effectivePlan(subscription, now)
  let state: PeriodState
  if (plan === 'free') state = 'free'
  else if (sub.source === 'grace') state = 'courtesy'
  else if (sub.status === 'past_due') state = 'paymentIssue'
  else if (sub.status === 'cancelled') state = 'endsOn'
  else if (sub.status === 'expired') state = 'free'
  else state = sub.source === 'store' ? 'renewsOn' : 'endsOn'
  const limits = effectiveLimits(subscription, now)
  const usage = record(sub.usage)
  return {
    plan,
    state,
    expiresAt,
    usage: { users: num(usage.usersActive, 1), photos: num(usage.photosThisMonth, 0), checklists: num(usage.formTemplatesActive, 0) },
    limits,
    overageAllowed: checkPlanLimit({ subscription, resource: 'collaborator', usage: limits.users, enforced: true, now }).contactUs,
  }
}

/**
 * People the plan allows, by the same rule as checklists (forms/model
 * activeLimit): -1 (no limit) unless `enforced` (the switch config/paidPlans).
 */
export function seatLimit(plan: PlanSummary, enforced: boolean): number {
  return enforced ? plan.limits.users : -1
}

/** One more invite fits (members and invites that still work count, recounted by the server). */
export function roomForPerson(plan: PlanSummary, enforced: boolean): boolean {
  const limit = seatLimit(plan, enforced)
  return limit < 0 || plan.usage.users < limit || plan.overageAllowed
}

export type UsageLevel = 'unlimited' | 'ok' | 'near' | 'atLimit'

/** "Quase no limite" from 80% on; -1 is no limit (PlanUsage.level). */
export function usageLevel(used: number, limit: number): UsageLevel {
  if (limit < 0) return 'unlimited'
  if (used >= limit) return 'atLimit'
  if (limit > 0 && used / limit >= 0.8) return 'near'
  return 'ok'
}

// ── Company ──────────────────────────────────────────────────────────────

/** Countries the app puts first (company_editors.companyCountryOptions). */
export const COMMON_COUNTRIES = ['BR', 'US', 'PT', 'ES', 'MX'] as const

/** Every ISO country with a translated name: the common ones first, then by name. */
export function countryOptions(language: string, codes: readonly string[]): { code: string; name: string }[] {
  let names: Intl.DisplayNames | null = null
  try {
    names = new Intl.DisplayNames([language], { type: 'region' })
  } catch {
    names = null
  }
  const nameOf = (code: string) => names?.of(code) ?? code
  const common = COMMON_COUNTRIES.filter((code) => codes.includes(code)).map((code) => ({ code, name: nameOf(code) }))
  const rest = codes
    .filter((code) => !(COMMON_COUNTRIES as readonly string[]).includes(code))
    .map((code) => ({ code, name: nameOf(code) }))
    .filter((item) => item.name !== item.code)
    .sort((a, b) => a.name.localeCompare(b.name, language, { sensitivity: 'base' }))
  return [...common, ...rest]
}

/** Two-letter region codes: A to Z twice, kept when the browser knows a name. */
export function regionCodes(): string[] {
  const codes: string[] = []
  for (let a = 65; a <= 90; a++) for (let b = 65; b <= 90; b++) codes.push(String.fromCharCode(a, b))
  let names: Intl.DisplayNames | null = null
  try {
    names = new Intl.DisplayNames(['en'], { type: 'region', fallback: 'none' })
  } catch {
    return [...COMMON_COUNTRIES]
  }
  // Private and exceptionally reserved codes, groupings and countries that no longer exist are left out.
  const skip = new Set([
    'AA', 'QM', 'QN', 'QO', 'QP', 'QQ', 'QR', 'QS', 'QT', 'QU', 'QV', 'QW', 'QX', 'QY', 'QZ', 'XA', 'XB', 'ZZ', 'EU', 'EZ', 'UN', 'UK',
    'AC', 'CP', 'DG', 'EA', 'IC', 'TA', 'AN', 'BU', 'CS', 'DD', 'DY', 'FX', 'HV', 'NH', 'NT', 'RH', 'SU', 'TP', 'VD', 'YD', 'YU', 'ZR',
  ])
  return codes.filter((code) => !skip.has(code) && !!names?.of(code))
}

/** A web address the customer can open: with or without https://, a dot in the host, no spaces. */
export function isWebsite(value: string): boolean {
  const text = value.trim()
  if (!text) return true
  if (/\s/.test(text)) return false
  try {
    const url = new URL(/^https?:\/\//i.test(text) ? text : `https://${text}`)
    return /\.[a-z]{2,}$/i.test(url.hostname)
  } catch {
    return false
  }
}

export interface CompanyData {
  name: string
  phone: string
  address: string
  email: string
  site: string
  country: string
}

/** Fields to write: trimmed, empty as null (company_editors._clean). */
export function companyFields(data: CompanyData): Record<string, string | null> {
  const clean = (value: string) => (value.trim() ? value.trim() : null)
  return {
    name: data.name.trim(),
    phone: clean(data.phone),
    address: clean(data.address),
    email: clean(data.email),
    site: clean(data.site),
    country: clean(data.country),
  }
}

/** Only what changed since the form opened, cleaned as companyFields: a field changed meanwhile elsewhere is kept. */
export function changedFields(before: CompanyData, after: CompanyData): Record<string, string | null> {
  const old = companyFields(before)
  const next = companyFields(after)
  return Object.fromEntries(Object.entries(next).filter(([key, value]) => value !== old[key]))
}

/**
 * Countries a company can pick: those with a money format and a zone here
 * (lib/format, lib/zone). Any other would show BRL and the browser's zone. A
 * country stored by the app outside this list stays, so the form never drops it.
 */
export function companyCountries(current: string | null | undefined): string[] {
  const known = FORMAT_COUNTRIES.filter(hasCountryZone)
  const stored = current?.toUpperCase()
  return stored && !known.includes(stored) ? [...known, stored] : [...known]
}

export type CompanyProblem = 'name' | 'email' | 'site'

export function companyProblems(data: CompanyData): CompanyProblem[] {
  const problems: CompanyProblem[] = []
  if (!data.name.trim()) problems.push('name')
  if (data.email.trim() && !isEmail(data.email)) problems.push('email')
  if (!isWebsite(data.site)) problems.push('site')
  return problems
}

export interface SegmentOption {
  id: string
  name: string
  nameI18n: Record<string, string>
  subspecialties: { id: string; name: string; nameI18n: Record<string, string> }[]
  termsI18n: Record<string, string>
}

const FULL: Record<string, string> = { pt: 'pt-BR', en: 'en-US', es: 'es-ES' }

/** Name in the language, then pt-BR, then the stored name (OnboardingSegment.nameFor). */
export function localName(item: { name: string; nameI18n: Record<string, string> }, language: string): string {
  return pickLocalized(item.nameI18n, FULL[language] ?? language) ?? item.name
}

/** segments/{id} as the settings read it. `name` may be a text, a map by locale or that map as JSON (the seed's shape). */
export function toSegmentOption(id: string, data: Record<string, unknown>): SegmentOption {
  const names = localizedNames(data.name, data.nameI18n)
  const subs = Array.isArray(data.subspecialties) ? (data.subspecialties as Record<string, unknown>[]) : []
  return {
    id,
    name: pickLocalized(names, 'pt-BR') ?? id,
    nameI18n: names,
    termsI18n: localizedMap(data.defaultTermsOfService),
    subspecialties: subs
      .filter((sub) => !!sub && typeof sub.id === 'string')
      .map((sub) => {
        const subNames = localizedNames(sub.name, sub.nameI18n)
        return { id: sub.id as string, name: pickLocalized(subNames, 'pt-BR') ?? (sub.id as string), nameI18n: subNames }
      }),
  }
}

/** The segment's default terms in the language, then pt-BR (SegmentConfigService). */
export function defaultTerms(segment: SegmentOption | null | undefined, language: string): string | null {
  if (!segment) return null
  return segment.termsI18n[FULL[language] ?? language] ?? segment.termsI18n['pt-BR'] ?? null
}

// ── Account ──────────────────────────────────────────────────────────────

/** The account API lives in its own function: …/api becomes …/accountApi (resolveAccountApiBaseUrl). */
export function accountApiBase(apiBase: string): string {
  return apiBase.replace(/\/api\/?$/, '/accountApi')
}

/** Invite code as typed: upper case, INV_ in front when missing (accept_invite_screen). */
export function normalizeInviteCode(value: string): string {
  const code = value.trim().toUpperCase().replace(/\s+/g, '')
  if (!code) return ''
  return code.startsWith('INV_') ? code : `INV_${code}`
}

/** Segment options without `global` (labels for every segment, never one to pick), by stored name. */
export function pickableSegmentOptions(docs: { id: string; data: Record<string, unknown> }[]): SegmentOption[] {
  return docs
    .filter((doc) => doc.id !== 'global')
    .map((doc) => toSegmentOption(doc.id, doc.data))
    .sort((a, b) => a.name.localeCompare(b.name))
}
