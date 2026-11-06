// Per-person preferences kept in this browser.
import { reactive, watch } from 'vue'
import { readStorage, writeStorage } from './storage'

export type ThemePref = 'system' | 'light' | 'dark'
export type LanguagePref = 'system' | 'pt' | 'en' | 'es'

export interface Prefs {
  theme: ThemePref
  language: LanguagePref
  /** WCAG 2.1.4: single-letter shortcuts can be turned off. */
  singleKeyShortcuts: boolean
  /**
   * Values of the order screens shown as "R$ •••" (the eye, like bank apps).
   * Per browser, not per person: the shop's TV stays hidden while the office
   * computer shows them. Only on screen: the values still reach the browser.
   */
  hideValues: boolean
}

const KEY = 'praticos.prefs'
const DEFAULTS: Prefs = { theme: 'system', language: 'system', singleKeyShortcuts: true, hideValues: false }

function read(): Prefs {
  try {
    return { ...DEFAULTS, ...(JSON.parse(readStorage(KEY) ?? '{}') as Partial<Prefs>) }
  } catch {
    return { ...DEFAULTS }
  }
}

export const prefs = reactive<Prefs>(read())

function applyTheme(): void {
  const dark = prefs.theme === 'dark' || (prefs.theme === 'system' && matchMedia('(prefers-color-scheme: dark)').matches)
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light')
}

export function startPrefs(): void {
  watch(
    prefs,
    () => {
      writeStorage(KEY, JSON.stringify(prefs))
      applyTheme()
    },
    { immediate: true },
  )
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyTheme)
}
