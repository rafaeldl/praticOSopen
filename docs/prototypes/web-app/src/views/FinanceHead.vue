<script setup>
import { computed } from 'vue'
import { route, go, db, rest } from '../store.js'
defineProps({ title: String, sub: String })
const pending = computed(() => db.value.orders.filter((o) => o.status === 'done' && rest(o) > 0).length)
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p v-if="sub" class="page-sub">{{ sub }}</p>
    </div>
    <slot />
    <div class="tabs" role="group" aria-label="Parte do financeiro">
      <button :aria-pressed="route.name === 'financeiro'" @click="go('financeiro')">Resumo</button>
      <button :aria-pressed="route.name === 'receber'" @click="go('receber')">Receber<span v-if="pending" class="num tab-count">{{ pending }}</span></button>
    </div>
  </header>
</template>
