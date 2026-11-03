<script setup lang="ts">
// ARIA combobox with aria-activedescendant. An empty field already lists the
// groups (Recentes, Mais usados), as the app's picker does.
import { computed, nextTick, ref, watch } from 'vue'

export interface ComboboxItem {
  id: string
  label: string
  sub?: string
  right?: string
}
export interface ComboboxGroup {
  title?: string
  items: ComboboxItem[]
}

const props = defineProps<{
  id: string
  label: string
  placeholder?: string
  /** Returns what to list for the text typed so far. */
  groups: (query: string) => ComboboxGroup[]
  /** Current choice, marked with ✓. */
  selectedId?: string | null
  autofocus?: boolean
}>()
const emit = defineEmits<{ pick: [item: ComboboxItem, query: string]; cancel: [] }>()

const query = ref('')
const open = ref(false)
const active = ref(-1)
const input = ref<HTMLInputElement | null>(null)
const listId = computed(() => `${props.id}-list`)
const sections = computed(() => (open.value ? props.groups(query.value).filter((group) => group.items.length) : []))
const flat = computed(() => sections.value.flatMap((group) => group.items))
const optionId = (index: number) => `${props.id}-opt-${index}`
const activeId = computed(() => (open.value && flat.value[active.value] ? optionId(active.value) : undefined))

watch(query, (text) => {
  open.value = true
  active.value = text ? 0 : -1
})

function pick(item: ComboboxItem) {
  emit('pick', item, query.value)
  query.value = ''
  active.value = -1
  open.value = false
}

function reveal() {
  void nextTick(() => document.getElementById(optionId(active.value))?.scrollIntoView({ block: 'nearest' }))
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    open.value = true
    active.value = Math.min(active.value + 1, flat.value.length - 1)
    reveal()
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    active.value = Math.max(active.value - 1, 0)
    reveal()
  } else if (event.key === 'Enter' && !event.ctrlKey && !event.metaKey) {
    const item = flat.value[active.value]
    if (item) {
      event.preventDefault()
      event.stopPropagation()
      pick(item)
    }
  } else if (event.key === 'Escape') {
    // First Esc only clears this field; the next one reaches the layer.
    if (open.value && (query.value || flat.value.length)) {
      event.preventDefault()
      event.stopPropagation()
      query.value = ''
      open.value = false
      active.value = -1
    } else {
      emit('cancel')
    }
  }
}

defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <div class="combo">
    <label class="field-label" :for="id">{{ label }}</label>
    <input
      :id="id"
      ref="input"
      v-model="query"
      class="field"
      type="text"
      role="combobox"
      autocomplete="off"
      aria-autocomplete="list"
      :placeholder="placeholder"
      :aria-expanded="open && flat.length > 0"
      :aria-controls="open && flat.length ? listId : undefined"
      :aria-activedescendant="activeId"
      :data-autofocus="autofocus ? '' : undefined"
      @focus="open = true"
      @click="open = true"
      @blur="open = false"
      @keydown="onKeydown"
    />
    <div v-if="open && flat.length" :id="listId" class="combo-list" role="listbox" :aria-label="label">
      <div v-for="group in sections" :key="group.title ?? ''" role="group" :aria-label="group.title">
        <div v-if="group.title" class="combo-sec" aria-hidden="true">{{ group.title }}</div>
        <div
          v-for="item in group.items"
          :id="optionId(flat.indexOf(item))"
          :key="item.id"
          class="combo-opt"
          :class="{ 'is-active': flat.indexOf(item) === active }"
          role="option"
          :aria-selected="item.id === selectedId"
          @mousedown.prevent="pick(item)"
          @mousemove="active = flat.indexOf(item)"
        >
          <span class="combo-main">
            <strong>{{ item.label }}</strong>
            <small v-if="item.sub">{{ item.sub }}</small>
          </span>
          <span v-if="item.id === selectedId" aria-hidden="true">✓</span>
          <span v-else-if="item.right" class="num">{{ item.right }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
