<template>
  <div v-if="services?.length" class="order-card animate-fade-in-up mb-5 overflow-hidden rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)]">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.servicesTitle }}</h3>
    </div>
    <div class="divide-y divide-[var(--border-color)]">
      <div
        v-for="service in services"
        :key="service.id"
        class="flex items-center justify-between px-5 py-3.5"
      >
        <div class="flex items-center gap-3">
          <img
            v-if="service.photo"
            :src="service.photo"
            :alt="service.name"
            class="h-10 w-10 rounded-lg object-cover"
          >
          <span class="text-sm text-[var(--text-primary)]">{{ service.name }}</span>
        </div>
        <span v-if="showPrices && service.value" class="text-sm font-semibold text-brand-primary">
          {{ formatCurrency(service.value, country) }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'

defineProps<{
  services: Array<{ id: string; name: string; value?: number; photo?: string }>
  showPrices: boolean
  country?: string
}>()

const { t } = useProfileI18n()
</script>
