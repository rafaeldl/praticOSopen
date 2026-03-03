<template>
  <div v-if="hasContent" class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Total header -->
    <div class="flex items-center justify-between">
      <span class="text-sm font-semibold text-[#5A7184]">Total</span>
      <span class="text-2xl font-bold text-[#1B5E7B] tabular-nums">{{ formatCurrency(remaining, country) }}</span>
    </div>

    <!-- Subtotal / discount / paid breakdown -->
    <div v-if="discount > 0 || paidAmount > 0" class="mt-3 space-y-1 rounded-xl bg-[#F8FAFB] p-3">
      <div class="flex items-center justify-between text-[13px]">
        <span class="text-[#5A7184]">{{ t.subtotal }}</span>
        <span class="font-medium text-[#1A2B3C] tabular-nums">{{ formatCurrency(subtotal, country) }}</span>
      </div>
      <div v-if="discount > 0" class="flex items-center justify-between text-[13px] text-[#16A34A]">
        <span>{{ t.discount }}</span>
        <span class="font-medium tabular-nums">-{{ formatCurrency(discount, country) }}</span>
      </div>
      <div v-if="paidAmount > 0" class="flex items-center justify-between text-[13px] text-[#5A7184]">
        <span>{{ t.paid }}</span>
        <span class="font-medium tabular-nums">-{{ formatCurrency(paidAmount, country) }}</span>
      </div>
    </div>

    <!-- Services -->
    <template v-if="order?.services?.length">
      <div class="my-4 h-px bg-[#EDF2F7]" />
      <h4 class="mb-3 text-[11px] font-semibold uppercase tracking-[0.5px] text-[#5A7184]">{{ t.services }}</h4>
      <div class="flex flex-col gap-3.5">
        <div v-for="(service, i) in order.services" :key="'s-' + i">
          <div class="flex items-start justify-between gap-3">
            <span class="text-[13px] font-medium text-[#1A2B3C]">{{ service.name || t.serviceDefault }}</span>
            <span class="flex-shrink-0 text-[13px] font-semibold text-[#1A2B3C] tabular-nums">{{ formatCurrency(service.value, country) }}</span>
          </div>
          <div class="mt-1 flex items-center gap-1.5">
            <span v-if="serviceDeviceName(service)" class="inline-block rounded bg-[#EBF4FA] px-1.5 py-0.5 text-[10px] font-medium text-[#1B5E7B]">
              {{ serviceDeviceName(service) }}
            </span>
            <span v-if="service.description" class="text-[11px] text-[#8FA3B8]">{{ service.description }}</span>
          </div>
        </div>
      </div>
    </template>

    <!-- Products -->
    <template v-if="order?.products?.length">
      <div class="my-4 h-px bg-[#EDF2F7]" />
      <h4 class="mb-3 text-[11px] font-semibold uppercase tracking-[0.5px] text-[#5A7184]">{{ t.products }}</h4>
      <div class="flex flex-col gap-3.5">
        <div v-for="(product, i) in order.products" :key="'p-' + i">
          <div class="flex items-start justify-between gap-3">
            <span class="text-[13px] font-medium text-[#1A2B3C]">{{ product.name || t.productDefault }}</span>
            <span class="flex-shrink-0 text-[13px] font-semibold text-[#1A2B3C] tabular-nums">{{ formatCurrency((product.value || 0) * (product.quantity || 1), country) }}</span>
          </div>
          <div class="mt-1 flex items-center gap-1.5">
            <span class="inline-block rounded bg-[#FFF3E0] px-1.5 py-0.5 text-[10px] font-medium text-[#E67E22]">{{ t.productDefault }}</span>
            <span class="text-[11px] text-[#8FA3B8]">{{ t.qty }}: {{ product.quantity || 1 }}</span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'

const props = defineProps<{
  order: any
  country?: string
}>()

const { t } = useOrderI18n()

const hasContent = computed(() => {
  return props.order?.services?.length || props.order?.products?.length || props.order?.total
})

const total = computed(() => props.order?.total || 0)
const discount = computed(() => props.order?.discount || 0)
const paidAmount = computed(() => props.order?.paidAmount || 0)
const subtotal = computed(() => total.value + discount.value)
const remaining = computed(() => total.value - paidAmount.value)

const deviceMap = computed(() => {
  const devices = props.order?.devices?.length
    ? props.order.devices
    : (props.order?.device ? [{ id: props.order.device.id || '_single', name: props.order.device.name }] : [])
  const map: Record<string, string> = {}
  devices.forEach((d: any) => { map[d.id] = d.name })
  return map
})

function serviceDeviceName(service: any): string {
  if (!service.deviceId) return ''
  return deviceMap.value[service.deviceId] || ''
}
</script>
