// Agenda (agenda.*): week and day of visits in the company's zone, the month on
// the side, person filter, open the order, and moving a visit by dragging or by
// keyboard, with confirmation and undo. Each test uses its own month far in the
// future, so the orders other tests create never land on its screen.
import { expect, test, type Locator, type Page } from '@playwright/test'
import { makeOrder, makeOrderInB, readOrder, updateCompanyB, updateOrderDoc } from './data'
import { chooseCompany, expectNoAxeViolations, expectNoSideScroll, login, setTheme, type UserKey } from './helpers'

const grid = (page: Page) => page.locator('.tg')
const block = (page: Page, id: string) => page.locator(`[data-order="${id}"]`)
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const calendarDay = (page: Page, day: string) => page.locator(`.cal-day[data-day="${day}"]`)

async function openAgenda(page: Page, user: UserKey, query: string) {
  await login(page, user, `schedule?${query}`)
  await expect(page.getByRole('heading', { level: 1, name: 'Agenda' })).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
}

/** Drag a block to an hour of a day column, by the hour label on the side. */
async function dragTo(page: Page, from: Locator, day: string, hour: string) {
  const column = page.locator(`.tg-col[data-day="${day}"]`)
  const label = page.locator('.tg-hour', { hasText: new RegExp(`^${hour}$`) })
  const [col, line] = [await column.boundingBox(), await label.boundingBox()]
  if (!col || !line) throw new Error('grade sem coluna ou hora')
  await from.dragTo(column, { targetPosition: { x: 20, y: line.y + line.height / 2 - col.y + 4 } })
}

test('semana com visitas na hora da empresa, linha, cabeçalho do dia, pontos do mês e abrir a OS (agenda.view, agenda.row, agenda.day-header, agenda.day-markers, agenda.open-order)', async ({ page }) => {
  // App style (local time, no zone), API style (UTC) and an all-day one.
  const a = await makeOrder('admin', {
    scheduledDate: '2031-03-11T09:30:00.000',
    assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' },
    devices: [{ id: 'device-2', name: 'Veículo 2' }, { id: 'device-3', name: 'Veículo 3' }],
  })
  const b = await makeOrder('admin', { scheduledDate: '2031-03-11T00:00:00.000' })
  const c = await makeOrder('admin', { scheduledDate: '2031-03-12T14:00:00.000Z' })
  await openAgenda(page, 'admin', 'd=2031-03-11')
  await expect(page.getByTestId('agenda-summary')).toHaveText('9 de mar. a 15 de mar. · 3 marcados')
  await expect(block(page, a.id)).toHaveAccessibleName(new RegExp(`^09:30 Cliente 02 OS ${a.number} · Aprovado.*Veículo 2 \\+1 · com Tiago Tecnico$`))
  await expect(block(page, c.id)).toHaveAccessibleName(new RegExp(`^11:00 Cliente 02 OS ${c.number} · Aprovado`))
  await expect(page.locator('.tg-allday[data-allday="2031-03-11"]')).toContainText('Cliente 02')
  await expect(page.locator('[data-head="2031-03-11"]')).toContainText('2 marcados')
  await expect(page.locator('[data-head="2031-03-11"]').getByRole('heading', { level: 2 })).toBeVisible()
  await expect(calendarDay(page, '2031-03-11')).toHaveAccessibleName(/tem serviço marcado/)
  await expect(calendarDay(page, '2031-03-13')).not.toHaveAccessibleName(/tem serviço marcado/)
  await expect(calendarDay(page, '2031-03-11')).toHaveAttribute('aria-pressed', 'true')
  // Day order: with time first, "Dia todo" apart.
  await page.locator('[data-head="2031-03-11"]').getByRole('button', { name: /Ver só/ }).click()
  await expect(page).toHaveURL(/view=day/)
  await expect(page.locator('.tg-col')).toHaveCount(1)
  await expect(page.getByTestId('agenda-summary')).toHaveText('terça-feira, 11 de março · 2 marcados')
  await expect(block(page, a.id)).toContainText('Veículo 2 +1 · com Tiago Tecnico')
  await block(page, b.id).click()
  await expect(panel(page)).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`order=${b.id}`))
})

