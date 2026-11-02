// Turns the single-file build into the page fragment the Artifact publisher wraps.
import { readFileSync, writeFileSync } from 'fs'
const html = readFileSync('dist/index.html', 'utf8')
const head = html.match(/<head>([\s\S]*)<\/head>/)[1].replace(/<meta charset[^>]*>\s*/, '').replace(/<meta name="viewport"[^>]*>\s*/, '')
const body = html.match(/<body>([\s\S]*)<\/body>/)[1]
writeFileSync('dist/artifact.html', head + body)
console.log('artifact.html', Math.round((head + body).length / 1024), 'KB')
