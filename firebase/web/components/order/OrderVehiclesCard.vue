<template>
  <div v-if="devices.length" class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Header -->
    <div class="mb-3.5 flex items-center gap-2">
      <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M7 17m-2 0a2 2 0 1 0 4 0 2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0 2 2 0 1 0 -4 0"/><path d="M5 17h-2v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0h-6m-6 -6h15m-6 -3v3"/>
      </svg>
      <h3 class="text-sm font-bold text-[#1A2B3C]">{{ t.vehicles }}</h3>
    </div>

    <!-- Device items -->
    <div class="flex flex-col gap-2.5 lg:flex-row lg:gap-3">
      <div
        v-for="device in devices"
        :key="device.id"
        class="flex-1 rounded-xl bg-[#F0F4F8] px-3.5 py-3"
      >
        <div class="text-[13px] font-medium text-[#1A2B3C]">{{ device.name || '-' }}</div>
        <div v-if="device.serial" class="mt-0.5 font-mono text-[11px] tracking-wide text-[#8FA3B8]">{{ device.serial }}</div>
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
</script>
