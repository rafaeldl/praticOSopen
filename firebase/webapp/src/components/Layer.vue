<script setup lang="ts">
// Drawer, sheet or dialog: focus trapped inside, Esc closes, focus returns to
// the opener. Each layer is a history entry, so Voltar closes it too. Rendered
// at the end of <body>; everything behind it (the app, lower layers) is inert,
// so neither the mouse nor a screen reader reaches it.
// Every way of closing (Voltar, Esc, backdrop, a Cancel button) passes `guard`.
import { nextTick, onBeforeUnmount, onMounted, ref, useId, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { LAYER_PARAM, openLayers, queryValues, withoutParam } from '@/lib/route-layer'
import { ui } from '@/lib/ui'

const props = withDefaults(
  defineProps<{
    kind?: 'dialog' | 'drawer' | 'sheet' | 'palette' | 'cheat' | 'menu'
    label: string
    /** Runs before closing. Resolve false to stay, e.g. after "Descartar?". */
    guard?: () => boolean | Promise<boolean>
    /** Position of the box (a menu held to its button). */
    boxStyle?: Record<string, string>
  }>(),
  { kind: 'dialog', guard: undefined, boxStyle: undefined },
)
const emit = defineEmits<{ close: [] }>()

const route = useRoute()
const router = useRouter()
const box = ref<HTMLElement | null>(null)
const root = ref<HTMLElement | null>(null)
let madeInert: Element[] = []
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

async function requestClose() {
  // In the history: going back runs the navigation guard below, which asks.
  if (pushed && isOpenInUrl()) {
    router.back()
    return
  }
  if (props.guard && !(await props.guard())) return
  emit('close')
}

function makeBackgroundInert() {
  madeInert = [...document.body.children].filter(
    (element) => element !== root.value && !element.hasAttribute('inert') && element.tagName !== 'SCRIPT',
  )
  madeInert.forEach((element) => element.setAttribute('inert', ''))
}

function restoreBackground() {
  madeInert.forEach((element) => element.removeAttribute('inert'))
  madeInert = []
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
  makeBackgroundInert()
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
  restoreBackground()
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
  <Teleport to="body">
    <div ref="root" class="layer" :class="`layer--${kind}`" @mousedown.self="requestClose">
      <div ref="box" class="layer-box" :style="boxStyle" role="dialog" aria-modal="true" :aria-label="label" tabindex="-1" @keydown="onKeydown">
        <slot :close="requestClose" />
      </div>
    </div>
  </Teleport>
</template>
