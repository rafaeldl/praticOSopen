// Fatia 07, equipe: list, invites and role changes through the API, against the
// Emulator Suite. Everything happens in the team company (fixtures COMPANY_T),
// in order: the tests share its people and invites.
import { expect, test, type Page } from '@playwright/test'
import { COMPANY_T, TEAM_INVITES, USERS } from './fixtures.mjs'
import { login } from './helpers'
import { invitesOf, readPath } from './settings-data'

test.describe.configure({ mode: 'serial' })

const members = (page: Page) => page.getByTestId('team-members')
const invites = (page: Page) => page.getByTestId('team-invites')
const share = (page: Page) => page.getByTestId('invite-share')

async function openTeam(page: Page, user: 'tAdmin' | 'tOwner' = 'tAdmin') {
  await login(page, user, 'team')
  await expect(page.getByRole('heading', { level: 1, name: 'Equipe' })).toBeVisible()
  await expect(members(page)).toBeVisible()
}

test('Equipe: resumo, convite esperando com os dias, vencido à mostra e você primeiro, sem abrir (team.list.load, team.view.list, team.member.self-row, team.invite-share.copy, team.invite-share.share)', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write'])
  await openTeam(page)
  await expect(page.getByTestId('team-summary')).toHaveText('5 pessoas e 2 convites')
  // The seats count shows; the plan limit never blocks in the browser (the app's rule, M1 of the #528 review).
  await expect(page.getByTestId('team-seats')).toHaveText('Pessoas na equipe: 6 de 1')
  await expect(page.getByTestId('team-waiting-block')).toContainText('Paula Pendente ainda não entrou. O convite vence em 5 dias.')
  await expect(invites(page).locator(`[data-invite="${TEAM_INVITES.waiting.token}"]`)).toContainText('Convite enviado · vence em 5 dias')
  await expect(invites(page).locator(`[data-invite="${TEAM_INVITES.expired.token}"]`)).toContainText('Convite enviado · venceu')
  const rows = members(page).locator('li')
  await expect(rows.first()).toContainText('Tadeu Admin (você)')
  // You and the owner never open; the others do.
  await expect(rows.first().getByRole('button')).toHaveCount(0)
  await expect(members(page).locator(`[data-member="${USERS.tOwner.uid}"]`)).toContainText('Proprietário')
  await expect(members(page).locator(`[data-member="${USERS.tOwner.uid}"]`).getByRole('button')).toHaveCount(0)
  await expect(page.locator('[data-member="e2e-t-tech1"]').getByRole('button')).toBeVisible()

  // Reenviar: the code, how long it lasts (from the server), copy and WhatsApp.
  await page.getByTestId('team-resend').click()
  await expect(share(page).getByTestId('invite-code')).toHaveText(TEAM_INVITES.waiting.token)
  await expect(share(page)).toContainText('Vale por 7 dias')
  await share(page).getByTestId('invite-copy').click()
  await expect(page.locator('.toast')).toContainText('Código do convite copiado!')
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(TEAM_INVITES.waiting.token)
  const whatsapp = await share(page).getByTestId('invite-whatsapp').getAttribute('href')
  expect(whatsapp).toMatch(/^https:\/\/wa\.me\/\?text=/)
  expect(decodeURIComponent(whatsapp!)).toContain(TEAM_INVITES.waiting.token)
})

test('Compartilhar convite: a folha do navegador com a mensagem e o código, quando ele tem (team.invite-share.share)', async ({ page }) => {
  await page.addInitScript(() => {
    const w = window as unknown as { __shared: ShareData[] }
    w.__shared = []
    Object.defineProperty(Navigator.prototype, 'share', { configurable: true, value: async (data: ShareData) => void w.__shared.push({ text: data.text }) })
  })
  await openTeam(page)
  await page.getByTestId('team-resend').click()
  await share(page).getByTestId('invite-sheet').click()
  await expect.poll(() => page.evaluate(() => (window as unknown as { __shared: ShareData[] }).__shared.length)).toBe(1)
  const text = await page.evaluate(() => (window as unknown as { __shared: ShareData[] }).__shared[0]?.text)
  expect(text).toContain(TEAM_INVITES.waiting.token)
})