test.describe('fuso da empresa, não o do computador', () => {
  test.use({ timezoneId: 'Asia/Tokyo' })
  test('visita das 09:30 em São Paulo aparece às 09:30 num computador em Tóquio (agenda.view)', async ({ page }) => {
    const a = await makeOrder('admin', { scheduledDate: '2031-04-08T12:30:00.000Z' })
    await openAgenda(page, 'admin', 'd=2031-04-08&view=day')
    await expect(block(page, a.id)).toHaveAccessibleName(new RegExp(`^09:30 Cliente 02 OS ${a.number}`))
  })

  test('em Tóquio, mover e o seletor da OS gravam a hora da empresa sem fuso, e o painel mostra a mesma hora (M1, B2)', async ({ page }) => {
    const a = await makeOrder('admin', { scheduledDate: '2031-04-09T09:30:00.000', customer: null })
    await openAgenda(page, 'admin', 'd=2031-04-09&view=day')
    await block(page, a.id).focus()
    await page.keyboard.press('Shift+ArrowDown')
    await page.keyboard.press('Enter')
    await expect.poll(async () => (await readOrder(a.id))?.scheduledDate).toBe('2031-04-09T10:00:00.000')
    await block(page, a.id).click()
    const details = panel(page).getByRole('region', { name: 'Detalhes' })
    await expect(details).toContainText('09/04, 10:00')
    await details.getByRole('button', { name: /09\/04, 10:00/ }).click()
    const visit = page.getByRole('dialog', { name: 'Agendar dia e hora' })
    await expect(visit.getByLabel('Visita')).toHaveValue('2031-04-09T10:00')
    await visit.getByLabel('Visita').fill('2031-04-09T11:00')
    await visit.getByRole('button', { name: 'Salvar' }).click()
    await expect.poll(async () => (await readOrder(a.id))?.scheduledDate).toBe('2031-04-09T11:00:00.000')
    await expect(details).toContainText('09/04, 11:00')
    await expect(page.locator(`.tg-col [data-order="${a.id}"]`)).toContainText('11:00')
  })
})

test('21h do último dia do mês fica no dia certo e "Dia todo" grava meia-noite sem fuso (M1)', async ({ page }) => {
  const late = await makeOrder('admin', { scheduledDate: '2031-01-31T19:00:00.000', customer: null })
  const allDay = await makeOrder('admin', { scheduledDate: '2031-01-30T10:00:00.000', customer: null })
  await openAgenda(page, 'admin', 'd=2031-01-31')
  await block(page, late.id).focus()
  for (let i = 0; i < 4; i++) await page.keyboard.press('Shift+ArrowDown')
  await page.keyboard.press('Enter')
  await expect.poll(async () => (await readOrder(late.id))?.scheduledDate).toBe('2031-01-31T21:00:00.000')
  await expect(page.locator(`.tg-col[data-day="2031-01-31"] [data-order="${late.id}"]`)).toContainText('21:00')
  // The move above scrolled the grid to 21:00; back to the top, where "Dia todo" is.
  await page.locator('.ag-scroll').evaluate((element) => (element.scrollTop = 0))
  await block(page, allDay.id).dragTo(page.locator('.tg-allday[data-allday="2031-01-30"]'))
  await expect.poll(async () => (await readOrder(allDay.id))?.scheduledDate).toBe('2031-01-30T00:00:00.000')
  await expect(page.locator(`.tg-allday[data-allday="2031-01-30"] [data-order="${allDay.id}"]`)).toBeVisible()
})

test('arrastar para outro dia e hora pergunta antes, grava pela API e desfaz (agenda drag)', async ({ page }) => {
  const order = await makeOrder('admin', { scheduledDate: '2031-04-15T09:00:00.000' })
  await openAgenda(page, 'admin', 'd=2031-04-15')
  await dragTo(page, block(page, order.id), '2031-04-16', '13:00')
  const confirm = page.getByRole('dialog', { name: 'Mudar a visita de Cliente 02?' })
  await expect(confirm).toContainText('Estava para ter., 15 de abr., 09:00. Vai para qua., 16 de abr., 13:00.')
  // "Deixar como estava" keeps everything.
  await confirm.getByRole('button', { name: 'Deixar como estava' }).click()
  await expect(confirm).toHaveCount(0)
  expect((await readOrder(order.id))?.scheduledDate).toBe('2031-04-15T09:00:00.000')

  await dragTo(page, block(page, order.id), '2031-04-16', '13:00')
  await page.getByRole('dialog', { name: 'Mudar a visita de Cliente 02?' }).getByRole('button', { name: 'Mudar a data' }).click()
  await expect(page.locator('.toast').filter({ hasText: `OS ${order.number} foi para qua., 16 de abr., 13:00` })).toBeVisible()
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe('2031-04-16T13:00:00.000')
  await expect(page.locator(`.tg-col[data-day="2031-04-16"] [data-order="${order.id}"]`)).toBeVisible()
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe('2031-04-15T09:00:00.000')
  await expect(page.locator(`.tg-col[data-day="2031-04-15"] [data-order="${order.id}"]`)).toBeVisible()
})

