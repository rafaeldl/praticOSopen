// Who is signed in, their companies and the current one.
// The role always comes from the token claim, the same source firestore.rules
// reads. The `companies` list of the user document only gives names and order.
import { reactive } from 'vue'
import type { User } from 'firebase/auth'
import { authMethod, clearUser, logLogin, logSignUp } from './analytics'
import { createApi, type ApiOptions } from './api'
import { authClient, cacheState, clearFirestoreCache, firestoreClient, firestoreLite } from './firebase'
import { mark } from './marks'
import { hasAnyPermission, roleHasPermission, type Permission } from './permissions'
import { isSignupBlocked } from './auth-errors'
import { readStorage, writeStorage } from './storage'
import { fetchWebAccess, rememberAccess, rememberedAccess, shouldRecheck, warmUpApi, type WebAccess } from './web-access'

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
  /** Device control (Configurações shows the devices list only with it on). */
  useDeviceManagement?: boolean
  /** Contratos on (company.settings.contracts). */
  useContracts?: boolean
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
  /** Web app access list (lib/web-access.ts). */
  webAccess: WebAccess
  /** More than one company and none chosen yet in this browser. */
  needsCompanyChoice: boolean
  /** Sign-in that came back from a redirect and failed. */
  signInError: string | null
  /** The company document could not be read: money stays hidden until it loads. */
  companyFailed: boolean
  /** Unverified e-mails are never on the access list. */
  emailVerified: boolean
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
  webAccess: 'unknown',
  needsCompanyChoice: false,
  signInError: null,
  companyFailed: false,
  emailVerified: false,
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

export function pickCompany(companies: CompanyEntry[], saved: string | null): string | null {
  return companies.find((company) => company.id === saved)?.id ?? companies[0]?.id ?? null
}

const savedCompanyKey = (uid: string) => `praticos.company.${uid}`

/**
 * One-shot read through the REST build (lib/firebase.ts), so the start never
 * waits for the full Firestore client.
 */
async function readDoc<T>(path: string): Promise<T | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDoc(doc(db, path))
  return snapshot.exists() ? (snapshot.data() as T) : null
}

async function loadCompany(companyId: string): Promise<void> {
  try {
    const profile = await readDoc<CompanyProfile>(`companies/${companyId}`)
    if (session.companyId === companyId) {
      session.company = profile
      session.companyFailed = false
    }
  } catch (error) {
    console.warn('session: company not loaded', error)
    if (session.companyId === companyId) session.companyFailed = true
  }
}

/** Retry after a failed company read. */
export async function reloadCompany(): Promise<void> {
  if (session.companyId) await loadCompany(session.companyId)
}

/**
 * Values and billing only once the company says so: while its document has not
 * loaded, `useFinancial` counts as off, so money is never shown by accident.
 */
export function effectiveUseFinancial(): boolean {
  return session.company ? session.company.useFinancial !== false : false
}

const staleTriedKey = (uid: string) => `praticos.claimRefresh.${uid}`

/**
 * Companies listed in the user document but missing from the claim. A refresh
 * is worth it once per new set: a company the claim will never have (an entry the
 * server does not confirm) must not force a refresh on every start.
 */
export function staleCompanyIds(entries: unknown, roles: Record<string, string>): string[] {
  if (!Array.isArray(entries)) return []
  return (entries as UserCompanyEntry[])
    .map((entry) => entry?.company?.id)
    .filter((id): id is string => typeof id === 'string' && !roles[id])
    .sort()
}

export function shouldRefreshForStale(missing: string[], lastTried: string | null): boolean {
  return missing.length > 0 && missing.join(',') !== (lastTried ?? '')
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
    webAccess: 'unknown',
    needsCompanyChoice: false,
    emailVerified: false,
  })
}

/**
 * A remembered "yes" lets the start go on and is confirmed in the background;
 * otherwise the start waits for the answer.
 */
const accessAsks = new Map<string, Promise<void>>()

