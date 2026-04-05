<template>
  <div v-if="reviews?.length" class="rounded-xl border border-[#E4E4E7] bg-white p-7">
    <!-- Header with rating summary -->
    <div class="mb-4 flex items-center gap-3">
      <h3 class="text-lg font-semibold text-[#18181B]">{{ t.reviewsTitle }}</h3>
      <div v-if="avgRating > 0" class="flex items-center gap-1.5 text-sm">
        <svg class="h-4 w-4 text-[#F59E0B]" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
        </svg>
        <span class="font-semibold text-[#18181B]">{{ avgRating }}</span>
        <span class="text-[#A1A1AA]">({{ reviews.length }})</span>
      </div>
    </div>

    <div class="space-y-4">
      <!-- Featured review -->
      <div
        v-if="featuredReview"
        class="rounded-[10px] border border-[#2563EB]/20 bg-[#EFF6FF] p-5"
      >
        <div class="mb-3 flex items-center gap-2">
          <span class="rounded-full bg-[#2563EB] px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-widest text-white">
            {{ t.featuredReview }}
          </span>
          <div class="flex items-center gap-0.5">
            <svg
              v-for="star in 5"
              :key="star"
              class="h-4 w-4"
              :class="star <= featuredReview.score ? 'text-[#F59E0B]' : 'text-[#A1A1AA] opacity-30'"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
            </svg>
          </div>
        </div>

        <p class="mb-4 text-base leading-relaxed text-[#71717A]">
          &ldquo;{{ featuredReview.comment }}&rdquo;
        </p>

        <div class="flex items-center gap-3">
          <div
            class="flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold text-white"
            :style="{ backgroundColor: getAvatarColor(featuredReview.customerName) }"
          >
            {{ getInitials(featuredReview.customerName) }}
          </div>
          <div>
            <div class="text-sm font-medium text-[#18181B]">{{ featuredReview.customerName }}</div>
            <div class="text-xs text-[#A1A1AA]">{{ formatRelativeDate(featuredReview.createdAt) }}</div>
          </div>
        </div>
      </div>

      <!-- Remaining reviews -->
      <div class="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <div
          v-for="review in visibleReviews"
          :key="review.id"
          class="rounded-[10px] border border-[#E4E4E7] p-4"
        >
          <div class="flex items-start gap-3">
            <div
              class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
              :style="{ backgroundColor: getAvatarColor(review.customerName) }"
            >
              {{ getInitials(review.customerName) }}
            </div>

            <div class="min-w-0 flex-1">
              <div class="mb-1 flex items-center justify-between gap-2">
                <span class="truncate text-sm font-medium text-[#18181B]">{{ review.customerName }}</span>
                <div class="flex shrink-0 items-center gap-0.5">
                  <svg
                    v-for="star in 5"
                    :key="star"
                    class="h-3.5 w-3.5"
                    :class="star <= review.score ? 'text-[#F59E0B]' : 'text-[#A1A1AA] opacity-30'"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                  >
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                  </svg>
                </div>
              </div>

              <p v-if="review.comment" class="mb-1 text-sm leading-relaxed text-[#71717A]">
                {{ review.comment }}
              </p>

              <span class="text-xs text-[#A1A1AA]">{{ formatRelativeDate(review.createdAt) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Show more/less button -->
      <button
        v-if="remainingReviews.length > 5"
        class="w-full rounded-lg border border-[#E4E4E7] py-3 text-center text-sm font-medium text-[#2563EB] transition-colors hover:bg-[#F4F4F5]"
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

const avgRating = computed(() => {
  if (!props.reviews?.length) return 0
  const sum = props.reviews.reduce((acc, r) => acc + r.score, 0)
  return Number((sum / props.reviews.length).toFixed(1))
})

const featuredReview = computed(() => {
  const withComments = props.reviews.filter(r => r.comment && r.comment.length >= 30)
  if (!withComments.length) return null
  return withComments.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score
    return (b.comment?.length || 0) - (a.comment?.length || 0)
  })[0]
})

const remainingReviews = computed(() => {
  if (!featuredReview.value) return props.reviews
  return props.reviews.filter(r => r.id !== featuredReview.value!.id)
})

const visibleReviews = computed(() =>
  showAll.value ? remainingReviews.value : remainingReviews.value.slice(0, 5)
)

const avatarColors = [
  '#2563EB', '#16A34A', '#F59E0B', '#EF4444', '#8B5CF6',
  '#EC4899', '#6366F1', '#0EA5E9', '#14B8A6', '#D97706',
]

function getAvatarColor(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash)
  }
  return avatarColors[Math.abs(hash) % avatarColors.length]
}

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/)
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  }
  return name.substring(0, 2).toUpperCase()
}
</script>
