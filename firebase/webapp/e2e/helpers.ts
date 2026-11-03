import AxeBuilder from '@axe-core/playwright'
import { expect, type Page } from '@playwright/test'
import { PASSWORD, USERS } from './fixtures.mjs'

export type UserKey = keyof typeof USERS

export async function login(page: Page, user: UserKey, path = './') {
  await page.goto(path)
  await page.getByLabel('E-mail').fill(USERS[user].email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByLabel('E-mail')).toBeHidden()
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

export async function expectNoSideScroll(page: Page) {
  const overflow = await page.evaluate(() => {
    const roots = [document.documentElement, ...document.querySelectorAll('.main, .list-pane, .workspace, .entry-main')]
    return roots
      .filter((element) => element.scrollWidth > element.clientWidth + 1)
      .map((element) => `${element.tagName}.${element.className}: ${element.scrollWidth} > ${element.clientWidth}`)
  })
  expect(overflow).toEqual([])
}