async function checkWebAccess(uid: string): Promise<void> {
  // The login screen and onAuthStateChanged both hydrate the same sign-in: one question for both.
  const ask = () => {
    let asking = accessAsks.get(uid)
    if (!asking) {
      asking = askAccess().finally(() => accessAsks.delete(uid))
      accessAsks.set(uid, asking)
    }
    return asking
  }
  const askAccess = async () => {
    try {
      const allowed = await fetchWebAccess((path) => api(path, { noCompany: true }))
      rememberAccess(uid, allowed)
      mark('session:access')
      if (session.uid === uid) session.webAccess = allowed ? 'allowed' : 'denied'
    } catch (error) {
      console.warn('session: web access not checked', error)
      // Only a still valid "yes" of this same account survives a network failure.
      if (session.uid === uid) session.webAccess = rememberedAccess(uid) ? 'allowed' : 'error'
    }
  }
  if (rememberedAccess(uid)) {
    session.webAccess = 'allowed'
    if (shouldRecheck(uid)) void ask()
    return
  }
  await ask()
}

const methodOf = (user: User) => authMethod((user.providerData ?? []).map((provider) => provider.providerId))

/** A sign-in made now (not a page opened with a saved session): the app's login, after the company is known. */
function loggedIn(user: User): void {
  if (session.uid === user.uid) logLogin(methodOf(user), session.companies.length > 0)
}

const hydrating = new Map<string, Promise<void>>()

/** The login screen and onAuthStateChanged load the same sign-in at once: one load for both. */
function hydrate(user: User, forceRefresh = false): Promise<void> {
  if (forceRefresh) return load(user, true)
  let loading = hydrating.get(user.uid)
  if (!loading) {
    loading = load(user).finally(() => hydrating.delete(user.uid))
    hydrating.set(user.uid, loading)
  }
  return loading
}

async function load(user: User, forceRefresh = false): Promise<void> {
  session.failed = false
  // Another account: nothing of the previous one (access answer, cached data) carries over.
  if (session.uid !== user.uid) {
    session.webAccess = 'unknown'
    await clearCacheOfOtherAccount(user.uid)
  }
  session.uid = user.uid
  session.email = user.email
  session.emailVerified = user.emailVerified
  try {
    let token = await user.getIdTokenResult(forceRefresh)
    mark('session:token')
    const access = checkWebAccess(user.uid)
    let companyReadFailed = false
    let roles = (token.claims.roles ?? {}) as Record<string, string>
    const saved = readStorage(savedCompanyKey(user.uid))
    // User and company documents in parallel: the claim already names the company.
    const guess = guessCompany(roles, saved)
    if (guess) hintListeners.forEach((listener) => listener({ uid: user.uid, companyId: guess, role: roles[guess] as string }))
    const [profile, guessed] = await Promise.all([
      readDoc<{ name?: string; companies?: unknown; preferredLanguage?: string }>(`users/${user.uid}`),
      guess
        ? readDoc<CompanyProfile>(`companies/${guess}`).catch((error) => {
            console.warn('session: company not loaded', error)
            companyReadFailed = true
            return null
          })
        : Promise.resolve(null),
    ])
    mark('session:docs')
    const missing = staleCompanyIds(profile?.companies, roles)
    if (!forceRefresh && shouldRefreshForStale(missing, readStorage(staleTriedKey(user.uid)))) {
      writeStorage(staleTriedKey(user.uid), missing.join(','))
      token = await user.getIdTokenResult(true)
      roles = (token.claims.roles ?? {}) as Record<string, string>
    }
    session.name = profile?.name ?? user.displayName
    // First sign-in on the web: the app's users/{uid} (without waiting); otherwise the account's language.
    if (!profile) {
      const fresh = { uid: user.uid, name: user.displayName, email: user.email }
      void import('./user-profile')
        .then((m) => m.ensureUserDoc(fresh))
        .then((created) => created && logSignUp(methodOf(user)))
        .catch((error) => console.warn('session: user not created', error))
    } else if (profile.preferredLanguage) {
      const tag = profile.preferredLanguage
      void import('./user-profile').then((m) => m.applyAccountLanguage(tag))
    }
    session.companies = resolveCompanies(profile?.companies, roles)
    const companyId = pickCompany(session.companies, saved)
    session.companyId = companyId
    session.role = session.companies.find((company) => company.id === companyId)?.role ?? null
    session.company = companyId && companyId === guess ? guessed : null
    session.companyFailed = !!companyId && companyId === guess && companyReadFailed
    session.needsCompanyChoice = session.companies.length > 1 && !session.companies.some((company) => company.id === saved)
    await Promise.all([access, companyId && companyId !== guess ? loadCompany(companyId) : null])
  } catch (error) {
    console.error('session: could not load account', error)
    // Nothing from a previous account or company may stay on screen.
    Object.assign(session, {
      companies: [],
      companyId: null,
      company: null,
      role: null,
      needsCompanyChoice: false,
      failed: true,
    })
  }
}

