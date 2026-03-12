<template>
  <NuxtPage />
</template>

<script setup lang="ts">
onMounted(() => {
  document.documentElement.setAttribute('data-theme', 'light')
})
</script>
