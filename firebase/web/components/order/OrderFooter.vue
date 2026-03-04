<template>
  <footer class="bg-white px-4 py-5 pb-8 lg:px-16">
    <div class="h-px bg-[#EDF2F7]" />
    <!-- Powered by row -->
    <div class="mt-3 flex items-center justify-center gap-1.5">
      <svg class="h-3.5 w-3.5 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
        <polyline points="9 12 11 14 15 10"/>
      </svg>
      <span class="text-xs text-[#5A7184]">{{ t.poweredBy }}</span>
      <a href="https://praticos.web.app" target="_blank" class="text-xs font-bold text-[#1B5E7B] transition-colors hover:text-[#0D3B4F]">PraticOS</a>
    </div>
    <!-- Secure link text -->
    <p class="mt-2 text-center text-[10px] text-[#A0AEC0]">
      {{ t.secureLink }}
      <template v-if="termsOfService"> · {{ t.termsTitle }}</template>
    </p>
    <!-- Terms box (shown when not in quote status) -->
    <div v-if="termsOfService && !isQuote" class="mt-2 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFB] p-3 lg:mx-auto lg:max-w-[600px]">
      <div class="mb-2 flex items-center gap-1.5">
        <svg class="h-[13px] w-[13px] text-[#8FA3B8]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M16 16v3a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8c0-1.1.9-2 2-2h3"/><path d="M8 2h13a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z"/><line x1="10" y1="6" x2="18" y2="6"/><line x1="10" y1="9.5" x2="18" y2="9.5"/><line x1="10" y1="13" x2="15" y2="13"/>
        </svg>
        <span class="text-[11px] font-bold text-[#5A7184]">{{ t.termsTitle }}</span>
      </div>
      <p class="whitespace-pre-line text-[11px] leading-[1.6] text-[#8FA3B8]">{{ termsOfService }}</p>
    </div>
  </footer>
</template>

<script setup lang="ts">
defineProps<{
  termsOfService?: string | null
  isQuote?: boolean
}>()

const { t } = useOrderI18n()
</script>
