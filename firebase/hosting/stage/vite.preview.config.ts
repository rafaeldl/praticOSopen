import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Local preview: preview/index.html shows each scene on the hero's navy band,
// at the widths the site uses, for filming with the Stageshow skill.
export default defineConfig({
  root: 'preview',
  plugins: [react()],
  server: { host: '127.0.0.1', port: 5174, strictPort: true, fs: { allow: ['..', '../..'] } },
  resolve: { dedupe: ['react', 'react-dom'] },
})
