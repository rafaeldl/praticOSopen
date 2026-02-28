import type { Config } from 'tailwindcss'

export default {
  darkMode: ['selector', '[data-theme="dark"]'],
  content: [
    './components/**/*.{js,vue,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './composables/**/*.{js,ts}',
    './plugins/**/*.{js,ts}',
    './app.vue',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#4A9BD9',
          'primary-light': '#6BB3E9',
          'primary-dark': '#3A7BB9',
          yellow: '#FFE600',
          orange: '#F5A623',
        },
        status: {
          quote: '#4A9BD9',
          'quote-bg': 'rgba(74, 155, 217, 0.15)',
          approved: '#34C759',
          'approved-bg': 'rgba(52, 199, 89, 0.15)',
          progress: '#FF9500',
          'progress-bg': 'rgba(255, 149, 0, 0.15)',
          done: '#248A3D',
          'done-bg': 'rgba(36, 138, 61, 0.15)',
          canceled: '#FF3B30',
          'canceled-bg': 'rgba(255, 59, 48, 0.15)',
        },
      },
      fontFamily: {
        heading: ['Outfit', 'sans-serif'],
        body: ['DM Sans', 'sans-serif'],
      },
      animation: {
        'fade-in-up': 'fadeInUp 0.5s ease forwards',
        'pulse-dot': 'pulseDot 2s ease-in-out infinite',
      },
      keyframes: {
        fadeInUp: {
          from: { opacity: '0', transform: 'translateY(20px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        pulseDot: {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.6', transform: 'scale(0.9)' },
        },
      },
    },
  },
  plugins: [],
} satisfies Config
