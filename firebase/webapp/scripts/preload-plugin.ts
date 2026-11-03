// Starts the startup chunks with the HTML instead of after the entry runs.
// Auth is always needed. Firestore and the list screen only for someone who
// already has a session, so the login screen does not download them.
import type { Plugin } from 'vite'

interface ChunkLike {
  type: string
  fileName: string
  facadeModuleId?: string | null
  imports?: string[]
}

function chunkFiles(bundle: Record<string, ChunkLike>, test: (id: string) => boolean): string[] {
  const chunks = Object.values(bundle).filter((item): item is ChunkLike => item.type === 'chunk')
  const byName = new Map(chunks.map((chunk) => [chunk.fileName, chunk]))
  const found = new Set<string>()
  const visit = (file: string) => {
    if (found.has(file)) return
    found.add(file)
    byName.get(file)?.imports?.forEach(visit)
  }
  chunks.filter((chunk) => chunk.facadeModuleId && test(chunk.facadeModuleId)).forEach((chunk) => visit(chunk.fileName))
  return [...found]
}

/** Someone with a saved session gets Firestore (and the list, on /app/orders) preloaded. */
export const PRELOAD_SCRIPT =
  "try{if(Object.keys(localStorage).some(function(k){return k.indexOf('firebase:authUser:')===0})){" +
  "var m=function(n){var e=document.querySelector('meta[name=\"'+n+'\"]');return e&&e.content?e.content.split(' '):[]};" +
  "var f=m('praticos-preload-session');if(/^\\/app\\/orders\\/?$/.test(location.pathname))f=f.concat(m('praticos-preload-orders'));" +
  "f.forEach(function(h){var l=document.createElement('link');l.rel='modulepreload';l.href=h;document.head.appendChild(l)})}}catch(e){}"

export function preloadCritical(base: string): Plugin {
  return {
    name: 'praticos-preload-critical',
    apply: 'build',
    transformIndexHtml: {
      order: 'post',
      handler(_html, context) {
        const bundle = context.bundle as unknown as Record<string, ChunkLike> | undefined
        if (!bundle) return []
        const entry = Object.values(bundle).find((item) => (item as { isEntry?: boolean }).isEntry)?.fileName
        const skip = new Set([entry, ...((entry && (bundle[entry]?.imports ?? [])) || [])])
        const url = (file: string) => `${base}${file}`
        const always = chunkFiles(bundle, (id) => /node_modules\/firebase\/(app|auth)\//.test(id)).filter((file) => !skip.has(file))
        const session = chunkFiles(bundle, (id) => /node_modules\/firebase\/firestore\//.test(id)).filter(
          (file) => !skip.has(file) && !always.includes(file),
        )
        const list = chunkFiles(bundle, (id) => id.endsWith('/views/OrdersView.vue')).filter(
          (file) => !skip.has(file) && !always.includes(file) && !session.includes(file),
        )
        // The script is the same on every build (its CSP hash is in firebase.json);
        // the file names travel in meta tags.
        return [
          ...always.map((file) => ({
            tag: 'link',
            attrs: { rel: 'modulepreload', crossorigin: '', href: url(file) },
            injectTo: 'head' as const,
          })),
          { tag: 'meta', attrs: { name: 'praticos-preload-session', content: session.map(url).join(' ') }, injectTo: 'head' as const },
          { tag: 'meta', attrs: { name: 'praticos-preload-orders', content: list.map(url).join(' ') }, injectTo: 'head' as const },
          { tag: 'script', children: PRELOAD_SCRIPT, injectTo: 'head' as const },
        ]
      },
    },
  }
}
