import { chromium } from 'playwright'
const url = process.env.URL || 'http://localhost:5199/'
const out = process.env.OUT || 'tests/shots'
import { mkdirSync } from 'fs'
mkdirSync(out, { recursive: true })
const b = await chromium.launch({ channel: undefined })
const SIZES = { n: [1366, 768], w: [1920, 1080] }
const SCREENS = ['inicio', 'os', 'quadro', 'agenda', 'receber', 'financeiro', 'clientes', 'notas', 'catalogo', 'importar', 'entrada']
const errors = []
for (const theme of ['light', 'dark']) for (const [sk, [w, h]] of Object.entries(SIZES)) {
  const c = await b.newContext({ viewport: { width: w, height: h } })
  await c.addInitScript((t) => localStorage.setItem('praticos-proto-prefs-3', JSON.stringify({ theme: t })), theme)
  const p = await c.newPage()
  p.on('pageerror', (e) => errors.push(e.message)); p.on('console', (m) => m.type() === 'error' && !/fonts\.g/.test(m.text()) && errors.push(m.text()))
  for (const s of SCREENS) {
    await p.goto(url + '#' + s); await p.reload(); await p.waitForTimeout(250)
    await p.screenshot({ path: `${out}/${s}-${sk}-${theme}.png` })
    const over = await p.evaluate(() => document.documentElement.scrollWidth > innerWidth)
    if (over) errors.push(`overflow ${s} ${sk} ${theme}`)
  }
  await p.goto(url + '#os'); await p.reload(); await p.waitForTimeout(200)
  await p.keyboard.press('Control+Enter'); await p.waitForTimeout(150)
  await p.screenshot({ path: `${out}/pagina-${sk}-${theme}.png` })
  await p.goto(url + '#os'); await p.reload(); await p.waitForTimeout(200)
  await p.keyboard.press('n'); await p.waitForTimeout(150)
  await p.keyboard.type('mar'); await p.waitForTimeout(100)
  await p.screenshot({ path: `${out}/nova-${sk}-${theme}.png` })
  await p.keyboard.press('Escape'); await p.keyboard.press('Escape'); await p.waitForTimeout(100)
  await p.keyboard.press('Control+k'); await p.waitForTimeout(100); await p.keyboard.type('onix')
  await p.waitForTimeout(100)
  await p.screenshot({ path: `${out}/paleta-${sk}-${theme}.png` })
  await c.close()
}
console.log('errors:', [...new Set(errors)])
await b.close()
