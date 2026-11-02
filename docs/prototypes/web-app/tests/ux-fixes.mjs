import { chromium } from 'playwright'
const url = process.env.URL
const b = await chromium.launch()
let pass = 0; const fails = []
const check = (n, ok, x = '') => { ok ? pass++ : fails.push(n + ' ' + x); console.log(ok ? 'ok  ' : 'FAIL', n, ok ? '' : x) }
const PH = { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true }
const TB = { viewport: { width: 820, height: 1180 }, hasTouch: true, isMobile: true }
const DK = { viewport: { width: 1366, height: 768 } }
async function pg(o, h) { const c = await b.newContext(o); const p = await c.newPage(); p.setDefaultTimeout(5000); p.on('pageerror', (e) => fails.push('pageerror ' + e.message)); await p.goto(url + '#' + h); await p.reload(); await p.waitForTimeout(300); return p }
const hash = (p) => p.evaluate(() => location.hash)
const nav = (p, i) => p.locator('.tabbar button').nth(i).click()

{ // 1 price replaces, never adds
  const p = await pg(DK, 'catalogo'); const i = p.getByLabel('Preço de Troca de óleo e filtro')
  await i.click(); await p.waitForTimeout(40); await p.keyboard.type('100'); await p.keyboard.press('Tab'); await p.waitForTimeout(80)
  check('catalog: typing replaces the price', (await i.inputValue()) === '100,00', await i.inputValue())
  await i.click(); await p.waitForTimeout(40); await p.keyboard.type('1500.50'); await p.keyboard.press('Tab'); await p.waitForTimeout(80)
  check('catalog: dot as decimal', (await i.inputValue()) === '1.500,50', await i.inputValue())
  await i.click(); await p.waitForTimeout(40); await p.keyboard.type('abc7'); await p.keyboard.press('Tab'); await p.waitForTimeout(80)
  check('catalog: letters are dropped', (await i.inputValue()) === '7,00', await i.inputValue())
  await p.goto(url + '#os'); await p.reload(); await p.waitForTimeout(250)
  await p.keyboard.press('n'); await p.waitForTimeout(150); await p.keyboard.type('mar'); await p.waitForTimeout(80); await p.keyboard.press('Enter'); await p.waitForTimeout(100); await p.keyboard.press('Enter'); await p.waitForTimeout(100)
  await p.keyboard.type('Serviço xyz'); await p.waitForTimeout(100)
  check('own service reads as this OS', await p.getByText('+ Usar “Serviço xyz” nesta OS').isVisible())
  await p.keyboard.press('Enter'); await p.waitForTimeout(150)
  const f = p.locator('.drawer-items input'); check('new item: cursor goes to the value', await f.evaluate((e) => e === document.activeElement))
  await p.keyboard.type('150'); await p.keyboard.press('Tab'); await p.waitForTimeout(80)
  check('new order: 150 stays 150', (await p.locator('.drawer-foot .hint').innerText()).includes('150,00'), await p.locator('.drawer-foot .hint').innerText())
  await p.keyboard.press('Control+Enter'); await p.waitForTimeout(150)
  check('toast has no timing', /OS \d+ criada$/.test((await p.locator('.toast span').first().innerText()).trim()))
  await p.context().close()
}
{ // 2 and 3 dates on the phone
  const p = await pg(PH, 'os'); await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(300)
  const t = await p.evaluate(() => document.body.innerText)
  check('no word Entrada or Prazo', !/\bEntrada\b|\bPrazo\b|Fica pronta/.test(t))
  check('names are clear', t.includes('Quando chega') && t.includes('Prometido para') && t.includes('Prometida para'))
  const gap = await p.evaluate(() => { const e = document.querySelector('.od-device'); const r = document.createRange(); r.selectNodeContents(e.firstChild); return e.querySelector('.num').getBoundingClientRect().left - r.getBoundingClientRect().right })
  check('space between model and plate', gap > 2, gap)
  await p.getByRole('button', { name: 'hoje, 08:00' }).click(); await p.waitForTimeout(250)
  const a = await p.evaluate(() => [document.activeElement.id, document.activeElement.type, document.activeElement.value])
  check('date field gets focus with native picker', a[0] === 'od-when' && a[1] === 'datetime-local' && a[2].startsWith('2026-11-02T08'), a.join())
  check('no Enter hint on touch', !(await p.evaluate(() => document.body.innerText)).includes('Enter'))
  await p.locator('#od-when').fill('2026-11-03T18:00'); await p.getByRole('button', { name: 'Salvar' }).click(); await p.waitForTimeout(200)
  check('later visit asks about the promised date', await p.getByText('Mudar a data prometida também?').isVisible())
  await p.getByRole('button', { name: 'Mudar a data', exact: true }).click(); await p.waitForTimeout(250)
  check('promised date opens to edit', (await p.evaluate(() => document.activeElement.id)) === 'od-when')
  await p.context().close()
}
{ // 4 back
  const p = await pg(PH, 'inicio')
  await nav(p, 1); await p.waitForTimeout(150); await nav(p, 2); await p.waitForTimeout(150)
  await p.goBack(); await p.waitForTimeout(200); check('back returns to the previous tab', (await hash(p)) === '#os', await hash(p))
  await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(250)
  check('order open', await p.locator('.od-top').first().isVisible())
  await p.goBack(); await p.waitForTimeout(250)
  check('back closes the order, keeps the list', (await p.locator('.od-top').count()) === 0 && await p.locator('.list-pane').isVisible() && (await hash(p)) === '#os')
  await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(250)
  await p.getByRole('button', { name: 'Voltar', exact: true }).first().click(); await p.waitForTimeout(250)
  check('arrow closes the order', (await p.locator('.od-top').count()) === 0)
  await p.goBack(); await p.waitForTimeout(250)
  check('no dead back press after the arrow', (await hash(p)) === '#inicio', await hash(p))
  await nav(p, 1); await p.waitForTimeout(150)
  await p.locator('.topbar-add').click(); await p.waitForTimeout(250); await p.keyboard.type('Pedro Novo'); await p.waitForTimeout(100); await p.getByText('+ Cadastrar').click(); await p.waitForTimeout(200)
  await p.goBack(); await p.waitForTimeout(250)
  check('back on typed data asks first', await p.getByText('Descartar esta OS?').isVisible() && await p.locator('.layer-title', { hasText: 'Nova OS' }).isVisible())
  await p.getByRole('button', { name: 'Continuar' }).click(); await p.waitForTimeout(150)
  await p.goBack(); await p.waitForTimeout(250)
  await p.getByRole('button', { name: 'Descartar' }).click(); await p.waitForTimeout(250)
  check('discard closes, stays on the list', (await p.locator('.layer').count()) === 0 && (await hash(p)) === '#os', await hash(p))
  await p.goBack(); await p.waitForTimeout(300)
  check('stale entries are skipped', (await hash(p)) !== '#os' || (await p.locator('.layer').count()) === 0)
  await p.context().close()
  const q = await pg(DK, 'os'); await q.keyboard.press('Control+Enter'); await q.waitForTimeout(200)
  check('full page has its own address', /^#os\/\d+\/pagina$/.test(await hash(q)), await hash(q))
  await q.reload(); await q.waitForTimeout(300)
  check('that address reopens the order', await q.locator('.od--page').isVisible())
  await q.context().close()
}
{ // 5, 8 touch targets on phone and tablet
  for (const [label, o] of [['phone', PH], ['tablet', TB]]) {
    const p = await pg(o, 'os'); await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(300)
    const small = await p.evaluate(() => [...document.querySelectorAll('.od button:not(.proto-sim), .od input:not([type=file])')].filter((e) => e.offsetParent && !e.closest('.od-actions .x')).map((e) => { const r = e.getBoundingClientRect(); return [(e.getAttribute('aria-label') || e.innerText || e.className).slice(0, 24), Math.round(r.width), Math.round(r.height)] }).filter((x) => x[2] < 44 || x[1] < 44))
    check(label + ': OS targets at least 44', small.length === 0, JSON.stringify(small.slice(0, 8)))
    await p.goto(url + '#clientes'); await p.reload(); await p.waitForTimeout(250)
    check(label + ': no keyboard hints', (await p.evaluate(() => [...document.querySelectorAll('kbd')].filter((k) => k.offsetParent).length)) === 0)
    await p.context().close()
  }
}
{ // 6, 7 message and link
  const p = await pg(DK, 'os'); await p.getByText('Joel Fagundes').first().click(); await p.waitForTimeout(250)
  await p.keyboard.press('m'); await p.waitForTimeout(200)
  check('message says how it is going', (await p.locator('#send-text').inputValue()).includes('está assim: aprovada'), await p.locator('#send-text').inputValue())
  await p.getByRole('button', { name: 'Copiar mensagem' }).click(); await p.waitForTimeout(200)
  check('copying is not sent', await p.getByText('Mensagem copiada, falta mandar').isVisible())
  await p.getByRole('button', { name: 'Já mandei' }).click(); await p.waitForTimeout(150)
  check('confirmed as sent', await p.locator('.track').getByText('Enviado').isVisible())
  await p.locator('.price-btn').first().click(); await p.waitForTimeout(60); await p.keyboard.type('160'); await p.keyboard.press('Enter'); await p.waitForTimeout(150)
  check('value change warns about the link', await p.getByText(/O valor mudou. O cliente ainda vê R\$\s140,00/).isVisible())
  await p.getByRole('button', { name: 'Mandar de novo' }).click(); await p.waitForTimeout(150); await p.getByRole('button', { name: 'Copiar mensagem' }).click(); await p.waitForTimeout(150)
  check('resending clears the warning', (await p.getByText('O valor mudou').count()) === 0)
  await p.context().close()
}
{ // 9 one yellow
  const p = await pg(DK, 'os'); await p.getByText('Joel Fagundes').first().click(); await p.waitForTimeout(250)
  const y = await p.evaluate(() => [...document.querySelectorAll('.btn--primary')].filter((e) => e.offsetParent).length)
  check('one yellow button with the panel open', y === 1, y)
  await p.context().close()
}
{ // 10 the phone button says what it does
  const p = await pg(PH, 'clientes'); check('top button named', (await p.locator('.topbar-add').innerText()).includes('Nova OS')); await p.context().close()
  const q = await pg({ ...PH, viewport: { width: 320, height: 640 } }, 'clientes'); check('fits at 320', await q.evaluate(() => document.documentElement.scrollWidth <= innerWidth)); await q.context().close()
}
{ // 11 200% text
  for (const [label, o] of [['phone', PH], ['desk', DK]]) for (const s of ['inicio', 'os', 'quadro', 'agenda', 'financeiro', 'receber', 'clientes', 'notas', 'catalogo', 'importar']) {
    const p = await pg(o, s); await p.addStyleTag({ content: 'html{font-size:200%!important}' }); await p.waitForTimeout(150)
    const w = await p.evaluate(() => { const m = document.querySelector('.home') || document.querySelector('.main'); return [document.documentElement.scrollWidth, innerWidth, m ? m.scrollWidth : 0, m ? m.clientWidth : 0, Math.round(document.querySelector('.topbar-add').getBoundingClientRect().right)] })
    check(`200% ${label} ${s}`, w[0] <= w[1] && w[2] <= w[3] + 1 && w[4] <= w[1], w.join())
    if (label === 'phone') { const lap = await p.evaluate(() => { const l = [...document.querySelectorAll('.tabbar span:not(.count)')].map((e) => { const r = document.createRange(); r.selectNodeContents(e); return r.getBoundingClientRect() }); return l.some((a, i) => l[i + 1] && a.right > l[i + 1].left) }); check(`tabs do not overlap ${s}`, !lap) }
    await p.context().close()
  }
}
{ // 12 sizes on the phone
  const p = await pg(PH, 'os')
  const f = await p.evaluate(() => [parseFloat(getComputedStyle(document.body).fontSize), parseFloat(getComputedStyle(document.querySelector('.grid .sub')).fontSize)])
  check('phone text 17 and 15', f[0] === 17 && f[1] === 15, f.join())
  await p.goto(url + '#inicio'); await p.reload(); await p.waitForTimeout(250)
  check('primary button 52', (await p.locator('.btn--primary').first().boundingBox()).height >= 52)
  await p.context().close()
}
{ // 13 undo stays, 14 no default method, 15 menu
  const p = await pg(DK, 'os'); await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(200)
  await p.getByRole('button', { name: /^Tirar / }).first().click(); await p.waitForTimeout(100); await p.waitForTimeout(7600)
  check('undo does not vanish', await p.locator('.toast .link').isVisible())
  await p.getByRole('button', { name: 'Fechar aviso' }).click(); await p.waitForTimeout(80); check('notice closes by hand', (await p.locator('.toast').count()) === 0)
  await p.goto(url + '#receber'); await p.reload(); await p.waitForTimeout(250)
  await p.getByRole('checkbox', { name: 'Selecionar OS 1200' }).check(); await p.locator('[data-page-title]').focus(); await p.keyboard.press('r'); await p.waitForTimeout(120)
  check('no payment method chosen for you', (await p.locator('.layer fieldset [aria-pressed="true"]').count()) === 0)
  await p.getByRole('button', { name: /Marcar como recebido/ }).last().click(); await p.waitForTimeout(100)
  check('asks how it was paid', await p.getByText('Escolha como o cliente pagou.').isVisible())
  await p.locator('.layer').getByRole('button', { name: 'Dinheiro' }).click(); await p.getByRole('button', { name: /Marcar como recebido/ }).last().click(); await p.waitForTimeout(150)
  check('then receives', await p.getByText(/Recebido R\$/).first().isVisible())
  await p.goto(url + '#notas'); await p.reload(); await p.waitForTimeout(250)
  check('rare settings left the top', (await p.getByText('Quando emitir').count()) === 0)
  await p.getByRole('button', { name: 'Mais ações' }).click(); await p.waitForTimeout(100); await p.getByRole('button', { name: /Quando emitir/ }).click(); await p.waitForTimeout(150); await p.getByRole('button', { name: 'Quando a OS for paga' }).click(); await p.waitForTimeout(120)
  await p.getByRole('button', { name: 'Mais ações' }).click(); await p.waitForTimeout(100)
  check('setting is kept', await p.getByText('Quando emitir: Quando a OS for paga').isVisible())
  await p.context().close()
}
{
  const c = await b.newContext({ viewport: { width: 1366, height: 768 } }); const p = await c.newPage()
  await p.goto(url + '#entrada'); await p.reload(); await p.waitForTimeout(150)
  await p.getByRole('button', { name: /Criar conta|Continuar com|Entrar/ }).first().click(); await p.waitForTimeout(150)
  await p.getByRole('button', { name: 'Continuar' }).click(); await p.waitForTimeout(150)
  check('first access explains OS', (await p.locator('.entry-form').innerText()).includes('OS é a ordem de serviço'))
  await c.close()
}
console.log(`\n${pass} passed, ${fails.length} failed`); fails.forEach((f) => console.log(' -', f));
await b.close()
