<script setup lang="ts">
// Drawer, sheet or dialog: focus trapped inside, Esc closes, focus returns to
// the opener. Each layer is a history entry, so Voltar closes it too.
import { nextTick, onBeforeUnmount, onMounted, ref, useId, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { LAYER_PARAM, openLayers, queryValues, withoutParam } from '@/lib/route-layer'
import { ui } from '@/lib/ui'

const props = withDefaults(
  defineProps<{
    kind?: 'dialog' | 'drawer' | 'sheet' | 'palette' | 'cheat'
    label: string
    /** Runs before closing. Resolve false to stay, e.g. after "Descartar?". */
    guard?: () => boolean | Promise<boolean>
  }>(),
  { kind: 'dialog', guard: undefined },
)
const emit = defineEmits<{ close: [] }>()

const route = useRoute()
const router = useRouter()
const box = ref<HTMLElement | null>(null)
const key = `l${useId()}`.replace(/[^\w-]/g, '')
const FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]),textarea:not([disabled]),select:not([disabled]),[tabindex="0"]'

let opener: HTMLElement | null = null
let pushed = false
let closing = false
let removeGuard: (() => void) | undefined

const isOpenInUrl = () => queryValues(route.query, LAYER_PARAM).includes(key)

function focusables(): HTMLElement[] {
  return [...(box.value?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])].filter((item) => item.offsetParent !== null)
}

function requestClose() {
  if (pushed && isOpenInUrl()) router.back()
  else emit('close')
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    requestClose()
    return
  }
  if (event.key !== 'Tab') return
  const items = focusables()
  const first = items[0]
  const last = items[items.length - 1]
  if (!first || !last) {
    event.preventDefault()
    return
  }
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}

// Leaving the URL means Voltar, Esc or a link: the parent removes the layer.
watch(
  () => route.query[LAYER_PARAM],
  () => {
    if (pushed && !isOpenInUrl() && !closing) {
      closing = true
      emit('close')
    }
  },
)

onMounted(async () => {
  opener = document.activeElement as HTMLElement | null
  ui.layers++
  openLayers.add(key)
  removeGuard = router.beforeEach(async (to) => {
    if (!props.guard || !pushed || queryValues(to.query, LAYER_PARAM).includes(key)) return true
    return (await props.guard()) ? true : false
  })
  await router.push({ query: { ...route.query, [LAYER_PARAM]: [...queryValues(route.query, LAYER_PARAM), key] } })
  pushed = true
  await nextTick()
  const target = box.value?.querySelector<HTMLElement>('[data-autofocus]') ?? focusables()[0] ?? box.value
  target?.focus()
})

onBeforeUnmount(() => {
  ui.layers--
  openLayers.delete(key)
  removeGuard?.()
  // Closed by the parent (saved, say): the entry must not stay behind.
  if (pushed && isOpenInUrl()) {
    const others = queryValues(route.query, LAYER_PARAM).filter((item) => item !== key)
    void router.replace({ query: { ...withoutParam(route.query, LAYER_PARAM), ...(others.length ? { [LAYER_PARAM]: others } : {}) } })
  }
  if (opener?.isConnected) opener.focus()
})

defineExpose({ close: requestClose })
</script>

<template>
  <div class="layer" :class="`layer--${kind}`" @mousedown.self="requestClose">
    <div ref="box" class="layer-box" role="dialog" aria-modal="true" :aria-label="label" tabindex="-1" @keydown="onKeydown">
      <slot :close="requestClose" />
    </div>
  </div>
</template>
