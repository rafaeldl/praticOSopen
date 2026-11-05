// praticos.app is the main domain. /web opened on the old Hosting domains goes
// there with the same path, query and hash, before Firebase loads: sign-in by
// redirect only works on the authDomain's own site (Safari), and the session
// lives per origin. Only in the production build; dev, the emulator and the E2E
// build stay where they are. Its hash is in the CSP of firebase.json (check-csp).
import type { Plugin } from 'vite'

export const LEGACY_HOST_SCRIPT =
  "var h=location.hostname;if((h==='praticos.web.app'||h==='praticos.firebaseapp.com')&&/^\\/web(\\/|$)/.test(location.pathname))" +
  "location.replace('https://praticos.app'+location.pathname+location.search+location.hash)"

export function legacyHostRedirect(): Plugin {
  let production = false
  return {
    name: 'praticos-legacy-host',
    apply: 'build',
    configResolved(config) {
      production = config.mode === 'production'
    },
    transformIndexHtml: {
      order: 'pre',
      // Right after the charset, ahead of every other tag and download.
      handler(html) {
        if (!production) return html
        const charset = /<meta charset="utf-8" \/>/
        if (!charset.test(html)) throw new Error('index.html sem <meta charset="utf-8" />')
        return html.replace(charset, (tag) => `${tag}\n    <script>${LEGACY_HOST_SCRIPT}</script>`)
      },
    },
  }
}