test('teclado: Shift e setas mostram para onde vai, Esc desfaz, Enter confirma (agenda keyboard)', async ({ page }) => {
  const order = await makeOrder('admin', { scheduledDate: '2031-06-10T14:00:00.000Z' })
  await openAgenda(page, 'admin', 'd=2031-06-10')
  const moving = block(page, order.id)
  await moving.focus()
  await page.keyboard.press('Shift+ArrowUp')
  await expect(block(page, order.id)).toHaveClass(/is-pending/)
  await page.keyboard.press('Escape')
  await expect(block(page, order.id)).not.toHaveClass(/is-pending/)
  expect((await readOrder(order.id))?.scheduledDate).toBe('2031-06-10T14:00:00.000Z')

  await block(page, order.id).focus()
  await page.keyboard.press('Shift+ArrowDown')
  await page.keyboard.press('Shift+ArrowDown')
  await page.keyboard.press('Shift+ArrowRight')
  await expect(page.locator(`.tg-col[data-day="2031-06-11"] [data-order="${order.id}"]`)).toContainText('12:00')
  await page.keyboard.press('Enter')
  await page.getByRole('dialog', { name: 'Mudar a visita de Cliente 02?' }).getByRole('button', { name: 'Mudar a data' }).click()
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe('2031-06-11T12:00:00.000')
  await expect(block(page, order.id)).toBeFocused()
})

test('sem cliente não pergunta; OS que mudou em outro lugar não é gravada por cima (agenda drag, version)', async ({ page }) => {
  const free = await makeOrder('admin', { scheduledDate: '2031-07-08T13:00:00.000Z', customer: null })
  const other = await makeOrder('admin', { scheduledDate: '2031-07-08T17:00:00.000Z' })
  await openAgenda(page, 'admin', 'd=2031-07-08')
  await dragTo(page, block(page, free.id), '2031-07-09', '10:00')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect.poll(async () => (await readOrder(free.id))?.scheduledDate).toBe('2031-07-09T10:00:00.000')

  // Someone saves the other order after the agenda read it: the move is refused and the agenda reads it again.
  await updateOrderDoc(other.id, { updatedAt: new Date().toISOString(), status: 'progress' })
  await dragTo(page, block(page, other.id), '2031-07-10', '10:00')
  await page.getByRole('dialog', { name: 'Mudar a visita de Cliente 02?' }).getByRole('button', { name: 'Mudar a data' }).click()
  await expect(page.locator('.toast').filter({ hasText: 'Isso mudou enquanto você mexia' })).toBeVisible()
  expect((await readOrder(other.id))?.scheduledDate).toBe('2031-07-08T17:00:00.000Z')
  await expect(page.locator(`.tg-col[data-day="2031-07-08"] [data-order="${other.id}"]`)).toContainText('Na oficina')
})

