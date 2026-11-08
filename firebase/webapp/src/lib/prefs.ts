// Per-person preferences kept in this browser.
import { reactive, ref, watch } from 'vue'
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

const systemDark = ref(false)

/** Whether the screen is dark now: the person's choice, or the system's. */
export const isDark = () => prefs.theme === 'dark' || (prefs.theme === 'system' && systemDark.value)

/** The quick switch of the sidebar: the other of what is on screen, kept as the person's choice. */
export function toggleTheme(): void {
  prefs.theme = isDark() ? 'light' : 'dark'
}

function applyTheme(): void {
  systemDark.value = matchMedia('(prefers-color-scheme: dark)').matches
  document.documentElement.setAttribute('data-theme', isDark() ? 'dark' : 'light')
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
