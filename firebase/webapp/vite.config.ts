import { execSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'
import { legacyHostRedirect } from './scripts/legacy-host-plugin'
import { preloadCritical } from './scripts/preload-plugin'

const BASE = '/web/'

/** Version of this web build (settings.more-view): build day and commit, e.g. "2026.11.03 (3bc8283)". */
function buildVersion(): string {
  const day = new Date().toISOString().slice(0, 10).replaceAll('-', '.')
  let commit = process.env.GITHUB_SHA?.slice(0, 7) ?? ''
  if (!commit) {
    try {
      commit = execSync('git rev-parse --short HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim()
    } catch {
      commit = 'local'
    }
  }
  return `${day} (${commit})`
}

export default defineConfig({
  base: BASE,
  plugins: [vue(), legacyHostRedirect(), preloadCritical(BASE)],
  define: { __WEB_VERSION__: JSON.stringify(buildVersion()) },
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  // tokens.css lives in firebase/hosting and the contracts in the repo root.
  server: { fs: { allow: ['../..'] } },
  // Message catalogs: JSON.parse of one string, without an export per key.
  json: { stringify: true },
  build: { manifest: true, target: 'es2022' },
  test: {
    environment: 'happy-dom',
    include: ['tests/**/*.test.ts'],
    restoreMocks: true,
    // Formatting must not depend on the machine running the tests.
    env: { TZ: 'America/Sao_Paulo' },
  },
})
