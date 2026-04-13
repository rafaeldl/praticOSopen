export default defineNuxtConfig({
  devtools: { enabled: true },
  ssr: true,
  modules: ['@nuxtjs/tailwindcss'],
  ignore: ['**/node_modules/**', '**/.git/**', '**/.nuxt/**', '**/.output/**'],
  watchers: {
    chokidar: {
      ignored: ['**/node_modules/**', '**/.git/**'],
      ignoreInitial: true,
    },
  },
  runtimeConfig: {
    apiBaseUrl: process.env.API_BASE_URL || 'https://southamerica-east1-praticos.cloudfunctions.net/api',
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL || 'https://southamerica-east1-praticos.cloudfunctions.net/api',
      firebaseConfig: {
        apiKey: 'AIzaSyCzd0yGNoLaj3KGkrACvLy4lP_ynAYcFms',
        authDomain: 'praticos.firebaseapp.com',
        projectId: 'praticos',
        storageBucket: 'praticos.appspot.com',
      },
    },
  },
  app: {
    head: {
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&family=Inter:wght@400;500;600;700&display=swap' },
        { rel: 'icon', type: 'image/png', href: '/logo.png' },
      ],
      meta: [
        { name: 'theme-color', content: '#FFFFFF' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
      ],
    },
  },
  tailwindcss: {
    cssPath: '~/assets/css/main.css',
  },
  routeRules: {
    '/pro/**': { swr: 3600 },
    '/admin/**': { ssr: false },
  },
  nitro: {
    externals: {
      external: ['firebase-admin'],
    },
    watchOptions: {
      ignored: ['**/node_modules/**', '**/.git/**'],
    },
  },
  compatibilityDate: '2025-01-01',
})
