// Fatia 07, checklists (checklist.*, order.checklist.*), against the Emulator
// Suite. Templates in /companies/{cid}/forms, answers in the order's `forms`,
// photos in tenants/{cid}/orders/{oid}/forms/{fid}/. Each test makes the
// templates and orders it changes; the seed has "Vistoria de entrada" copied
// from the segment, "Teste final" and "Pronto para copiar" still ready.
import { expect, test, type Page } from '@playwright/test'
import { makeOrder, makeOrderForm, makeTemplate, readOrder, readOrderForms, readTemplate, templatesNamed, updateTemplateDoc, writeOrderFormRaw } from './data'
import { chooseCompany, login, signOut, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const editor = (page: Page) => page.getByTestId('template-editor')
const fill = (page: Page) => page.getByTestId('form-fill')
const forms = (page: Page) => panel(page).getByTestId('order-forms')
// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')

async function openChecklists(page: Page, user: UserKey) {
  await login(page, user, 'checklists')
  await expect(page.getByRole('heading', { level: 1, name: 'Checklists' })).toBeVisible()
  await expect(page.getByTestId('checklists-list')).toBeVisible()
}

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

/** Adds a question in the editor. */
async function addQuestion(page: Page, label: string, type?: string, options?: string) {
  await editor(page).getByTestId('add-question').click()
  const dialog = page.getByTestId('question-dialog')
  await dialog.getByLabel('Pergunta', { exact: true }).fill(label)
  if (type) await dialog.getByLabel('Tipo de resposta').selectOption({ label: type })
  if (options) await dialog.getByLabel('Opções').fill(options)
  await dialog.getByTestId('question-done').click()
  await expect(dialog).toBeHidden()
}

test('Ajustes leva aos checklists: os seus e os prontos, sem o pronto já copiado (settings.open-checklists, checklist.list.load, checklist.view.list)', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByTestId('settings-checklists').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Checklists' })).toBeVisible()
  const yours = page.getByTestId('checklists-list')
  await expect(yours.getByRole('button', { name: 'Abrir Vistoria de entrada' })).toContainText('2 perguntas')
  const ready = page.getByTestId('ready-list')
  await expect(ready.getByRole('button', { name: 'Ver Teste final' })).toContainText('1 pergunta')
  // Copied on the first access with the segment's id: not offered again (the app shows it).
  await expect(ready.getByText('Vistoria de entrada')).toHaveCount(0)
  // A template off shows so.
  const off = await makeTemplate({ isActive: false })
  await expect(yours.getByRole('button', { name: `Abrir ${off.title}` })).toContainText('Desligado · 1 pergunta')
})

test('prontos que não carregam mostram o erro com Tentar de novo, sem sumir calados (checklist.list.load)', async ({ page }) => {
  await openChecklists(page, 'admin')
  await expect(page.getByTestId('ready-list')).toBeVisible()
  await page.locator('a[href="/app/settings"]').first().click()
  await expect(page.getByTestId('settings-checklists')).toBeVisible()
  await page.context().setOffline(true)
  await page.getByTestId('settings-checklists').click()
  const ready = page.locator('section', { has: page.getByRole('heading', { name: 'Prontos para usar' }) })
  await expect(ready.getByRole('alert')).toContainText('Erro ao carregar procedimentos', { timeout: 20_000 })
  await page.context().setOffline(false)
  await ready.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('ready-list')).toBeVisible()
})

test('quem não gerencia checklists não chega à tela, nem pela URL (checklist.list.load)', async ({ page }) => {
  for (const user of ['technician', 'manager'] as const) {
    await login(page, user, 'checklists')
    await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
    await page.goto('settings')
    await expect(page.getByTestId('settings-checklists')).toHaveCount(0)
    await signOut(page)
  }
  await openChecklists(page, 'supervisor')
})

