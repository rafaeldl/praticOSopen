<template>
  <div class="fixed bottom-[88px] right-6 z-[1000] flex gap-1.5 rounded-full border border-[#E4E4E7] bg-white p-1 shadow-lg safe-area-lang lg:bottom-6">
    <button
      v-for="l in languages"
      :key="l.code"
      :class="[
        'h-9 w-9 rounded-full border-0 text-xs font-semibold tracking-wide transition-all cursor-pointer',
        l.code === lang ? 'bg-[#2563EB] text-white' : 'bg-transparent text-[#71717A] hover:bg-[#F4F4F5] hover:text-[#18181B]',
      ]"
      @click="setLang(l.code as any)"
    >
      {{ l.label }}
    </button>
  </div>
</template>

<script setup lang="ts">
const { lang, setLang } = useProfileI18n()

const languages = [
  { code: 'pt', label: 'PT' },
  { code: 'en', label: 'EN' },
  { code: 'es', label: 'ES' },
]
</script>

<style scoped>
@supports (bottom: env(safe-area-inset-bottom)) {
  .safe-area-lang {
    bottom: calc(88px + env(safe-area-inset-bottom));
  }
}
</style>