test('Convite sem a folha do navegador: copiar e WhatsApp, sem Compartilhar (team.invite-share.share)', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(Navigator.prototype, 'share', { configurable: true, value: undefined }))
  await openTeam(page)
  await page.getByTestId('team-resend').click()
  await expect(share(page).getByTestId('invite-copy')).toBeVisible()
  await expect(share(page).getByTestId('invite-whatsapp')).toBeVisible()
  await expect(share(page).getByTestId('invite-sheet')).toHaveCount(0)
})

test('Convidar: confere e-mail e WhatsApp, cria pela API e a vaga é contada no servidor (team.invite.new, team.form.invite, team.invite-form.fields, team.invite-form.role, team.counter.seats, team.invite-share.whatsapp)', async ({ page }) => {
  await openTeam(page)
  await page.getByTestId('team-invite').click()
  const form = page.getByTestId('invite-form')
  await expect(form.getByTestId('invite-role-note')).toHaveText(/Executa serviços/)
  await form.getByTestId('send-invite').click()
  await expect(form.locator('.hint')).toHaveText('Escreva o e-mail ou o WhatsApp para salvar.')
  await form.getByLabel('E-mail').fill('joao@')
  await form.getByLabel('WhatsApp (opcional)').fill('123')
  await form.getByTestId('send-invite').click()
  await expect(form.locator('.field-error', { hasText: 'Email inválido' })).toBeVisible()
  await expect(form.locator('.field-error', { hasText: 'Telefone inválido' })).toBeVisible()
  await form.getByLabel('Nome (opcional)').fill('João Novo')
  await form.getByLabel('E-mail').fill('Joao.Novo@Praticos.test')
  // Masked by the company country (B5 of the #528 review).
  await form.getByLabel('WhatsApp (opcional)').fill('11977776666')
  await expect(form.getByLabel('WhatsApp (opcional)')).toHaveValue('(11) 97777-6666')
  await form.getByRole('radio', { name: /Supervisor/ }).check()
  await expect(form.getByTestId('invite-role-note')).toHaveText(/Coordena equipes/)
  await form.getByTestId('send-invite').click()

  await expect(share(page)).toContainText('Vale por 7 dias')
  const code = (await share(page).getByTestId('invite-code').textContent())!.trim()
  expect(code).toMatch(/^INV_/)
  const whatsapp = await share(page).getByTestId('invite-whatsapp').getAttribute('href')
  expect(whatsapp).toMatch(/^https:\/\/wa\.me\/5511977776666\?text=/)
  const saved = (await invitesOf(COMPANY_T)).find((invite) => invite.token === code)
  expect(saved).toMatchObject({ name: 'João Novo', email: 'joao.novo@praticos.test', phone: '11977776666', role: 'supervisor', status: 'pending' })
  // Members plus invites that still work (the expired one does not count), recounted by the server.
  await expect.poll(async () => ((await readPath(`companies/${COMPANY_T}`))?.subscription as { usage?: { usersActive?: number } })?.usage?.usersActive, { timeout: 20_000 }).toBe(7)
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('team-summary')).toHaveText('5 pessoas e 3 convites')
})