test('pronto: ver as perguntas e usar, com id novo, e ele sai dos prontos (checklist.list.preview, checklist.list.import)', async ({ page }) => {
  await openChecklists(page, 'admin')
  await page.getByTestId('ready-list').getByRole('button', { name: 'Ver Pronto para copiar' }).click()
  const preview = page.getByTestId('ready-preview')
  await expect(preview).toContainText('Só o teste de Usar')
  await expect(preview).toContainText('Uma pergunta')
  await page.getByRole('dialog', { name: 'Pronto para copiar' }).getByRole('button', { name: 'Usar' }).click()
  await page.getByRole('dialog', { name: 'Usar Pronto para copiar?' }).getByRole('button', { name: 'Usar' }).click()
  await expect(page.getByText('Pronto para copiar está nos seus checklists').first()).toBeVisible()
  await expect(page.getByTestId('checklists-list').getByRole('button', { name: 'Abrir Pronto para copiar' })).toBeVisible()
  await expect(page.getByTestId('ready-list').getByText('Pronto para copiar')).toHaveCount(0)
  const copies = await templatesNamed('Pronto para copiar')
  expect(copies).toHaveLength(1)
  expect(copies[0]?.docId).not.toBe('seg-import')
  expect(copies[0]).toMatchObject({ title: 'Pronto para copiar', description: 'Só o teste de Usar', isActive: true, id: copies[0]?.docId })
})

test('novo checklist só com teclado: diz o que falta, valida a pergunta, reordena com Alt+↑ e grava como o app (checklist.view.new, checklist.form.*, checklist.question.validation)', async ({ page }) => {
  await openChecklists(page, 'supervisor')
  await page.getByTestId('new-checklist').click()
  await expect(editor(page)).toBeVisible()
  await expect(page.getByLabel('Nome do checklist')).toBeFocused()
  // Three different phrases for what is missing.
  await expect(page.getByTestId('template-hint')).toHaveText('Escreva o nome e adicione uma pergunta para salvar.')
  const name = `Zeta Teclado ${Date.now()}`
  await page.keyboard.type(name)
  await expect(page.getByTestId('template-hint')).toHaveText('Adicione uma pergunta para salvar.')
  await page.getByLabel('Descrição').fill('Antes de começar')
  // A choice with one option is refused.
  await editor(page).getByTestId('add-question').click()
  const dialog = page.getByTestId('question-dialog')
  await expect(dialog.getByLabel('Tipo de resposta')).toHaveValue('boolean')
  await dialog.getByTestId('question-done').click()
  await expect(dialog).toContainText('Escreva a pergunta para continuar.')
  await dialog.getByLabel('Pergunta', { exact: true }).fill('Nível do óleo')
  await dialog.getByLabel('Tipo de resposta').selectOption({ label: 'Escolher uma opção' })
  await dialog.getByLabel('Opções').fill('Bom')
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(dialog).toContainText('Escreva pelo menos 2 opções, uma por linha.')
  await dialog.getByLabel('Opções').fill('Bom\n\nBaixo\n')
  await dialog.getByLabel('Obrigatória').check()
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(dialog).toBeHidden()
  await addQuestion(page, 'Foto do painel', 'Só foto')
  // Alt + ↑ moves the photo question to the top.
  const second = editor(page).getByRole('button', { name: 'Pergunta 2: Foto do painel' })
  await second.focus()
  await page.keyboard.press('Alt+ArrowUp')
  await expect(editor(page).getByRole('button', { name: 'Pergunta 1: Foto do painel' })).toBeFocused()
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(editor(page)).toBeHidden()
  await expect(page.getByText(`${name} salvo`).first()).toBeVisible()
  const [saved] = await templatesNamed(name)
  expect(saved).toMatchObject({ id: saved?.docId, title: name, description: 'Antes de começar', isActive: true, company: { id: 'company-alpha' }, createdBy: { id: 'e2e-supervisor' } })
  expect(saved?.items).toMatchObject([
    { label: 'Foto do painel', type: 'photo_only', required: false, allowPhotos: true, options: null },
    { label: 'Nível do óleo', type: 'select', required: true, options: ['Bom', 'Baixo'] },
  ])
  expect(typeof saved?.createdAt).toBe('string')
})

