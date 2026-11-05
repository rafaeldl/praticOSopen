// npm run build:hosting: puts the built SPA at firebase/hosting/public/web,
// where firebase.json serves /app. Run after the site build (Eleventy writes public/).
import { cpSync, existsSync, rmSync } from 'node:fs'
import { resolve } from 'node:path'

const webapp = resolve(import.meta.dirname, '..')
const from = resolve(webapp, 'dist')
const to = resolve(webapp, '../hosting/public/web')

if (!existsSync(resolve(from, 'index.html'))) {
  console.error('dist/index.html não existe: rode npm run build antes')
  process.exit(1)
}
rmSync(to, { recursive: true, force: true })
// The Vite manifest is only for the budget check.
cpSync(from, to, { recursive: true, filter: (path) => !path.includes('/.vite') })
console.log(`SPA copiada para ${to}`)
