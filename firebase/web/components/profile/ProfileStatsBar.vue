<template>
  <div v-if="hasStats" class="animate-fade-in-up mx-auto mb-5 flex items-center justify-center gap-4 rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] px-6 py-4 sm:gap-6">
    <!-- Completed orders -->
    <div v-if="stats.completedOrders > 0" class="text-center">
      <div class="text-lg font-bold text-[var(--text-primary)] sm:text-xl">
        {{ stats.completedOrders >= 100 ? Math.floor(stats.completedOrders / 50) * 50 + '+' : stats.completedOrders }}
      </div>
      <div class="text-xs text-[var(--text-tertiary)]">{{ t.completedOrders }}</div>
    </div>

    <div v-if="stats.completedOrders > 0 && stats.avgRating > 0" class="h-8 w-px bg-[var(--border-color)]" />

    <!-- Average rating -->
    <div v-if="stats.avgRating > 0" class="text-center">
      <div class="flex items-center justify-center gap-1">
        <svg class="h-5 w-5 text-brand-yellow" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
        </svg>
        <span class="text-lg font-bold text-[var(--text-primary)] sm:text-xl">{{ stats.avgRating }}</span>
      </div>
      <div class="text-xs text-[var(--text-tertiary)]">{{ t.avgRating }}</div>
    </div>

    <div v-if="stats.avgRating > 0 && stats.reviewCount > 0" class="h-8 w-px bg-[var(--border-color)]" />

    <!-- Review count -->
    <div v-if="stats.reviewCount > 0" class="text-center">
      <div class="text-lg font-bold text-[var(--text-primary)] sm:text-xl">{{ stats.reviewCount }}</div>
      <div class="text-xs text-[var(--text-tertiary)]">{{ t.reviewCount }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  stats: {
    completedOrders: number
    avgRating: number
    reviewCount: number
  }
}>()

const { t } = useProfileI18n()

const hasStats = computed(() =>
  props.stats.completedOrders > 0 || props.stats.avgRating > 0 || props.stats.reviewCount > 0
)
</script>
