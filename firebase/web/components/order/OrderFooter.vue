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
    <p class="mt-2 text-center text-[10px] text-[#A0AEC0]">{{ t.secureLink }}</p>
  </footer>
</template>

<script setup lang="ts">
const { t } = useOrderI18n()
</script>