test('editar: apagar pergunta com Desfazer, sair sem salvar pergunta, salvar por cima de quem mudou é recusado (checklist.view.open, checklist.form.question-delete, checklist.form.discard)', async ({ page }) => {
  const template = await makeTemplate({ items: [{ id: 'a', label: 'Primeira', type: 'text' }, { id: 'b', label: 'Segunda', type: 'boolean' }] })
  await openChecklists(page, 'admin')
  await page.getByRole('button', { name: `Abrir ${template.title}` }).click()
  await expect(page).toHaveURL(new RegExp(`checklist=${template.id}`))
  await editor(page).getByRole('button', { name: 'Pergunta 2: Segunda' }).click()
  await page.getByTestId('question-dialog').getByRole('button', { name: 'Apagar pergunta' }).click()
  await expect(editor(page).getByRole('button', { name: /Segunda/ })).toHaveCount(0)
  await expect(editor(page).getByTestId('question-removed')).toContainText('Pergunta apagada: Segunda')
  await editor(page).getByRole('button', { name: 'Desfazer' }).click()
  await expect(editor(page).getByRole('button', { name: 'Pergunta 2: Segunda' })).toBeVisible()
  // Closing with a change asks; "Cancel" stays.
  await page.getByLabel('Nome do checklist').fill(`${template.title} mudado`)
  page.once('dialog', (dialog) => {
    expect(dialog.message()).toContain('Sair sem salvar o checklist?')
    void dialog.dismiss()
  })
  await page.keyboard.press('Escape')
  await expect(editor(page)).toBeVisible()
  // The app saved meanwhile: nothing is written over it, and the drawer keeps what was typed (M2).
  await updateTemplateDoc(template.id, { title: `${template.title} pelo app` })
  await editor(page).getByTestId('save-template').click()
  const conflict = editor(page).getByTestId('template-conflict')
  await expect(conflict).toContainText('Este checklist mudou em outro lugar.')
  await expect(editor(page)).toBeVisible()
  await expect(page.getByLabel('Nome do checklist')).toHaveValue(`${template.title} mudado`)
  expect((await readTemplate(template.id))?.title).toBe(`${template.title} pelo app`)
  // "Copiar minhas perguntas" keeps the work; "Recarregar" brings the saved one.
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write'])
  await conflict.getByRole('button', { name: 'Copiar minhas perguntas' }).click()
  await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toContain(`${template.title} mudado\n1. Primeira\n2. Segunda`)
  await conflict.getByRole('button', { name: 'Recarregar' }).click()
  await expect(page.getByLabel('Nome do checklist')).toHaveValue(`${template.title} pelo app`)
  await expect(conflict).toHaveCount(0)
  // After reloading, saving works on top of the app's version.
  await page.getByLabel('Descrição').fill('Depois de recarregar')
  await editor(page).getByTestId('save-template').click()
  await expect(editor(page)).toBeHidden()
  expect(await readTemplate(template.id)).toMatchObject({ title: `${template.title} pelo app`, description: 'Depois de recarregar' })
})

test('app salva, web liga ou desliga e salva: o web avisa e não grava por cima (M1, checklist.form.toggle)', async ({ page }) => {
  const template = await makeTemplate({ items: [{ id: 'a', label: 'Primeira', type: 'text' }] })
  await openChecklists(page, 'admin')
  await page.getByRole('button', { name: `Abrir ${template.title}` }).click()
  await expect(editor(page)).toBeVisible()
  await updateTemplateDoc(template.id, { items: [{ id: 'a', label: 'Primeira', type: 'text' }, { id: 'z', label: 'Do app', type: 'boolean' }] })
  await editor(page).getByTestId('template-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Parar de usar' }).click()
  await expect(editor(page).getByTestId('template-conflict')).toBeVisible()
  expect((await readTemplate(template.id))?.isActive).toBe(true)
  await page.getByLabel('Descrição').fill('Do web')
  await editor(page).getByTestId('save-template').click()
  await expect(editor(page).getByTestId('template-conflict')).toBeVisible()
  const saved = await readTemplate(template.id)
  expect((saved?.items as unknown[]).length).toBe(2)
  expect(saved?.description ?? null).toBeNull()
})

