<template>
  <div class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <div class="flex flex-col gap-4 lg:gap-5">
      <!-- Header: mobile = row, desktop = row with total on right -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3 lg:gap-3.5">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[#FFF7ED] lg:h-10 lg:w-10">
            <svg class="h-[18px] w-[18px] text-[#D97706] lg:h-5 lg:w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="m9 15 2 2 4-4"/>
            </svg>
          </div>
          <div>
            <h3 class="text-[15px] font-bold text-[#1A2B3C] lg:text-[18px]">{{ t.quotePending }}</h3>
            <p class="text-[12px] text-[#8FA3B8] lg:text-[13px]">{{ t.quoteSubtitle }}</p>
          </div>
        </div>
        <!-- Total: hidden on mobile, shown on desktop -->
        <div class="hidden text-right lg:block">
          <span class="block text-[13px] text-[#5A7184]">{{ t.quoteTotalLabel }}</span>
          <span class="text-[26px] font-bold text-[#1A2B3C] tabular-nums">{{ formattedTotal }}</span>
        </div>
      </div>

      <!-- Divider (mobile only, before total row) -->
      <div class="h-px bg-[#EDF2F7] lg:hidden" />

      <!-- Total row (mobile only) -->
      <div class="flex items-center justify-between lg:hidden">
        <span class="text-[13px] text-[#5A7184]">{{ t.quoteTotalLabel }}</span>
        <span class="text-[22px] font-bold text-[#1A2B3C] tabular-nums">{{ formattedTotal }}</span>
      </div>

      <!-- Divider (desktop: after header, mobile: after total) -->
      <div class="h-px bg-[#EDF2F7] hidden lg:block" />

      <!-- Info box -->
      <div class="flex gap-2.5 rounded-[10px] bg-[#F0F7FF] p-3 lg:p-3.5">
        <svg class="mt-0.5 h-4 w-4 shrink-0 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>
        </svg>
        <p class="text-[12px] leading-relaxed text-[#3B6DAA] lg:text-[13px]">
          <span class="lg:hidden">{{ t.quoteInfoText }}</span>
          <span class="hidden lg:inline">{{ t.quoteInfoTextLong }}</span>
        </p>
      </div>

      <!-- Terms of Service -->
      <template v-if="termsOfService">
        <!-- Checkbox row -->
        <div class="flex items-start gap-2.5">
          <label class="flex cursor-pointer items-start gap-2.5">
            <input
              type="checkbox"
              v-model="termsAccepted"
              class="mt-0.5 h-5 w-5 shrink-0 cursor-pointer rounded border-[#CBD5E1] accent-[#1B5E7B]"
              @change="showTermsError = false"
            />
            <span class="text-[12px] leading-[1.4] text-[#5A7184] lg:text-[13px]">{{ t.termsAcceptCheckbox }}</span>
          </label>
        </div>
        <p v-if="showTermsError" class="ml-[30px] text-[11px] text-[#DC2626] lg:text-[12px]">{{ t.termsRequiredError }}</p>

        <!-- Terms box -->
        <div class="rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFB] p-3.5 lg:p-4">
          <div class="mb-2.5 flex items-center gap-2">
            <svg class="h-3.5 w-3.5 text-[#5A7184]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M16 16v3a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8c0-1.1.9-2 2-2h3"/><path d="M8 2h13a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z"/><line x1="10" y1="6" x2="18" y2="6"/><line x1="10" y1="9.5" x2="18" y2="9.5"/><line x1="10" y1="13" x2="15" y2="13"/>
            </svg>
            <span class="text-[12px] font-bold text-[#1A2B3C] lg:text-[13px]">{{ t.termsTitle }}</span>
          </div>
          <p
            class="whitespace-pre-line text-[11px] leading-[1.6] text-[#5A7184] lg:text-[12px]"
            :class="{ 'line-clamp-3': !termsExpanded }"
          >{{ termsOfService }}</p>
          <button
            v-if="isTermsLong"
            class="mt-1.5 text-[11px] font-medium text-[#2563EB] hover:underline lg:text-[12px]"
            @click="termsExpanded = !termsExpanded"
          >{{ termsExpanded ? t.termsReadLess : t.termsReadMore }}</button>
        </div>
      </template>

      <!-- Divider (mobile only, before buttons) -->
      <div class="h-px bg-[#EDF2F7] lg:hidden" />

      <!-- Buttons: mobile = stacked, desktop = right-aligned -->
      <div class="flex flex-col gap-2.5 sm:flex-row lg:flex-row lg:items-center lg:justify-end lg:gap-3">
        <!-- Approve (first on mobile, second on desktop) -->
        <button
          class="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[#16A34A] px-5 py-3 text-[14px] font-bold text-white shadow-[0_4px_20px_rgba(22,163,74,0.25)] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(22,163,74,0.35)] lg:order-2 lg:flex-none lg:px-8 lg:py-3.5"
          @click="handleApproveClick"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
          <span class="lg:hidden">{{ t.approveShort }}</span>
          <span class="hidden lg:inline">{{ t.approveQuote }}</span>
        </button>
        <!-- Reject (second on mobile, first on desktop) -->
        <button
          class="flex flex-1 items-center justify-center gap-2 rounded-xl border border-[#E4E4E7] bg-white px-5 py-3 text-[14px] font-semibold text-[#DC2626] transition-all hover:bg-[#FEF2F2] lg:order-1 lg:flex-none lg:px-7 lg:py-3.5"
          @click="$emit('reject')"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>
          </svg>
          <span class="lg:hidden">{{ t.reject }}</span>
          <span class="hidden lg:inline">{{ t.rejectQuote }}</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'

const props = defineProps<{
  order: any
  country?: string
  termsOfService?: string | null
}>()

const emit = defineEmits<{
  approve: []
  reject: []
}>()

const { t } = useOrderI18n()

const termsExpanded = ref(false)
const termsAccepted = ref(false)
const showTermsError = ref(false)

const isTermsLong = computed(() => {
  if (!props.termsOfService) return false
  return props.termsOfService.length > 120 || props.termsOfService.split('\n').length > 2
})

const formattedTotal = computed(() => {
  const total = props.order?.total || 0
  return formatCurrency(total, props.country)
})

function handleApproveClick() {
  if (props.termsOfService && !termsAccepted.value) {
    showTermsError.value = true
    return
  }
  emit('approve')
}
</script>
