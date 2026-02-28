<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-[3000] flex flex-col bg-black/95 transition-opacity duration-300"
      :class="isOpen ? 'opacity-100' : 'opacity-0'"
      @keydown.escape="close"
      @keydown.left="prev"
      @keydown.right="next"
    >
      <!-- Header -->
      <div class="flex items-center justify-between px-5 py-4 text-white">
        <span class="text-sm opacity-80">{{ currentIndex + 1 }} / {{ photos.length }}</span>
        <button
          class="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20"
          @click="close"
        >
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <!-- Content -->
      <div
        class="relative flex flex-1 items-center justify-center overflow-hidden"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
      >
        <!-- Prev button (desktop only) -->
        <button
          class="absolute left-4 top-1/2 z-10 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20 disabled:opacity-30 disabled:cursor-not-allowed sm:flex"
          :disabled="currentIndex === 0"
          @click="prev"
        >
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="15 18 9 12 15 6"/>
          </svg>
        </button>

        <img
          :src="currentPhoto?.url"
          :alt="currentPhoto?.description || 'Photo'"
          class="max-h-full max-w-full object-contain transition-transform duration-300"
        >

        <!-- Next button (desktop only) -->
        <button
          class="absolute right-4 top-1/2 z-10 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/20 disabled:opacity-30 disabled:cursor-not-allowed sm:flex"
          :disabled="currentIndex === photos.length - 1"
          @click="next"
        >
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="9 18 15 12 9 6"/>
          </svg>
        </button>
      </div>

      <!-- Description -->
      <div class="min-h-[52px] px-5 py-4 text-center text-sm text-white opacity-80">
        {{ currentPhoto?.description || '' }}
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
const props = defineProps<{
  photos: any[]
  initialIndex: number
  isOpen: boolean
}>()

const emit = defineEmits<{
  close: []
}>()

const currentIndex = ref(props.initialIndex)

watch(() => props.initialIndex, (val) => {
  currentIndex.value = val
})

watch(() => props.isOpen, (val) => {
  if (val) {
    document.body.style.overflow = 'hidden'
    document.addEventListener('keydown', handleKeydown)
  } else {
    document.body.style.overflow = ''
    document.removeEventListener('keydown', handleKeydown)
  }
})

const currentPhoto = computed(() => props.photos[currentIndex.value])

function prev() {
  if (currentIndex.value > 0) currentIndex.value--
}

function next() {
  if (currentIndex.value < props.photos.length - 1) currentIndex.value++
}

function close() {
  emit('close')
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Escape') close()
  else if (e.key === 'ArrowLeft') prev()
  else if (e.key === 'ArrowRight') next()
}

let touchStartX = 0
function onTouchStart(e: TouchEvent) {
  touchStartX = e.changedTouches[0].screenX
}

function onTouchEnd(e: TouchEvent) {
  const diff = touchStartX - e.changedTouches[0].screenX
  if (Math.abs(diff) > 50) {
    if (diff > 0) next()
    else prev()
  }
}

onUnmounted(() => {
  document.body.style.overflow = ''
  document.removeEventListener('keydown', handleKeydown)
})
</script>
