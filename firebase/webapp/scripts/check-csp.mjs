// Every inline script of the built index.html must be allowed by its hash in the
// CSP of firebase.json, or the browser blocks it in production. Fails the build
// and prints the hashes to paste when an inline script changes.
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const webapp = resolve(import.meta.dirname, '..')
const html = readFileSync(resolve(webapp, process.argv[2] ?? 'dist', 'index.html'), 'utf8')
const hosting = JSON.parse(readFileSync(resolve(webapp, '../firebase.json'), 'utf8')).hosting
const csp = hosting.headers
  .filter((rule) => rule.source === '/app/**')
  .flatMap((rule) => rule.headers)
  .find((header) => header.key === 'Content-Security-Policy')?.value ?? ''

if (!csp) console.error('firebase.json sem Content-Security-Policy em /app/**')

const inline = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g)].map((match) => match[1])
const hashes = inline.map((code) => `'sha256-${createHash('sha256').update(code, 'utf8').digest('base64')}'`)
const missing = hashes.filter((hash) => !csp.includes(hash))

if (missing.length) {
  console.error(`CSP: scripts inline sem hash em firebase.json (script-src):\n  ${missing.join('\n  ')}`)
  process.exit(1)
}
console.log(`CSP: ${hashes.length} scripts inline liberados por hash`)