test('parar de usar, voltar a usar e apagar pelo "…"; apagar na lista mantém a linha se falhar (checklist.form.toggle, checklist.form.delete, checklist.list.delete)', async ({ page }) => {
  const template = await makeTemplate()
  const other = await makeTemplate()
  await openChecklists(page, 'admin')
  await page.getByRole('button', { name: `Abrir ${template.title}` }).click()
  await editor(page).getByTestId('template-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Parar de usar' }).click()
  await expect(editor(page).getByTestId('template-off')).toBeVisible()
  expect((await readTemplate(template.id))?.isActive).toBe(false)
  await editor(page).getByTestId('template-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Voltar a usar' }).click()
  await expect(editor(page).getByTestId('template-off')).toHaveCount(0)
  expect((await readTemplate(template.id))?.isActive).toBe(true)
  await editor(page).getByTestId('template-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Apagar checklist' }).click()
  await page.getByRole('dialog', { name: 'Apagar este checklist?' }).getByRole('button', { name: 'Apagar checklist' }).click()
  await expect(editor(page)).toBeHidden()
  expect(await readTemplate(template.id)).toBeUndefined()
  // On the list: "Apagar", with the app's words, and a failure keeps the row.
  await page.context().setOffline(true)
  await page.getByRole('button', { name: `Apagar ${other.title}` }).click()
  await page.getByRole('dialog', { name: 'Apagar este checklist?' }).getByRole('button', { name: 'Apagar checklist' }).click()
  await expect(page.getByText('Não deu para apagar o checklist.', { exact: false }).first()).toBeVisible({ timeout: 15_000 })
  await expect(page.getByRole('button', { name: `Abrir ${other.title}` })).toBeVisible()
  await page.context().setOffline(false)
  await page.getByRole('button', { name: `Apagar ${other.title}` }).click()
  await page.getByRole('dialog', { name: 'Apagar este checklist?' }).getByRole('button', { name: 'Apagar checklist' }).click()
  await expect(page.getByRole('button', { name: `Abrir ${other.title}` })).toHaveCount(0)
  expect(await readTemplate(other.id)).toBeUndefined()
})

test('plano Free com 1 ativo não trava no navegador, como o app sem planos pagos (checklist.counter.active, checklist.view.new)', async ({ page }) => {
  await login(page, 'owner', 'checklists')
  await chooseCompany(page, 'Beta Repairs')
  await expect(page.getByTestId('checklists-summary')).not.toContainText('em uso')
  await page.getByRole('button', { name: 'Abrir Old check' }).click()
  await editor(page).getByTestId('template-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Voltar a usar' }).click()
  await expect(editor(page).getByTestId('template-off')).toHaveCount(0)
  await expect(page.getByTestId('template-error')).toHaveCount(0)
  await editor(page).getByRole('button', { name: 'Fechar' }).click()
  await expect(editor(page)).toBeHidden()
  await page.getByTestId('new-checklist').click()
  await expect(editor(page)).toBeVisible()
  await expect(page.getByTestId('checklists-limit')).toHaveCount(0)
})

test('pronto do segmento direto na OS, sem copiar, por quem não gerencia checklists (checklist.pick.choose)', async ({ page }) => {
  const order = await makeOrder('technician', { status: 'quote', payment: null })
  await openOrder(page, 'technician', order.id)
  await forms(page).getByTestId('add-checklist').click()
  const picker = page.getByTestId('checklist-picker')
  await expect(picker.getByRole('heading', { name: 'Da empresa' })).toBeVisible()
  await expect(picker.getByRole('heading', { name: 'Globais' })).toBeVisible()
  await expect(picker.getByTestId('picker-new')).toHaveCount(0)
  await picker.getByRole('button', { name: /Teste final/ }).click()
  await expect(fill(page)).toBeVisible()
  await page.keyboard.press('Escape')
  const [saved] = await readOrderForms(order.id)
  expect(saved).toMatchObject({ formDefinitionId: 'seg-final', title: 'Teste final', status: 'pending' })
  expect(await templatesNamed('Teste final')).toEqual([])
})

