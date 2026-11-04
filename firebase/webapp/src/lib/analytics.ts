// Firebase Analytics (GA4) of the web, with the app's event names and
// parameters (lib/services/analytics_service.dart, docs/FIREBASE_ANALYTICS.md),
// so the app and the web read as one funnel.
//
// - Nothing is sent before the person says yes in the notice (AnalyticsConsent.vue).
//   "Recusar" (or no answer) keeps firebase/analytics from ever downloading.
// - The client loads only after the first screen (startAnalytics, AppShell) and
//   never on the way to the login or the list (scripts/check-budget.mjs).
// - No personal data: only the keys below go out (name, phone, e-mail never);
//   the user id is the uid, as the app.
// - Without VITE_FIREBASE_MEASUREMENT_ID (and VITE_FIREBASE_APP_ID) analytics is off, silently.
import { reactive } from 'vue'
import { readStorage, writeStorage } from './storage'

export type EventParams = Record<string, string | number>

export interface UserIdentity {
  userId: string
  companyId?: string | null
  segment?: string | null
  userRole?: string | null
}

/** Where the events go: Firebase in production, a spy in the e2e build. */
export interface AnalyticsSink {
  event(name: string, params: EventParams): void
  identify(user: UserIdentity | null): void
  /** Page address without ids or search (sent with every event, enhanced measurement included). */
  page(path: string): void
  /** Consent taken back in Configurações: nothing more leaves this tab. */
  stop(): void
}

/** The only parameters that may leave. Anything else is dropped (and never a name, phone or e-mail). */
export const ALLOWED_PARAMS = new Set([
  'method',
  'has_company',
  'variant',
  'company_id',
  'segment',
  'content_type',
  'item_id',
  'amount',
  'input',
  'result',
  'trigger',
  'types',
  'edited',
  'step',
  'firebase_screen',
  'firebase_screen_class',
])

const CONSENT_KEY = 'praticos.analyticsConsent'
/** E2E only: the notice and the spy appear only in the tests that ask (e2e/analytics.spec.ts). */
const E2E_KEY = 'praticos.analyticsE2E'

export type Consent = 'granted' | 'denied' | null

export const analyticsState = reactive<{ consent: Consent }>({ consent: readConsent() })

function readConsent(): Consent {
  const value = readStorage(CONSENT_KEY)
  return value === 'granted' || value === 'denied' ? value : null
}

/** Analytics can run in this build: a measurement id in production, or a test that asked for the spy. */
export function analyticsAvailable(): boolean {
  if (import.meta.env.VITE_USE_EMULATORS === '1') return readStorage(E2E_KEY) === '1'
  return !!import.meta.env.VITE_FIREBASE_MEASUREMENT_ID && !!import.meta.env.VITE_FIREBASE_APP_ID
}

/** The notice shows once, while there is no answer in this browser. */
export function needsConsent(): boolean {
  return analyticsAvailable() && analyticsState.consent === null
}

type Call = (sink: AnalyticsSink) => void
const MAX_QUEUE = 100
let queue: Call[] = []
let sink: AnalyticsSink | null = null
let loading: Promise<void> | null = null
let currentPage = '/'
let identity: UserIdentity | null = null

function send(call: Call): void {
  if (analyticsState.consent === 'denied' || !analyticsAvailable()) return
  if (sink) {
    try {
      call(sink)
    } catch (error) {
      console.warn('analytics: not sent', error)
    }
    return
  }
  // Before the answer or the download: kept in memory, never on disk.
  if (queue.length < MAX_QUEUE) queue.push(call)
}

/** Only allowed keys, strings cut short; e-mail-looking values never leave. */
export function cleanParams(params: Record<string, unknown>): EventParams {
  const clean: EventParams = {}
  for (const [key, value] of Object.entries(params)) {
    if (!ALLOWED_PARAMS.has(key)) continue
    if (typeof value === 'number' && Number.isFinite(value)) clean[key] = value
    else if (typeof value === 'string' && !value.includes('@')) clean[key] = value.slice(0, 100)
  }
  return clean
}

export function logEvent(name: string, params: Record<string, unknown> = {}): void {
  const clean = cleanParams(params)
  send((target) => target.event(name, clean))
}

async function defaultLoader(): Promise<AnalyticsSink> {
  if (import.meta.env.VITE_USE_EMULATORS === '1') {
    // E2E build: the events land on window.__analytics for the test to read.
    const spy = ((window as unknown as { __analytics?: unknown[] }).__analytics ??= [])
    return {
      event: (name, params) => spy.push({ name, params }),
      identify: (user) => spy.push({ identify: user }),
      page: (path) => spy.push({ page: path }),
      stop: () => spy.push({ stop: true }),
    }
  }
  const { loadFirebaseAnalytics } = await import('./analytics-client')
  return loadFirebaseAnalytics()
}

/**
 * Downloads the client and sends what was waiting. Only with consent and after
 * the first screen; safe to call many times.
 */
export function startAnalytics(load: () => Promise<AnalyticsSink> = defaultLoader): Promise<void> {
  if (!analyticsAvailable() || analyticsState.consent !== 'granted') return Promise.resolve()
  loading ??= load()
    .then((loaded) => {
      sink = loaded
      sink.page(currentPage)
      if (identity) sink.identify(identity)
      const waiting = queue
      queue = []
      waiting.forEach((call) => send(call))
    })
    .catch((error) => {
      // Blocked by the browser or an extension: the app goes on without it.
      console.warn('analytics: not loaded', error)
      queue = []
    })
  return loading
}

