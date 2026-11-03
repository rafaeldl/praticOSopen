// npm run e2e: builds the app for the emulators, starts the Emulator Suite on
// demo-praticos, seeds it and runs Playwright. Nothing here reaches real Firebase.
// Env: E2E_ORDERS (orders to generate), E2E_ONLY (emulators), E2E_SKIP_BUILD, PW_ARGS.
import { spawnSync } from 'node:child_process'
import { existsSync, rmSync, writeFileSync } from 'node:fs'
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

if (!process.env.E2E_SKIP_BUILD && !serve) run('npm', ['run', 'build:e2e'])

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
    ? 'E2E_PERF=1 npx playwright test e2e/perf'
    : `npx playwright test ${process.env.PW_ARGS ?? ''}`

// Ctrl+C reaches the emulators too; stay alive to remove the fake secrets.
process.on('SIGINT', () => {})
const result = spawnSync(
  'npx',
  [
    'firebase',
    'emulators:exec',
    '--config',
    '../firebase.e2e.json',
    '--project',
    'demo-praticos',
    '--only',
    only,
    `node e2e/seed.mjs && ${test}`,
  ],
  { cwd: webapp, stdio: 'inherit' },
)

if (createdSecrets) rmSync(secretFile, { force: true })
process.exit(result.status ?? 1)
