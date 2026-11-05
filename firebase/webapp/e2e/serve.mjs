// Serves dist-e2e like Firebase Hosting will: brotli, long cache for hashed
// assets, /web/** rewritten to index.html. vite preview sends plain files, which
// made the network numbers of the tests look 3 times worse than production.
import { readFile } from 'node:fs/promises'
import { createServer } from 'node:http'
import { extname, normalize, resolve } from 'node:path'
import { brotliCompressSync, constants } from 'node:zlib'

const root = resolve(import.meta.dirname, '../dist-e2e')
const port = Number(process.argv[2] ?? 4183)
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.woff2': 'font/woff2',
}
const cache = new Map()

async function load(path) {
  if (!cache.has(path)) {
    const raw = await readFile(path)
    const compressible = extname(path) !== '.woff2'
    cache.set(path, {
      body: compressible ? brotliCompressSync(raw, { params: { [constants.BROTLI_PARAM_QUALITY]: 9 } }) : raw,
      compressed: compressible,
    })
  }
  return cache.get(path)
}

createServer(async (request, response) => {
  const { pathname } = new URL(request.url, 'http://localhost')
  if (!pathname.startsWith('/web')) {
    response.writeHead(404).end()
    return
  }
  const relative = normalize(pathname.replace(/^\/web\/?/, '') || 'index.html')
  let path = resolve(root, relative)
  if (!path.startsWith(root) || !extname(path)) path = resolve(root, 'index.html')
  try {
    const file = await load(path)
    response.writeHead(200, {
      'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': pathname.includes('/assets/') ? 'public, max-age=31536000, immutable' : 'no-cache',
      ...(file.compressed ? { 'Content-Encoding': 'br' } : {}),
    })
    response.end(file.body)
  } catch {
    response.writeHead(404).end()
  }
}).listen(port, '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${port}/web/`))
