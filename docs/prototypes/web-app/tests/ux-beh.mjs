import { chromium } from 'playwright'
const url = process.env.URL
const b = await chromium.launch()
const PH = { viewport:{width:390,height:844}, hasTouch:true, isMobile:true }
const R = {}
const open = async (o) => { const c = await b.newContext(o); const p = await c.newPage(); await p.goto(url); await p.waitForTimeout(250); return p }
{ const p = await open(PH)
  await p.goto(url+'#inicio'); await p.waitForTimeout(100); await p.goto(url+'#os'); await p.waitForTimeout(200)
  await p.getByText('Márcia Teles').first().click(); await p.waitForTimeout(250)
  R.openHash = await p.evaluate(()=>location.hash); await p.screenshot({path:'tests/ux/os-open.png'}); await p.screenshot({path:'tests/ux/os-open-full.png', fullPage:true})
  R.osOpenPrimary = await p.evaluate(()=>[...document.querySelectorAll('.btn--primary')].filter(e=>e.offsetParent).map(e=>e.innerText.trim()))
  R.osOpenBtns = await p.evaluate(()=>[...document.querySelectorAll('main button, .layer button')].filter(e=>e.offsetParent).map(e=>{const r=e.getBoundingClientRect();return [(e.getAttribute('aria-label')||e.innerText||'').trim().slice(0,26),Math.round(r.width),Math.round(r.height)]}).filter(x=>x[2]<44||x[1]<44).slice(0,30))
  await p.goBack(); await p.waitForTimeout(250); R.afterBack = await p.evaluate(()=>location.hash + ' | ' + (document.querySelector('h1')?.innerText||'') + ' | layerStillOpen=' + !!document.querySelector('.layer'))
  await p.goto(url+'#os'); await p.reload(); await p.waitForTimeout(250)
  await p.locator('.topbar button').last().click(); await p.waitForTimeout(250)
  R.newFs = await p.evaluate(()=>[...document.querySelectorAll('.layer input,.layer textarea,.layer select')].filter(e=>e.offsetParent).map(e=>[e.placeholder||e.getAttribute('aria-label')||e.id,e.type,e.inputMode,e.autocomplete,parseFloat(getComputedStyle(e).fontSize)]))
  R.focus = await p.evaluate(()=>document.activeElement?.tagName+':'+(document.activeElement?.placeholder||''))
  await p.keyboard.type('Pedro Novo'); await p.waitForTimeout(120)
  await p.screenshot({path:'tests/ux/new-typed.png'})
  const t0 = await p.evaluate(()=>document.querySelector('.layer')?1:0)
  await p.goBack(); await p.waitForTimeout(300)
  R.newOrderBack = { hadLayer:t0, url: await p.evaluate(()=>location.href.slice(-20)), layerAfter: await p.evaluate(()=>!!document.querySelector('.layer')), dialog: await p.evaluate(()=>document.querySelector('.layer h2')?.innerText||'') }
  await p.context().close() }
{ const p = await open(PH)
  await p.goto(url+'#clientes'); await p.reload(); await p.waitForTimeout(300)
  await p.getByText('Novo cliente').first().click({timeout:4000}).catch(e=>R.ncErr=String(e).slice(0,120)); await p.waitForTimeout(250); await p.screenshot({path:'tests/ux/new-customer.png'})
  R.newCustomer = await p.evaluate(()=>[...document.querySelectorAll('.layer input,.layer textarea,.layer select,main input')].filter(e=>e.offsetParent).slice(0,10).map(e=>[e.placeholder||e.getAttribute('aria-label')||e.id,e.type,e.inputMode,e.autocomplete,parseFloat(getComputedStyle(e).fontSize)]))
  await p.context().close()
  const q = await open(PH); await q.goto(url+'#receber'); await q.reload(); await q.waitForTimeout(300)
  await q.locator('main button').filter({hasText:/Receber|recebido/}).first().click({timeout:1500}).catch(()=>{}); await q.waitForTimeout(250); await q.screenshot({path:'tests/ux/receive.png'})
  R.receive = await q.evaluate(()=>[...document.querySelectorAll('.layer input,.layer select')].filter(e=>e.offsetParent).map(e=>[e.getAttribute('aria-label')||e.id,e.type,e.inputMode,parseFloat(getComputedStyle(e).fontSize)]))
  await q.context().close() }
{ const p = await open({viewport:{width:1366,height:768}})
  const titles={}; for (const s of ['inicio','os','agenda','clientes','notas']){ await p.goto(url+'#'+s); await p.waitForTimeout(120); titles[s]=await p.title() } R.titles=titles
  await p.goto(url+'#os'); await p.waitForTimeout(200)
  R.deskTiny = await p.evaluate(()=>{const m={};[...document.querySelectorAll('button,a[href],input,select,[role=tab]')].filter(e=>e.offsetParent).forEach(e=>{const r=e.getBoundingClientRect();if(r.height<28||r.width<28){const k=(e.className||e.tagName).toString().split(' ')[0];(m[k]||=[0,(e.getAttribute('aria-label')||e.innerText||'').slice(0,22),Math.round(r.width),Math.round(r.height)])[0]++}});return m})
  await p.context().close() }
{ const c=await b.newContext({viewport:{width:1366,height:768}}); const p=await c.newPage(); await p.goto(url+'#os'); await p.waitForTimeout(150)
  const w = await p.evaluate(async()=>{const f=[];return getComputedStyle(document.body).fontSize}); R.bodyDesk=w; await c.close() }
console.log(JSON.stringify(R,null,0)); await b.close()
