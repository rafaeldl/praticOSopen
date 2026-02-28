<template>
  <div v-if="bio" class="order-card animate-fade-in-up mb-5 overflow-hidden rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)]">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
        <circle cx="12" cy="7" r="4"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.about }}</h3>
    </div>
    <div class="p-5">
      <p
        :class="[
          'whitespace-pre-line text-sm leading-relaxed text-[var(--text-secondary)]',
          !expanded && 'line-clamp-3',
        ]"
      >
        {{ bio }}
      </p>
      <button
        v-if="isLong"
        class="mt-2 text-sm font-medium text-brand-primary hover:underline"
        @click="expanded = !expanded"
      >
        {{ expanded ? t.readLess : t.readMore }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  bio: string
}>()

const { t } = useProfileI18n()
const expanded = ref(false)
const isLong = computed(() => props.bio.length > 180 || props.bio.split('\n').length > 3)
</script>
