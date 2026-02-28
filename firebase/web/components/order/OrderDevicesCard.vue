<template>
  <div v-if="isMulti" class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mb-5">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
        <line x1="8" y1="21" x2="16" y2="21"/>
        <line x1="12" y1="17" x2="12" y2="21"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.devices }}</h3>
    </div>
    <div class="p-5">
      <div class="flex flex-col">
        <div
          v-for="(device, index) in devices"
          :key="device.id"
          :class="[
            'flex items-center gap-3.5 py-3.5',
            index < devices.length - 1 ? 'border-b border-[var(--border-color)]' : '',
            index === 0 ? 'pt-0' : '',
            index === devices.length - 1 ? 'pb-0' : '',
          ]"
        >
          <div class="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-[rgba(74,155,217,0.12)] text-xs font-semibold text-brand-primary">
            {{ index + 1 }}
          </div>
          <div class="flex min-w-0 flex-col gap-0.5">
            <div class="font-medium text-[var(--text-primary)]">{{ device.name || '-' }}</div>
            <div v-if="device.serial" class="font-mono text-xs tracking-wide text-[var(--text-tertiary)]">{{ device.serial }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  order: any
}>()

const { t } = useOrderI18n()

const devices = computed(() => {
  if (props.order?.devices?.length) return props.order.devices
  if (props.order?.device) return [{ id: props.order.device.id || '_single', name: props.order.device.name, serial: props.order.device.serial }]
  return []
})

const isMulti = computed(() => devices.value.length >= 2)
</script>
