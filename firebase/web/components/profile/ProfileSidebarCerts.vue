<template>
  <div v-if="certifications?.length" class="rounded-xl border border-[#E4E4E7] bg-white p-6">
    <!-- Title -->
    <div class="mb-4 flex items-center gap-2">
      <svg class="h-5 w-5 text-[#F59E0B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="12" cy="8" r="7"/>
        <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/>
      </svg>
      <h3 class="text-lg font-semibold text-[#18181B]">{{ t.certifications }}</h3>
    </div>

    <!-- Certifications list -->
    <div class="flex flex-col gap-4">
      <div
        v-for="cert in certifications"
        :key="cert.id"
        class="flex items-start gap-3"
      >
        <!-- Icon -->
        <div class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-lg bg-[#EFF6FF]">
          <svg class="h-4 w-4 text-[#2563EB]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
            <polyline points="14 2 14 8 20 8"/>
            <line x1="16" y1="13" x2="8" y2="13"/>
            <line x1="16" y1="17" x2="8" y2="17"/>
          </svg>
        </div>

        <!-- Info -->
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-1.5">
            <span class="text-sm font-medium text-[#18181B]">{{ cert.name }}</span>
            <svg class="h-4 w-4 shrink-0 text-[#16A34A]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22 4 12 14.01 9 11.01"/>
            </svg>
          </div>
          <span v-if="cert.issuer" class="text-xs text-[#A1A1AA]">{{ cert.issuer }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  certifications: Array<{
    id: string
    name: string
    issuer?: string
    verifiedAt?: string
  }>
}>()

const { t } = useProfileI18n()
</script>