/** The answer of the notice (or of Configurações), kept in this browser. */
export function setConsent(value: 'granted' | 'denied'): void {
  writeStorage(CONSENT_KEY, value)
  analyticsState.consent = value
  if (value === 'denied') {
    queue = []
    sink?.stop()
    sink = null
    loading = null
  }
}

// ---------------------------------------------------------------------------
// The app's events (AnalyticsService), same names and parameters
// ---------------------------------------------------------------------------

/** google, apple, email, phone or unknown, from the user's providerData (AnalyticsService.getAuthMethod). */
export function authMethod(providerIds: readonly string[]): string {
  for (const id of providerIds) {
    if (id === 'google.com') return 'google'
    if (id === 'apple.com') return 'apple'
    if (id === 'password') return 'email'
    if (id === 'phone') return 'phone'
  }
  return 'unknown'
}

export const logEmailLoginOpened = () => logEvent('email_login_opened')
/** has_company goes as text, as the app ('true'/'false'). */
export const logLogin = (method: string, hasCompany = true) => logEvent('login', { method, has_company: String(hasCompany) })
export const logSignUp = (method: string) => logEvent('sign_up', { method })
export const logTutorialBegin = (variant: 'setup') => logEvent('tutorial_begin', { variant })
export const logTutorialComplete = () => logEvent('tutorial_complete')
export const logCompanyCreated = (companyId: string, segment: string | null | undefined) =>
  logEvent('company_created', { company_id: companyId, ...(segment ? { segment } : {}) })
export const logInviteAccepted = (companyId: string) => logEvent('invite_accepted', { company_id: companyId })

export type ShareMethod = 'sheet' | 'whatsapp' | 'clipboard'
/** The app's share: "sheet" (the system's share), "whatsapp" or "clipboard"; content_type "order". */
export function logShare(method: ShareMethod, contentType = 'order'): void {
  logEvent('share', { method, content_type: contentType, item_id: '' })
}
/** A payment received in one order (the amount only, as the app; never who paid). */
export const logPaymentAdded = (amount?: number) => logEvent('payment_added', amount === undefined ? {} : { amount })

/** The assistant's funnel (docs/FIREBASE_ANALYTICS.md, "AI assistant adoption"). */
export type AiEvent =
  | 'ai_intro_shown'
  | 'ai_intro_accepted'
  | 'ai_intro_dismissed'
  | 'ai_assist_requested'
  | 'ai_assist_result'
  | 'ai_assist_undone'
  | 'ai_order_saved'
  | 'ai_action_proposed'
  | 'ai_action_dismissed'
  | 'ai_action_confirmed'
  | 'ai_action_failed'
  | 'ai_action_undone'
  | 'upgrade_modal_shown'
export const logAiEvent = (name: AiEvent, params: Record<string, string | number> = {}) => logEvent(name, params)

/** ai_assist_requested's input: text, photo or photo_text. */
export function aiInput(text: string, photos: number): 'text' | 'photo' | 'photo_text' {
  if (!photos) return 'text'
  return text.trim() ? 'photo_text' : 'photo'
}

/** ai_assist_result's result, as order_screen_v2: quota, error, filled, actions or nothing. */
export function aiResult(outcome: { errorCode?: string | null; failed?: boolean; filled?: boolean; actions?: boolean }): string {
  if (outcome.errorCode === 'AI_QUOTA_EXCEEDED') return 'quota'
  if (outcome.failed) return 'error'
  if (outcome.filled) return 'filled'
  return outcome.actions ? 'actions' : 'nothing'
}

/** The app's userId, user properties and default parameters (identifyUser). */
export function identifyUser(user: UserIdentity): void {
  identity = user
  send((target) => target.identify(user))
}

export function clearUser(): void {
  identity = null
  send((target) => target.identify(null))
}

// ---------------------------------------------------------------------------
// Screens: the app's route names (TabRoutes and lib/routes.dart) where they match
// ---------------------------------------------------------------------------

const APP_SCREEN: Record<string, string> = {
  home: '/home',
  orders: '/home',
  schedule: '/agenda',
  finance: '/financial',
  customers: '/customer_list',
  devices: '/device_list',
  catalog: '/catalog',
  team: '/collaborator_list',
  checklists: '/form_template_list',
  notifications: '/notifications',
  contracts: '/contract_list',
  integrations: '/integrations',
  ratings: '/ratings',
  financeReport: '/financial_report',
}

/** The app's name for the screen; web-only screens keep their own route name. */
export function screenNameFor(routeName: string): string {
  return APP_SCREEN[routeName] ?? `/${routeName}`
}

/**
 * One screen_view per screen, as the app's tabs (firebase_screen and
 * firebase_screen_class). `path` is the route's pattern: no ids, no search.
 */
export function logScreenView(routeName: string, path: string): void {
  const name = screenNameFor(routeName)
  currentPage = path
  send((target) => {
    target.page(path)
    target.event('screen_view', { firebase_screen: name, firebase_screen_class: name })
  })
}
