import { expect, test } from '@playwright/test'
import { login } from './helpers'

test.describe('Voltar do navegador (REVISAO-UX P0 4)', () => {
  test('fecha o diálogo e fica na mesma tela', async ({ page }) => {
    await login(page, 'admin', 'dev/components')
    await page.getByRole('button', { name: 'Diálogo' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.goBack()
    await expect(page.getByRole('dialog')).toHaveCount(0)
    await expect(page).toHaveURL(/\/dev\/components$/)
  })

  test('fecha o painel da OS, e a lista continua', async ({ page }) => {
    await login(page, 'admin', 'orders')
    await page.getByTestId('orders-table').getByRole('button').first().click()
    await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
    await expect(page).toHaveURL(/order=/)
    await page.goBack()
    await expect(page.getByRole('complementary', { name: 'OS aberta' })).toHaveCount(0)
    await expect(page.getByTestId('orders-table')).toBeVisible()
    await expect(page).toHaveURL(/\/orders$/)
  })

  test('link direto para a OS: Voltar fecha o painel antes de sair do app', async ({ page }) => {
    await login(page, 'admin', 'orders')
    await expect(page.getByTestId('orders-table')).toBeVisible()
    await page.goto('orders?order=order-1')
    await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
    await page.goBack()
    await expect(page.getByRole('complementary', { name: 'OS aberta' })).toHaveCount(0)
    await expect(page).toHaveURL(/\/orders$/)
  })

  test('com texto digitado, pergunta antes de fechar', async ({ page }) => {
    await login(page, 'admin', 'dev/components')
    await page.getByRole('button', { name: 'Painel lateral' }).click()
    await page.getByLabel('Observações').fill('rascunho')
    page.once('dialog', (dialog) => dialog.dismiss())
    await page.goBack()
    await expect(page.getByRole('dialog', { name: 'Painel lateral' })).toBeVisible()
    await expect(page.getByLabel('Observações')).toHaveValue('rascunho')
    page.once('dialog', (dialog) => dialog.accept())
    await page.keyboard.press('Escape')
    await expect(page.getByRole('dialog')).toHaveCount(0)
  })

  test('recarregar com a camada aberta volta limpo', async ({ page }) => {
    await login(page, 'admin', 'dev/components')
    await page.getByRole('button', { name: 'Diálogo' }).click()
    await expect(page).toHaveURL(/layer=/)
    await page.reload()
    await expect(page).toHaveURL(/\/dev\/components$/)
    await expect(page.getByRole('dialog')).toHaveCount(0)
  })
})

test('foco fica preso na camada e volta para quem abriu', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  const opener = page.getByRole('button', { name: 'Diálogo' })
  await opener.focus()
  await page.keyboard.press('Enter')
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByRole('button', { name: 'Confirmar' })).toBeFocused()
  for (let i = 0; i < 5; i++) {
    await page.keyboard.press('Tab')
    expect(await page.evaluate(() => !!document.activeElement?.closest('[role=dialog]'))).toBe(true)
  }
  await page.keyboard.press('Escape')
  await expect(dialog).toHaveCount(0)
  await expect(opener).toBeFocused()
})

test.describe('MoneyInput (REVISAO-UX P0 1)', () => {
  test('clicar no meio e digitar substitui, sem somar nem mexer nos centavos', async ({ page }) => {
    await login(page, 'admin', 'dev/components')
    const price = page.getByLabel('Preço')
    await expect(price).toHaveValue('90,00')
    await price.click({ position: { x: 150, y: 10 } })
    await page.keyboard.type('100')
    await page.keyboard.press('Tab')
    await expect(page.getByTestId('money-value')).toHaveText('100')
    await expect(price).toHaveValue('100,00')
  })

  test('Tab entra selecionando tudo', async ({ page }) => {
    await login(page, 'admin', 'dev/components')
    await page.getByLabel('Preço').focus()
    await page.keyboard.type('150')
    await page.keyboard.press('Enter')
    await expect(page.getByTestId('money-value')).toHaveText('150')
  })
})

test('Combobox pelo teclado: lista ao focar, setas, Enter, Esc', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  const combo = page.getByRole('combobox', { name: 'Escolher' })
  await combo.focus()
  await expect(page.getByRole('option')).toHaveCount(4)
  await combo.fill('cha')
  await expect(page.getByRole('option')).toHaveCount(1)
  await page.keyboard.press('Enter')
  await expect(page.getByTestId('combo-value')).toHaveText('charlie')
})

test('Toast com Desfazer fica até a pessoa agir', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await page.getByRole('button', { name: 'Mostrar aviso' }).click()
  await expect(page.getByTestId('money-value')).toHaveText('0')
  await page.waitForTimeout(7000)
  await page.getByRole('button', { name: 'Desfazer' }).click()
  await expect(page.getByTestId('money-value')).toHaveText('90')
  await expect(page.locator('.toast')).toHaveCount(0)
})

test('DateField mostra a data pelo país da empresa', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await expect(page.getByText('2 de novembro de 2026')).toBeVisible()
  await page.getByLabel('Data').fill('2026-01-09')
  await expect(page.getByText('9 de janeiro de 2026')).toBeVisible()
})

test('fundo inerte com camada aberta, também com camada sobre camada', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await page.getByRole('button', { name: 'Painel lateral' }).click()
  await expect(page.locator('#app')).toHaveAttribute('inert', '')
  await page.getByRole('dialog', { name: 'Painel lateral' }).getByRole('button', { name: 'Diálogo' }).click()
  await expect(page.locator('.layer--drawer')).toHaveAttribute('inert', '')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog', { name: 'Diálogo' })).toHaveCount(0)
  await expect(page.locator('.layer--drawer')).not.toHaveAttribute('inert', '')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.locator('#app')).not.toHaveAttribute('inert', '')
})

test('Cancelar com texto digitado também pergunta', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await page.getByRole('button', { name: 'Painel lateral' }).click()
  await page.getByLabel('Observações').fill('rascunho')
  const drawer = page.getByRole('dialog', { name: 'Painel lateral' })
  page.once('dialog', (dialog) => dialog.dismiss())
  await drawer.getByRole('button', { name: 'Cancelar' }).click()
  await expect(drawer).toBeVisible()
  page.once('dialog', (dialog) => dialog.accept())
  await drawer.getByRole('button', { name: 'Cancelar' }).click()
  await expect(page.getByRole('dialog')).toHaveCount(0)
})

test('painel aberto por link de outra tela: fechar fica na lista', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await page.getByRole('link', { name: 'Abrir a OS 1 na lista' }).click()
  await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
  await page.getByRole('complementary', { name: 'OS aberta' }).getByRole('button', { name: 'Fechar' }).click()
  await expect(page).toHaveURL(/\/orders$/)
  await expect(page.getByTestId('orders-table')).toBeVisible()
})

test('lista do disco sem resposta do servidor avisa que pode estar desatualizada', async ({ page }) => {
  await login(page, 'admin', 'orders')
  await expect(page.getByTestId('orders-table').locator('tbody tr')).toHaveCount(30)
  // The next pages fill the saved copy; then the database goes away.
  await expect(page.locator('.page-sub')).toHaveText('30 OS')
  await page.route(/127\.0\.0\.1:18080/, (route) => route.abort())
  await page.reload()
  await expect(page.getByTestId('orders-table')).toBeVisible()
  const warning = page.getByRole('alert').filter({ hasText: 'podem estar desatualizados' })
  await expect(warning).toBeVisible({ timeout: 20_000 })
  await page.unroute(/127\.0\.0\.1:18080/)
  await warning.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(warning).toHaveCount(0, { timeout: 20_000 })
})
