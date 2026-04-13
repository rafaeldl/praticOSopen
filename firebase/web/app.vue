<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>

<script setup lang="ts">
onMounted(() => {
  const route = useRoute()
  if (!route.path.startsWith('/admin')) {
    document.documentElement.setAttribute('data-theme', 'light')
  }
})
</script>
