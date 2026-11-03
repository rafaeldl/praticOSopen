// npm run check:hosting: serves firebase/hosting/public with the real
// firebase.json in the Hosting emulator (demo project, own port) and checks that
// /app routes get the SPA with its headers while the site stays the same.
// Only static paths are requested: /q, /pro, /admin and /mcp go to Cloud Run or
// Functions, so they are checked in the config instead of over the network.
import { spawn } from 'node:child_process'
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const webapp = resolve(import.meta.dirname, '..')
const firebaseDir = resolve(webapp, '..')
const PORT = 15050
const tempConfig = resolve(firebaseDir, 'firebase.hosting-check.json')

const config = JSON.parse(readFileSync(resolve(firebaseDir, 'firebase.json'), 'utf8'))
const failures = []
const check = (ok, message) => {
  if (!ok) failures.push(message)
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${message}`)
}

// 1. Config: /app goes first and the old rewrites are untouched and in order.
const rewrites = config.hosting.rewrites.map((rule) => rule.source)
check(
  rewrites[0] === '/app' && config.hosting.rewrites[1].regex === '^/app/[^.]*$',
  'rewrites de /app vêm primeiro, só para caminhos sem extensão',
)
for (const source of ['/mcp/**', '/_nuxt/**', '/q/**', '/pro/**', '/admin', '/admin/**', '/api/admin/**', '/api/orders/**']) {
  check(rewrites.includes(source), `rewrite ${source} continua`)
}

for (const file of ['public/index.html', 'public/app/index.html']) {
  if (!existsSync(resolve(firebaseDir, 'hosting', file))) {
    console.error(`Falta hosting/${file}: rode o build do site e npm run build:hosting`)
    process.exit(1)
  }
}

// 2. Emulator, with only the port changed.
writeFileSync(tempConfig, JSON.stringify({ hosting: config.hosting, emulators: { hosting: { port: PORT }, ui: { enabled: false } } }))
const emulator = spawn(
  'npx',
  ['firebase', 'emulators:start', '--only', 'hosting', '--project', 'demo-praticos', '--config', tempConfig],
  { cwd: webapp, stdio: ['ignore', 'pipe', 'pipe'], detached: true },
)
let log = ''
emulator.stdout.on('data', (chunk) => (log += chunk))
emulator.stderr.on('data', (chunk) => (log += chunk))

async function waitUp() {
  for (let i = 0; i < 60; i++) {
    try {
      await fetch(`http://127.0.0.1:${PORT}/`)
      return
    } catch {
      await new Promise((r) => setTimeout(r, 500))
    }
  }
  throw new Error(`emulador não subiu:\n${log}`)
}

