<script setup lang="ts">
// Fotos da Nova OS antes do ✓ (order.new.photos): kept in the browser until the
// order has its id, then sent to the order's folder. A click on a thumbnail
// offers "Remover Foto". Only with attachPhotos. The app swallows a failed
// upload (defect 18); here the drawer says which photos did not stay.
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { ImagePlus } from '@lucide/vue'
import { t } from '@/i18n'
import ConfirmDialog from './ConfirmDialog.vue'

const props = defineProps<{ modelValue: File[] }>()
const emit = defineEmits<{ 'update:modelValue': [files: File[]] }>()
const removing = ref<number | null>(null)
const urls = ref<string[]>([])

// Object URLs follow the list, and are released when they leave it.
watch(
  () => props.modelValue,
  (files) => {
    urls.value.forEach((url) => URL.revokeObjectURL(url))
    urls.value = files.map((file) => URL.createObjectURL(file))
  },
  { immediate: true },
)
onBeforeUnmount(() => urls.value.forEach((url) => URL.revokeObjectURL(url)))

const shown = computed(() => props.modelValue.length > 0)
function add(files: FileList | null | undefined) {
  const images = [...(files ?? [])].filter((file) => file.type.startsWith('image/'))
  if (images.length) emit('update:modelValue', [...props.modelValue, ...images])
}
function remove() {
  const index = removing.value
  removing.value = null
  if (index !== null) emit('update:modelValue', props.modelValue.filter((_, i) => i !== index))
}
</script>

<template>
  <section class="step" aria-labelledby="no-photos-title" data-testid="new-order-photos" @dragover.prevent @drop.prevent="add($event.dataTransfer?.files)">
    <h3 id="no-photos-title" class="field-label">{{ t('orderPhotosSection') }}</h3>
    <div class="photos">
      <button v-for="(url, index) in urls" :key="url" type="button" class="photo" :aria-label="`${t('removePhoto')} ${index + 1}`" @click="removing = index">
        <img :src="url" alt="" />
      </button>
      <label class="photo photo-add">
        <ImagePlus :size="18" aria-hidden="true" />
        <span class="photo-add-text">{{ shown ? t('orderAssistantAddPhoto') : t('addPhoto') }}</span>
        <input class="sr" type="file" accept="image/*" multiple :aria-label="t('addPhoto')" data-testid="new-order-photo-input" @change="add(($event.target as HTMLInputElement).files); ($event.target as HTMLInputElement).value = ''" />
      </label>
    </div>
  </section>
  <ConfirmDialog v-if="removing !== null" :title="t('removePhoto')" :confirm="t('removePhoto')" :keep="t('cancel')" danger @confirm="remove" @close="removing = null" />
</template>
