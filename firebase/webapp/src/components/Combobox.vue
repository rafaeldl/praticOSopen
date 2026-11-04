<script setup lang="ts">
// ARIA combobox with aria-activedescendant. An empty field already lists the
// groups (Recentes, Mais usados), as the app's picker does.
import { computed, nextTick, ref, watch } from 'vue'
import { t } from '@/i18n'

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
  /** The first suggestion is ready for Enter even before typing (the device of the customer). */
  preselect?: boolean
  /** The list is still loading: Enter typed meanwhile picks the first match when it arrives. */
  loading?: boolean
  /**
   * Optional field: with nothing typed and nothing suggested, Enter goes on to the
   * next field instead of taking the first of the list (the device of a customer without one).
   */
  skippable?: boolean
}>()
const emit = defineEmits<{ pick: [item: ComboboxItem, query: string]; cancel: []; next: [] }>()

const query = ref('')
const open = ref(false)
const active = ref(-1)
const input = ref<HTMLInputElement | null>(null)
const listId = computed(() => `${props.id}-list`)
const sections = computed(() => (open.value ? props.groups(query.value).filter((group) => group.items.length) : []))
const flat = computed(() => sections.value.flatMap((group) => group.items))
const optionId = (index: number) => `${props.id}-opt-${index}`
const activeId = computed(() => (open.value && flat.value[active.value] ? optionId(active.value) : undefined))

/**
 * Where the highlight starts with nothing typed: the current choice (✓), else the
 * first suggestion (Recentes, Mais usados), so Enter picks it (timed-comparison T1, T9).
 * An optional field without a suggestion starts with none.
 */
function startIndex(): number {
  const selected = props.selectedId ? flat.value.findIndex((item) => item.id === props.selectedId) : -1
  if (selected >= 0) return selected
  return props.preselect || !props.skippable ? 0 : -1
}
const autoFirst = () => !!query.value || !!props.preselect || !props.skippable

// Clearing by Esc must not reopen the list (the next Esc then reaches the layer).
let quiet = false
watch(query, (text) => {
  if (quiet) {
    quiet = false
    return
  }
  open.value = true
  active.value = text ? 0 : startIndex()
})

// Enter typed while the list loads picks the first match when it arrives, even
// if the field lost focus meanwhile (Ctrl+Enter blurs it): nothing typed is lost.
const pendingEnter = ref(false)
const firstMatch = computed(() => (pendingEnter.value || props.loading ? props.groups(query.value).flatMap((group) => group.items)[0] : undefined))
watch([firstMatch, () => props.loading], ([item, loading]) => {
  if (!pendingEnter.value) return
  if (item && autoFirst()) {
    pendingEnter.value = false
    pick(item)
  } else if (!loading) {
    // Loaded and nothing to pick for an empty field: the Enter goes on to the next field.
    pendingEnter.value = false
    if (!query.value) emit('next')
  }
})

// No suggestion any more (the customer has no device): an empty Enter must not pick the first of the list.
watch(() => props.preselect, (on) => {
  if (!on && !query.value && props.skippable) active.value = -1
})

function onFocus() {
  open.value = true
  if (active.value < 0) active.value = startIndex()
}

function pick(item: ComboboxItem) {
  emit('pick', item, query.value)
  // The list stays closed over what was just added (it reopens on typing or arrows).
  quiet = !!query.value
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
    } else if (props.loading && autoFirst()) {
      event.preventDefault()
      event.stopPropagation()
      pendingEnter.value = true
    } else if (!query.value) {
      // Nothing to pick and nothing typed: Enter goes on to the next field.
      event.preventDefault()
      event.stopPropagation()
      emit('next')
    }
  } else if (event.key === 'Escape') {
    // First Esc only clears this field; the next one reaches the layer.
    if (open.value && (query.value || flat.value.length)) {
      event.preventDefault()
      event.stopPropagation()
      quiet = !!query.value
      query.value = ''
      open.value = false
      active.value = -1
    } else {
      emit('cancel')
    }
  }
}

defineExpose({ focus: () => input.value?.focus(), pending: () => query.value.trim() })
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
      @focus="onFocus"
      @click="onFocus"
      @blur="open = false"
      @keydown="onKeydown"
    />
    <p v-if="open && loading && !flat.length" class="combo-loading sub" role="status">{{ t('web.loading') }}</p>
    <!-- tabindex -1: a scrolling box is a Tab stop in Chrome, and leaving the field closes it (focus would be lost). -->
    <div v-if="open && flat.length" :id="listId" class="combo-list" role="listbox" :aria-label="label" tabindex="-1">
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