test('OS: adicionar abre direto na 1ª pergunta e responde só com teclado, como o app grava (order.checklist.add, checklist.pick.choose, checklist.fill.*, checklist.question.*)', async ({ page }) => {
  const template = await makeTemplate({
    items: [
      { id: 'b', label: 'Pneus bons?', type: 'boolean', required: true },
      { id: 's', label: 'Óleo', type: 'select', options: ['Bom', 'Baixo'] },
      { id: 'c', label: 'Itens', type: 'checklist', options: ['Estepe', 'Macaco', 'Triângulo'] },
      { id: 't', label: 'Observação', type: 'text' },
      { id: 'n', label: 'Quilometragem', type: 'number' },
    ],
  })
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  await expect(forms(page)).toContainText('Nenhum checklist nesta OS.')
  await forms(page).getByTestId('add-checklist').click()
  const picker = page.getByTestId('checklist-picker')
  // Only active ones, by title; the seed's comes first.
  await expect(picker.getByRole('button', { name: /Vistoria de entrada/ })).toBeVisible()
  await picker.getByRole('button', { name: new RegExp(template.title) }).click()
  await expect(fill(page)).toBeVisible()
  await expect(fill(page).getByTestId('fill-device')).toHaveText('Veículo 2 · TST0002')
  await expect(fill(page).getByTestId('fill-status')).toContainText('Faltam 5 perguntas')
  // Straight on the first question: a number picks, then the next one has the focus.
  await expect(fill(page).getByRole('radio', { name: 'Sim' })).toBeFocused()
  await page.keyboard.press('1')
  await expect(fill(page).getByRole('radiogroup', { name: /Óleo/ }).getByRole('radio', { name: 'Bom' })).toBeFocused()
  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('Space')
  const items = fill(page)
  await expect(items.getByRole('checkbox', { name: 'Estepe' })).toBeFocused()
  await page.keyboard.press('Space')
  await page.keyboard.press('3')
  await expect(items.getByRole('checkbox', { name: 'Triângulo' })).toHaveAttribute('aria-checked', 'true')
  await page.keyboard.press('Enter')
  await expect(fill(page).getByRole('textbox', { name: 'Observação' })).toBeFocused()
  await page.keyboard.type('Arranhão na porta')
  await page.keyboard.press('Enter')
  await expect(fill(page).getByRole('textbox', { name: 'Quilometragem' })).toBeFocused()
  await page.keyboard.type('doze')
  await page.keyboard.press('Enter')
  await expect(fill(page)).toContainText('Formato inválido')
  await fill(page).getByRole('textbox', { name: 'Quilometragem' }).fill('12.345,5')
  // Last answer with nothing left: completed and back to the order.
  await page.keyboard.press('Enter')
  // Five answers go one after the other; on a busy machine the last one may take a while.
  await expect(fill(page)).toBeHidden({ timeout: 20_000 })
  await expect(forms(page).getByTestId('form-progress')).toHaveText('Completo')
  const [saved] = await readOrderForms(order.id)
  expect(saved).toMatchObject({ formDefinitionId: template.id, title: template.title, status: 'completed', deviceId: 'device-2' })
  expect(typeof saved?.completedAt).toBe('string')
  const responses = Object.fromEntries((saved?.responses as { itemId: string; value: unknown; photoUrls: string[] }[]).map((r) => [r.itemId, r]))
  expect(responses.b).toEqual({ itemId: 'b', value: true, photoUrls: [] })
  expect(responses.s?.value).toBe('Baixo')
  expect(responses.c?.value).toEqual(['Estepe', 'Triângulo'])
  expect(responses.t?.value).toBe('Arranhão na porta')
  expect(responses.n?.value).toBe('12.345,5')
})