test('Convite repetido: reenviar o que existe ou trocar, criando o novo antes de cancelar o velho (team.form.duplicate)', async ({ page }) => {
  await openTeam(page)
  await page.getByTestId('team-invite').click()
  await page.getByTestId('invite-form').getByLabel('E-mail').fill('PAULA@praticos.test')
  await page.getByTestId('send-invite').click()
  await expect(page.getByRole('dialog', { name: 'Convite Existente' })).toBeVisible()
  await page.getByTestId('duplicate-resend').click()
  await expect(share(page).getByTestId('invite-code')).toHaveText(TEAM_INVITES.waiting.token)
  await page.keyboard.press('Escape')

  await page.getByTestId('team-invite').click()
  await page.getByTestId('invite-form').getByLabel('E-mail').fill('paula@praticos.test')
  await page.getByTestId('send-invite').click()
  await page.getByTestId('duplicate-replace').click()
  const code = (await share(page).getByTestId('invite-code').textContent())!.trim()
  expect(code).not.toBe(TEAM_INVITES.waiting.token)
  const all = await invitesOf(COMPANY_T)
  expect(all.find((invite) => invite.token === TEAM_INVITES.waiting.token)?.status).toBe('cancelled')
  expect(all.find((invite) => invite.token === code)).toMatchObject({ email: 'paula@praticos.test', status: 'pending' })
})

test('Convite vencido: "Convidar de novo" cria o novo e só depois cancela o velho (team.invite.expired, team.invite.reinvite)', async ({ page }) => {
  await openTeam(page)
  await invites(page).locator(`[data-invite="${TEAM_INVITES.expired.token}"]`).getByRole('button').click()
  const dialog = page.getByRole('dialog', { name: 'O convite de Pedro Vencido venceu' })
  await expect(dialog).toContainText('O código não funciona mais.')
  await dialog.getByTestId('expired-again').click()
  const form = page.getByTestId('invite-form')
  await expect(form.getByLabel('Nome (opcional)')).toHaveValue('Pedro Vencido')
  await expect(form.getByLabel('WhatsApp (opcional)')).toHaveValue('(11) 98888-7777')
  await form.getByTestId('send-invite').click()
  const code = (await share(page).getByTestId('invite-code').textContent())!.trim()
  const all = await invitesOf(COMPANY_T)
  expect(all.find((invite) => invite.token === code)).toMatchObject({ name: 'Pedro Vencido', phone: '11988887777', role: 'technician', status: 'pending' })
  expect(all.find((invite) => invite.token === TEAM_INVITES.expired.token)?.status).toBe('cancelled')
})

test('Cancelar convite pede confirmação (team.invite.cancel, team.invite-share.cancel)', async ({ page }) => {
  await openTeam(page)
  const joao = (await invitesOf(COMPANY_T)).find((invite) => invite.email === 'joao.novo@praticos.test' && invite.status === 'pending')!
  await invites(page).locator(`[data-invite="${joao.token}"]`).getByRole('button').click()
  await page.getByTestId('invite-cancel').click()
  const confirm = page.getByRole('dialog', { name: 'Cancelar o convite de João Novo?' })
  await confirm.getByRole('button', { name: 'Manter convite' }).click()
  expect((await invitesOf(COMPANY_T)).find((invite) => invite.token === joao.token)?.status).toBe('pending')
  await page.getByTestId('invite-cancel').click()
  await page.getByRole('dialog', { name: 'Cancelar o convite de João Novo?' }).getByRole('button', { name: 'Cancelar convite' }).click()
  await expect(page.locator('.toast')).toContainText('Convite cancelado')
  await expect(invites(page).locator(`[data-invite="${joao.token}"]`)).toHaveCount(0)
  expect((await invitesOf(COMPANY_T)).find((invite) => invite.token === joao.token)?.status).toBe('cancelled')
})

