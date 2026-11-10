// Fatia 07 (equipe, empresa, plano, conta, integrações) on every screen: axe in
// light and dark, 320 to 2560 px without side scroll, text at 200%, and the
// three languages. Only reads: the tests that write are in their own files.
import { expect, test, type Page } from './test'
import { expectNoAxeViolations, expectNoSideScroll, login, newPersonPage, setTheme, type UserKey } from './helpers'

const SCREENS: [UserKey, string, string][] = [
  ['gOwner', 'settings', 'Configurações'],
  ['gOwner', 'settings/account', 'Sua conta'],
  ['gOwner', 'settings/company', 'Sua empresa'],
  ['gOwner', 'settings/plan', 'Plano'],
  ['gOwner', 'settings/integrations', 'Integrações'],
  ['tAdmin', 'team', 'Equipe'],
]

async function settingsScreens(page: Page, label: string) {
  await page.goto('settings')
  await expect(page.getByRole('heading', { level: 1, name: 'Configurações' })).toBeVisible()
  await expectNoAxeViolations(page, `configurações ${label}`)
  await page.goto('settings/account')
  await expect(page.getByTestId('account-profile')).toBeVisible()
  await expectNoAxeViolations(page, `conta ${label}`)
  await page.getByTestId('account-profile').click()
  await expect(page.getByTestId('profile-form')).toBeVisible()
  await expectNoAxeViolations(page, `perfil ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('account-delete').click()
  await page.getByTestId('delete-continue').click()
  await expectNoAxeViolations(page, `apagar conta ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('account-code').click()
  await expectNoAxeViolations(page, `código ${label}`)
  await page.keyboard.press('Escape')

  await page.goto('settings/company')
  await expect(page.getByTestId('company-data')).toBeVisible()
  await expect(page.getByTestId('company-segment')).toBeEnabled()
  await expectNoAxeViolations(page, `empresa ${label}`)
  await page.getByTestId('company-data').click()
  await page.getByText('Mais dados (e-mail, site, país)').click()
  await expectNoAxeViolations(page, `dados da empresa ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('company-terms').click()
  await expectNoAxeViolations(page, `termos ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('company-segment').click()
  await expectNoAxeViolations(page, `ramo ${label}`)
  await page.keyboard.press('Escape')

  await page.route('**/v1/app/ai/status', (route) => route.fulfill({ status: 200, contentType: 'application/json', body: '{"success":true,"data":{"enabled":true,"usage":{"used":9,"limit":10}}}' }))
  await page.goto('settings/plan')
  await expect(page.getByTestId('plan-usage')).toBeVisible()
  await expectNoAxeViolations(page, `plano ${label}`)

  await page.goto('settings/integrations')
  await expect(page.getByTestId('asaas-section')).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
  await expectNoAxeViolations(page, `integrações ${label}`)
  await page.getByTestId('mcp-new').click()
  await expectNoAxeViolations(page, `nova conexão ${label}`)
}

async function teamScreens(page: Page, label: string) {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto('team')
  await expect(page.getByTestId('permission-table')).toBeVisible()
  await expectNoAxeViolations(page, `equipe ${label}`)
  await page.getByTestId('team-invite').click()
  await expect(page.getByTestId('invite-form')).toBeVisible()
  await expectNoAxeViolations(page, `convidar ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('team-invites').locator('li').first().getByRole('button').click()
  await expectNoAxeViolations(page, `convite ${label}`)
  await page.keyboard.press('Escape')
  await page.locator('[data-member="e2e-t-super"]').getByRole('button').click()
  await expect(page.getByTestId('member-dialog')).toBeVisible()
  await expectNoAxeViolations(page, `pessoa ${label}`)
}

for (const theme of ['light', 'dark'] as const) {
  const name = theme === 'light' ? 'claro' : 'escuro'
  test(`axe: 0 violações em configurações, conta, empresa, plano e integrações, tema ${name}`, async ({ page }) => {
    test.setTimeout(60_000)
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'gOwner', 'login')
    await setTheme(page, theme)
    await settingsScreens(page, name)
  })
  test(`axe: 0 violações na equipe, tema ${name}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'tAdmin', 'login')
    await setTheme(page, theme)
    await teamScreens(page, name)
  })
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral em configurações, conta, empresa, plano, integrações e equipe`, async ({ page, browser }) => {
    test.setTimeout(60_000)
    await page.setViewportSize({ width, height })
    await login(page, 'gOwner', 'login')
    for (const [user, path, title] of SCREENS) {
      const target = user === 'gOwner' ? page : await newPersonPage(browser)
      if (target !== page) {
        await target.setViewportSize({ width, height })
        await login(target, user, 'login')
      }
      await target.goto(path)
      await expect(target.getByRole('heading', { level: 1, name: title })).toBeVisible()
      await expect(target.getByText('Carregando…')).toHaveCount(0)
      await expectNoSideScroll(target)
      if (target !== page) await target.context().close()
    }
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px nas telas de configurações`, async ({ page }) => {
    test.setTimeout(60_000)
    await page.setViewportSize({ width, height })
    await login(page, 'gOwner', 'login')
    for (const [, path, title] of SCREENS.filter(([user]) => user === 'gOwner')) {
      await page.goto(path)
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
      await expect(page.getByText('Carregando…')).toHaveCount(0)
      await expectNoSideScroll(page)
    }
    await page.goto('settings/company')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await page.getByTestId('company-data').click()
    const drawer = page.locator('.layer--drawer .layer-box')
    await expect(drawer).toBeVisible()
    expect(await drawer.evaluate((box) => box.scrollWidth - box.clientWidth)).toBeLessThanOrEqual(1)
  })
}

for (const [language, settings, account, company, plan, team, invite] of [
  ['en', 'Settings', 'Your account', 'Your company', 'Plan', 'Team', 'Invite someone'],
  ['es', 'Configuración', 'Tu cuenta', 'Tu empresa', 'Plan', 'Equipo', 'Invitar persona'],
] as const) {
  test(`idioma ${language}: textos de configurações, conta, empresa, plano e equipe`, async ({ page }) => {
    await login(page, 'tAdmin', 'settings')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: settings })).toBeVisible()
    for (const [path, title] of [
      ['settings/account', account],
      ['settings/company', company],
      ['settings/plan', plan],
      ['team', team],
    ] as const) {
      await page.goto(path)
      await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    }
    await page.getByTestId('team-invite').click()
    await expect(page.getByRole('heading', { level: 2, name: invite })).toBeVisible()
  })
}