test('dois aparelhos: pergunta qual antes; Novo checklist no seletor já volta escolhido (checklist.pick.device-first, checklist.pick.create, checklist.fill.device-label)', async ({ page }) => {
  const order = await makeOrder('admin', {
    devices: [
      { id: 'device-2', name: 'Veículo 2', serial: 'TST0002' },
      { id: 'device-5', name: 'Veículo 5', serial: 'TST0005' },
    ],
    deviceIds: ['device-2', 'device-5'],
  })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByTestId('add-checklist').click()
  const which = page.getByRole('dialog', { name: 'Qual veículo?' })
  await expect(which.getByRole('button', { name: 'Geral' })).toBeVisible()
  await which.getByRole('button', { name: /Veículo 5/ }).click()
  await page.getByTestId('picker-new').click()
  const name = `Zeta Do Seletor ${Date.now()}`
  await page.getByLabel('Nome do checklist').fill(name)
  await addQuestion(page, 'Lataria ok?')
  await editor(page).getByTestId('save-template').click()
  await expect(fill(page)).toBeVisible()
  await expect(fill(page).getByTestId('fill-device')).toHaveText('Veículo 5 · TST0005')
  await page.keyboard.press('Escape')
  await expect(forms(page)).toContainText(name)
  await expect(forms(page)).toContainText('Veículo 5 · TST0005')
  const [saved] = await readOrderForms(order.id)
  expect(saved).toMatchObject({ title: name, deviceId: 'device-5', status: 'pending' })
})

test('app e web no mesmo checklist: a resposta do web não apaga a do app (checklist.fill.answer)', async ({ page }) => {
  const order = await makeOrder('admin')
  const formId = await makeOrderForm(order.id, {
    items: [
      { id: 'a', label: 'Pergunta do web', type: 'boolean' },
      { id: 'b', label: 'Pergunta do app', type: 'text' },
    ],
  })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await expect(fill(page)).toBeVisible()
  // The app answers the other question while the web is open (whole list, as its offline path writes).
  await writeOrderFormRaw(order.id, formId, { responses: [{ itemId: 'b', value: 'Do celular', photoUrls: [] }], status: 'in_progress' })
  await expect(fill(page).getByRole('textbox', { name: 'Pergunta do app' })).toHaveValue('Do celular')
  await fill(page).getByRole('radio', { name: 'Não' }).click()
  await expect(fill(page)).toBeHidden()
  const [saved] = await readOrderForms(order.id)
  expect(saved?.responses).toEqual(
    expect.arrayContaining([
      { itemId: 'b', value: 'Do celular', photoUrls: [] },
      { itemId: 'a', value: false, photoUrls: [] },
    ]),
  )
  expect(saved?.status).toBe('completed')
})

test('sem conexão a resposta fica na tela marcada e Tentar de novo grava (checklist.fill.answer)', async ({ page }) => {
  test.setTimeout(60_000)
  const order = await makeOrder('admin')
  await makeOrderForm(order.id, { items: [{ id: 'a', label: 'Uma', type: 'boolean' }, { id: 'b', label: 'Outra', type: 'text' }] })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await page.context().setOffline(true)
  await fill(page).getByRole('radio', { name: 'Sim' }).click()
  await expect(fill(page).getByText('Não deu para guardar a resposta. Tente de novo.')).toBeVisible({ timeout: 20_000 })
  await expect(fill(page).getByRole('radio', { name: 'Sim' })).toHaveAttribute('aria-checked', 'true')
  await page.context().setOffline(false)
  await fill(page).getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(fill(page).getByText('Não deu para guardar a resposta.', { exact: false })).toHaveCount(0)
  await expect.poll(async () => ((await readOrderForms(order.id))[0]?.responses as unknown[])?.length).toBe(1)
  expect((await readOrderForms(order.id))[0]).toMatchObject({ status: 'in_progress', responses: [{ itemId: 'a', value: true, photoUrls: [] }] })
})

