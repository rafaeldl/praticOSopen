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

// Texts only the order screens use, in their own chunk (scripts/gen.mjs).
const ORDER_LOADERS: Record<Locale, () => Promise<{ default: unknown }>> = {
  pt: () => import('@/generated/i18n/pt-orders.json'),
  en: () => import('@/generated/i18n/en-orders.json'),
  es: () => import('@/generated/i18n/es-orders.json'),
}

export const locale = ref<Locale>('pt')
const catalog = ref<Catalog>({})
let withOrders = false

export function t(key: MessageKey, params: Params = {}): string {
  const message = catalog.value[key]
  return message === undefined ? '' : render(message, params, locale.value)
}

export async function setLocale(next: Locale): Promise<void> {
  const [loaded, extra] = await Promise.all([LOADERS[next](), withOrders ? ORDER_LOADERS[next]() : null])
  catalog.value = { ...(loaded.default as Catalog), ...((extra?.default as Catalog) ?? {}) }
  locale.value = next
  document.documentElement.lang = HTML_LANG[next]
}

/** Before an order screen renders: its texts join the catalog (and follow language changes). */
export async function loadOrderTexts(): Promise<void> {
  if (withOrders) return
  const extra = await ORDER_LOADERS[locale.value]()
  withOrders = true
  catalog.value = { ...catalog.value, ...(extra.default as Catalog) }
}

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
