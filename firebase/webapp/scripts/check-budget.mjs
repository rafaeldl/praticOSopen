// Fails the build when the first download grows past the budget. Reads the Vite
// manifest and measures brotli, the encoding Firebase Hosting serves.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { brotliCompressSync, constants } from 'node:zlib'

const INITIAL_LIMIT_KB = 200
const LIST_LIMIT_KB = 240

const dist = resolve(import.meta.dirname, '..', process.argv[2] ?? 'dist')
const manifest = JSON.parse(readFileSync(resolve(dist, '.vite/manifest.json'), 'utf8'))
const entries = Object.entries(manifest)

function findKey(test) {
  const found = entries.find(([key, item]) => test(key, item))
  if (!found) throw new Error(`Chunk não encontrado: ${test}`)
  return found[0]
}

/** A chunk and everything it imports statically. */
function closure(keys) {
  const seen = new Set()
  const visit = (key) => {
    if (seen.has(key)) return
    seen.add(key)
    for (const next of manifest[key]?.imports ?? []) visit(next)
  }
  keys.forEach(visit)
  return seen
}

const brotliBytes = (file) =>
  brotliCompressSync(readFileSync(resolve(dist, file)), {
    params: { [constants.BROTLI_PARAM_QUALITY]: 11 },
  }).length

function size(keys) {
  let total = 0
  const lines = []
  for (const key of closure(keys)) {
    const file = manifest[key].file
    if (!file.endsWith('.js')) continue
    const bytes = brotliBytes(file)
    total += bytes
    lines.push([bytes, file])
  }
  return { total, lines: lines.sort((a, b) => b[0] - a[0]) }
}

const kb = (bytes) => (bytes / 1024).toFixed(1)
const entry = findKey((_, item) => item.isEntry)
const pkg = (name) => findKey((key) => key.includes(`node_modules/${name}/`) && !key.includes('.css') && !key.includes('.woff'))

// What a first visit needs for the login screen: code, text and Auth.
const initial = size([entry, findKey((key) => key.endsWith('generated/i18n/pt.json')), pkg('firebase/app'), pkg('firebase/auth'), findKey((key) => key.endsWith('views/LoginView.vue'))])
// What an authenticated first visit downloads until the list shows.
const list = size([
  entry,
  findKey((key) => key.endsWith('generated/i18n/pt.json')),
  pkg('firebase/app'),
  pkg('firebase/auth'),
  pkg('firebase/firestore'),
  findKey((key) => key.endsWith('views/OrdersView.vue')),
])

const css = entries.filter(([, item]) => item.isEntry).flatMap(([, item]) => item.css ?? [])
const cssBytes = css.reduce((sum, file) => sum + brotliBytes(file), 0)

console.log(`Orçamento (brotli):`)
for (const [bytes, file] of initial.lines) console.log(`  ${kb(bytes).padStart(7)} KB  ${file}`)
console.log(`JS inicial (tela de entrada): ${kb(initial.total)} KB, limite ${INITIAL_LIMIT_KB} KB`)
console.log(`JS até a lista (com Firestore): ${kb(list.total)} KB, limite ${LIST_LIMIT_KB} KB`)
console.log(`CSS: ${kb(cssBytes)} KB`)

const failures = []
if (initial.total > INITIAL_LIMIT_KB * 1024) failures.push(`JS inicial passou de ${INITIAL_LIMIT_KB} KB`)
if (list.total > LIST_LIMIT_KB * 1024) failures.push(`JS até a lista passou de ${LIST_LIMIT_KB} KB`)
if (failures.length) {
  console.error(failures.join('\n'))
  process.exit(1)
}