test('fotos: pôr na pergunta, ver, tirar (e o arquivo sai); obrigatória vazia não deixa concluir (checklist.fill.photo-gallery, checklist.fill.gallery, checklist.fill.photo-delete, checklist.question.photo, checklist.fill.complete)', async ({ page }) => {
  const order = await makeOrder('admin')
  const formId = await makeOrderForm(order.id, {
    items: [
      { id: 'p', label: 'Foto da frente', type: 'photo_only', required: true },
      { id: 'o', label: 'Opcional', type: 'text' },
    ],
  })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await page.getByTestId('photo-input-p').setInputFiles({ name: 'frente.png', mimeType: 'image/png', buffer: PNG })
  await expect(fill(page).getByRole('button', { name: 'Ver foto 1 de Foto da frente' })).toBeVisible()
  const [withPhoto] = await readOrderForms(order.id)
  const url = (withPhoto?.responses as { photoUrls: string[] }[])[0]?.photoUrls[0] as string
  // Same folder the app uploads to (storage.rules: one level under the form).
  expect(decodeURIComponent(url)).toContain(`tenants/company-alpha/orders/${order.id}/forms/${formId}/p_`)
  expect((await fetch(url)).status).toBe(200)
  await expect(fill(page).getByTestId('fill-finish-anyway')).toBeVisible()
  await fill(page).getByRole('button', { name: 'Ver foto 1 de Foto da frente' }).click()
  await page.getByTestId('photo-remove').click()
  await page.getByRole('dialog', { name: 'Apagar esta foto?' }).getByRole('button', { name: 'Remover Foto' }).click()
  await expect(fill(page).getByRole('button', { name: /Ver foto/ })).toHaveCount(0)
  expect(((await readOrderForms(order.id))[0]?.responses as { photoUrls: string[] }[])[0]?.photoUrls).toEqual([])
  // The emulator answers 403 for a file that is gone.
  await expect.poll(async () => (await fetch(url)).status).not.toBe(200)
  // A required one empty: the list of what is missing, never completed.
  await fill(page).getByRole('textbox', { name: 'Opcional' }).fill('algo')
  await fill(page).getByRole('textbox', { name: 'Opcional' }).press('Tab')
  await expect(fill(page).getByTestId('fill-finish-anyway')).toHaveCount(0)
  await fill(page).getByTestId('fill-start').click()
  await expect(page.getByTestId('photo-input-p')).toBeFocused()
})

test('concluído em outro lugar enquanto se digita: a resposta não entra (B1)', async ({ page }) => {
  const order = await makeOrder('admin')
  const formId = await makeOrderForm(order.id, { items: [{ id: 't', label: 'Observação', type: 'text' }, { id: 'u', label: 'Outra', type: 'text' }], responses: [{ itemId: 'u', value: 'feito', photoUrls: [] }], status: 'in_progress' })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await fill(page).getByRole('textbox', { name: 'Observação' }).fill('digitado no web')
  await writeOrderFormRaw(order.id, formId, { status: 'completed', completedAt: new Date().toISOString() })
  await expect(fill(page).getByTestId('fill-status')).toContainText('Completo')
  await fill(page).getByRole('button', { name: 'Fechar' }).click()
  await expect(fill(page)).toBeHidden()
  const [saved] = await readOrderForms(order.id)
  expect(saved?.status).toBe('completed')
  expect(saved?.responses).toEqual([{ itemId: 'u', value: 'feito', photoUrls: [] }])
})

