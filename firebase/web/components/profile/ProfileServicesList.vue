<template>
  <div v-if="services?.length" class="rounded-xl border border-[#E4E4E7] bg-white p-7">
    <h3 class="mb-4 text-lg font-semibold text-[#18181B]">{{ t.servicesTitle }}</h3>

    <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
      <div
        v-for="service in services"
        :key="service.id"
        class="card-hover-lift overflow-hidden rounded-[10px] border border-[#E4E4E7]"
      >
        <!-- Service photo -->
        <div v-if="service.photo" class="h-[120px] overflow-hidden bg-[#F4F4F5]">
          <img
            :src="service.photo"
            :alt="service.name"
            loading="lazy"
            class="h-full w-full object-cover transition-transform duration-300 hover:scale-105"
          >
        </div>

        <!-- Service info -->
        <div class="px-3.5 py-3">
          <span class="block text-sm font-semibold text-[#18181B]">{{ service.name }}</span>
          <span v-if="showPrices && service.value" class="mt-1 block text-[13px] text-[#2563EB]">
            {{ t.startingAt }} {{ formatCurrency(service.value, country) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'

defineProps<{
  services: Array<{ id: string; name: string; value?: number; photo?: string }>
  showPrices: boolean
  country?: string
}>()

const { t } = useProfileI18n()
</script>
