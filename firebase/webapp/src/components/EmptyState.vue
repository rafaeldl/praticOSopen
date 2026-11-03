<script setup lang="ts">
defineProps<{ title: string; body?: string }>()
</script>

<template>
  <div class="empty">
    <h2>{{ title }}</h2>
    <p v-if="body">{{ body }}</p>
    <slot />
  </div>
</template>
