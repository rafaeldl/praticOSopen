export function useTheme() {
  const theme = ref<'dark' | 'light'>('dark')

  if (import.meta.client) {
    const saved = localStorage.getItem('theme')
    theme.value = (saved as 'dark' | 'light') || (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark')
    document.documentElement.setAttribute('data-theme', theme.value)
  }

  function toggleTheme() {
    theme.value = theme.value === 'dark' ? 'light' : 'dark'
    if (import.meta.client) {
      document.documentElement.setAttribute('data-theme', theme.value)
      localStorage.setItem('theme', theme.value)
    }
  }

  return { theme, toggleTheme }
}
