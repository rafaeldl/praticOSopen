<template>
  <div v-if="order?.products?.length" class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mb-5">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
        <polyline points="3.27 6.96 12 12.01 20.73 6.96"/>
        <line x1="12" y1="22.08" x2="12" y2="12"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.products }}</h3>
    </div>
    <div class="p-5">
      <div class="flex flex-col">
        <template v-if="isMulti">
          <template v-for="group in groupedItems" :key="group.key">
            <div class="border-t border-[var(--border-color)] pt-3.5 pb-1.5 first:border-t-0 first:pt-0">
              <span class="inline-block rounded-full bg-[rgba(74,155,217,0.12)] px-3 py-1 text-xs font-semibold tracking-wide text-brand-primary">{{ group.label }}</span>
            </div>
            <div
              v-for="(product, i) in group.items"
              :key="i"
              class="flex items-start justify-between gap-4 border-b border-[var(--border-color)] py-4 last:border-b-0 last:pb-0"
            >
              <div class="flex-1">
                <div class="font-medium">{{ product.name || t.productDefault }}</div>
                <div v-if="product.description" class="mt-1 text-sm text-[var(--text-tertiary)]">{{ product.description }}</div>
                <div class="mt-1 text-xs text-[var(--text-secondary)]">{{ t.qty }}: {{ product.quantity || 1 }}</div>
              </div>
              <div class="whitespace-nowrap font-semibold text-brand-primary">{{ formatCurrency((product.value || 0) * (product.quantity || 1), country) }}</div>
            </div>
          </template>
        </template>
        <template v-else>
          <div
            v-for="(product, i) in order.products"
            :key="i"
            :class="[
              'flex items-start justify-between gap-4 py-4 border-b border-[var(--border-color)]',
              i === 0 ? 'pt-0' : '',
              i === order.products.length - 1 ? 'border-b-0 pb-0' : '',
            ]"
          >
            <div class="flex-1">
              <div class="font-medium">{{ product.name || t.productDefault }}</div>
              <div v-if="product.description" class="mt-1 text-sm text-[var(--text-tertiary)]">{{ product.description }}</div>
              <div class="mt-1 text-xs text-[var(--text-secondary)]">{{ t.qty }}: {{ product.quantity || 1 }}</div>
            </div>
            <div class="whitespace-nowrap font-semibold text-brand-primary">{{ formatCurrency((product.value || 0) * (product.quantity || 1), country) }}</div>
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
  if (!isMulti.value || !props.order?.products) return []
  const groups: Record<string, any[]> = {}
  props.order.products.forEach((item: any) => {
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
