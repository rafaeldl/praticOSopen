<script setup lang="ts">
// PDF of one order or of several (order.pdf.view, order.pdf.batch): made in the
// browser like the app's (lib/pdf/), then "Abrir" in the browser's PDF viewer
// (order.pdf.viewer) or "Baixar". The PDF code is loaded only here.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { orderShort } from '@/lib/orders/text'
import { announce } from '@/lib/ui'

const props = defineProps<{ ids: string[]; numbers: (number | undefined)[] }>()
const emit = defineEmits<{ close: [] }>()

const state = ref<'loading' | 'ready' | 'error'>('loading')
const result = shallowRef<{ url: string; fileName: string; missing: number; size: number } | null>(null)
const title = computed(() =>
  props.ids.length === 1
    ? t('web.pdf.titleOne', { order: orderShort(), number: props.numbers[0] ?? '' })
    : t('web.pdf.titleMany', { count: props.ids.length, order: orderShort() }),
)

async function make() {
  state.value = 'loading'
  try {
    const { ordersPdf } = await import('@/lib/pdf/load')
    const pdf = await ordersPdf(props.ids)
    if (result.value) URL.revokeObjectURL(result.value.url)
    result.value = { url: URL.createObjectURL(pdf.blob), fileName: pdf.fileName, missing: pdf.missing, size: pdf.blob.size }
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
          <a class="btn btn--primary" :href="result.url" :download="result.fileName" data-autofocus data-testid="pdf-download">{{ t('web.pdf.download') }}</a>
        </template>
      </div>
    </template>
  </Layer>
</template>
