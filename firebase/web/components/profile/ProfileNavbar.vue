<template>
  <nav class="sticky top-0 z-50 h-16 border-b border-[#E4E4E7] bg-white">
    <div class="mx-auto flex h-full max-w-7xl items-center justify-between px-5 lg:px-10">
      <!-- Left: Logo + Links -->
      <div class="flex items-center gap-8">
        <a href="https://praticos.web.app" class="text-lg font-bold text-[#2563EB]">PraticOS</a>
        <div class="hidden items-center gap-6 sm:flex">
          <a href="https://praticos.web.app" class="text-sm text-[#71717A] transition-colors hover:text-[#18181B]">{{ t.navExplore }}</a>
          <a href="https://praticos.web.app" class="text-sm text-[#71717A] transition-colors hover:text-[#18181B]">{{ t.navCategories }}</a>
          <a href="https://praticos.web.app" class="text-sm text-[#71717A] transition-colors hover:text-[#18181B]">{{ t.navHowItWorks }}</a>
        </div>
      </div>

      <!-- Right: Search + Sign in -->
      <div class="flex items-center gap-4">
        <div class="relative hidden md:block">
          <svg class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#A1A1AA]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            type="text"
            :placeholder="t.navSearch"
            class="h-9 w-[220px] rounded-lg border border-[#E4E4E7] bg-[#F4F4F5] pl-9 pr-3 text-sm text-[#18181B] placeholder-[#A1A1AA] outline-none transition-colors focus:border-[#2563EB] focus:bg-white"
            readonly
          >
        </div>
        <a
          href="https://praticos.web.app"
          class="rounded-lg bg-[#2563EB] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#1D4ED8]"
        >
          {{ t.navSignIn }}
        </a>
      </div>
    </div>
  </nav>
</template>

<script setup lang="ts">
const { t } = useProfileI18n()
</script>
