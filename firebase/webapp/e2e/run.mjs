// npm run e2e: builds the app for the emulators, starts the Emulator Suite on
// demo-praticos, seeds it and runs Playwright. Nothing here reaches real Firebase.
// Env: E2E_ORDERS (orders to generate), E2E_ONLY (emulators), E2E_SKIP_BUILD, PW_ARGS,
// E2E_PORT_OFFSET (another worktree already uses the ports: every emulator and the
// page server move by this much, e.g. 100).
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'

const webapp = resolve(import.meta.dirname, '..')
const functionsDir = resolve(webapp, '../functions')
const only = process.env.E2E_ONLY ?? 'auth,firestore,storage,functions'
const perf = process.argv[2] === 'perf'
// `serve` leaves the suite up, seeded, for npm run dev.
const serve = process.argv[2] === 'serve'
const usesFunctions = only.includes('functions')

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: webapp, stdio: 'inherit', ...options })
  if (result.status !== 0) process.exit(result.status ?? 1)
}

if (usesFunctions && !existsSync(resolve(functionsDir, 'lib/index.js'))) {
  console.error('Functions sem build. Rode em firebase/functions: npm ci && npm run build')
  process.exit(1)
}

// Own ports: a copy of firebase.e2e.json and an .env.e2e.local for the build, both removed at the end.
const offset = Number(process.env.E2E_PORT_OFFSET ?? 0)
let config = '../firebase.e2e.json'
const generated = []
if (offset) {
  const base = JSON.parse(readFileSync(resolve(webapp, config), 'utf8'))
  const port = (name) => base.emulators[name].port
  for (const [name, value] of Object.entries(base.emulators)) if (value?.port) value.port += offset
  config = '../firebase.e2e.offset.json'
  writeFileSync(resolve(webapp, config), JSON.stringify(base, null, 2))
  writeFileSync(
    resolve(webapp, '.env.e2e.local'),
    [
      `VITE_API_BASE_URL=http://127.0.0.1:${port('functions')}/demo-praticos/southamerica-east1/api`,
      `VITE_EMULATOR_AUTH_PORT=${port('auth')}`,
      `VITE_EMULATOR_FIRESTORE_PORT=${port('firestore')}`,
      `VITE_EMULATOR_STORAGE_PORT=${port('storage')}`,
      '',
    ].join('\n'),
  )
  generated.push(resolve(webapp, config), resolve(webapp, '.env.e2e.local'))
  process.env.PW_PORT = String(4183 + offset)
  process.env.E2E_FIRESTORE_PORT = String(port('firestore'))
}
const cleanUp = () => generated.forEach((file) => rmSync(file, { force: true }))

if (!process.env.E2E_SKIP_BUILD && !serve) {
  const build = spawnSync('npm', ['run', 'build:e2e'], { cwd: webapp, stdio: 'inherit' })
  if (build.status !== 0) {
    cleanUp()
    process.exit(build.status ?? 1)
  }
}

// The functions bind secrets at load. Fake values, removed afterwards; a real
// local file is left alone (it is git-ignored and never read here).
const secretFile = resolve(functionsDir, '.secret.local')
const createdSecrets = usesFunctions && !existsSync(secretFile)
if (createdSecrets) {
  writeFileSync(
    secretFile,
    [
      `ASAAS_CREDENTIALS_KEY=${Buffer.alloc(32).toString('base64')}`,
      'REVENUECAT_WEBHOOK_AUTH=fake',
      'REVENUECAT_SECRET_API_KEY=fake',
      'SSR_API_SECRET=fake',
      'ANTHROPIC_API_KEY=fake',
      '',
    ].join('\n'),
  )
}

const test = serve
  ? `node -e "setInterval(() => {}, 1 << 30)"`
  : perf
    ? `E2E_PERF=1 ${process.env.PERF_COLD ? 'PERF_COLD=1 ' : ''}npx playwright test e2e/perf`
    : `npx playwright test ${process.env.PW_ARGS ?? ''}`

// Ctrl+C reaches the emulators too; stay alive to remove the fake secrets.
process.on('SIGINT', () => {})
const result = spawnSync(
  'npx',
  [
    'firebase',
    'emulators:exec',
    '--config',
    config,
    '--project',
    'demo-praticos',
    '--only',
    only,
    `node e2e/seed.mjs && ${test}`,
  ],
  { cwd: webapp, stdio: 'inherit' },
)

if (createdSecrets) rmSync(secretFile, { force: true })
cleanUp()
process.exit(result.status ?? 1)
