<script setup lang="ts">
// PDF of one order or of several (order.pdf.view, order.pdf.batch): made in the
// browser like the app's (lib/pdf/), then "Abrir" in the browser's PDF viewer
// (order.pdf.viewer) or "Baixar". The PDF code is loaded only here.
// Sending it (order.pdf.share): the browser's sheet with the file where it takes
// files; and, for one order, "Mandar pelo WhatsApp" downloads the PDF (to attach)
// and opens the order's link for the customer (the order asks ShareDialog).
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { orderShort, ordersShort } from '@/lib/orders/text'
import { canShareFiles, downloadFile, shareSheet } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

/** whatsapp: the order has a customer to send to (one order only). */
const props = defineProps<{ ids: string[]; numbers: (number | undefined)[]; whatsapp?: boolean }>()
const emit = defineEmits<{ close: []; whatsapp: [] }>()

const state = ref<'loading' | 'ready' | 'error'>('loading')
const result = shallowRef<{ url: string; fileName: string; missing: number; size: number; file: File } | null>(null)
const sheet = computed(() => !!result.value && canShareFiles([result.value.file]))
const title = computed(() =>
  props.ids.length === 1
    ? t('web.pdf.titleOne', { order: orderShort(), number: props.numbers[0] ?? '' })
    : t('web.pdf.titleMany', { count: props.ids.length, order: ordersShort(props.ids.length) }),
)

async function make() {
  state.value = 'loading'
  try {
    const { ordersPdf } = await import('@/lib/pdf/load')
    const pdf = await ordersPdf(props.ids)
    if (result.value) URL.revokeObjectURL(result.value.url)
    const file = new File([pdf.blob], pdf.fileName, { type: 'application/pdf' })
    result.value = { url: URL.createObjectURL(pdf.blob), fileName: pdf.fileName, missing: pdf.missing, size: pdf.blob.size, file }
    state.value = 'ready'
    announce(t('web.pdf.ready'))
  } catch (error) {
    console.warn('pdf: not made', error)
    state.value = 'error'
  }
}

const size = computed(() => {
  const bytes = result.value?.size ?? 0
  return bytes >= 1_000_000 ? `${(bytes / 1_000_000).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1000))} KB`
})

async function share() {
  if (!result.value) return
  if ((await shareSheet({ files: [result.value.file], title: title.value }, 'pdf')) === 'failed') showToast(t('web.share.sheetFailed'))
}

/** The file goes to Downloads to be attached; WhatsApp opens with the order's link. */
function sendWhatsapp() {
  if (!result.value) return
  downloadFile(result.value.file, result.value.fileName)
  showToast(t('web.share.pdfAttach'))
  emit('whatsapp')
}

onMounted(make)
onBeforeUnmount(() => {
  if (result.value) URL.revokeObjectURL(result.value.url)
})
</script>

<template>
  <Layer kind="dialog" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="layer-body" data-testid="pdf-dialog">
        <LoadingState v-if="state === 'loading'" :label="t('web.pdf.making')" />
        <ErrorState v-else-if="state === 'error'" :body="t('web.pdf.error')" :retry="make" />
        <template v-else-if="result">
          <p>{{ t('web.pdf.readyBody', { file: result.fileName, size }) }}</p>
          <p v-if="result.missing" class="muted" role="status">{{ t('web.pdf.missing', { count: result.missing }) }}</p>
        </template>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" :data-autofocus="state !== 'ready' ? '' : undefined" @click="close()">{{ t('close') }}</button>
        <template v-if="state === 'ready' && result">
          <a class="btn" :href="result.url" target="_blank" rel="noopener" data-testid="pdf-open">{{ t('web.pdf.open') }}</a>
          <button v-if="sheet" type="button" class="btn" data-testid="pdf-share" @click="share">{{ t('share') }}</button>
          <button v-if="whatsapp && ids.length === 1" type="button" class="btn" data-testid="pdf-whatsapp" @click="sendWhatsapp">{{ t('shareSendWhatsApp') }}</button>
          <a class="btn btn--primary" :href="result.url" :download="result.fileName" data-autofocus data-testid="pdf-download">{{ t('web.pdf.download') }}</a>
        </template>
      </div>
    </template>
  </Layer>
</template>
