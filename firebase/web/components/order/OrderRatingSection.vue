<template>
  <div class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mt-8">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5" :fill="hasRating ? '#FFD700' : 'none'" :stroke="hasRating ? '#FFD700' : 'currentColor'" stroke-width="2" viewBox="0 0 24 24">
        <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ hasRating ? t.yourRating : t.rateService }}</h3>
    </div>
    <div class="p-5 py-8 text-center">
      <!-- Existing rating (read-only) -->
      <template v-if="hasRating">
        <div class="flex flex-col items-center gap-4">
          <div class="flex gap-1">
            <svg
              v-for="i in 5"
              :key="i"
              class="h-8 w-8"
              :fill="i <= rating.score ? '#FFD700' : 'none'"
              :stroke="i <= rating.score ? '#FFD700' : 'currentColor'"
              :class="i > rating.score ? 'text-[var(--border-color)]' : ''"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
            </svg>
          </div>
          <div class="text-xl font-semibold">{{ rating.score }}/5</div>
          <div v-if="rating.comment" class="max-w-[400px] rounded-xl bg-[var(--bg-tertiary)] p-4 text-center italic text-[var(--text-secondary)]">"{{ rating.comment }}"</div>
          <div class="text-sm text-[var(--text-tertiary)]">— {{ rating.customerName }}</div>
        </div>
      </template>

      <!-- Rating form -->
      <template v-else-if="!submitted">
        <p class="mb-6 text-[0.9375rem] text-[var(--text-secondary)]">{{ t.rateDescription }}</p>

        <!-- Stars -->
        <div class="mb-6 inline-flex gap-2">
          <button
            v-for="i in 5"
            :key="i"
            class="h-10 w-10 border-0 bg-transparent p-0 transition-transform hover:scale-[1.2] cursor-pointer"
            @click="selectedRating = i"
            @mouseenter="hoverRating = i"
            @mouseleave="hoverRating = 0"
          >
            <svg
              class="h-full w-full transition-colors"
              :fill="(hoverRating || selectedRating) >= i ? '#FFD700' : 'none'"
              :stroke="(hoverRating || selectedRating) >= i ? '#FFD700' : 'var(--border-color)'"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
            </svg>
          </button>
        </div>

        <!-- Comment -->
        <textarea
          v-model="ratingComment"
          :placeholder="t.rateCommentPlaceholder"
          maxlength="500"
          class="mb-5 w-full min-h-[100px] max-h-[200px] resize-y rounded-xl border border-[var(--border-color)] bg-[var(--bg-secondary)] p-3.5 font-body text-[0.9375rem] text-[var(--text-primary)] transition-all focus:border-brand-primary focus:outline-none placeholder:text-[var(--text-tertiary)]"
        />

        <!-- Submit -->
        <button
          class="rounded-full bg-gradient-to-br from-[#FFD700] to-[#FFA500] px-8 py-3.5 font-semibold text-[#1a1a1a] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_24px_rgba(255,215,0,0.3)] disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="selectedRating < 1 || submitting"
          @click="submitRatingHandler"
        >
          {{ submitting ? '...' : t.rateSubmit }}
        </button>
      </template>

      <!-- Success state -->
      <template v-else>
        <div class="flex flex-col items-center gap-4 py-8">
          <div class="flex h-16 w-16 items-center justify-center rounded-full bg-status-approved-bg">
            <svg class="h-8 w-8 text-status-approved" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
          </div>
          <h4 class="text-lg text-[var(--text-primary)]">{{ t.rateSuccess }}</h4>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  order: any
  token: string
}>()

const emit = defineEmits<{
  rated: []
}>()

const { t } = useOrderI18n()
const { submitRating } = useOrderApi()

const rating = computed(() => props.order?.rating)
const hasRating = computed(() => !!rating.value?.score)

const selectedRating = ref(0)
const hoverRating = ref(0)
const ratingComment = ref('')
const submitting = ref(false)
const submitted = ref(false)

async function submitRatingHandler() {
  if (selectedRating.value < 1 || submitting.value) return

  submitting.value = true
  try {
    const result = await submitRating(props.token, selectedRating.value, ratingComment.value.trim() || undefined) as any
    if (result?.success) {
      submitted.value = true
      emit('rated')
    }
  } catch {
    // Error handled by toast
  } finally {
    submitting.value = false
  }
}
</script>
