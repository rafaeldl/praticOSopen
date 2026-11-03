import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Browser, type Page } from '@playwright/test'
import { PASSWORD, USERS } from './fixtures.mjs'

export type UserKey = keyof typeof USERS

// The login screen in pt, en and es: a test may set the language before the app starts (startWithPrefs).
const EMAIL_LOGIN = /^(Já tenho conta com e-mail|I already have an account with email|Ya tengo cuenta con correo)$/
const EMAIL = /^(E-mail|Email|Correo)$/
const SIGN_IN = /^(Entrar|Sign In|Iniciar Sesión)$/

export async function login(page: Page, user: UserKey, path = './') {
  await page.goto(path)
  await page.getByRole('button', { name: EMAIL_LOGIN }).click()
  await page.getByLabel(EMAIL).fill(USERS[user].email)
  await page.getByLabel(/^(Senha|Password|Contraseña)$/).fill(PASSWORD)
  await page.getByRole('button', { name: SIGN_IN }).click()
  await expect(page.getByLabel(EMAIL)).toBeHidden()
}

/**
 * "Sair" shows the login at once and then starts the page over clean
 * (signOutEverywhere: location.assign after clearing the cache). Wait for that
 * new page, or the next goto is aborted by it (ERR_ABORTED).
 */
export async function signOut(page: Page) {
  const reloaded = page.waitForEvent('load')
  // In Configurações "Sair" asks first (account.sign-out), as the app; the
  // screens outside the shell (no company, not allowed) sign out at once.
  await expect(page.getByRole('button', { name: 'Sair' }).first()).toBeVisible()
  const settings = page.getByTestId('settings-sign-out')
  if (await settings.count()) {
    await settings.click()
    await page.getByRole('dialog', { name: 'Deseja realmente sair?' }).getByRole('button', { name: 'Sair' }).click()
  } else {
    await page.getByRole('button', { name: 'Sair' }).click()
  }
  await reloaded
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
}

/** Owner works in two companies, so the first stop is the company choice. */
export async function chooseCompany(page: Page, name: string) {
  await expect(page.getByRole('heading', { level: 1, name: 'Onde você vai trabalhar agora?' })).toBeVisible()
  await page.getByRole('button', { name }).click()
}

export async function expectNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page }).analyze()
  const summary = violations.map((violation) => `${violation.id}: ${violation.nodes.map((node) => node.target).join(' | ')}`)
  expect(summary, `axe em ${label}`).toEqual([])
}

export async function setTheme(page: Page, theme: 'light' | 'dark') {
  await page.evaluate((value) => {
    localStorage.setItem('praticos.prefs', JSON.stringify({ theme: value }))
    document.documentElement.setAttribute('data-theme', value)
  }, theme)
}

/**
 * Theme and language in place before the app starts, so the test logs in
 * straight on the screen it checks: one page load. Reloading right after the
 * live Firestore client starts can leave the new page waiting for the old
 * one's lease on the browser cache (persistentMultipleTabManager), and the
 * live data (order, checklists) only arrives seconds later.
 */
export async function startWithPrefs(page: Page, prefs: { theme?: 'light' | 'dark'; language?: 'pt' | 'en' | 'es' }) {
  await page.addInitScript((value) => localStorage.setItem('praticos.prefs', JSON.stringify(value)), prefs)
}

/** `allowed`: containers that scroll sideways on purpose (the board's columns). */
export async function expectNoSideScroll(page: Page, allowed: string[] = []) {
  const overflow = await page.evaluate((skip) => {
    const roots = [document.documentElement, ...document.querySelectorAll('.main, .list-pane, .workspace, .entry-main, .od-scroll, .board-wrap')].filter(
      (element) => !skip.some((selector) => element.matches(selector)),
    )
    return roots
      .filter((element) => element.scrollWidth > element.clientWidth + 1)
      .map((element) => `${element.tagName}.${element.className}: ${element.scrollWidth} > ${element.clientWidth}`)
  }, allowed)
  expect(overflow).toEqual([])
}

/** A second person in the same test: a new browser context with the project's base URL, language and zone. */
export async function newPersonPage(browser: Browser): Promise<Page> {
  const { baseURL, locale, timezoneId } = test.info().project.use
  const context = await browser.newContext({ baseURL, locale, timezoneId })
  return context.newPage()
}
