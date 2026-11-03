<script setup lang="ts">
// The title answers the screen's question. Keeps tabindex so navigation can move focus here.
defineProps<{ title: string; sub?: string }>()
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p v-if="sub" class="page-sub">{{ sub }}</p>
    </div>
    <slot />
  </header>
</template>
