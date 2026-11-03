// Reads and writes of the team, company, plan, account and integrations
// screens. Team, invites, Asaas and MCP tokens only go through the API, which
// checks role, recipient and limits. The company and profile documents are
// written straight to Firestore, as the app does (firestore.rules: owner/admin
// for the company, the person for users/{uid}).
import { createApi, type ApiOptions } from '@/lib/api'
import { authClient, firestoreClient, firestoreLite, storageClient } from '@/lib/firebase'
import { api, session } from '@/lib/session'
import { accountApiBase, normalizeInviteCode, type AssignableRole, type Member, type SegmentOption, type TeamInvite } from './model'

const companyId = (): string => {
  if (!session.companyId) throw new Error('settings: no company')
  return session.companyId
}

const me = () => ({ id: session.uid ?? '', name: session.name ?? '' })

async function readOne(path: string): Promise<Record<string, unknown> | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDoc(doc(db, path))
  return snapshot.exists() ? (snapshot.data() as Record<string, unknown>) : null
}

async function update(path: string, fields: Record<string, unknown>): Promise<void> {
  const [db, { doc, updateDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  await updateDoc(doc(db, path), fields)
}

async function upload(path: string, file: File): Promise<string> {
  const [storage, { ref, uploadBytes, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  const target = ref(storage, path)
  await uploadBytes(target, file, { contentType: file.type || 'image/jpeg' })
  return getDownloadURL(target)
}

// ── Team ─────────────────────────────────────────────────────────────────

interface MembershipDoc {
  userId?: string
  user?: { id?: string; name?: string }
  role?: string
}

/** companies/{cid}/memberships: what the app's team screen reads (any member may read it). */
export async function listMembers(): Promise<Member[]> {
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDocs(collection(db, 'companies', companyId(), 'memberships'))
  return snapshot.docs.map((doc) => {
    const data = doc.data() as MembershipDoc
    return { userId: data.userId ?? data.user?.id ?? doc.id, name: data.user?.name ?? '', role: data.role ?? '' }
  })
}

/** Owner and plan of the company, read once for the team screen. */
export async function teamContext(): Promise<{ ownerId: string | null; subscription: unknown }> {
  const company = await readOne(`companies/${companyId()}`)
  const owner = company?.owner as { id?: unknown } | string | undefined
  const ownerId = typeof owner === 'string' ? owner : typeof owner?.id === 'string' ? owner.id : null
  return { ownerId, subscription: company?.subscription }
}

export async function listInvites(): Promise<TeamInvite[]> {
  const data = await api<{ invites?: TeamInvite[] }>('/v1/app/invites')
  return (data.invites ?? []).filter((invite) => typeof invite.token === 'string')
}

export function createInvite(body: { name?: string; email?: string; phone?: string; role: AssignableRole }): Promise<{ token: string; expiresAt?: string }> {
  return api('/v1/app/invites', { method: 'POST', body })
}

export async function cancelInvite(token: string): Promise<void> {
  await api(`/v1/app/invites/${encodeURIComponent(token)}`, { method: 'DELETE' })
}

export async function changeRole(userId: string, role: AssignableRole): Promise<void> {
  await api(`/v1/app/team/members/${encodeURIComponent(userId)}`, { method: 'PATCH', body: { role } })
}

export async function removeMember(userId: string): Promise<void> {
  await api(`/v1/app/team/members/${encodeURIComponent(userId)}`, { method: 'DELETE' })
}

// ── Company ──────────────────────────────────────────────────────────────

export interface CompanyDoc {
  name?: string
  phone?: string | null
  address?: string | null
  email?: string | null
  site?: string | null
  country?: string | null
  logo?: string | null
  segment?: string | null
  subspecialties?: string[] | null
  termsOfService?: string | null
  useFinancial?: boolean
  useScheduling?: boolean
  fieldService?: boolean
  useContracts?: boolean
  useDeviceManagement?: boolean
  subscription?: unknown
  /** Version: the other side may have saved after this copy was read. */
  updatedAt?: unknown
}

export async function loadCompany(): Promise<CompanyDoc> {
  const data = await readOne(`companies/${companyId()}`)
  if (!data) throw new Error('settings: company not found')
  return data as CompanyDoc
}

/** Same instant whatever the reader (REST, full client, string). */
export function stampOf(value: unknown): string {
  if (!value) return ''
  if (typeof value === 'string') return value
  const stamp = value as { toMillis?: () => number; seconds?: number; nanoseconds?: number }
  if (typeof stamp.toMillis === 'function') return String(stamp.toMillis())
  if (typeof stamp.seconds === 'number') return String(stamp.seconds * 1000 + Math.floor((stamp.nanoseconds ?? 0) / 1e6))
  return JSON.stringify(value)
}

export class CompanyChanged extends Error {
  constructor() {
    super('settings: company changed meanwhile')
    this.name = 'CompanyChanged'
  }
}

/**
 * Writes only `fields`, and only if nobody saved the company after `expected`
 * was read (the app or another tab): a transaction reads the version first.
 * Returns the new version.
 */
export async function saveCompanyChecked(fields: Partial<CompanyDoc>, expected: unknown): Promise<string> {
  if (import.meta.env.VITE_USE_EMULATORS === '1' && sessionStorage.getItem('praticos.e2e.failCompanyWrite')) throw new Error('e2e: company write refused')
  const [db, { doc, runTransaction }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const ref = doc(db, 'companies', companyId())
  const updatedAt = new Date().toISOString()
  await runTransaction(db, async (tx) => {
    const current = await tx.get(ref)
    if (stampOf(current.data()?.updatedAt) !== stampOf(expected)) throw new CompanyChanged()
    tx.update(ref, { ...fields, updatedAt, updatedBy: me() })
  })
  applyToSession(fields)
  return updatedAt
}

function applyToSession(fields: Partial<CompanyDoc>): void {
  if (!session.company) return
  for (const key of ['name', 'country', 'segment', 'useFinancial', 'useDeviceManagement', 'useContracts'] as const) {
    if (key in fields) (session.company as Record<string, unknown>)[key] = fields[key] ?? undefined
  }
}

/** Writes some fields of the company, with who and when (app: updatedAt, updatedBy). Returns the new version. */
export async function saveCompany(fields: Partial<CompanyDoc>): Promise<string> {
  // E2E only (emulator builds): a write the server refuses, to see the switch go back.
  if (import.meta.env.VITE_USE_EMULATORS === '1' && sessionStorage.getItem('praticos.e2e.failCompanyWrite')) throw new Error('e2e: company write refused')
  const updatedAt = new Date().toISOString()
  await update(`companies/${companyId()}`, { ...fields, updatedAt, updatedBy: me() })
  // The shell and the money switches read session.company: change it in place, no reload.
  applyToSession(fields)
  return updatedAt
}

/** Same file as the app (tenants/{cid}/logo/logo.jpg); storage.rules lets only owner/admin write it. */
export async function uploadLogo(file: File, expected?: unknown): Promise<{ url: string; updatedAt: string }> {
  const url = await upload(`tenants/${companyId()}/logo/logo.jpg`, file)
  const updatedAt = expected === undefined ? await saveCompany({ logo: url }) : await saveCompanyChecked({ logo: url }, expected)
  return { url, updatedAt }
}

interface SegmentDoc {
  name?: string
  nameI18n?: Record<string, string>
  active?: boolean
  subspecialties?: { id?: string; name?: string; nameI18n?: Record<string, string> }[]
  defaultTermsOfService?: Record<string, string>
}

const strings = (value: unknown): Record<string, string> =>
  Object.fromEntries(Object.entries((value as Record<string, unknown>) ?? {}).filter((entry): entry is [string, string] => typeof entry[1] === 'string'))

/** Active segments (firestoreOnboardingSegments), sorted by stored name like the app. */
export async function loadSegments(): Promise<SegmentOption[]> {
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDocs(query(collection(db, 'segments'), where('active', '==', true)))
  return snapshot.docs
    .map((doc) => {
      const data = doc.data() as SegmentDoc
      return {
        id: doc.id,
        name: data.name ?? doc.id,
        nameI18n: strings(data.nameI18n),
        termsI18n: strings(data.defaultTermsOfService),
        subspecialties: (data.subspecialties ?? [])
          .filter((sub) => typeof sub?.id === 'string')
          .map((sub) => ({ id: sub.id as string, name: sub.name ?? (sub.id as string), nameI18n: strings(sub.nameI18n) })),
      }
    })
    .sort((a, b) => a.name.localeCompare(b.name))
}

// ── Plan ─────────────────────────────────────────────────────────────────

export interface AiStatus {
  enabled: boolean
  usage?: { used: number; limit: number }
}

export function loadAiStatus(): Promise<AiStatus> {
  return api<AiStatus>('/v1/app/ai/status')
}

// ── Account ──────────────────────────────────────────────────────────────

export interface Profile {
  name: string
  email: string
  photo: string | null
}

export async function loadProfile(): Promise<Profile> {
  const data = await readOne(`users/${session.uid}`)
  return {
    name: typeof data?.name === 'string' ? data.name : (session.name ?? ''),
    email: typeof data?.email === 'string' ? data.email : (session.email ?? ''),
    photo: typeof data?.photo === 'string' && data.photo ? data.photo : null,
  }
}

/** Only the name of users/{uid}; the updateUserClaims trigger follows, as after the app's save. */
export async function saveProfileName(name: string): Promise<void> {
  const clean = name.trim()
  await update(`users/${session.uid}`, { name: clean, updatedAt: new Date().toISOString(), updatedBy: { id: session.uid, name: clean } })
  session.name = clean
}

/** Same file as the app: per company (tenants/{cid}/users/{uid}/photo.jpg). */
export async function uploadProfilePhoto(file: File): Promise<string> {
  const url = await upload(`tenants/${companyId()}/users/${session.uid}/photo.jpg`, file)
  await update(`users/${session.uid}`, { photo: url, updatedAt: new Date().toISOString(), updatedBy: me() })
  return url
}

export interface InvitePreview {
  token: string
  company: { id: string; name: string }
  role: string
  invitedBy?: string
}

export function lookupInvite(code: string): Promise<InvitePreview> {
  return api<InvitePreview>(`/v1/app/invites/${encodeURIComponent(normalizeInviteCode(code))}`, { noCompany: true })
}

const accountClient = createApi({
  baseUrl: () => accountApiBase(import.meta.env.VITE_API_BASE_URL ?? ''),
  getCompanyId: () => null,
  getToken: async (forceRefresh) => {
    const auth = await authClient()
    return (await auth.currentUser?.getIdToken(forceRefresh)) ?? null
  },
})

/** DELETE /v1/app/account on the accountApi function. The uid comes only from the token. */
export function deleteAccount(options: ApiOptions = {}): Promise<{ deletedCompanies?: number; leftCompanies?: number; alreadyDeleted?: boolean }> {
  return accountClient.request('/v1/app/account', { ...options, method: 'DELETE', noCompany: true })
}

export type ReauthKind = 'password' | 'google' | 'apple'

/** First provider the app supports, skipping a linked phone (account.deletion.reauth). */
export async function reauthKind(): Promise<ReauthKind | null> {
  const auth = await authClient()
  for (const provider of auth.currentUser?.providerData ?? []) {
    if (provider.providerId === 'password') return 'password'
    if (provider.providerId === 'google.com') return 'google'
    if (provider.providerId === 'apple.com') return 'apple'
  }
  return null
}

/** Signs in again so the server sees a recent sign-in (auth_time under 5 minutes). */
export async function reauthenticate(kind: ReauthKind, password?: string): Promise<void> {
  const [auth, firebaseAuth] = await Promise.all([authClient(), import('firebase/auth')])
  const user = auth.currentUser
  if (!user) throw new Error('settings: signed out')
  if (kind === 'password') {
    await firebaseAuth.reauthenticateWithCredential(user, firebaseAuth.EmailAuthProvider.credential(user.email ?? '', password ?? ''))
  } else {
    const provider = kind === 'google' ? new firebaseAuth.GoogleAuthProvider() : new firebaseAuth.OAuthProvider('apple.com')
    await firebaseAuth.reauthenticateWithPopup(user, provider, firebaseAuth.browserPopupRedirectResolver)
  }
  // The new auth_time reaches the server only in a new ID token.
  await user.getIdToken(true)
}

// ── Integrations ─────────────────────────────────────────────────────────

export interface McpToken {
  id: string
  name: string
  lastUsedAt?: string | null
  createdAt?: string | null
}

export async function listTokens(): Promise<McpToken[]> {
  const data = await api<McpToken[] | { tokens?: McpToken[] }>('/v1/app/integrations/tokens')
  return Array.isArray(data) ? data : (data.tokens ?? [])
}

export function createToken(name: string): Promise<{ id: string; url?: string; expiresAt?: string }> {
  return api('/v1/app/integrations/tokens', { method: 'POST', body: { name } })
}

export async function revokeToken(id: string): Promise<void> {
  await api(`/v1/app/integrations/tokens/${encodeURIComponent(id)}`, { method: 'DELETE' })
}

export interface PaymentSettings {
  asaasEnabled: boolean
  asaasConnected: boolean
  asaasAccountName?: string
  asaasEnvironment?: string
  nfseEnabled?: boolean
  nfseReady?: boolean
}

export function loadPaymentSettings(): Promise<PaymentSettings> {
  return api<PaymentSettings>('/v1/app/payments/asaas/settings')
}

export function connectAsaas(apiKey: string): Promise<PaymentSettings> {
  return api<PaymentSettings>('/v1/app/payments/asaas/connect', { method: 'POST', body: { apiKey } })
}

export async function disconnectAsaas(): Promise<void> {
  await api('/v1/app/payments/asaas/connect', { method: 'DELETE' })
}
