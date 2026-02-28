<template>
  <NuxtPage />
</template>

<script setup lang="ts">
if (import.meta.client) {
  const saved = localStorage.getItem('theme')
  const theme = saved || (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark')
  document.documentElement.setAttribute('data-theme', theme)
}
</script>
