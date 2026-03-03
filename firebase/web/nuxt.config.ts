export default defineNuxtConfig({
  devtools: { enabled: true },
  ssr: true,
  modules: ['@nuxtjs/tailwindcss'],
  runtimeConfig: {
    apiBaseUrl: process.env.API_BASE_URL || 'https://southamerica-east1-praticos.cloudfunctions.net/api',
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL || 'https://southamerica-east1-praticos.cloudfunctions.net/api',
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
  },
  nitro: {
    externals: {
      external: ['firebase-admin'],
    },
  },
  compatibilityDate: '2025-01-01',
})
