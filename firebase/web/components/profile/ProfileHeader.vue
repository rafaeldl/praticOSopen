<template>
  <header class="border-b border-[#E4E4E7] bg-white">
    <div class="mx-auto max-w-7xl px-5 py-6 lg:px-10">
      <div class="flex flex-col items-center gap-6 sm:flex-row sm:items-start sm:gap-8">
        <!-- Company logo / avatar -->
        <img
          v-if="company?.logo"
          :src="company.logo"
          :alt="company.name"
          class="h-[120px] w-[120px] shrink-0 rounded-2xl border border-[#E4E4E7] object-cover sm:h-[140px] sm:w-[140px]"
        >
        <div
          v-else-if="company?.name"
          class="flex h-[120px] w-[120px] shrink-0 items-center justify-center rounded-2xl border border-[#E4E4E7] bg-[#EFF6FF] font-heading text-5xl font-bold text-[#2563EB] sm:h-[140px] sm:w-[140px]"
        >
          {{ company.name.charAt(0).toUpperCase() }}
        </div>

        <!-- Info -->
        <div class="flex-1 text-center sm:text-left">
          <!-- Name + badges -->
          <div class="mb-2 flex flex-wrap items-center justify-center gap-2.5 sm:justify-start">
            <h1 class="text-[24px] font-bold tracking-tight text-[#18181B] sm:text-[28px]">
              {{ company?.name }}
            </h1>
            <span
              v-if="company?.verified"
              class="inline-flex items-center gap-1 rounded-full bg-[#DCFCE7] px-2.5 py-0.5 text-xs font-semibold text-[#16A34A]"
            >
              <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                <path d="M9 12l2 2 4-4"/>
              </svg>
              {{ t.verified }}
            </span>
            <span
              v-if="(certCount ?? 0) > 0"
              class="inline-flex items-center gap-1 rounded-full bg-[#EFF6FF] px-2.5 py-0.5 text-xs font-semibold text-[#2563EB]"
            >
              <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="8" r="7"/>
                <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/>
              </svg>
              {{ certCount }}
            </span>
          </div>

          <!-- Meta row: rating, location, completed orders -->
          <div class="mb-3 flex flex-wrap items-center justify-center gap-x-2 gap-y-1 text-sm text-[#71717A] sm:justify-start">
            <template v-if="stats.avgRating > 0">
              <div class="flex items-center gap-1">
                <svg class="h-4 w-4 text-[#F59E0B]" viewBox="0 0 24 24" fill="currentColor">
                  <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                </svg>
                <span class="font-semibold text-[#18181B]">{{ stats.avgRating }}</span>
                <span>({{ stats.reviewCount }} {{ t.reviewCount }})</span>
              </div>
              <span v-if="locationText || stats.completedOrders > 0">&middot;</span>
            </template>
            <span v-if="locationText" class="inline-flex items-center gap-1">
              <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                <circle cx="12" cy="10" r="3"/>
              </svg>
              {{ locationText }}
            </span>
            <span v-if="locationText && stats.completedOrders > 0">&middot;</span>
            <span v-if="stats.completedOrders > 0">
              {{ formattedOrders }}+ {{ t.completedOrders }}
            </span>
          </div>

          <!-- Tags -->
          <div v-if="company?.tags?.length" class="mb-4 flex flex-wrap justify-center gap-2 sm:justify-start">
            <span
              v-for="tag in company.tags"
              :key="tag"
              class="rounded-full bg-[#EFF6FF] px-3 py-1 text-xs font-medium text-[#2563EB]"
            >
              {{ tag }}
            </span>
          </div>

          <!-- CTAs -->
          <div class="flex flex-wrap justify-center gap-3 sm:justify-start">
            <a
              v-if="company?.whatsapp"
              :href="whatsappUrl"
              target="_blank"
              rel="noopener"
              class="btn bg-[#25D366] font-bold text-white shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
            >
              <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
              </svg>
              {{ t.whatsappFull }}
            </a>
            <a
              v-if="company?.phone"
              :href="'tel:' + company.phone"
              class="btn border border-[#E4E4E7] bg-white font-semibold text-[#18181B] transition-all hover:bg-[#F4F4F5]"
            >
              <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
                <line x1="16" y1="2" x2="16" y2="6"/>
                <line x1="8" y1="2" x2="8" y2="6"/>
                <line x1="3" y1="10" x2="21" y2="10"/>
              </svg>
              {{ t.scheduleFull }}
            </a>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
const props = defineProps<{
  company: any
  segmentLabel?: string
  stats: {
    completedOrders: number
    avgRating: number
    reviewCount: number
  }
  certCount?: number
}>()

const { t } = useProfileI18n()

const locationText = computed(() => {
  const parts = [props.company?.city, props.company?.state].filter(Boolean)
  return parts.join(', ')
})

const formattedOrders = computed(() => {
  const n = props.stats.completedOrders
  if (n >= 100) return Math.floor(n / 50) * 50
  return n
})

const whatsappUrl = computed(() => {
  if (!props.company?.whatsapp) return ''
  const phone = props.company.whatsapp.replace(/\D/g, '')
  return `https://wa.me/${phone}`
})
</script>
