<script setup>
import { ref, computed, watch, nextTick } from 'vue'
const props = defineProps({
  id: String, label: String, placeholder: String, groups: Function, autofocus: Boolean,
  keepOpen: Boolean, compact: Boolean, preselect: Boolean,
})
const emit = defineEmits(['pick', 'cancel', 'skip'])
const q = ref('')
const open = ref(false)
const active = ref(props.preselect ? 0 : -1)
const input = ref(null)
const listId = computed(() => props.id + '-list')
const sections = computed(() => (open.value ? props.groups(q.value) : []))
const flat = computed(() => sections.value.flatMap((s) => s.items))
const reset = () => { active.value = q.value || props.preselect ? 0 : -1 }
watch(q, reset)
const optionId = (i) => `${props.id}-opt-${i}`
function indexOf(item) { return flat.value.indexOf(item) }
function pick(item) {
  emit('pick', item, q.value)
  q.value = ''
  reset()
}
function onKey(e) {
  if (e.key === 'ArrowDown') { e.preventDefault(); open.value = true; active.value = Math.min(active.value + 1, flat.value.length - 1); scrollTo() }
  else if (e.key === 'ArrowUp') { e.preventDefault(); active.value = Math.max(active.value - 1, 0); scrollTo() }
  else if (e.key === 'Enter' && !e.ctrlKey && !e.metaKey) {
    if (flat.value[active.value]) { e.preventDefault(); e.stopPropagation(); pick(flat.value[active.value]) }
  } else if (e.key === 'Escape' && (q.value || props.keepOpen)) {
    if (q.value) { e.stopPropagation(); e.preventDefault(); q.value = '' } else emit('cancel')
  } else if (e.key === 'Tab' && !e.shiftKey) { emit('skip') }
}
function scrollTo() {
  nextTick(() => document.getElementById(optionId(active.value))?.scrollIntoView({ block: 'nearest' }))
}
defineExpose({ focus: () => input.value?.focus() })
</script>
<template>
  <div class="combo" :class="{ 'combo--compact': compact }">
    <input
      :id="id" ref="input" v-model="q" class="field" type="text" role="combobox" autocomplete="off"
      :aria-label="label" :placeholder="placeholder" :aria-expanded="open" :aria-controls="listId"
      :aria-activedescendant="active >= 0 && flat.length ? optionId(active) : undefined" :data-autofocus="autofocus ? '' : undefined"
      @focus="open = true" @blur="open = false" @keydown="onKey"
    >
    <div v-if="open && flat.length" :id="listId" class="combo-list" role="listbox" :aria-label="label">
      <template v-for="s in sections" :key="s.title">
        <div v-if="s.title && s.items.length" class="combo-sec">{{ s.title }}</div>
        <div
          v-for="it in s.items" :id="optionId(indexOf(it))" :key="it.id" class="combo-opt" role="option"
          :aria-selected="indexOf(it) === active" :class="{ 'is-active': indexOf(it) === active }"
          @mousedown.prevent="pick(it)" @mousemove="active = indexOf(it)"
        >
          <span class="combo-main"><strong>{{ it.label }}</strong><small v-if="it.sub">{{ it.sub }}</small></span>
          <span v-if="it.right" class="num">{{ it.right }}</span>
        </div>
      </template>
    </div>
  </div>
</template>
