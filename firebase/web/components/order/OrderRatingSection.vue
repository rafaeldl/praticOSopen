<template>
  <div class="card-stagger card-v2 rounded-2xl bg-white shadow-[0_2px_10px_rgba(27,94,123,0.03)]"
    :class="hasRating ? 'p-5 lg:p-5' : 'p-6'"
  >
    <!-- ===== ALREADY RATED STATE ===== -->
    <template v-if="hasRating">
      <div class="flex flex-col gap-3.5">
        <!-- Header: teal circle with heart + title -->
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-b from-[#1B5E7B] to-[#0D3B4F]">
            <svg class="h-5 w-5 text-white" viewBox="0 0 24 24" fill="currentColor" stroke="none">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
            </svg>
          </div>
          <h3 class="text-[15px] font-bold text-[#1A2B3C]">{{ t.thankYouRating }}</h3>
        </div>

        <!-- Divider -->
        <div class="h-px bg-[#EDF2F7]" />

        <!-- Rating display -->
        <div class="flex flex-col items-center gap-2">
          <span class="text-[13px] font-semibold text-[#1A2B3C]">{{ t.yourRating }}</span>
          <div class="flex justify-center gap-1.5">
            <svg
              v-for="i in 5"
              :key="i"
              class="h-6 w-6 lg:h-[22px] lg:w-[22px]"
              :fill="i <= rating.score ? '#F59E0B' : 'none'"
              :stroke="i <= rating.score ? '#F59E0B' : '#D0DAE4'"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
            </svg>
          </div>
          <span class="text-[12px] font-semibold text-[#F59E0B]">{{ ratingLabel(rating.score) }}</span>
        </div>

        <!-- Comment (if exists) -->
        <template v-if="rating.comment">
          <div class="h-px bg-[#EDF2F7]" />
          <div class="flex gap-3">
            <div class="w-[3px] shrink-0 rounded-sm bg-[#1B5E7B]" />
            <div class="flex flex-col gap-1.5">
              <span class="text-[11px] font-semibold tracking-[0.5px] text-[#5A7184]">{{ t.yourComment }}</span>
              <p class="text-[13px] leading-relaxed text-[#1A2B3C]">{{ rating.comment }}</p>
            </div>
          </div>
        </template>

        <!-- Timestamp -->
        <div class="flex items-center gap-1.5">
          <svg class="h-3 w-3 text-[#A0AEC0]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16.5 12"/>
          </svg>
          <span class="text-[11px] text-[#A0AEC0]">{{ ratedOnText }}</span>
        </div>
      </div>
    </template>

    <!-- ===== RATING FORM STATE ===== -->
    <template v-else-if="!submitted">
      <div class="flex flex-col gap-5">
        <!-- Success banner -->
        <div class="flex flex-col items-center gap-3">
          <div class="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-b from-[#16A34A] to-[#22C55E]">
            <svg class="h-7 w-7 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
          </div>
          <h3 class="text-[18px] font-bold text-[#1A2B3C] text-center lg:text-[17px]">{{ t.serviceCompleted }}</h3>
          <p class="whitespace-pre-line text-center text-[13px] leading-relaxed text-[#5A7184]">{{ t.serviceCompletedDesc }}</p>
        </div>

        <!-- Divider -->
        <div class="h-px bg-[#EDF2F7]" />

        <!-- Rating section -->
        <div class="flex flex-col items-center gap-3">
          <span class="text-[14px] font-semibold text-[#1A2B3C]">{{ t.rateTheService }}</span>
          <div class="flex justify-center gap-2">
            <button
              v-for="i in 5"
              :key="i"
              class="border-0 bg-transparent p-0 transition-transform hover:scale-[1.15] cursor-pointer"
              @click="selectedRating = i"
              @mouseenter="hoverRating = i"
              @mouseleave="hoverRating = 0"
            >
              <svg
                class="h-9 w-9 transition-colors lg:h-8 lg:w-8"
                :fill="(hoverRating || selectedRating) >= i ? '#F59E0B' : 'none'"
                :stroke="(hoverRating || selectedRating) >= i ? '#F59E0B' : '#D0DAE4'"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
              </svg>
            </button>
          </div>
          <span v-if="activeRating > 0" class="text-[13px] font-semibold text-[#F59E0B]">{{ ratingLabel(activeRating) }}</span>
        </div>

        <!-- Divider -->
        <div class="h-px bg-[#EDF2F7]" />

        <!-- Feedback section -->
        <div class="flex flex-col gap-2.5">
          <span class="text-[13px] font-semibold text-[#1A2B3C]">{{ t.feedbackLabel }}</span>
          <textarea
            v-model="ratingComment"
            :placeholder="t.feedbackPlaceholder"
            maxlength="500"
            class="w-full min-h-[100px] max-h-[200px] resize-y rounded-xl border border-[#E2E8F0] bg-[#F5F7FA] p-3 text-[13px] leading-relaxed text-[#1A2B3C] transition-all focus:border-[#1B5E7B] focus:outline-none placeholder:text-[#A0AEC0]"
          />
        </div>

        <!-- Submit button -->
        <button
          class="flex h-12 w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-b from-[#22C55E] to-[#16A34A] text-[15px] font-bold text-white transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_24px_rgba(22,163,74,0.3)] disabled:opacity-50 disabled:cursor-not-allowed lg:h-11 lg:text-[14px]"
          :disabled="selectedRating < 1 || submitting"
          @click="submitRatingHandler"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
          </svg>
          {{ submitting ? '...' : t.rateSubmit }}
        </button>
      </div>
    </template>

    <!-- ===== SUCCESS STATE (brief) ===== -->
    <template v-else>
      <div class="flex flex-col items-center gap-4 py-8">
        <div class="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-b from-[#16A34A] to-[#22C55E]">
          <svg class="h-7 w-7 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
        </div>
        <h4 class="text-lg font-semibold text-[#1A2B3C]">{{ t.rateSuccess }}</h4>
      </div>
    </template>
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

const { t, lang } = useOrderI18n()
const { submitRating } = useOrderApi()

const rating = computed(() => props.order?.rating)
const hasRating = computed(() => !!rating.value?.score)

const selectedRating = ref(0)
const hoverRating = ref(0)
const ratingComment = ref('')
const submitting = ref(false)
const submitted = ref(false)

const activeRating = computed(() => hoverRating.value || selectedRating.value)

function ratingLabel(score: number): string {
  const labels: Record<number, string> = {
    1: t.value.ratingPoor,
    2: t.value.ratingFair,
    3: t.value.ratingGood,
    4: t.value.ratingVeryGood,
    5: t.value.ratingExcellent,
  }
  return labels[score] || ''
}

const ratedOnText = computed(() => {
  const dateStr = rating.value?.createdAt || rating.value?.date
  if (!dateStr) return ''
  const date = new Date(dateStr)
  const locale = lang.value === 'en' ? 'en-US' : lang.value === 'es' ? 'es-ES' : 'pt-BR'
  const formatted = date.toLocaleDateString(locale, {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  })
  return `${t.value.ratedOn} ${formatted}`
})

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
