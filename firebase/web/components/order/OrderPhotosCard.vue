<template>
  <div v-if="photos?.length" class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mb-5">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
        <circle cx="8.5" cy="8.5" r="1.5"/>
        <polyline points="21 15 16 10 5 21"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.photos }}</h3>
    </div>
    <div class="p-5">
      <div class="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-3">
        <div
          v-for="(photo, index) in photos"
          :key="index"
          class="relative aspect-square cursor-pointer overflow-hidden rounded-xl bg-[var(--bg-tertiary)] transition-transform duration-200 hover:scale-[1.02] hover:shadow-lg"
          @click="$emit('openLightbox', index)"
        >
          <img :src="photo.url" :alt="photo.description || t.photo" loading="lazy" class="h-full w-full object-cover">
          <div v-if="photo.description" class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/80 to-transparent p-2 text-xs text-white">
            {{ photo.description }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  photos: any[]
}>()

defineEmits<{
  openLightbox: [index: number]
}>()

const { t } = useOrderI18n()
</script>
