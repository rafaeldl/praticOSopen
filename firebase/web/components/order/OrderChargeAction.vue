<template>
  <div v-if="view.kind !== 'none'" class="mt-4">
    <template v-if="view.kind === 'pay'">
      <a
        :href="view.invoiceUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex w-full items-center justify-center gap-2 rounded-xl bg-[#1B5E7B] px-4 py-3 text-[15px] font-semibold text-white transition hover:bg-[#164E66] active:scale-[0.99]"
      >
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <rect x="1" y="4" width="22" height="16" rx="2" ry="2" /><line x1="1" y1="10" x2="23" y2="10" />
        </svg>
        {{ payLabel }}
      </a>
      <p class="mt-2 text-center text-[12px] text-[#5A7184]">{{ detailLabel }}</p>
    </template>

    <div
      v-else-if="view.kind === 'overdue'"
      role="status"
      class="flex items-center gap-2 rounded-xl bg-[#FEF2F2] px-4 py-3 text-[13px] font-medium text-[#B91C1C]"
    >
      <span class="h-2 w-2 shrink-0 rounded-full bg-[#EF4444]" aria-hidden="true" />
      {{ t.chargeOverdue }}
    </div>

    <div
      v-else
      role="status"
      class="flex items-center justify-center gap-2 rounded-xl bg-[#F0FDF4] px-4 py-3 text-[14px] font-semibold text-[#16A34A]"
    >
      {{ paidLabel }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'
import { getChargeView, formatChargeDueDate, type PublicOrderCharge } from '~/utils/charge'

const props = defineProps<{
  charge?: PublicOrderCharge | null
}>()

const { t, lang } = useOrderI18n()

const view = computed(() => getChargeView(props.charge))

// Asaas charges are always in BRL, regardless of the company country.
const payLabel = computed(() => {
  const v = view.value
  if (v.kind !== 'pay') return ''
  return t.value.chargePay.replace('{amount}', formatCurrency(v.value, 'BR'))
})

const paidLabel = computed(() => {
  const v = view.value
  if (v.kind !== 'paid') return ''
  return t.value.chargePaid.replace('{amount}', formatCurrency(v.value, 'BR'))
})

const detailLabel = computed(() => {
  const v = view.value
  if (v.kind !== 'pay') return ''
  const how = v.installmentCount
    ? t.value.chargeInstallments.replace('{count}', String(v.installmentCount))
    : t.value.chargeMethods
  const due = t.value.chargeDue.replace('{date}', formatChargeDueDate(v.dueDate, lang.value))
  return `${how} · ${due}`
})
</script>
