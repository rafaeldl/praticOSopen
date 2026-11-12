<script setup lang="ts">
// The title names the screen; the answer (when given) answers its question in one sentence,
// as Início and Clientes do. Keeps tabindex so navigation can move focus here.
defineProps<{ title: string; answer?: string; sub?: string }>()
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p v-if="answer !== undefined" class="page-sub page-answer" data-testid="page-answer">{{ answer }}</p>
      <p v-if="sub" class="page-sub">{{ sub }}</p>
    </div>
    <slot />
  </header>
</template>
