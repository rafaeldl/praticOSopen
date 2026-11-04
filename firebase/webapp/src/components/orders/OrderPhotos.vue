    else if (!openTab(viewing.value?.url)) showToast(t('web.share.downloadFailed'))<script setup lang="ts">
// Photos: see them (viewPhotos), add by choosing, dragging or pasting
// (attachPhotos). "Enviando…" while they go up; a failure says so (the app
// swallows it: defect 18). Photos saved elsewhere arrive through the listener.
// The viewer passes between photos (buttons and ← →) and makes one the cover
// (the first photo, as the app's coverPhotoUrl: order.photo.viewer, order.photo.cover).
// Sending one (order.photo.share): the browser's sheet with the file where it
// takes files, "Baixar", "Copiar o link" and WhatsApp with the link to the customer.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { ChevronLeft, ChevronRight, ImagePlus } from '@lucide/vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import ShareButtons from '@/components/ShareButtons.vue'
import type { Order, OrderPhoto } from '@/lib/orders/model'
import { deletePhoto, setCoverPhoto, uploadPhoto } from '@/lib/orders/writes'
import ConfirmDialog from './ConfirmDialog.vue'
import { can } from '@/lib/session'
import { orderShort } from '@/lib/orders/text'
import { downloadFile, fileFromUrl } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { ui } from '@/lib/ui'

const props = defineProps<{ order: Order }>()
const uploading = ref(0)
const over = ref(false)
/** Index of the photo open in the viewer. */
const viewingIndex = ref<number | null>(null)
const viewing = computed<OrderPhoto | null>(() => (viewingIndex.value === null ? null : (props.order.photos[viewingIndex.value] ?? null)))
const covering = ref(false)

function step(by: number) {
  const count = props.order.photos.length
  if (viewingIndex.value === null || count < 2) return
  viewingIndex.value = (viewingIndex.value + by + count) % count
}

function onViewerKey(event: KeyboardEvent) {
  if (viewingIndex.value === null || asking.value || event.defaultPrevented) return
  if (event.key === 'ArrowRight') step(1)
  else if (event.key === 'ArrowLeft') step(-1)
  else return
  event.preventDefault()
}

/** order.photo.cover: the photo goes first (the cover of the order, its PDF and the list). */
async function makeCover() {
  const photo = viewing.value
  if (!photo || covering.value) return
  covering.value = true
  try {
    await setCoverPhoto(props.order.id, photo)
    viewingIndex.value = 0
    showToast(t('orderPhotoCoverSet'))
  } catch (error) {
    console.warn('photos: cover failed', error)
    showToast(t('web.order.photoCoverFailed'))
  } finally {
    covering.value = false
  }
}
const asking = ref(false)
const deleting = ref(false)

/** order.photo.delete: asks first; the photo leaves the order and the Storage. */
async function remove() {
  const photo = viewing.value
  asking.value = false
  if (!photo || deleting.value) return
  deleting.value = true
  try {
    await deletePhoto(props.order.id, photo)
    viewingIndex.value = null
    showToast(t('web.order.photoDeleted'))
  } catch (error) {
    console.warn('photos: delete failed', error)
    showToast(t('web.order.photoDeleteFailed'))
  } finally {
    deleting.value = false
  }
}
/** The photo as a file (for the sheet and "Baixar"); null when the browser cannot read it. */
function photoName(): string {
  return `${orderShort()}-${props.order.number ?? ''}-${(viewingIndex.value ?? 0) + 1}.jpg`.replace(/\s+/g, '-')
}
const photoFile = () => (viewing.value ? fileFromUrl(viewing.value.url, photoName()) : Promise.resolve(null))
const photoText = computed(() => (viewing.value ? t('web.share.photoText', { order: orderShort(), number: props.order.number ?? '', url: viewing.value.url }) : ''))
const downloading = ref(false)
function openTab(url: string | undefined): boolean {
  const tab = url ? window.open(url, '_blank') : null
  if (tab) tab.opener = null
  return !!tab
}
async function download() {
  if (downloading.value) return
  downloading.value = true
  try {
    const file = await photoFile()
    if (file) downloadFile(file, file.name)
    // Not readable here (no CORS on the bucket): the photo opens in a tab, to save from there.
    else if (!openTab(viewing.value?.url)) showToast(t('web.share.downloadFailed'))
  } finally {
    downloading.value = false
  }
}

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
onMounted(() => {
  window.addEventListener('paste', onPaste)
  window.addEventListener('keydown', onViewerKey)
})
onBeforeUnmount(() => {
  window.removeEventListener('paste', onPaste)
  window.removeEventListener('keydown', onViewerKey)
})
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
      <button v-for="(photo, index) in order.photos" :key="photo.id ?? photo.url" type="button" class="photo" :aria-label="t('web.order.viewPhoto', { number: index + 1 })" @click="viewingIndex = index">
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
  <Layer v-if="viewing" kind="dialog" :label="t('orderPhotosSection')" @close="viewingIndex = null">
    <template #default="{ close }">
      <div class="layer-body photo-viewer" data-testid="photo-viewer">
        <img class="photo-full" :src="viewing.url" :alt="viewing.description || t('orderPhotosSection')" />
        <div v-if="order.photos.length > 1" class="photo-nav">
          <button type="button" class="icon-btn" :aria-label="t('web.order.previousPhoto')" @click="step(-1)"><ChevronLeft :size="18" aria-hidden="true" /></button>
          <span class="sub num" aria-live="polite">{{ t('web.order.photoOf', { number: (viewingIndex ?? 0) + 1, count: order.photos.length }) }}</span>
          <button type="button" class="icon-btn" :aria-label="t('web.order.nextPhoto')" @click="step(1)"><ChevronRight :size="18" aria-hidden="true" /></button>
        </div>
      </div>
      <div class="layer-foot">
        <button v-if="canAttach" type="button" class="btn btn--ghost btn--danger" :disabled="deleting" @click="asking = true">{{ t('web.order.deletePhoto') }}</button>
        <button v-if="canAttach && viewingIndex" type="button" class="btn btn--ghost" :disabled="covering" @click="makeCover">{{ t('setAsCover') }}</button>
        <span class="spacer"></span>
        <button type="button" class="btn" :disabled="downloading" data-testid="photo-download" @click="download">{{ t('web.share.download') }}</button>
        <ShareButtons
          context="photo"
          :text="photoText"
          :title="orderShort()"
          :copy="viewing.url"
          :phone="order.customer?.phone"
          :customer-id="order.customer?.id"
          :file="photoFile"
          testid="photo-share"
        />
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="asking"
    :title="t('web.order.deletePhotoTitle')"
    :body="t('web.order.deletePhotoBody')"
    :confirm="t('web.order.deletePhoto')"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="asking = false"
  />
</template>
