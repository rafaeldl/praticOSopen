<script setup lang="ts">
// ⌘K: search and commands from any screen (web.search.global). Results come in
// groups (OS, customers, devices, catalog, actions), each only for who may open
// it. The screen on display adds what it holds (searchers); the rest is read
// here when the palette opens (lib/global-search.ts).
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { t } from '@/i18n'
import { searchAll, type Command } from '@/lib/commands'
import { directoryResults, groupLabel, groupOf, GROUPS, loadDirectory, ordersByNumber, screenCommands, type Directory } from '@/lib/global-search'
import { shortcutLabel } from '@/lib/shortcuts'
import { matchesWords } from '@/lib/text'
import { ui } from '@/lib/ui'
import Layer from './Layer.vue'

const query = ref('')
const active = ref(0)
const directory = shallowRef<Directory>({ customers: [], devices: [], catalog: [] })
const byNumber = shallowRef<Command[]>([])
const screens = screenCommands()
let timer: ReturnType<typeof setTimeout> | undefined
let asked = 0

onMounted(() => {
  void loadDirectory().then((value) => (directory.value = value))
})
onBeforeUnmount(() => clearTimeout(timer))

const results = computed(() => {
  const text = query.value.trim()
  const fromScreen = searchAll(query.value, (key) => t(key))
  const actions = text ? screens.filter((command) => matchesWords(command.text ?? '', text)) : []
  const all = [...fromScreen, ...byNumber.value, ...directoryResults(directory.value, text), ...actions]
  // The screen's own result wins over the same record found again.
  const seen = new Set<string>()
  const unique = all.filter((command) => !seen.has(command.id) && !!seen.add(command.id))
  return GROUPS.map((group) => ({ group, label: groupLabel(group), items: unique.filter((command) => groupOf(command) === group).slice(0, 6) })).filter(
    (entry) => entry.items.length,
  )
})
const flat = computed(() => results.value.flatMap((entry) => entry.items))
const optionId = (index: number) => `palette-opt-${index}`
const activeId = computed(() => (flat.value[active.value] ? optionId(active.value) : undefined))
const indexOf = (command: Command) => flat.value.indexOf(command)

watch(query, (text) => {
  active.value = 0
  clearTimeout(timer)
  byNumber.value = []
  const ask = ++asked
  if (!/^#?\d{1,9}$/.test(text.trim())) return
  // An order by its number, also when the list is not on screen.
  timer = setTimeout(() => {
    ordersByNumber(text)
      .then((found) => ask === asked && (byNumber.value = found))
      .catch((error) => console.warn('palette: order not found', error))
  }, 200)
})

function run(command: Command | undefined) {
  if (!command) return
  ui.palette = false
  // After the palette has left (its history entry is being removed): a command that
  // navigates, such as opening an order, must not be undone by that removal.
  void nextTick(() => command.run())
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    active.value = Math.min(active.value + 1, flat.value.length - 1)
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    active.value = Math.max(active.value - 1, 0)
  } else if (event.key === 'Enter') {
    event.preventDefault()
    run(flat.value[active.value])
    return
  } else return
  void nextTick(() => document.getElementById(optionId(active.value))?.scrollIntoView({ block: 'nearest' }))
}
</script>

<template>
  <Layer kind="palette" :label="t('web.palette.title')" @close="ui.palette = false">
    <input
      v-model="query"
      class="pal-input"
      type="text"
      role="combobox"
      aria-expanded="true"
      aria-controls="palette-list"
      aria-autocomplete="list"
      autocomplete="off"
      data-autofocus
      :aria-label="t('web.palette.placeholder')"
      :aria-activedescendant="activeId"
      :placeholder="t('web.palette.placeholder')"
      @keydown="onKeydown"
    />
    <div id="palette-list" class="pal-list" role="listbox" :aria-label="t('web.palette.title')">
      <div v-for="entry in results" :key="entry.group" role="group" :aria-label="entry.label">
        <div class="pal-sec" aria-hidden="true">{{ entry.label }}</div>
        <div
          v-for="command in entry.items"
          :id="optionId(indexOf(command))"
          :key="command.id"
          class="pal-opt"
          :class="{ 'is-active': indexOf(command) === active }"
          role="option"
          :aria-selected="indexOf(command) === active"
          @click="run(command)"
          @mousemove="active = indexOf(command)"
        >
          <component :is="command.icon" v-if="command.icon" :size="18" aria-hidden="true" />
          <span class="pal-main">{{ command.text ?? t(command.label) }}<small v-if="command.sub"> · {{ command.sub }}</small></span>
          <kbd v-if="command.keys">{{ shortcutLabel(command.keys) }}</kbd>
        </div>
      </div>
    </div>
    <p v-if="!flat.length" class="pal-none muted">{{ query.trim() ? t('web.palette.empty') : t('web.palette.hint') }}</p>
  </Layer>
</template>
