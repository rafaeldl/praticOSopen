<script setup>
import { onMounted, onBeforeUnmount, ref, nextTick } from 'vue'
import { ui } from '../store.js'
const props = defineProps({ kind: { type: String, default: 'dialog' }, label: String, top: { type: Boolean, default: false } })
const emit = defineEmits(['close'])
const root = ref(null)
let opener = null
const FOCUS = 'a[href],button:not([disabled]),input:not([disabled]),textarea,select,[tabindex="0"]'
function onKey(e) {
  if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); emit('close'); return }
  if (e.key !== 'Tab') return
  const items = [...root.value.querySelectorAll(FOCUS)].filter((x) => x.offsetParent !== null)
  if (!items.length) return
  const first = items[0]; const last = items[items.length - 1]
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus() }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus() }
}
onMounted(async () => {
  opener = document.activeElement
  ui.layers++
  await nextTick()
  const auto = root.value.querySelector('[data-autofocus]') || root.value.querySelector(FOCUS)
  auto?.focus()
})
onBeforeUnmount(() => {
  ui.layers--
  if (opener?.isConnected) opener.focus()
})
</script>
<template>
  <div class="layer" :class="'layer--' + kind" @mousedown.self="emit('close')">
    <div ref="root" class="layer-box" role="dialog" aria-modal="true" :aria-label="label" @keydown="onKey"><slot /></div>
  </div>
</template>
