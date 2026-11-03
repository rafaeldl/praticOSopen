<script setup lang="ts">
// Parts of the Financeiro: Resumo, Receber and Relatório, each with its own URL.
import { useRoute } from 'vue-router'
import { t } from '@/i18n'

const route = useRoute()
const LINKS = [
  { path: '/finance', label: 'web.fin.tabSummary' },
  { path: '/finance/receive', label: 'receiveTitle' },
  { path: '/finance/report', label: 'financialReportShort' },
] as const
</script>

<template>
  <nav class="fin-nav" :aria-label="t('web.finance.parts')">
    <RouterLink
      v-for="link in LINKS"
      :key="link.path"
      :to="link.path"
      class="fin-nav-link"
      :aria-current="route.path === link.path ? 'page' : undefined"
      >{{ t(link.label) }}</RouterLink
    >
  </nav>
</template>
