import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Each scene mounts itself on the Eleventy page. One ES module and one
// stylesheet per scene land in ../src/assets/stage/, which Eleventy copies
// as is; the built files are committed so the site build needs no Node step
// beyond Eleventy. An app build (not library mode) so the output is minified.
// Pages link assets/stage/shared.css and the scene's module (hero.js, tabs.js).
export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2020',
    outDir: '../src/assets/stage',
    emptyOutDir: true,
    modulePreload: false,
    rollupOptions: {
      input: { hero: 'scenes/hero/mount.tsx', tabs: 'scenes/tabs/mount.tsx' },
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name][extname]',
        // React, the kit and every scene's CSS go in one shared chunk
        // (shared.js, shared.css): the page links shared.css once and each
        // scene's entry stays a few KB
        manualChunks: (id) => (/scenes\/[^/]+\/mount\.tsx$/.test(id) ? undefined : 'shared'),
      },
    },
  },
  resolve: { dedupe: ['react', 'react-dom'] },
})
