<template>
  <div v-if="order?.services?.length" class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mb-5">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.services }}</h3>
    </div>
    <div class="p-5">
      <div class="flex flex-col">
        <template v-if="isMulti">
          <template v-for="group in groupedItems" :key="group.key">
            <div class="border-t border-[var(--border-color)] pt-3.5 pb-1.5 first:border-t-0 first:pt-0">
              <span class="inline-block rounded-full bg-[rgba(74,155,217,0.12)] px-3 py-1 text-xs font-semibold tracking-wide text-brand-primary">{{ group.label }}</span>
            </div>
            <div
              v-for="(service, i) in group.items"
              :key="i"
              class="flex items-start justify-between gap-4 border-b border-[var(--border-color)] py-4 last:border-b-0 last:pb-0"
            >
              <div class="flex-1">
                <div class="font-medium">{{ service.name || t.serviceDefault }}</div>
                <div v-if="service.description" class="mt-1 text-sm text-[var(--text-tertiary)]">{{ service.description }}</div>
              </div>
              <div class="whitespace-nowrap font-semibold text-brand-primary">{{ formatCurrency(service.value, country) }}</div>
            </div>
          </template>
        </template>
        <template v-else>
          <div
            v-for="(service, i) in order.services"
            :key="i"
            :class="[
              'flex items-start justify-between gap-4 py-4 border-b border-[var(--border-color)]',
              i === 0 ? 'pt-0' : '',
              i === order.services.length - 1 ? 'border-b-0 pb-0' : '',
            ]"
          >
            <div class="flex-1">
              <div class="font-medium">{{ service.name || t.serviceDefault }}</div>
              <div v-if="service.description" class="mt-1 text-sm text-[var(--text-tertiary)]">{{ service.description }}</div>
            </div>
            <div class="whitespace-nowrap font-semibold text-brand-primary">{{ formatCurrency(service.value, country) }}</div>
          </div>
        </template>
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

const { t } = useOrderI18n()

const deviceMap = computed(() => {
  const devices = props.order?.devices?.length
    ? props.order.devices
    : (props.order?.device ? [{ id: props.order.device.id || '_single', name: props.order.device.name }] : [])
  const map: Record<string, { name: string }> = {}
  devices.forEach((d: any) => { map[d.id] = { name: d.name } })
  return map
})

const isMulti = computed(() => {
  const devices = props.order?.devices?.length
    ? props.order.devices
    : (props.order?.device ? [props.order.device] : [])
  return devices.length >= 2
})

const groupedItems = computed(() => {
  if (!isMulti.value || !props.order?.services) return []
  const groups: Record<string, any[]> = {}
  props.order.services.forEach((item: any) => {
    const key = (item.deviceId && deviceMap.value[item.deviceId]) ? item.deviceId : '_general'
    if (!groups[key]) groups[key] = []
    groups[key].push(item)
  })
  const deviceIds = Object.keys(deviceMap.value)
  const orderedKeys = [...deviceIds.filter(k => groups[k]), ...('_general' in groups ? ['_general'] : [])]
  return orderedKeys.map(key => ({
    key,
    label: key === '_general' ? t.value.general : deviceMap.value[key]?.name || key,
    items: groups[key] || [],
  }))
})
</script>