try {
  await waitUp()
  const get = (path) => fetch(`http://127.0.0.1:${PORT}${path}`, { redirect: 'manual' })
  const spa = readFileSync(resolve(firebaseDir, 'hosting/public/app/index.html'), 'utf8')
  const site = readFileSync(resolve(firebaseDir, 'hosting/public/index.html'), 'utf8')

  // /app is a folder in public/, so Hosting answers with a redirect to /app/.
  const bare = await get('/app')
  check(
    bare.status === 200 || (bare.status === 301 && bare.headers.get('location')?.endsWith('/app/')),
    '/app leva à SPA',
  )

  for (const path of ['/app/', '/app/orders', '/app/orders/x', '/app/orders?order=1', '/app/login']) {
    const response = await get(path)
    const body = await response.text()
    check(response.status === 200 && body === spa, `${path} serve a SPA`)
    check(response.headers.get('cache-control') === 'no-cache', `${path} com no-cache`)
    check((response.headers.get('content-security-policy') ?? '').includes("frame-ancestors 'none'"), `${path} com CSP`)
    check(response.headers.get('x-content-type-options') === 'nosniff', `${path} com nosniff`)
  }

  const asset = /\/app\/assets\/[^"]+\.js/.exec(spa)?.[0]
  const assetResponse = await get(asset)
  check(assetResponse.status === 200 && (await assetResponse.text()).length > 0, `${asset} existe`)
  check(assetResponse.headers.get('cache-control') === 'public, max-age=31536000, immutable', 'asset com cache imutável')

  // The CSP must let the page run: open the login screen in a browser, with every
  // request outside this machine blocked (this build carries the production config).
  const { chromium } = await import('@playwright/test')
  const browser = await chromium.launch()
  try {
    const page = await browser.newPage()
    const violations = []
    page.on('console', (message) => {
      if (/Content Security Policy|Refused to/i.test(message.text())) violations.push(message.text())
    })
    await page.route(/^https?:\/\/(?!127\.0\.0\.1)/, (route) => route.abort())
    await page.goto(`http://127.0.0.1:${PORT}/app/login`)
    const heading = await page.getByRole('heading', { level: 1 }).textContent({ timeout: 15000 }).catch(() => null)
    check(!!heading, `login renderiza com a CSP (${heading ?? 'nada'})`)
    check(violations.length === 0, `sem bloqueio da CSP${violations.length ? `: ${violations.join(' | ')}` : ''}`)
  } finally {
    await browser.close()
  }

  // An old domain sends /app to praticos.app with path, query and hash, before
  // Firebase loads. praticos.firebaseapp.com is pointed at this emulator (web.app is
  // HSTS-preloaded, so the browser would not ask it over http); praticos.app is stubbed.
  const old = 'praticos.firebaseapp.com'
  const legacy = await chromium.launch({ args: [`--host-resolver-rules=MAP ${old} 127.0.0.1`] })
  try {
    const page = await legacy.newPage()
    const outside = []
    await page.route('https://praticos.app/**', (route) => route.fulfill({ contentType: 'text/html', body: '<h1>novo</h1>' }))
    await page.route(/^https?:\/\/(?!127\.0\.0\.1|praticos\.firebaseapp\.com|praticos\.app\/)/, (route) => {
      outside.push(route.request().url())
      return route.abort()
    })
    await page.goto(`http://${old}:${PORT}/app/orders?order=1#x`)
    await page.waitForURL('https://praticos.app/**', { timeout: 10000 }).catch(() => {})
    check(page.url() === 'https://praticos.app/app/orders?order=1#x', `${old}/app vai para praticos.app (${page.url()})`)
    check(outside.length === 0, `sem carregar o Firebase antes de sair${outside.length ? `: ${outside.join(' | ')}` : ''}`)
    await page.goto(`http://${old}:${PORT}/`)
    check(page.url() === `http://${old}:${PORT}/`, `site em ${old} fica onde está`)
  } finally {
    await legacy.close()
  }

  // A tab from before a deploy asks for an old chunk: 404, never the index cached for a year.
  const gone = await get('/app/assets/index-ffffffff.js')
  const goneBody = await gone.text()
  check(gone.status === 404 && goneBody !== spa, 'asset que não existe dá 404')

  const home = await get('/')
  check(home.status === 200 && (await home.text()) === site, '/ continua sendo o site')
  check(!home.headers.get('content-security-policy'), '/ sem a CSP do app')
  const pricing = await get('/pricing')
  check(pricing.status === 301 && pricing.headers.get('location')?.endsWith('/'), '/pricing continua redirecionando')
  const robots = await get('/robots.txt')
  check(robots.status === 200 && robots.headers.get('cache-control') === 'public, max-age=3600', '/robots.txt igual')
} finally {
  // npx starts the emulator as a grandchild: stop the whole process group, or
  // its open pipes keep this script (and the CI job) alive after the checks.
  try {
    process.kill(-emulator.pid, 'SIGKILL')
  } catch {
    emulator.kill('SIGKILL')
  }
  emulator.stdout.destroy()
  emulator.stderr.destroy()
  rmSync(tempConfig, { force: true })
}

if (failures.length) {
  console.error(`\n${failures.length} falha(s)`)
  process.exit(1)
}
console.log('\nHosting ok')
process.exit(0)