test('técnico vê as que criou e as atribuídas a ele, sem filtro de pessoa, e só muda orçamento (agenda.view por papel)', async ({ page }) => {
  const mine = await makeOrder('technician', { status: 'quote', payment: null, scheduledDate: '2031-08-12T13:00:00.000Z' })
  const assigned = await makeOrder('admin', { scheduledDate: '2031-08-12T15:00:00.000Z', assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' } })
  const others = await makeOrder('admin', { scheduledDate: '2031-08-12T17:00:00.000Z' })
  const agendaList = page.waitForResponse((response) => /\/v1\/app\/orders\?.*sort=scheduledDate/.test(response.url()))
  await openAgenda(page, 'technician', 'd=2031-08-12')
  // The projection without values, as in the list (who lacks viewPrices).
  expect(JSON.stringify((await (await agendaList).json()).data)).not.toMatch(/"(total|paidAmount|value|payment)"/)
  await expect(block(page, mine.id)).toBeVisible()
  await expect(block(page, assigned.id)).toBeVisible()
  await expect(block(page, others.id)).toHaveCount(0)
  await expect(page.getByTestId('agenda-who')).toHaveCount(0)
  // Approved order assigned to the technician: the date is not theirs to change (canEditOrderMainFields).
  await expect(block(page, assigned.id)).toHaveAttribute('draggable', 'false')
  await block(page, assigned.id).focus()
  await page.keyboard.press('Shift+ArrowDown')
  await expect(page.locator('.toast').filter({ hasText: 'Você não pode mudar a data desta OS.' })).toBeVisible()
  await expect(block(page, mine.id)).toHaveAttribute('draggable', 'true')
})

test('consultor vê só as próprias e muda a data delas; gerente vê todas (agenda.view por papel)', async ({ page }) => {
  const own = await makeOrder('consultant', { scheduledDate: '2031-09-09T13:00:00.000Z' })
  const others = await makeOrder('admin', { scheduledDate: '2031-09-09T15:00:00.000Z' })
  await openAgenda(page, 'consultant', 'd=2031-09-09')
  await expect(block(page, own.id)).toHaveAttribute('draggable', 'true')
  await expect(block(page, others.id)).toHaveCount(0)
  await expect(page.getByTestId('agenda-who')).toHaveCount(0)
})

test('gerente vê todas e muda a data (agenda.view por papel)', async ({ page }) => {
  const others = await makeOrder('admin', { scheduledDate: '2031-09-16T15:00:00.000Z' })
  await openAgenda(page, 'manager', 'd=2031-09-16')
  await expect(block(page, others.id)).toHaveAttribute('draggable', 'true')
})

test('filtro de pessoa: De quem, Só de, Mostrar todos (agenda.filter-person, agenda.filter-clear)', async ({ page }) => {
  const assigned = await makeOrder('admin', { scheduledDate: '2031-10-14T13:00:00.000Z', assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' } })
  const nobody = await makeOrder('admin', { scheduledDate: '2031-10-14T15:00:00.000Z' })
  await openAgenda(page, 'supervisor', 'd=2031-10-14')
  await expect(block(page, nobody.id)).toBeVisible()
  await page.getByTestId('agenda-who').click()
  const picker = page.getByRole('dialog', { name: 'De quem mostrar?' })
  await expect(picker.getByRole('button', { name: 'Toda a equipe' })).toHaveAttribute('aria-current', 'true')
  await picker.getByRole('button', { name: 'Tiago Tecnico' }).click()
  await expect(page.getByTestId('agenda-only')).toContainText('Só de Tiago Tecnico')
  await expect(block(page, assigned.id)).toBeVisible()
  await expect(block(page, nobody.id)).toHaveCount(0)
  await expect(calendarDay(page, '2031-10-14')).toHaveAccessibleName(/tem serviço marcado/)
  await page.getByTestId('agenda-only').getByRole('button', { name: 'Mostrar todos' }).click()
  await expect(block(page, nobody.id)).toBeVisible()
  await expect(page.getByTestId('agenda-only')).toHaveCount(0)
})

test('passar semana e dia, voltar para hoje, escolher dia no mês, setas e T (agenda.step, agenda.today, agenda.day, agenda.toggle-month)', async ({ page }) => {
  await openAgenda(page, 'admin', 'd=2031-11-12')
  await page.getByRole('button', { name: 'Próxima semana' }).click()
  await expect(page).toHaveURL(/d=2031-11-19/)
  await page.getByRole('button', { name: 'Semana anterior' }).click()
  await expect(page).toHaveURL(/d=2031-11-12/)
  await page.getByRole('button', { name: 'Dia', exact: true }).click()
  await page.getByRole('button', { name: 'Próximo dia' }).click()
  await expect(page).toHaveURL(/d=2031-11-13/)
  await page.getByRole('button', { name: 'Próximo mês' }).click()
  await expect(page).toHaveURL(/d=2031-12-13/)
  await calendarDay(page, '2031-12-02').click()
  await expect(page).toHaveURL(/d=2031-12-02/)
  await page.locator('.page-title').click()
  await page.keyboard.press('ArrowLeft')
  await expect(page).toHaveURL(/d=2031-12-01/)
  await page.keyboard.press('t')
  await expect(page).not.toHaveURL(/d=/)
  await page.getByRole('button', { name: 'Semana', exact: true }).click()
  await page.getByRole('button', { name: /Próxima semana/ }).click()
  await page.getByRole('button', { name: /^Hoje/ }).click()
  await expect(page).not.toHaveURL(/d=/)
})

test('vazio, erro com tentar de novo e carregando sem vazio por baixo (agenda.view estados)', async ({ page }) => {
  await openAgenda(page, 'admin', 'd=2034-02-15')
  await expect(page.getByTestId('agenda-empty')).toContainText('Nenhuma OS agendada nesta semana')
  await page.route('**/v1/app/orders?**', (route) => route.abort())
  await page.getByRole('button', { name: 'Próxima semana' }).click()
  await page.getByRole('button', { name: 'Próximo mês' }).click()
  const error = page.getByRole('alert').filter({ hasText: 'Não deu para carregar a agenda.' })
  await expect(error).toBeVisible()
  await page.unroute('**/v1/app/orders?**')
  let release: () => void = () => {}
  const held = new Promise<void>((resolve) => (release = resolve))
  await page.route('**/v1/app/orders?**', async (route) => {
    await held
    await route.continue()
  })
  await error.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Carregando…' })).toBeVisible()
  await expect(page.getByTestId('agenda-empty')).toHaveCount(0)
  release()
  await expect(page.getByTestId('agenda-empty')).toBeVisible()
})

test('tirar o agendamento pela OS aberta da agenda some da agenda (order.schedule.clear)', async ({ page }) => {
  const order = await makeOrder('admin', { scheduledDate: '2031-12-16T13:00:00.000Z' })
  await openAgenda(page, 'admin', 'd=2031-12-16')
  await block(page, order.id).click()
  const details = panel(page).getByRole('region', { name: 'Detalhes' })
  await details.getByRole('button', { name: /16\/12, 10:00/ }).click()
  await page.getByRole('dialog', { name: 'Agendar dia e hora' }).getByRole('button', { name: 'Tirar agendamento' }).click()
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate ?? null).toBeNull()
  await expect(page.locator(`.tg [data-order="${order.id}"]`)).toHaveCount(0)
})

test('inglês e espanhol, formato do país mantido (agenda i18n)', async ({ page }) => {
  await makeOrder('admin', { scheduledDate: '2032-01-13T13:00:00.000Z' })
  await login(page, 'admin', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await page.goto('schedule?d=2032-01-13')
  await expect(page.getByRole('button', { name: 'Week', exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Next week' })).toBeVisible()
  await expect(page.locator('[data-head="2032-01-13"]')).toContainText('1 scheduled')
  // Brazilian company in English: the words are English, the dates keep the Brazilian format.
  await expect(page.getByTestId('agenda-summary')).toContainText('11 de jan. to 17 de jan.')
  await page.goto('settings')
  await page.getByLabel('Language').selectOption('es')
  await page.goto('schedule?d=2032-01-13')
  await expect(page.getByRole('button', { name: 'Semana siguiente' })).toBeVisible()
  await expect(page.locator('[data-head="2032-01-13"]')).toContainText('1 agendado')
})

test('celular de 320 px: faixa da semana, lista do dia, ver o mês, sem rolagem de lado', async ({ page }) => {
  const order = await makeOrder('admin', {
    scheduledDate: '2032-02-10T13:00:00.000Z',
    assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' },
  })
  await page.setViewportSize({ width: 320, height: 720 })
  await openAgenda(page, 'admin', 'd=2032-02-10')
  await expect(grid(page)).toHaveCount(0)
  const row = page.locator(`.ag-row[data-order="${order.id}"]`)
  await expect(row).toContainText('Cliente 02')
  await expect(row).toContainText('10:00')
  await expect(row).toContainText(`Aprovado · ${order.number}`)
  await expect(row).toContainText('Veículo 2 · com Tiago Tecnico')
  await expect(page.getByRole('heading', { level: 2, name: /ter\., 10 de fev\..*1 marcado/ })).toBeVisible()
  await expectNoSideScroll(page)
  await page.getByRole('button', { name: 'Ver o mês' }).click()
  await expect(calendarDay(page, '2032-02-10')).toHaveAccessibleName(/tem serviço marcado/)
  await expectNoSideScroll(page)
  await row.click()
  await expect(panel(page)).toBeVisible()
})

test('2560 px e texto a 200%: grade inteira e nada para o lado fora da grade', async ({ page }) => {
  await makeOrder('admin', { scheduledDate: '2032-03-09T13:00:00.000Z' })
  await page.setViewportSize({ width: 2560, height: 1300 })
  await openAgenda(page, 'admin', 'd=2032-03-09')
  await expect(page.locator('.tg-col')).toHaveCount(7)
  await expectNoSideScroll(page)
  await page.setViewportSize({ width: 1280, height: 800 })
  await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
  await expect(page.locator('.tg-col').first()).toBeVisible()
  await expectNoSideScroll(page, ['.list-pane'])
})

// Company B (United States) in one worker, in order: the test without scheduling turns
// useScheduling off on B for a moment, and the others there read it.
test.describe.serial('empresa B', () => {
  // Late orders go to company B: in A they would change the counts of the list tests running alongside.
  test('atrasada pela entrega, em vermelho, mesmo com visita marcada (agenda.row)', async ({ page }) => {
    const { id, number } = await makeOrderInB({ scheduledDate: '2031-05-13T14:30:00.000Z', dueDate: '2025-03-01T15:00:00.000Z' })
    await login(page, 'owner', 'schedule?d=2031-05-13&view=day')
    await chooseCompany(page, 'Beta Repairs')
    await expect(block(page, id)).toHaveAccessibleName(new RegExp(`^10:30 AM Dana Customer OS ${number} · Atrasada`))
    await expect(block(page, id)).toHaveClass(/is-late/)
  })

  test('formato do país da empresa: empresa dos EUA em 12 horas (agenda.view)', async ({ page }) => {
    // 14:30 UTC is 10:30 in New York (summer time in May).
    const { id } = await makeOrderInB({ scheduledDate: '2031-05-06T14:30:00.000Z' })
    await login(page, 'owner', 'schedule?d=2031-05-06&view=day')
    await chooseCompany(page, 'Beta Repairs')
    await expect(block(page, id)).toHaveAccessibleName(/^10:30 AM Dana Customer/)
    await expect(page.locator('.tg-hour', { hasText: /^1:00 PM$/ })).toBeVisible()
  })

  for (const theme of ['light', 'dark'] as const) {
    test(`axe sem violações na agenda, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
      // B, so the late one does not count in A's lists (see above).
      await makeOrderInB({ scheduledDate: '2032-04-13T13:00:00.000Z', dueDate: '2025-01-01T15:00:00.000Z' })
      await makeOrderInB({ scheduledDate: '2032-04-13T04:00:00.000Z' })
      await page.emulateMedia({ colorScheme: theme })
      await login(page, 'owner', 'schedule?d=2032-04-13')
      await chooseCompany(page, 'Beta Repairs')
      await expect(page.getByText('Carregando…')).toHaveCount(0)
      await setTheme(page, theme)
      await expect(grid(page)).toBeVisible()
      await expectNoAxeViolations(page, `agenda semana ${theme}`)
      await page.getByRole('button', { name: 'Dia', exact: true }).click()
      await expectNoAxeViolations(page, `agenda dia ${theme}`)
      await page.getByTestId('agenda-who').click()
      await expectNoAxeViolations(page, `agenda de quem ${theme}`)
      await page.keyboard.press('Escape')
      await page.setViewportSize({ width: 375, height: 800 })
      await expectNoAxeViolations(page, `agenda celular ${theme}`)
    })
  }

  test('sem agendamento na empresa, a agenda mostra as entregas, todas como Dia todo (agenda.mode-due)', async ({ page }) => {
    const { id } = await makeOrderInB({ dueDate: '2031-05-21T15:00:00.000Z' })
    await updateCompanyB({ useScheduling: false })
    try {
      await login(page, 'owner', 'schedule?d=2031-05-21')
      await chooseCompany(page, 'Beta Repairs')
      await expect(page.locator(`.tg-allday[data-allday="2031-05-21"] [data-order="${id}"]`)).toBeVisible()
      await expect(page.locator('.tg-col [data-order]')).toHaveCount(0)
      await page.getByRole('button', { name: 'Próxima semana' }).click()
      await expect(page.getByTestId('agenda-empty')).toContainText('Nenhuma OS com entrega nesta semana')
    } finally {
      await updateCompanyB({ useScheduling: true })
    }
  })
})
