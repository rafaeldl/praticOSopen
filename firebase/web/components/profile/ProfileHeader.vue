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

      <!-- Company name + verified badge -->
      <div class="mb-2 flex items-center justify-center gap-2">
        <h1 v-if="company?.name" class="text-xl font-semibold sm:text-2xl">
          {{ company.name }}
        </h1>
        <span
          v-if="company?.verified"
          class="inline-flex items-center gap-1 rounded-full bg-[rgba(52,199,89,0.15)] px-2.5 py-0.5 text-xs font-semibold text-status-approved"
          :title="t.verified"
        >
          <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/>
          </svg>
          {{ t.verified }}
        </span>
      </div>

      <!-- Segment badge -->
      <div v-if="segmentLabel" class="mb-3">
        <span class="inline-flex items-center gap-1.5 rounded-full bg-[var(--bg-card)] px-4 py-1.5 text-sm text-[var(--text-secondary)]">
          {{ segmentLabel }}
        </span>
      </div>

      <!-- Location -->
      <p v-if="locationText" class="flex items-center justify-center gap-1.5 text-sm text-[var(--text-tertiary)]">
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
          <circle cx="12" cy="10" r="3"/>
        </svg>
        {{ locationText }}
      </p>
    </div>
  </header>
</template>

<script setup lang="ts">
const props = defineProps<{
  company: any
  segmentLabel?: string
}>()

const { t } = useProfileI18n()

const locationText = computed(() => {
  const parts = [props.company?.city, props.company?.state].filter(Boolean)
  return parts.join(', ')
})
</script>
