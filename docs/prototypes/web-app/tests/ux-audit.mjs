import { chromium } from 'playwright'
import { writeFileSync } from 'fs'
const url = process.env.URL
const b = await chromium.launch()
const SCREENS = ['inicio','os','quadro','agenda','financeiro','receber','clientes','notas','catalogo','importar','entrada']
const out = {}
const collect = () => {
  const vis = (e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && r.bottom > 0 && r.top < innerHeight * 3 }
  const name = (e) => (e.getAttribute('aria-label') || e.innerText || e.title || e.placeholder || e.className || e.tagName).toString().trim().replace(/\s+/g,' ').slice(0,40)
  const targets = [...document.querySelectorAll('button,a[href],input,select,textarea,[role=button],[role=tab],[tabindex="0"],label.tick')].filter(vis)
  const small = targets.map(e => { const r = e.getBoundingClientRect(); return { n: name(e), w: Math.round(r.width), h: Math.round(r.height), c: (e.className||'').toString().split(' ')[0] } }).filter(t => t.h < 44 || t.w < 44)
  const fonts = {}
  const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
  while (w.nextNode()) { const t = w.currentNode; if (!t.textContent.trim()) continue; const e = t.parentElement; if (!vis(e)) continue; const f = Math.round(parseFloat(getComputedStyle(e).fontSize)*10)/10; (fonts[f] ||= []).push(t.textContent.trim().slice(0,28)) }
  const inputs = [...document.querySelectorAll('input:not([type=checkbox]):not([type=radio]),textarea,select')].filter(vis).map(e => ({ n: e.getAttribute('aria-label') || e.placeholder || e.name || e.id, t: e.type, im: e.inputMode, ac: e.autocomplete, fs: parseFloat(getComputedStyle(e).fontSize), lab: !!(e.labels?.length || e.getAttribute('aria-label') || e.getAttribute('aria-labelledby')) }))
  return {
    h1: [...document.querySelectorAll('h1')].filter(vis).map(e=>e.innerText.trim().slice(0,30)),
    primary: [...document.querySelectorAll('.btn--primary')].filter(vis).map(e=>e.innerText.trim().slice(0,30)),
    disabled: [...document.querySelectorAll('button:disabled')].filter(vis).map(name),
    kbd: [...document.querySelectorAll('kbd')].filter(vis).length,
    titleOnly: [...document.querySelectorAll('[title]')].filter(vis).length,
    small, fontsMin: Object.keys(fonts).map(Number).sort((a,b)=>a-b).slice(0,4).map(k => [k, fonts[k].length, fonts[k].slice(0,4)]),
    inputs, scrollW: document.documentElement.scrollWidth, iw: innerWidth,
    text: document.body.innerText,
  }
}
const ctx = async (o, prefs={}) => { const c = await b.newContext(o); await c.addInitScript((t) => localStorage.setItem('praticos-proto-prefs-3', JSON.stringify(t)), prefs); return c }
const PH = { viewport:{width:390,height:844}, hasTouch:true, isMobile:true }
for (const [label, opts] of [['phone',PH],['phone320',{...PH,viewport:{width:320,height:640}}],['tablet',{viewport:{width:820,height:1180},hasTouch:true,isMobile:true}],['desk',{viewport:{width:1366,height:768}}]]) {
  const c = await ctx(opts); const p = await c.newPage(); out[label] = {}
  for (const s of SCREENS) { await p.goto(url+'#'+s); await p.reload(); await p.waitForTimeout(220); out[label][s] = await p.evaluate(collect); if (label==='phone'||label==='tablet') await p.screenshot({path:`tests/ux/${label}-${s}.png`}) }
  await c.close()
}
// 200% text: root font doubled
out.zoom = {}
for (const [label, opts] of [['phone',PH],['desk',{viewport:{width:1366,height:768}}]]) {
  const c = await ctx(opts); const p = await c.newPage(); out.zoom[label] = {}
  for (const s of SCREENS) { await p.goto(url+'#'+s); await p.reload(); await p.waitForTimeout(150)
    await p.addStyleTag({content:'html{font-size:200%!important}'}); await p.waitForTimeout(120)
    const r = await p.evaluate(() => { const px = [...document.querySelectorAll('body *')].filter(e=>{const r=e.getBoundingClientRect();return r.right>innerWidth+2&&r.width>0&&r.width<innerWidth*1.5&&getComputedStyle(e).position!=='fixed'}).length
      const clipped=[...document.querySelectorAll('button,.nav-item,td,.btn')].filter(e=>e.scrollWidth>e.clientWidth+1&&getComputedStyle(e).overflow!=='visible').length
      return { sw: document.documentElement.scrollWidth, iw: innerWidth, px, clipped, rootPx: parseFloat(getComputedStyle(document.body).fontSize) } })
    out.zoom[label][s]=r; if (label==='phone' && ['os','inicio','financeiro'].includes(s)) await p.screenshot({path:`tests/ux/zoom-${s}.png`}); if (label==='desk'&&['os'].includes(s)) await p.screenshot({path:`tests/ux/zoomdesk-${s}.png`}) }
  await c.close()
}
// behaviours on phone
{
  const c = await ctx(PH); const p = await c.newPage(); const beh = {}
  await p.goto(url+'#os'); await p.reload(); await p.waitForTimeout(200)
  const before = await p.evaluate(()=>location.href)
  await p.locator('.tabbar button').nth(1).click(); await p.waitForTimeout(100)
  await p.locator('main button, main a, main [role=button], main li').filter({hasText:'OS'}).first().click({timeout:2000}).catch(()=>{}); await p.waitForTimeout(200)
  beh.afterOpen = await p.evaluate(()=>location.hash); await p.screenshot({path:'tests/ux/open.png'})
  await p.goBack(); await p.waitForTimeout(200); beh.afterBack = await p.evaluate(()=>location.hash)
  await p.goto(url+'#os'); await p.waitForTimeout(100)
  // new order, type, back: data lost?
  await p.locator('.topbar button').last().click().catch(()=>{}); await p.waitForTimeout(250); await p.screenshot({path:'tests/ux/new.png'})
  beh.newOrderDom = await p.evaluate(()=>[...document.querySelectorAll('.layer button, [role=dialog] button')].map(e=>(e.getAttribute('aria-label')||e.innerText).trim().slice(0,24)).slice(0,14))
  beh.layerHash = await p.evaluate(()=>location.hash)
  out.beh = beh; await c.close()
}
// contrast media & forced colors
{ const c = await b.newContext({viewport:{width:1366,height:768},forcedColors:'active'}); const p = await c.newPage(); await p.goto(url+'#os'); await p.waitForTimeout(200); await p.screenshot({path:'tests/ux/forced.png'}); await c.close() }
writeFileSync('tests/ux/audit.json', JSON.stringify(out))
await b.close()
