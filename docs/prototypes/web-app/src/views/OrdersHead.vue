<script setup>
import { route, go, ui } from '../store.js'
const props = defineProps({ title: String, sub: String })
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p v-if="sub" class="page-sub">{{ sub }}</p>
    </div>
    <div class="tabs" role="group" aria-label="Forma de ver">
      <button :aria-pressed="route.name === 'os'" @click="go('os')">Lista</button>
      <button :aria-pressed="route.name === 'quadro'" @click="go('quadro')">Quadro</button>
    </div>
    <slot />
  </header>
</template>
