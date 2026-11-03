// Who is signed in, their companies and the current one.
// The role always comes from the token claim, the same source firestore.rules
// reads. The `companies` list of the user document only gives names and order.
import { reactive } from 'vue'
import type { User } from 'firebase/auth'
import { createApi, type ApiOptions } from './api'
import { authClient, clearFirestoreCache, firestoreClient } from './firebase'
import { mark } from './marks'
import { hasAnyPermission, roleHasPermission, type Permission } from './permissions'
import { readStorage, writeStorage } from './storage'

export interface CompanyEntry {
  id: string
  name: string
  role: string
}

export interface CompanyProfile {
  name?: string
  country?: string
  segment?: string
  useFinancial?: boolean
}

export interface SessionState {
  /** First auth answer has arrived. */
  ready: boolean
  /** Could not read the account (offline, rules). Sign-in itself worked. */
  failed: boolean
  uid: string | null
  email: string | null
  name: string | null
  companies: CompanyEntry[]
  companyId: string | null
  company: CompanyProfile | null
  role: string | null
}

export const session = reactive<SessionState>({
  ready: false,
  failed: false,
  uid: null,
  email: null,
  name: null,
  companies: [],
  companyId: null,
  company: null,
  role: null,
})

interface UserCompanyEntry {
  company?: { id?: unknown; name?: unknown }
}

/** Companies confirmed by the claim, in the order of the user document. */
export function resolveCompanies(entries: unknown, roles: Record<string, string>): CompanyEntry[] {
  const list: CompanyEntry[] = []
  const seen = new Set<string>()
  for (const entry of Array.isArray(entries) ? (entries as UserCompanyEntry[]) : []) {
    const id = entry?.company?.id
    if (typeof id !== 'string' || seen.has(id) || !roles[id]) continue
    seen.add(id)
    list.push({ id, name: typeof entry.company?.name === 'string' ? entry.company.name : '', role: roles[id] })
  }
  for (const [id, role] of Object.entries(roles)) {
    if (!seen.has(id)) list.push({ id, name: '', role })
  }
  return list
}

/** The user document lists a company the token does not know yet: the token is stale. */
export function tokenIsStale(entries: unknown, roles: Record<string, string>): boolean {
  if (!Array.isArray(entries)) return false
  return (entries as UserCompanyEntry[]).some((entry) => {
    const id = entry?.company?.id
    return typeof id === 'string' && !roles[id]
  })
}

export function pickCompany(companies: CompanyEntry[], saved: string | null): string | null {
  return companies.find((company) => company.id === saved)?.id ?? companies[0]?.id ?? null
}

const savedCompanyKey = (uid: string) => `praticos.company.${uid}`

async function readDoc<T>(path: string): Promise<T | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const snapshot = await getDoc(doc(db, path))
  return snapshot.exists() ? (snapshot.data() as T) : null
}

/**
 * This browser's copy first, when it has one, and the server copy right after
 * through `onFresh`. Returning to the app then waits for the disk, not the network.
 */
