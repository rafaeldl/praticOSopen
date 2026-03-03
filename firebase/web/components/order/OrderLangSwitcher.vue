<template>
  <div class="fixed bottom-6 right-6 z-[1000] flex gap-1.5 rounded-full border border-[var(--border-color)] bg-[var(--bg-card)] p-1 shadow-lg safe-area-lang">
    <button
      v-for="l in languages"
      :key="l.code"
      :class="[
        'h-9 w-9 rounded-full border-0 font-body text-xs font-semibold tracking-wide transition-all cursor-pointer',
        l.code === lang ? 'bg-brand-primary text-white' : 'bg-transparent text-[var(--text-secondary)] hover:bg-[var(--bg-tertiary)] hover:text-[var(--text-primary)]',
      ]"
      @click="setLang(l.code as any)"
    >
      {{ l.label }}
    </button>
  </div>
</template>

<script setup lang="ts">
const { lang, setLang } = useOrderI18n()

const languages = [
  { code: 'pt', label: 'PT' },
  { code: 'en', label: 'EN' },
  { code: 'es', label: 'ES' },
]
</script>

<style scoped>
@supports (bottom: env(safe-area-inset-bottom)) {
  .safe-area-lang {
    bottom: calc(24px + env(safe-area-inset-bottom));
  }
}
</style>
