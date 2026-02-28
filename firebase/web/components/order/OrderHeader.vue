<template>
  <header class="relative overflow-hidden pt-20 pb-10 text-center sm:pt-24 sm:pb-12">
    <!-- Background glow -->
    <div class="pointer-events-none absolute -top-1/2 left-1/2 h-[600px] w-[600px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,rgba(74,155,217,0.08)_0%,transparent_70%)]" />

    <div class="relative z-10">
      <!-- Company logo -->
      <img
        v-if="company?.logo"
        :src="company.logo"
        :alt="company.name"
        class="mx-auto mb-4 h-[72px] w-[72px] rounded-2xl border-2 border-[var(--border-color)] bg-[var(--bg-card)] object-cover sm:h-[88px] sm:w-[88px]"
      >
      <div
        v-else-if="company?.name"
        class="mx-auto mb-4 flex h-[72px] w-[72px] items-center justify-center rounded-2xl border-2 border-[var(--border-color)] bg-[var(--bg-card)] font-heading text-3xl font-bold text-brand-primary sm:h-[88px] sm:w-[88px]"
      >
        {{ company.name.charAt(0).toUpperCase() }}
      </div>

      <!-- Company name -->
      <h1 v-if="company?.name" class="mb-2 text-xl font-semibold sm:text-2xl">
        {{ company.name }}
      </h1>

      <!-- Order number -->
      <div class="inline-flex items-center gap-2 rounded-full bg-[var(--bg-card)] px-4 py-2 text-sm text-[var(--text-secondary)]">
        <span>OS</span>
        <strong class="font-semibold text-[var(--text-primary)]">#{{ order?.number || '---' }}</strong>
      </div>

      <!-- Status badge -->
      <div class="mt-5">
        <span
          :class="[
            'inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold uppercase tracking-wide',
            statusClasses,
          ]"
        >
          <span :class="['inline-block h-2 w-2 rounded-full', dotClass, dotAnimate]" />
          {{ statusLabel }}
        </span>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
const props = defineProps<{
  order: any
  company: any
}>()

const { getStatusLabel } = useOrderI18n()

const statusLabel = computed(() => getStatusLabel(props.order?.status))

const statusClasses = computed(() => {
  const s = props.order?.status
  const map: Record<string, string> = {
    quote: 'bg-status-quote-bg text-status-quote',
    approved: 'bg-status-approved-bg text-status-approved',
    progress: 'bg-status-progress-bg text-status-progress',
    done: 'bg-status-done-bg text-status-done',
    canceled: 'bg-status-canceled-bg text-status-canceled',
  }
  return map[s] || map.quote
})

const dotClass = computed(() => {
  const s = props.order?.status
  const map: Record<string, string> = {
    quote: 'bg-status-quote',
    approved: 'bg-status-approved',
    progress: 'bg-status-progress',
    done: 'bg-status-done',
    canceled: 'bg-status-canceled',
  }
  return map[s] || map.quote
})

const dotAnimate = computed(() => {
  const s = props.order?.status
  return s === 'done' || s === 'canceled' ? '' : 'animate-pulse-dot'
})
</script>
