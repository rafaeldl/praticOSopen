// Messages come compiled from src/generated/i18n/{locale}.json, one chunk per
// language. Compiling ICU at build time keeps a parser out of the bundle.
import { ref, watchEffect } from 'vue'
import type { MessageKey } from '@/generated/message-keys'
import { prefs } from '@/lib/prefs'

export type { MessageKey }
export type Locale = 'pt' | 'en' | 'es'
export type Params = Record<string, string | number>

type Part = string | [kind: '#'] | [kind: 'a', name: string] | [kind: 'p' | 's', name: string, branches: Record<string, Part[]>]
export type Compiled = string | Part[]
export type Catalog = Record<string, Compiled>

const LOADERS: Record<Locale, () => Promise<{ default: unknown }>> = {
  pt: () => import('@/generated/i18n/pt.json'),
  en: () => import('@/generated/i18n/en.json'),
  es: () => import('@/generated/i18n/es.json'),
}
const HTML_LANG: Record<Locale, string> = { pt: 'pt-BR', en: 'en', es: 'es' }

export function detectLocale(languages: readonly string[]): Locale {
  for (const language of languages) {
    const code = language.toLowerCase().split('-')[0]
    if (code === 'pt' || code === 'en' || code === 'es') return code
  }
  return 'pt'
}

export function render(message: Compiled, params: Params, locale: string): string {
  if (typeof message === 'string') return message
  const rules = new Intl.PluralRules(locale)
  const walk = (parts: Part[], count?: number): string =>
    parts
      .map((part) => {
        if (typeof part === 'string') return part
        const [kind, name, branches] = part
        if (kind === '#') return String(count ?? '')
        const value = params[name as string]
        if (kind === 'a') return value === undefined ? '' : String(value)
        const options = branches as Record<string, Part[]>
        if (kind === 's') return walk(options[String(value)] ?? options.other ?? [])
        const number = Number(value)
        return walk(options[`=${number}`] ?? options[rules.select(number)] ?? options.other ?? [], number)
      })
      .join('')
  return walk(message)
}

// Texts only one feature uses, in their own chunks (scripts/gen.mjs FEATURES).
export type Feature = 'orders' | 'customers' | 'agenda' | 'finance' | 'settings'
const FEATURE_LOADERS: Record<Feature, Record<Locale, () => Promise<{ default: unknown }>>> = {
  orders: {
    pt: () => import('@/generated/i18n/pt-orders.json'),
    en: () => import('@/generated/i18n/en-orders.json'),
    es: () => import('@/generated/i18n/es-orders.json'),
  },
  customers: {
    pt: () => import('@/generated/i18n/pt-customers.json'),
    en: () => import('@/generated/i18n/en-customers.json'),
    es: () => import('@/generated/i18n/es-customers.json'),
  },
  agenda: {
    pt: () => import('@/generated/i18n/pt-agenda.json'),
    en: () => import('@/generated/i18n/en-agenda.json'),
    es: () => import('@/generated/i18n/es-agenda.json'),
  },
  finance: {
    pt: () => import('@/generated/i18n/pt-finance.json'),
    en: () => import('@/generated/i18n/en-finance.json'),
    es: () => import('@/generated/i18n/es-finance.json'),
  },
  settings: {
    pt: () => import('@/generated/i18n/pt-settings.json'),
    en: () => import('@/generated/i18n/en-settings.json'),
    es: () => import('@/generated/i18n/es-settings.json'),
  },
}

export const locale = ref<Locale>('pt')
const catalog = ref<Catalog>({})
const loaded = new Set<Feature>()

export function t(key: MessageKey, params: Params = {}): string {
  const message = catalog.value[key]
  return message === undefined ? '' : render(message, params, locale.value)
}

export async function setLocale(next: Locale): Promise<void> {
  const features = [...loaded]
  const [main, ...extra] = await Promise.all([LOADERS[next](), ...features.map((name) => FEATURE_LOADERS[name][next]())])
  catalog.value = Object.assign({}, main.default as Catalog, ...extra.map((part) => part.default as Catalog))
  locale.value = next
  document.documentElement.lang = HTML_LANG[next]
}

/** Before a feature's screen renders: its texts join the catalog (and follow language changes). */
export async function loadTexts(feature: Feature): Promise<void> {
  if (loaded.has(feature)) return
  const extra = await FEATURE_LOADERS[feature][locale.value]()
  loaded.add(feature)
  catalog.value = { ...catalog.value, ...(extra.default as Catalog) }
}

export const loadOrderTexts = (): Promise<void> => loadTexts('orders')

function wantedLocale(): Locale {
  return prefs.language === 'system' ? detectLocale(navigator.languages ?? [navigator.language]) : prefs.language
}

/** Loads the first language, then follows the preference. */
export async function startI18n(): Promise<void> {
  await setLocale(wantedLocale())
  watchEffect(() => {
    const next = wantedLocale()
    if (next !== locale.value) void setLocale(next)
  })
}
