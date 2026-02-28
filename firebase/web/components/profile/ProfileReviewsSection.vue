<template>
  <div v-if="reviews?.length" class="order-card animate-fade-in-up mb-5 overflow-hidden rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)]">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.reviewsTitle }}</h3>
    </div>
    <div class="p-5 space-y-4">
      <div
        v-for="review in visibleReviews"
        :key="review.id"
        class="rounded-xl bg-[var(--bg-tertiary)] p-4"
      >
        <!-- Stars -->
        <div class="mb-2 flex items-center gap-1">
          <svg
            v-for="star in 5"
            :key="star"
            class="h-4 w-4"
            :class="star <= review.score ? 'text-brand-yellow' : 'text-[var(--text-tertiary)] opacity-30'"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
          </svg>
        </div>

        <!-- Comment -->
        <p v-if="review.comment" class="mb-2 text-sm leading-relaxed text-[var(--text-secondary)]">
          {{ review.comment }}
        </p>

        <!-- Author + date -->
        <div class="flex items-center justify-between text-xs text-[var(--text-tertiary)]">
          <span>{{ review.customerName }}</span>
          <span>{{ formatRelativeDate(review.createdAt) }}</span>
        </div>
      </div>

      <!-- Show more/less button -->
      <button
        v-if="reviews.length > 5"
        class="w-full rounded-xl border border-[var(--border-color)] py-3 text-center text-sm font-medium text-brand-primary transition-colors hover:bg-[var(--bg-tertiary)]"
        @click="showAll = !showAll"
      >
        {{ showAll ? t.showLess : t.showMore }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  reviews: Array<{
    id: string
    score: number
    comment?: string
    customerName: string
    createdAt: string
  }>
}>()

const { t, formatRelativeDate } = useProfileI18n()
const showAll = ref(false)

const visibleReviews = computed(() =>
  showAll.value ? props.reviews : props.reviews.slice(0, 5)
)
</script>
