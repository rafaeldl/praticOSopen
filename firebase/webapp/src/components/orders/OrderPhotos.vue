<script setup lang="ts">
// Photos: see them (viewPhotos), add by choosing, dragging or pasting
// (attachPhotos). "Enviando…" while they go up; a failure says so (the app
// swallows it: defect 18). Photos saved elsewhere arrive through the listener.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { ImagePlus } from '@lucide/vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import type { Order, OrderPhoto } from '@/lib/orders/model'
import { uploadPhoto } from '@/lib/orders/writes'
import { can } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { ui } from '@/lib/ui'

const props = defineProps<{ order: Order }>()
const uploading = ref(0)
const over = ref(false)
const viewing = ref<OrderPhoto | null>(null)
const canAttach = computed(() => can('attachPhotos'))
const canView = computed(() => can('viewPhotos') || canAttach.value)

async function add(files: FileList | File[] | null | undefined) {
  const images = [...(files ?? [])].filter((file) => file.type.startsWith('image/'))
  if (!images.length || !canAttach.value) return
  uploading.value += images.length
  let failed = 0
  for (const file of images) {
    try {
      await uploadPhoto(props.order.id, file)
    } catch (error) {
      console.warn('photos: upload failed', error)
      failed++
    } finally {
      uploading.value--
    }
  }
  showToast(failed ? t('web.order.photoFailed', { count: failed }) : t('web.order.photoAdded', { count: images.length }))
}

function onPaste(event: ClipboardEvent) {
  // A dialog or drawer on top (a checklist, say) is not the order's photos.
  if (ui.layers > 0) return
  if (event.clipboardData?.files?.length && !(event.target as HTMLElement)?.matches?.('input, textarea')) void add(event.clipboardData.files)
}
onMounted(() => window.addEventListener('paste', onPaste))
onBeforeUnmount(() => window.removeEventListener('paste', onPaste))
</script>

<template>
  <section
    v-if="canView && (order.photos.length || canAttach)"
    class="od-sec od-sec--photos"
    aria-labelledby="od-photos-title"
    @dragover.prevent="over = true"
    @dragleave="over = false"
    @drop.prevent="over = false; add($event.dataTransfer?.files)"
  >
    <h3 id="od-photos-title">{{ t('orderPhotosSection') }}</h3>
    <div class="photos" data-testid="photos">
      <button v-for="(photo, index) in order.photos" :key="photo.id ?? photo.url" type="button" class="photo" :aria-label="t('web.order.viewPhoto', { number: index + 1 })" @click="viewing = photo">
        <img :src="photo.url" alt="" loading="lazy" />
      </button>
      <label v-if="canAttach" class="photo photo-add" :class="{ 'is-over': over }">
        <ImagePlus :size="18" aria-hidden="true" />
        <span class="photo-add-text">{{ uploading ? t('orderUploading') : t('web.order.addPhoto') }}</span>
        <input class="sr" type="file" accept="image/*" multiple :aria-label="t('addPhoto')" @change="add(($event.target as HTMLInputElement).files)" />
      </label>
    </div>
    <p v-if="uploading" class="sub" role="status">{{ t('orderUploading') }}</p>
  </section>
  <Layer v-if="viewing" kind="dialog" :label="t('orderPhotosSection')" @close="viewing = null">
    <template #default="{ close }">
      <div class="layer-body"><img class="photo-full" :src="viewing.url" :alt="viewing.description || t('orderPhotosSection')" /></div>
      <div class="layer-foot"><button type="button" class="btn" @click="close()">{{ t('close') }}</button></div>
    </template>
  </Layer>
</template>
