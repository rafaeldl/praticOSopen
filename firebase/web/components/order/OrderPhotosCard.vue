<template>
  <div v-if="photos?.length" class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Header: icon + title + count text -->
    <div class="mb-3.5 flex items-center gap-2">
      <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
        <circle cx="12" cy="13" r="4"/>
      </svg>
      <h3 class="flex-1 text-sm font-bold text-[#1A2B3C]">{{ t.photos }}</h3>
      <span class="text-xs text-[#8FA3B8]">{{ photos.length }} {{ photos.length === 1 ? t.photo : t.photos.toLowerCase() }}</span>
    </div>

    <!-- Photo grid -->
    <div class="flex gap-2.5 overflow-x-auto pb-1 lg:flex-wrap lg:overflow-visible">
      <div
        v-for="(photo, index) in photos"
        :key="index"
        class="photo-thumb relative flex-shrink-0 cursor-pointer overflow-hidden rounded-xl bg-[#F0F4F8] transition-all duration-200 hover:scale-[1.03] hover:shadow-md active:scale-[0.98]"
        @click="$emit('openLightbox', index)"
      >
        <img
          :src="photo.url"
          :alt="photo.description || t.photo"
          loading="lazy"
          class="h-[110px] w-[140px] object-cover lg:h-[180px] lg:w-auto lg:min-w-[180px]"
        >
        <div v-if="photo.description" class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent px-2.5 pb-2 pt-6 text-[10px] leading-tight text-white lg:text-[11px]">
          {{ photo.description }}
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