test('foto: só JPEG, PNG e WebP (B2)', async ({ page }) => {
  const order = await makeOrder('admin')
  await makeOrderForm(order.id, { items: [{ id: 'p', label: 'Foto da frente', type: 'photo_only' }] })
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await expect(page.getByTestId('photo-input-p')).toHaveAttribute('accept', 'image/jpeg,image/png,image/webp')
  await page.getByTestId('photo-input-p').setInputFiles({ name: 'x.svg', mimeType: 'image/svg+xml', buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>') })
  await expect(page.getByText('1 foto não foi enviada', { exact: false }).first()).toBeVisible()
  expect((await readOrderForms(order.id))[0]?.responses).toEqual([])
})

test('concluído: só leitura; admin reabre, técnico não; gerente lê sem responder (checklist.fill.reopen, checklist.fill.view)', async ({ page }) => {
  const order = await makeOrder('technician', { status: 'progress' })
  await makeOrderForm(order.id, { status: 'completed', responses: [{ itemId: 'q1', value: true, photoUrls: [] }] })
  await openOrder(page, 'technician', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await expect(fill(page).getByTestId('fill-status')).toContainText('Completo')
  await expect(fill(page)).toContainText('Sim')
  await expect(fill(page).getByRole('radio')).toHaveCount(0)
  await expect(fill(page).getByTestId('fill-menu')).toHaveCount(0)
  // Technician only adds or removes in a quote.
  await page.keyboard.press('Escape')
  await expect(forms(page).getByTestId('add-checklist')).toHaveCount(0)
  await page.goto('settings')
  await signOut(page)
  await openOrder(page, 'admin', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await fill(page).getByTestId('fill-menu').click()
  await page.getByRole('dialog').getByRole('button', { name: 'Reabrir' }).click()
  await expect(fill(page).getByTestId('fill-status')).toContainText('Tudo respondido')
  await expect(fill(page).getByRole('radio', { name: 'Sim' })).toHaveAttribute('aria-checked', 'true')
  expect((await readOrderForms(order.id))[0]?.status).toBe('in_progress')
  await page.keyboard.press('Escape')
  await page.goto('settings')
  await signOut(page)
  await openOrder(page, 'manager', order.id)
  await forms(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
  await expect(fill(page)).toContainText('Sim')
  await expect(fill(page).getByRole('radio')).toHaveCount(0)
  await expect(fill(page).getByTestId('fill-finish')).toHaveCount(0)
})

test('checklist pendente segura o "concluída" e abre o que falta; Remover tira da OS (order.status.pending-checklist, order.checklist.open, order.checklist.delete)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'progress' })
  await makeOrderForm(order.id, { title: 'Teste final', items: [{ id: 'a', label: 'Freio ok?', type: 'boolean' }, { id: 'b', label: 'Luzes ok?', type: 'boolean' }], responses: [{ itemId: 'a', value: true, photoUrls: [] }], status: 'in_progress' })
  await openOrder(page, 'admin', order.id)
  await expect(forms(page).getByTestId('form-progress')).toHaveText('1 de 2 respondidas')
  await panel(page).getByTestId('next-step').click()
  const blocked = page.getByRole('dialog', { name: 'Falta terminar 1 checklist' })
  await expect(blocked).toBeVisible()
  await blocked.getByRole('button', { name: 'Abrir checklist' }).click()
  await expect(fill(page)).toBeVisible()
  await expect(fill(page).getByTestId('fill-status')).toContainText('Falta 1 pergunta')
  expect((await readOrder(order.id))?.status).toBe('progress')
  await page.keyboard.press('Escape')
  await forms(page).getByRole('button', { name: 'Remover Teste final da OS' }).click()
  await page.getByRole('dialog', { name: 'Tirar Teste final da OS?' }).getByRole('button', { name: 'Remover' }).click()
  await expect(forms(page)).toContainText('Nenhum checklist nesta OS.')
  expect(await readOrderForms(order.id)).toEqual([])
  // Nothing pending now: the order finishes.
  await panel(page).getByTestId('next-step').click()
  await expect(panel(page).getByTestId('order-status')).toHaveText('Concluído')
})

test('Nova OS com veículo oferece o checklist de entrada; Agora não três vezes para de perguntar (order.offer.checklist, order.new.after-save)', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  async function newOrder() {
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 03')
    await page.keyboard.press('Enter')
    const drawer = page.getByRole('dialog', { name: 'Nova OS' })
    // The only vehicle comes in by itself once the customer's are read; with more than one known, pick it.
    const auto = await drawer
      .getByText('TST0003')
      .waitFor({ timeout: 4000 })
      .then(
        () => true,
        () => false,
      )
    if (!auto) {
      await page.locator('#no-device').fill('Veículo 3')
      await expect(page.getByRole('option', { name: /Veículo 3/ }).first()).toBeVisible()
      await page.keyboard.press('Enter')
    }
    await expect(drawer).toContainText('TST0003')
    await page.keyboard.press('ControlOrMeta+Enter')
    await expect(panel(page)).toBeVisible()
  }
  await newOrder()
  const offer = page.getByRole('dialog', { name: 'Fazer o checklist de entrada?' })
  await expect(offer).toContainText('Registre como Veículo 3 chegou')
  await offer.getByRole('button', { name: 'Fazer checklist' }).click()
  await expect(page.getByTestId('checklist-picker')).toBeVisible()
  await page.keyboard.press('Escape')
  for (let i = 0; i < 3; i++) {
    await newOrder()
    await expect(offer).toBeVisible()
    await offer.getByRole('button', { name: 'Agora não' }).click()
    await expect(offer).toBeHidden()
  }
  await newOrder()
  await expect(forms(page)).toBeVisible()
  await expect(offer).toHaveCount(0)
})