// Whose data is in this browser's Firestore cache. Kept until the cache is
// really gone, so a failed deletion is retried on the next load.
const CACHE_OWNER_KEY = 'praticos.cacheOwner'

/** The persistent cache belongs to someone other than `uid` (null: nobody signed in). */
export function cacheNeedsClearing(owner: string | null, uid: string | null): boolean {
  return !!owner && owner !== uid
}

async function clearCachedData(): Promise<boolean> {
  try {
    await clearFirestoreCache()
    writeStorage(CACHE_OWNER_KEY, '')
    return true
  } catch (error) {
    console.warn('session: cache not cleared, will retry on next load', error)
    return false
  }
}

async function clearCacheOfOtherAccount(uid: string): Promise<void> {
  // Owner changes only after the previous one's data is gone, or a failure would forget the retry.
  if (cacheNeedsClearing(readStorage(CACHE_OWNER_KEY), uid) && !(await clearCachedData())) {
    cacheState.trusted = false
    return
  }
  cacheState.trusted = true
  writeStorage(CACHE_OWNER_KEY, uid)
}

/**
 * Signed out without the button: another tab, a token that no longer renews, a
 * disabled account. The data must not stay on this computer.
 */
async function endedSession(): Promise<void> {
  // "Sair" already clears the cache and starts the page over; a second reload
  // from here would land on whatever page comes next.
  if (signingOut) return
  const wasSignedIn = !!session.uid
  clear()
  if (cacheNeedsClearing(readStorage(CACHE_OWNER_KEY), null)) {
    const cleared = await clearCachedData()
    // A running page holds the old Firestore instance: start over clean.
    if (cleared && wasSignedIn) location.assign(`${import.meta.env.BASE_URL}login`)
  }
}

let started: Promise<void> | undefined

