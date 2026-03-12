<template>
  <header class="relative overflow-hidden bg-gradient-to-b from-[#0D3B4F] to-[#1B5E7B]">
    <!-- Subtle noise texture overlay -->
    <div class="pointer-events-none absolute inset-0 opacity-[0.03]" style="background-image: url('data:image/svg+xml,%3Csvg viewBox=%220 0 256 256%22 xmlns=%22http://www.w3.org/2000/svg%22%3E%3Cfilter id=%22n%22%3E%3CfeTurbulence type=%22fractalNoise%22 baseFrequency=%220.9%22 numOctaves=%224%22 stitchTiles=%22stitch%22/%3E%3C/filter%3E%3Crect width=%22100%25%22 height=%22100%25%22 filter=%22url(%23n)%22/%3E%3C/svg%3E')" />

    <!-- Mobile layout -->
    <div class="lg:hidden flex flex-col gap-4 relative z-10 px-6 pt-11 pb-7">
      <!-- Top row: brand + OS pill -->
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-white/60 tracking-wide">PraticOS</span>
        <span class="inline-flex items-center gap-1 rounded-full bg-white/20 px-2.5 py-1">
          <svg class="h-2.5 w-2.5 text-white/80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>
          </svg>
          <span class="text-[10px] font-semibold text-white/80">OS #{{ order?.number || '---' }}</span>
        </span>
      </div>

      <!-- Company name -->
      <h1 class="text-xl font-bold text-white leading-tight">
        {{ company?.name || '' }}
      </h1>

      <!-- Company info row: phone + city -->
      <div v-if="customerPhone || customerCity" class="flex flex-wrap items-center gap-3">
        <span v-if="customerPhone" class="inline-flex items-center gap-1 text-[11px] text-white/70">
          <svg class="h-[11px] w-[11px] text-white/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
          </svg>
          {{ customerPhone }}
        </span>
        <span v-if="customerPhone && customerCity" class="text-[11px] text-white/40">&middot;</span>
        <span v-if="customerCity" class="inline-flex items-center gap-1 text-[11px] text-white/70">
          <svg class="h-[11px] w-[11px] text-white/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
          </svg>
          {{ customerCity }}
        </span>
      </div>

      <!-- Info grid: status + customer + forecast -->
      <div class="flex gap-0">
        <div class="flex flex-1 flex-col gap-1">
          <span class="text-[11px] font-medium text-white/70">Status</span>
          <div class="flex items-center gap-1.5">
            <span :class="['inline-block h-2 w-2 rounded-full', statusDotColor]" />
            <span class="text-sm font-semibold text-white">{{ statusLabel }}</span>
          </div>
        </div>
        <div class="flex flex-1 flex-col gap-1">
          <span class="text-[11px] font-medium text-white/70">{{ t.customer }}</span>
          <span class="text-sm font-semibold text-white truncate">{{ maskedCustomerName }}</span>
        </div>
        <div v-if="order?.dueDate" class="flex flex-1 flex-col gap-1">
          <span class="text-[11px] font-medium text-white/70">{{ t.forecast }}</span>
          <span class="text-sm font-semibold text-white">{{ formattedDueDate }}</span>
        </div>
      </div>
    </div>

    <!-- Desktop layout -->
    <div class="hidden lg:flex flex-col gap-6 relative z-10 px-16 pt-10 pb-8">
      <!-- Top row: brand + OS pill -->
      <div class="flex items-center justify-between">
        <span class="text-xs font-bold text-white/60 tracking-wide">PraticOS</span>
        <span class="inline-flex items-center gap-1.5 rounded-full bg-white/20 px-3 py-1.5">
          <svg class="h-3 w-3 text-white/80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>
          </svg>
          <span class="text-[11px] font-semibold text-white/80">OS #{{ order?.number || '---' }}</span>
        </span>
      </div>

      <!-- Main row: title col + info row -->
      <div class="flex items-end justify-between">
        <div class="flex flex-col gap-2">
          <h1 class="text-[28px] font-bold text-white leading-tight">
            {{ company?.name || '' }}
          </h1>
          <div v-if="customerPhone || customerCity" class="flex flex-wrap items-center gap-3">
            <span v-if="customerPhone" class="inline-flex items-center gap-1 text-[11px] text-white/70">
              <svg class="h-[11px] w-[11px] text-white/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>
              </svg>
              {{ customerPhone }}
            </span>
            <span v-if="customerPhone && customerCity" class="text-[11px] text-white/40">&middot;</span>
            <span v-if="customerCity" class="inline-flex items-center gap-1 text-[11px] text-white/70">
              <svg class="h-[11px] w-[11px] text-white/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
              </svg>
              {{ customerCity }}
            </span>
          </div>
        </div>

        <!-- Info columns -->
        <div class="flex items-start gap-10">
          <div class="flex flex-col gap-1">
            <span class="text-[11px] font-medium text-white/70">Status</span>
            <div class="flex items-center gap-1.5">
              <span :class="['inline-block h-2 w-2 rounded-full', statusDotColor]" />
              <span class="text-sm font-semibold text-white">{{ statusLabel }}</span>
            </div>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-[11px] font-medium text-white/70">{{ t.customer }}</span>
            <span class="text-sm font-semibold text-white">{{ maskedCustomerName }}</span>
          </div>
          <div v-if="order?.dueDate" class="flex flex-col gap-1">
            <span class="text-[11px] font-medium text-white/70">{{ t.forecast }}</span>
            <span class="text-sm font-semibold text-white">{{ formattedDueDate }}</span>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
const props = defineProps<{
  order: any
  company: any
}>()

const { t, lang, getStatusLabel } = useOrderI18n()

const statusLabel = computed(() => getStatusLabel(props.order?.status))

const statusDotColor = computed(() => {
  const s = props.order?.status
  const map: Record<string, string> = {
    quote: 'bg-blue-400',
    approved: 'bg-emerald-400',
    progress: 'bg-amber-400',
    done: 'bg-emerald-400',
    canceled: 'bg-red-400',
  }
  return map[s] || map.quote
})

const customerPhone = computed(() => props.order?.customer?.phone || '')

const customerCity = computed(() => {
  const addr = props.order?.customer?.address
  if (!addr) return ''
  const parts = [addr.city, addr.state].filter(Boolean)
  return parts.join(', ')
})

const maskedCustomerName = computed(() => {
  const name = props.order?.customer?.name || ''
  if (!name) return '-'
  const parts = name.split(' ')
  if (parts.length <= 1) return name
  return parts[0] + ' ' + parts.slice(1).map((p: string) => p.charAt(0) + '****').join(' ')
})

const formattedDueDate = computed(() => {
  if (!props.order?.dueDate) return ''
  const date = new Date(props.order.dueDate)
  const locale = lang.value === 'en' ? 'en-US' : lang.value === 'es' ? 'es-ES' : 'pt-BR'
  return date.toLocaleDateString(locale, { day: '2-digit', month: 'short' })
})
</script>
