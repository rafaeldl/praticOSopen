<template>
  <div class="rounded-xl border border-[#E4E4E7] bg-white p-6">
    <!-- Title -->
    <h3 class="mb-1 text-lg font-semibold text-[#18181B]">{{ t.requestQuote }}</h3>
    <p class="mb-5 text-sm text-[#71717A]">
      {{ t.contactDesc.replace('{name}', company?.name || '') }}
    </p>

    <!-- Action buttons -->
    <div class="mb-5 flex flex-col gap-3">
      <a
        v-if="company?.whatsapp"
        :href="whatsappUrl"
        target="_blank"
        rel="noopener"
        class="btn w-full animate-pulse-glow bg-[#25D366] py-3 text-center font-bold text-white shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
      >
        <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
          <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
        </svg>
        {{ t.whatsappFull }}
      </a>

      <a
        v-if="company?.phone"
        :href="'tel:' + company.phone"
        class="btn w-full border border-[#E4E4E7] bg-white py-3 text-center font-semibold text-[#18181B] transition-all hover:bg-[#F4F4F5]"
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

    <!-- Divider -->
    <div class="mb-5 border-t border-[#E4E4E7]" />

    <!-- Trust signals -->
    <div class="flex flex-col gap-3">
      <div v-if="company?.verified" class="flex items-center gap-3">
        <svg class="h-4 w-4 shrink-0 text-[#16A34A]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
          <path d="M9 12l2 2 4-4"/>
        </svg>
        <span class="text-sm text-[#71717A]">{{ t.trustVerified }}</span>
      </div>

      <div class="flex items-center gap-3">
        <svg class="h-4 w-4 shrink-0 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <polyline points="12 6 12 12 16 14"/>
        </svg>
        <span class="text-sm text-[#71717A]">{{ t.trustResponse }}</span>
      </div>

      <div v-if="stats.completedOrders > 0" class="flex items-center gap-3">
        <svg class="h-4 w-4 shrink-0 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20 7h-9"/>
          <path d="M14 17H5"/>
          <circle cx="17" cy="17" r="3"/>
          <circle cx="7" cy="7" r="3"/>
        </svg>
        <span class="text-sm text-[#71717A]">
          {{ t.trustJobs.replace('{n}', String(formattedOrders)) }}
        </span>
      </div>

      <div v-if="stats.avgRating > 0" class="flex items-center gap-3">
        <svg class="h-4 w-4 shrink-0 text-[#F59E0B]" viewBox="0 0 24 24" fill="currentColor">
          <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
        </svg>
        <span class="text-sm text-[#71717A]">
          {{ t.trustRating.replace('{rating}', String(stats.avgRating)).replace('{count}', String(stats.reviewCount)) }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  company: any
  stats: {
    completedOrders: number
    avgRating: number
    reviewCount: number
  }
}>()

const { t } = useProfileI18n()

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
