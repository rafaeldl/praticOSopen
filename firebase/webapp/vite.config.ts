import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  base: '/app/',
  plugins: [vue()],
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
