// Quick light/dark switch in the sidebar (docs/WEB_APP_DESIGN.md).
import { afterEach, describe, expect, test, vi } from 'vitest'
import { nextTick } from 'vue'

let systemDark = false
vi.stubGlobal('matchMedia', () => ({ matches: systemDark, addEventListener: () => {} }))

const { isDark, prefs, startPrefs, toggleTheme } = await import('../src/lib/prefs')
startPrefs()

afterEach(() => {
  prefs.theme = 'system'
  systemDark = false
})

describe('toggleTheme', () => {
  test('from the system light, it goes dark and stays as the choice', async () => {
    toggleTheme()
    await nextTick()
    expect(prefs.theme).toBe('dark')
    expect(isDark()).toBe(true)
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
  })

  test('from dark, it goes light', async () => {
    prefs.theme = 'dark'
    toggleTheme()
    await nextTick()
    expect(prefs.theme).toBe('light')
    expect(document.documentElement.getAttribute('data-theme')).toBe('light')
  })

  test('with the system dark, the switch picks light', async () => {
    systemDark = true
    prefs.theme = 'light'
    await nextTick()
    prefs.theme = 'system'
    await nextTick()
    expect(isDark()).toBe(true)
    toggleTheme()
    expect(prefs.theme).toBe('light')
  })
})
