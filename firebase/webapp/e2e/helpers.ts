import AxeBuilder from '@axe-core/playwright'
import { expect, type Page } from '@playwright/test'
import { PASSWORD, USERS } from './fixtures.mjs'

export type UserKey = keyof typeof USERS

export async function login(page: Page, user: UserKey, path = './') {
  await page.goto(path)
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await page.getByLabel('E-mail').fill(USERS[user].email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page.getByLabel('E-mail')).toBeHidden()
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
