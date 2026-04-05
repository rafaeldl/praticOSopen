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
          primary: '#2563EB',
          'primary-light': '#3B82F6',
          'primary-dark': '#1D4ED8',
          yellow: '#F59E0B',
        },
        verified: {
          green: '#16A34A',
          'green-bg': '#DCFCE7',
        },
        'blue-bg': '#EFF6FF',
        status: {
          quote: '#2563EB',
          'quote-bg': 'rgba(37, 99, 235, 0.1)',
          approved: '#16A34A',
          'approved-bg': 'rgba(22, 163, 74, 0.1)',
          progress: '#F59E0B',
          'progress-bg': 'rgba(245, 158, 11, 0.1)',
          done: '#16A34A',
          'done-bg': 'rgba(22, 163, 74, 0.1)',
          canceled: '#EF4444',
          'canceled-bg': 'rgba(239, 68, 68, 0.1)',
        },
      },
      fontFamily: {
        heading: ['Inter', 'sans-serif'],
        body: ['Inter', 'sans-serif'],
      },
      animation: {
        'fade-in-up': 'fadeInUp 0.5s ease forwards',
        'pulse-glow': 'pulseGlow 2.5s ease-in-out infinite',
      },
      keyframes: {
        fadeInUp: {
          from: { opacity: '0', transform: 'translateY(20px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        pulseGlow: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgba(37, 211, 102, 0.4)' },
          '50%': { boxShadow: '0 0 20px 4px rgba(37, 211, 102, 0.2)' },
        },
      },
    },
  },
  plugins: [],
} satisfies Config
