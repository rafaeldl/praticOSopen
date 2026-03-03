<template>
  <div v-if="photos?.length" class="rounded-xl border border-[#E4E4E7] bg-white p-7">
    <h3 class="mb-4 text-lg font-semibold text-[#18181B]">{{ t.portfolioTitle }}</h3>

    <!-- Featured (first) photo -->
    <div
      class="group relative mb-2 cursor-pointer overflow-hidden rounded-[10px] bg-[#F4F4F5]"
      @click="$emit('openLightbox', 0)"
    >
      <div class="h-[240px]">
        <img
          :src="photos[0].url"
          :alt="photos[0].description || ''"
          loading="lazy"
          class="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
        >
      </div>
      <div class="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100">
        <div class="absolute inset-x-0 bottom-0 p-4">
          <p v-if="photos[0].description" class="text-sm text-white">{{ photos[0].description }}</p>
        </div>
      </div>
    </div>

    <!-- Remaining photos grid -->
    <div v-if="photos.length > 1" class="grid grid-cols-3 gap-2 sm:grid-cols-5">
      <div
        v-for="(photo, index) in photos.slice(1)"
        :key="index + 1"
        class="group relative h-[90px] cursor-pointer overflow-hidden rounded-lg bg-[#F4F4F5]"
        @click="$emit('openLightbox', index + 1)"
      >
        <img
          :src="photo.url"
          :alt="photo.description || ''"
          loading="lazy"
          class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
        >
        <div class="absolute inset-0 bg-black/0 transition-colors duration-300 group-hover:bg-black/30" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  photos: Array<{ url: string; description?: string }>
}>()

defineEmits<{
  openLightbox: [index: number]
}>()

const { t } = useProfileI18n()
</script>
