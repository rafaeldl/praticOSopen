// npm run gen: permissions and messages from their single sources.
// Output goes to src/generated/ (ignored by git, see docs/WEB_APP.md).
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { LOCALES, compileAll, keysModule, mergeWeb, messagesOf, permissionsModule, usedKeys } from './gen-lib.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const webapp = resolve(here, '..')
const repo = resolve(webapp, '../..')
const out = resolve(webapp, 'src/generated')
const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'))

const arb = Object.fromEntries(LOCALES.map((l) => [l, messagesOf(readJson(resolve(repo, `lib/l10n/app_${l}.arb`)))]))
const web = Object.fromEntries(LOCALES.map((l) => [l, messagesOf(readJson(resolve(webapp, `src/i18n/web_${l}.json`)))]))

const app = compileAll(arb, 'ARB')
const own = compileAll(web, 'web')
const problems = [...app.problems, ...own.problems]
const merged = {}
for (const locale of LOCALES) {
  const result = mergeWeb(app.compiled[locale], own.compiled[locale])
  merged[locale] = result.merged
  if (locale === LOCALES[0]) problems.push(...result.problems)
}

if (problems.length) {
  console.error(`gen falhou:\n- ${problems.join('\n- ')}`)
  process.exit(1)
}

// --prune (builds): only keys the code names. The app has 1.800 texts and the web
// uses a fraction, which is ~30 KB less in the first download. Keys are checked
// above before pruning, and t() takes literal keys, so a scan finds them all.
function sourceFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((item) => {
    if (item.name === 'generated') return []
    const path = resolve(dir, item.name)
    return item.isDirectory() ? sourceFiles(path) : /\.(ts|vue)$/.test(item.name) ? [path] : []
  })
}
const prune = process.argv.includes('--prune')
const files = sourceFiles(resolve(webapp, 'src'))
// Texts only one feature uses (its screens load on demand, i18n loadTexts) go to
// a file of their own per language, out of the list's first download. A text
// two features share goes to both; a text the rest of the app uses stays in the
// main file. Each feature is a set of folders under src/.
const FEATURES = {
  // Checklists ride with the orders: they open inside the order, and src/i18n/index.ts (first download) stays as is.
  orders: ['src/components/orders', 'src/components/forms', 'src/views/forms'],
  // Cadastros: customers, devices and the catalog share one chunk (src/i18n/index.ts stays as is).
  customers: ['src/components/customers', 'src/views/customers', 'src/components/catalog', 'src/views/catalog'],
  agenda: ['src/components/agenda', 'src/views/agenda'],
  finance: ['src/components/finance', 'src/views/finance', 'src/lib/finance', 'src/lib/nfse'],
}
const read = (list) => usedKeys(list.map((file) => readFileSync(file, 'utf8')))
const inFeature = (file, dirs) => dirs.some((dir) => file.startsWith(resolve(webapp, dir) + '/'))
const featureFiles = Object.fromEntries(Object.entries(FEATURES).map(([name, dirs]) => [name, files.filter((file) => inFeature(file, dirs))]))
const coreFiles = files.filter((file) => !Object.values(FEATURES).some((dirs) => inFeature(file, dirs)))
const keep = prune ? read(files) : null
const core = prune ? read(coreFiles) : null
const featureKeys = Object.fromEntries(
  Object.entries(featureFiles).map(([name, list]) => [name, prune ? new Set([...read(list)].filter((key) => !core.has(key))) : new Set()]),
)
const featureOnly = new Set(Object.values(featureKeys).flatMap((keys) => [...keys]))
const pick = (messages) =>
  keep
    ? Object.fromEntries(Object.entries(messages).filter(([key]) => (keep.has(key) || key.startsWith('web.')) && !featureOnly.has(key)))
    : messages
const pickFeature = (messages, name) => Object.fromEntries(Object.entries(messages).filter(([key]) => featureKeys[name].has(key)))

mkdirSync(resolve(out, 'i18n'), { recursive: true })
for (const locale of LOCALES) {
  writeFileSync(resolve(out, `i18n/${locale}.json`), JSON.stringify(pick(merged[locale])))
  for (const name of Object.keys(FEATURES)) {
    writeFileSync(resolve(out, `i18n/${locale}-${name}.json`), JSON.stringify(pickFeature(merged[locale], name)))
  }
}
writeFileSync(resolve(out, 'message-keys.ts'), keysModule(Object.keys(merged[LOCALES[0]])))
writeFileSync(
  resolve(out, 'permissions.ts'),
  permissionsModule(readJson(resolve(repo, 'firebase/functions/src/__tests__/rbac/app-permissions.json'))),
)
console.log(
  `gen: ${Object.keys(merged[LOCALES[0]]).length} textos em ${LOCALES.length} idiomas` +
    (prune ? `, ${Object.keys(pick(merged[LOCALES[0]])).length} no build` : '') +
    ', permissões ok',
)