/** Resolves after the first auth answer. Safe to call many times. */
export function startSession(): Promise<void> {
  started ??= (async () => {
    await finishRedirect()
    const [auth, { onAuthStateChanged }] = await Promise.all([authClient(), import('firebase/auth')])
    await new Promise<void>((resolve) => {
      onAuthStateChanged(auth, (user) => {
        mark('session:auth')
        void (async () => {
          if (user) {
            await hydrate(user)
            // Back from a Google or Apple redirect: that was a sign-in.
            if (redirectedIn) loggedIn(user)
            redirectedIn = false
          } else await endedSession()
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

export type ProviderKind = 'google' | 'apple'
const REDIRECT_FLAG = 'praticos.signInRedirect'

/** What the login screen says after a redirect that came back with an error. */
export function redirectErrorOf(kind: string, error: unknown): string {
  return isSignupBlocked(error) ? SIGNUP_BLOCKED : kind
}
export const SIGNUP_BLOCKED = 'signupBlocked'

/**
 * Google or Apple, on the same page: the browser goes to /__/auth/handler on
 * praticos.app (the authDomain is the app's own domain, so Safari keeps the
 * storage first-party) and comes back to the login, where startSession
 * finishes it. No popup to block or lose behind the window.
 */
export async function signInWithProvider(kind: ProviderKind): Promise<'redirecting'> {
  const [auth, firebaseAuth] = await Promise.all([authClient(), import('firebase/auth')])
  const { GoogleAuthProvider, OAuthProvider, browserPopupRedirectResolver, signInWithRedirect } = firebaseAuth
  let provider: InstanceType<typeof GoogleAuthProvider> | InstanceType<typeof OAuthProvider>
  if (kind === 'google') {
    provider = new GoogleAuthProvider()
    provider.setCustomParameters({ prompt: 'select_account' })
  } else {
    provider = new OAuthProvider('apple.com')
    provider.addScope('email')
    provider.addScope('name')
  }
  writeStorage(REDIRECT_FLAG, kind)
  await signInWithRedirect(auth, provider, browserPopupRedirectResolver)
  return 'redirecting'
}

let redirectedIn = false

/** Back from a redirect sign-in: finish it before reading the session. */
async function finishRedirect(): Promise<void> {
  const kind = readStorage(REDIRECT_FLAG)
  if (!kind) return
  mark('login:back')
  writeStorage(REDIRECT_FLAG, '')
  try {
    const [auth, { getRedirectResult, browserPopupRedirectResolver }] = await Promise.all([
      authClient(),
      import('firebase/auth'),
    ])
    redirectedIn = !!(await getRedirectResult(auth, browserPopupRedirectResolver))
    mark('login:auth')
  } catch (error) {
    console.warn('session: redirect sign-in failed', error)
    session.signInError = redirectErrorOf(kind, error)
  }
}

export async function sendVerificationEmail(): Promise<void> {
  const [auth, { sendEmailVerification }] = await Promise.all([authClient(), import('firebase/auth')])
  if (auth.currentUser) await sendEmailVerification(auth.currentUser)
}

export async function sendPasswordReset(email: string): Promise<void> {
  const [auth, { sendPasswordResetEmail }] = await Promise.all([authClient(), import('firebase/auth')])
  await sendPasswordResetEmail(auth, email)
}

/** Wakes the API before the sign-in needs it (lib/web-access.ts). */
export function warmUpSignIn(): void {
  warmUpApi(import.meta.env.VITE_API_BASE_URL ?? '')
}

export async function signInWithEmail(email: string, password: string): Promise<void> {
  const [auth, { signInWithEmailAndPassword }] = await Promise.all([authClient(), import('firebase/auth')])
  const { user } = await signInWithEmailAndPassword(auth, email, password)
  mark('login:auth')
  // onAuthStateChanged also fires; awaiting here lets the login screen navigate on loaded data.
  await hydrate(user)
  mark('login:hydrated')
  loggedIn(user)
}

let signingOut = false

export async function signOutEverywhere(): Promise<void> {
  const [auth, { signOut }] = await Promise.all([authClient(), import('firebase/auth')])
  signingOut = true
  // This browser stops getting the account's notifications (still signed in, so it may write). Never holds the exit.
  const uid = session.uid
  if (uid) {
    const forget = import('@/lib/push').then((push) => push.forgetThisBrowser(uid))
    await Promise.race([forget, new Promise((done) => setTimeout(done, 3000))]).catch((error) => console.warn('push: not forgotten', error))
  }
  clearUser()
  await signOut(auth)
  clear()
  await clearCachedData()
  // Firestore cannot be used after its cache is gone: start the page over.
  location.assign(`${import.meta.env.BASE_URL}login`)
}

/** Forces a new token: an accepted invite only reaches the claim on the server. */
export async function refreshClaims(): Promise<void> {
  const auth = await authClient()
  // reload() brings emailVerified after the person clicked the link in the e-mail.
  if (auth.currentUser) await auth.currentUser.reload().catch(() => {})
  if (auth.currentUser) {
    rememberAccess(auth.currentUser.uid, false)
    await hydrate(auth.currentUser, true)
  }
}

export async function selectCompany(companyId: string): Promise<void> {
  const entry = session.companies.find((company) => company.id === companyId)
  if (!entry || !session.uid) return
  writeStorage(savedCompanyKey(session.uid), companyId)
  session.needsCompanyChoice = false
  session.companyId = companyId
  session.role = entry.role
  session.company = null
  session.companyFailed = false
  await loadCompany(companyId)
}

let stopCompany: (() => void) | null = null

/**
 * Follows companies/{id} live (one document), after the first screen is up: a
 * change made by the app or another tab, such as turning "Valores e cobrança"
 * off, reaches session.company at once, and the open screen is checked again
 * (App.vue). The first read stays on the REST build; this uses the full client.
 */
export async function followCompany(companyId: string | null): Promise<void> {
  stopCompany?.()
  stopCompany = null
  if (!companyId) return
  try {
    const [db, { doc, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
    if (session.companyId !== companyId) return
    stopCompany = onSnapshot(
      doc(db, 'companies', companyId),
      (snapshot) => {
        if (session.companyId !== companyId || !snapshot.exists()) return
        const data = snapshot.data() as CompanyProfile
        const next: CompanyProfile = { ...(session.company ?? {}) }
        for (const key of ['name', 'country', 'segment', 'useFinancial', 'useDeviceManagement', 'useContracts'] as const) {
          ;(next as Record<string, unknown>)[key] = data[key] ?? undefined
        }
        if (JSON.stringify(next) !== JSON.stringify(session.company)) session.company = next
        session.companyFailed = false
      },
      (error) => console.warn('session: company not followed', error),
    )
  } catch (error) {
    console.warn('session: company not followed', error)
  }
}

export function can(permission: Permission): boolean {
  return roleHasPermission(session.role, permission, effectiveUseFinancial())
}

export function canAny(permissions: readonly Permission[]): boolean {
  return hasAnyPermission(session.role, permissions, effectiveUseFinancial())
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