async function readDocCacheFirst<T>(path: string, onFresh: (value: T | null) => void): Promise<T | null> {
  const [db, { doc, getDocFromCache }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  try {
    const cached = await getDocFromCache(doc(db, path))
    if (cached.exists()) {
      void readDoc<T>(path).then(onFresh, (error) => console.warn('session: refresh failed', error))
      return cached.data() as T
    }
  } catch {
    // Not in the cache: read from the server below.
  }
  return readDoc<T>(path)
}

async function loadCompany(companyId: string): Promise<void> {
  const profile = await readDoc<CompanyProfile>(`companies/${companyId}`)
  session.company = profile
}

export interface SessionHint {
  uid: string
  companyId: string
  role: string
}

const hintListeners: ((hint: SessionHint) => void)[] = []

/**
 * Called as soon as the token says which company will open, before the user and
 * company documents arrive. Lets a screen start its query in the same round trip.
 */
export function onSessionHint(listener: (hint: SessionHint) => void): void {
  hintListeners.push(listener)
}

/** Same choice pickCompany will make, from the claim alone. */
export function guessCompany(roles: Record<string, string>, saved: string | null): string | null {
  return saved && roles[saved] ? saved : (Object.keys(roles)[0] ?? null)
}

function clear(): void {
  Object.assign(session, {
    failed: false,
    uid: null,
    email: null,
    name: null,
    companies: [],
    companyId: null,
    company: null,
    role: null,
  })
}

async function hydrate(user: User, forceRefresh = false): Promise<void> {
  session.failed = false
  session.uid = user.uid
  session.email = user.email
  try {
    let token = await user.getIdTokenResult(forceRefresh)
    mark('session:token')
    let roles = (token.claims.roles ?? {}) as Record<string, string>
    const saved = readStorage(savedCompanyKey(user.uid))
    // User and company documents in parallel: the claim already names the company.
    const guess = guessCompany(roles, saved)
    if (guess) hintListeners.forEach((listener) => listener({ uid: user.uid, companyId: guess, role: roles[guess] as string }))
    const [profile, guessed] = await Promise.all([
      readDocCacheFirst<{ name?: string; companies?: unknown }>(`users/${user.uid}`, (fresh) => {
        if (session.uid !== user.uid) return
        session.name = fresh?.name ?? user.displayName
        session.companies = resolveCompanies(fresh?.companies, roles)
      }),
      guess
        ? readDocCacheFirst<CompanyProfile>(`companies/${guess}`, (fresh) => {
            if (session.companyId === guess) session.company = fresh
          })
        : Promise.resolve(null),
    ])
    mark('session:docs')
    if (!forceRefresh && tokenIsStale(profile?.companies, roles)) {
      token = await user.getIdTokenResult(true)
      roles = (token.claims.roles ?? {}) as Record<string, string>
    }
    session.name = profile?.name ?? user.displayName
    session.companies = resolveCompanies(profile?.companies, roles)
    const companyId = pickCompany(session.companies, saved)
    session.companyId = companyId
    session.role = session.companies.find((company) => company.id === companyId)?.role ?? null
    session.company = companyId && companyId === guess ? guessed : null
    if (companyId && companyId !== guess) await loadCompany(companyId)
  } catch (error) {
    console.error('session: could not load account', error)
    session.failed = true
  }
}

let started: Promise<void> | undefined

/** Resolves after the first auth answer. Safe to call many times. */
export function startSession(): Promise<void> {
  started ??= (async () => {
    const [auth, { onAuthStateChanged }] = await Promise.all([authClient(), import('firebase/auth')])
    await new Promise<void>((resolve) => {
      onAuthStateChanged(auth, (user) => {
        mark('session:auth')
        void (async () => {
          if (user) await hydrate(user)
          else clear()
          session.ready = true
          resolve()
        })()
      })
    })
  })().catch((error) => {
    console.error('session: could not start', error)
    session.failed = true
    session.ready = true
  })
  return started
}

export async function signInWithEmail(email: string, password: string): Promise<void> {
  const [auth, { signInWithEmailAndPassword }] = await Promise.all([authClient(), import('firebase/auth')])
  const { user } = await signInWithEmailAndPassword(auth, email, password)
  // onAuthStateChanged also fires; awaiting here lets the login screen navigate on loaded data.
  await hydrate(user)
}

export async function signOutEverywhere(): Promise<void> {
  const [auth, { signOut }] = await Promise.all([authClient(), import('firebase/auth')])
  await signOut(auth)
  clear()
  await clearFirestoreCache()
  // Firestore cannot be used after its cache is gone: start the page over.
  location.assign(`${import.meta.env.BASE_URL}login`)
}

/** Forces a new token: an accepted invite only reaches the claim on the server. */
export async function refreshClaims(): Promise<void> {
  const auth = await authClient()
  if (auth.currentUser) await hydrate(auth.currentUser, true)
}

export async function selectCompany(companyId: string): Promise<void> {
  const entry = session.companies.find((company) => company.id === companyId)
  if (!entry || !session.uid) return
  writeStorage(savedCompanyKey(session.uid), companyId)
  session.companyId = companyId
  session.role = entry.role
  session.company = null
  await loadCompany(companyId)
}

export function can(permission: Permission): boolean {
  return roleHasPermission(session.role, permission, session.company?.useFinancial)
}

export function canAny(permissions: readonly Permission[]): boolean {
  return hasAnyPermission(session.role, permissions, session.company?.useFinancial)
}

const client = createApi({
  baseUrl: () => import.meta.env.VITE_API_BASE_URL ?? '',
  getCompanyId: () => session.companyId,
  getToken: async (forceRefresh) => {
    const auth = await authClient()
    return (await auth.currentUser?.getIdToken(forceRefresh)) ?? null
  },
})

export function api<T>(path: string, options?: ApiOptions): Promise<T> {
  return client.request<T>(path, options)
}
