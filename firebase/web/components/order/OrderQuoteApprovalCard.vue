<template>
  <!-- Mobile layout -->
  <div class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:hidden">
    <div class="flex flex-col gap-4">
      <!-- Header -->
      <div class="flex items-center gap-3">
        <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px] bg-[#FFF7ED]">
          <svg class="h-[18px] w-[18px] text-[#D97706]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="m9 15 2 2 4-4"/>
          </svg>
        </div>
        <div>
          <h3 class="text-[15px] font-bold text-[#1A2B3C]">{{ t.quotePending }}</h3>
          <p class="text-[12px] text-[#8FA3B8]">{{ t.quoteSubtitle }}</p>
        </div>
      </div>

      <!-- Divider -->
      <div class="h-px bg-[#EDF2F7]" />

      <!-- Total row -->
      <div class="flex items-center justify-between">
        <span class="text-[13px] text-[#5A7184]">{{ t.quoteTotalLabel }}</span>
        <span class="text-[22px] font-bold text-[#1A2B3C] tabular-nums">{{ formattedTotal }}</span>
      </div>

      <!-- Info box -->
      <div class="flex gap-2.5 rounded-[10px] bg-[#F0F7FF] p-3">
        <svg class="mt-0.5 h-4 w-4 shrink-0 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>
        </svg>
        <p class="text-[12px] leading-relaxed text-[#3B6DAA]">{{ t.quoteInfoText }}</p>
      </div>

      <!-- Divider -->
      <div class="h-px bg-[#EDF2F7]" />

      <!-- Buttons -->
      <div class="flex flex-col gap-2.5 sm:flex-row">
        <button
          class="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[#16A34A] px-5 py-3 text-[14px] font-bold text-white shadow-[0_4px_20px_rgba(22,163,74,0.25)] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(22,163,74,0.35)]"
          @click="$emit('approve')"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
          {{ t.approveShort }}
        </button>
        <button
          class="flex flex-1 items-center justify-center gap-2 rounded-xl border border-[#E4E4E7] bg-white px-5 py-3 text-[14px] font-semibold text-[#DC2626] transition-all hover:bg-[#FEF2F2]"
          @click="$emit('reject')"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>
          </svg>
          {{ t.reject }}
        </button>
      </div>
    </div>
  </div>

  <!-- Desktop layout -->
  <div class="card-stagger card-v2 hidden rounded-2xl bg-white p-6 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:block">
    <div class="flex flex-col gap-5">
      <!-- Top row -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3.5">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[#FFF7ED]">
            <svg class="h-5 w-5 text-[#D97706]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="m9 15 2 2 4-4"/>
            </svg>
          </div>
          <div>
            <h3 class="text-[18px] font-bold text-[#1A2B3C]">{{ t.quotePending }}</h3>
            <p class="text-[13px] text-[#8FA3B8]">{{ t.quoteSubtitle }}</p>
          </div>
        </div>
        <div class="text-right">
          <span class="block text-[13px] text-[#5A7184]">{{ t.quoteTotalLabel }}</span>
          <span class="text-[26px] font-bold text-[#1A2B3C] tabular-nums">{{ formattedTotal }}</span>
        </div>
      </div>

      <!-- Divider -->
      <div class="h-px bg-[#EDF2F7]" />

      <!-- Info box -->
      <div class="flex gap-2.5 rounded-[10px] bg-[#F0F7FF] p-3.5">
        <svg class="mt-0.5 h-4 w-4 shrink-0 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>
        </svg>
        <p class="text-[13px] leading-relaxed text-[#3B6DAA]">{{ t.quoteInfoTextLong }}</p>
      </div>

      <!-- Buttons -->
      <div class="flex items-center justify-end gap-3">
        <button
          class="flex items-center gap-2 rounded-xl border border-[#E4E4E7] bg-white px-7 py-3.5 text-[14px] font-semibold text-[#DC2626] transition-all hover:bg-[#FEF2F2]"
          @click="$emit('reject')"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>
          </svg>
          {{ t.rejectQuote }}
        </button>
        <button
          class="flex items-center gap-2 rounded-xl bg-[#16A34A] px-8 py-3.5 text-[14px] font-bold text-white shadow-[0_4px_20px_rgba(22,163,74,0.25)] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(22,163,74,0.35)]"
          @click="$emit('approve')"
        >
          <svg class="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>
          </svg>
          {{ t.approveQuote }}
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
}>()

defineEmits<{
  approve: []
  reject: []
}>()

const { t } = useOrderI18n()

const formattedTotal = computed(() => {
  const total = props.order?.total || 0
  const paidAmount = props.order?.paidAmount || 0
  return formatCurrency(total - paidAmount, props.country)
})
</script>
