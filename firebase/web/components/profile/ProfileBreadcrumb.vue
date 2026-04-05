<template>
  <div class="hidden border-b border-[var(--border-color)] bg-[var(--bg-tertiary)] sm:block">
    <div class="mx-auto flex max-w-7xl items-center gap-2 px-5 py-3 lg:px-10">
      <a href="https://praticos.web.app" class="text-xs text-[#71717A] transition-colors hover:text-[#2563EB]">
        {{ t.breadcrumbHome }}
      </a>
      <svg class="h-3 w-3 text-[#A1A1AA]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="9 18 15 12 9 6" />
      </svg>
      <a v-if="segmentLabel" href="https://praticos.web.app" class="text-xs text-[#71717A] transition-colors hover:text-[#2563EB]">
        {{ segmentLabel }}
      </a>
      <svg v-if="segmentLabel" class="h-3 w-3 text-[#A1A1AA]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="9 18 15 12 9 6" />
      </svg>
      <span class="text-xs font-medium text-[#18181B]">{{ companyName }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  companyName: string
  segmentLabel?: string
}>()

const { t } = useProfileI18n()
</script>