test('Mudar o papel pede confirmação e vai pela API; desistir não muda nada (team.member.role)', async ({ page }) => {
  await openTeam(page, 'tOwner')
  await page.locator('[data-member="e2e-t-tech1"]').getByRole('button').click()
  const dialog = page.getByTestId('member-dialog')
  await expect(dialog.getByRole('radio', { name: /Técnico/ })).toBeChecked()
  await expect(page.getByTestId('member-save')).toBeDisabled()
  await dialog.getByRole('radio', { name: /Gerente/ }).check()
  await page.getByTestId('member-save').click()
  await page.getByRole('dialog', { name: 'Tomas Tecnico passa a ser Gerente?' }).getByRole('button', { name: 'Cancelar' }).click()
  expect((await readPath(`companies/${COMPANY_T}/memberships/${USERS.tTech1.uid}`))?.role).toBe('technician')

  await dialog.getByRole('radio', { name: /Supervisor/ }).check()
  await page.getByTestId('member-save').click()
  await page.getByRole('dialog', { name: 'Tomas Tecnico passa a ser Supervisor?' }).getByRole('button', { name: 'Mudar o papel' }).click()
  await expect(page.locator('.toast')).toContainText('Papel trocado')
  await expect(members(page).locator(`[data-member="${USERS.tTech1.uid}"]`)).toContainText('Supervisor · coordena a equipe, não vê preços')
  expect((await readPath(`companies/${COMPANY_T}/memberships/${USERS.tTech1.uid}`))?.role).toBe('supervisor')
  expect((await readPath(`companies/${COMPANY_T}/private/membership`))?.members).toMatchObject({ [USERS.tTech1.uid]: 'supervisor' })
})

test('O servidor guarda o último administrador: a recusa aparece com frase própria (team.member.role)', async ({ page }) => {
  await openTeam(page)
  await page.route('**/v1/app/team/members/**', (route) =>
    route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'LAST_ADMIN', message: 'x' } }) }),
  )
  await page.locator('[data-member="e2e-t-super"]').getByRole('button').click()
  await page.getByTestId('member-dialog').getByRole('radio', { name: /Consultor/ }).check()
  await page.getByTestId('member-save').click()
  await page.getByRole('dialog', { name: 'Teo Supervisor passa a ser Consultor?' }).getByRole('button', { name: 'Mudar o papel' }).click()
  await expect(page.getByTestId('member-error')).toHaveText(/Não é possível alterar o perfil do único administrador/)
  expect((await readPath(`companies/${COMPANY_T}/memberships/${USERS.tSuper.uid}`))?.role).toBe('supervisor')
})

test('Tirar da equipe pede confirmação e vai pela API (team.member.remove)', async ({ page }) => {
  await openTeam(page)
  await page.locator('[data-member="e2e-t-tech2"]').getByRole('button').click()
  await page.getByTestId('member-remove').click()
  const confirm = page.getByRole('dialog', { name: 'Tirar Tania Tecnica da equipe?' })
  await expect(confirm).toContainText('A pessoa perde o acesso às OS.')
  await confirm.getByRole('button', { name: 'Tirar da equipe' }).click()
  await expect(page.locator('.toast')).toContainText('Tania Tecnica saiu da equipe')
  await expect(members(page).locator(`[data-member="${USERS.tTech2.uid}"]`)).toHaveCount(0)
  expect(await readPath(`companies/${COMPANY_T}/memberships/${USERS.tTech2.uid}`)).toBeUndefined()
})

test('Tela grande: o que cada papel pode fazer, lido do contrato de permissões', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await openTeam(page)
  const table = page.getByTestId('permission-table')
  await expect(table.getByRole('columnheader', { name: 'Técnico' })).toBeVisible()
  const prices = table.getByRole('row', { name: /Ver preços e totais/ })
  await expect(prices.getByRole('cell')).toHaveText(['Pode✓', 'Não pode–', 'Pode✓', 'Pode✓', 'Não pode–'].map((text) => new RegExp(text.replace(/[✓–]/, ''))))
  await page.setViewportSize({ width: 800, height: 900 })
  await expect(table).toBeHidden()
})

test('Quem não é dono nem admin não abre a Equipe (team.list.load)', async ({ page }) => {
  await login(page, 'tSuper', 'team')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
  await page.goto('settings')
  await expect(page.getByTestId('settings-team')).toHaveCount(0)
  await expect(page.getByTestId('settings-plan')).toBeVisible()
})
