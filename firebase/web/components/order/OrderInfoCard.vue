<template>
  <div class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mb-5">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
        <circle cx="12" cy="7" r="4"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.customer }}</h3>
    </div>
    <div class="p-5">
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <span class="text-xs uppercase tracking-wide text-[var(--text-tertiary)]">{{ t.name }}</span>
          <span class="text-base text-[var(--text-primary)]">{{ customerName }}</span>
        </div>
        <div v-if="customerPhone" class="flex flex-col gap-1">
          <span class="text-xs uppercase tracking-wide text-[var(--text-tertiary)]">{{ t.phone }}</span>
          <span class="text-base font-medium text-brand-primary">{{ customerPhone }}</span>
        </div>
        <div v-if="singleDevice" class="flex flex-col gap-1">
          <span class="text-xs uppercase tracking-wide text-[var(--text-tertiary)]">{{ t.device }}</span>
          <span class="text-base text-[var(--text-primary)]">
            {{ singleDevice.name }}
            <span v-if="singleDevice.serial" class="ml-1 font-mono text-xs tracking-wide text-[var(--text-tertiary)]">{{ singleDevice.serial }}</span>
          </span>
        </div>
        <div v-if="order?.dueDate" class="flex flex-col gap-1">
          <span class="text-xs uppercase tracking-wide text-[var(--text-tertiary)]">{{ t.forecast }}</span>
          <span class="text-base text-[var(--text-primary)]">{{ formatDate(order.dueDate, lang) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDate } from '~/utils/format'

const props = defineProps<{
  order: any
  customer: any
}>()

const { t, lang } = useOrderI18n()

const customerName = computed(() => props.order?.customer?.name || props.customer?.name || '-')
const customerPhone = computed(() => props.order?.customer?.phone || props.customer?.phone || '')

const devices = computed(() => {
  if (props.order?.devices?.length) return props.order.devices
  if (props.order?.device) return [{ id: props.order.device.id || '_single', name: props.order.device.name, serial: props.order.device.serial }]
  return []
})

const singleDevice = computed(() => devices.value.length === 1 ? devices.value[0] : null)
</script>
