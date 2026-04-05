<template>
  <div class="mb-5 rounded-2xl border border-[var(--border-color)] bg-gradient-to-br from-[var(--bg-tertiary)] to-[var(--bg-card)] p-6 animate-fade-in-up">
    <!-- Subtotal -->
    <div class="flex items-center justify-between py-2">
      <span class="text-[0.9rem] text-[var(--text-secondary)]">{{ t.subtotal }}</span>
      <span class="font-semibold">{{ formatCurrency(subtotal, country) }}</span>
    </div>

    <!-- Discount -->
    <div v-if="discount > 0" class="flex items-center justify-between py-2 text-status-approved">
      <span class="text-[0.9rem]">{{ t.discount }}</span>
      <span class="font-semibold">-{{ formatCurrency(discount, country) }}</span>
    </div>

    <!-- Paid -->
    <div v-if="paidAmount > 0" class="flex items-center justify-between py-2 text-[var(--text-secondary)]">
      <span class="text-[0.9rem]">{{ t.paid }}</span>
      <span class="font-semibold">-{{ formatCurrency(paidAmount, country) }}</span>
    </div>

    <!-- Grand Total -->
    <div class="mt-2 flex items-center justify-between border-t border-[var(--border-color)] pt-4">
      <span class="text-base font-semibold text-[var(--text-primary)]">{{ t.total }}</span>
      <span class="text-2xl font-semibold text-gradient">{{ formatCurrency(remaining, country) }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'

const props = defineProps<{
  order: any
  country?: string
}>()

const { t } = useOrderI18n()

const total = computed(() => props.order?.total || 0)
const discount = computed(() => props.order?.discount || 0)
const paidAmount = computed(() => props.order?.paidAmount || 0)
const subtotal = computed(() => total.value + discount.value)
const remaining = computed(() => total.value - paidAmount.value)
</script>
