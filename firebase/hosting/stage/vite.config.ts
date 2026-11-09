import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Each scene mounts itself on the Eleventy page. One ES module and one
// stylesheet per scene land in ../src/assets/stage/, which Eleventy copies
// as is; the built files are committed so the site build needs no Node step
// beyond Eleventy. An app build (not library mode) so the output is minified.
export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2020',
    outDir: '../src/assets/stage',
    emptyOutDir: true,
    modulePreload: false,
    rollupOptions: {
      input: { hero: 'scenes/hero/mount.tsx' },
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name][extname]',
      },
    },
  },
  resolve: { dedupe: ['react', 'react-dom'] },
})
