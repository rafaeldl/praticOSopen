<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { t } from '@/i18n'
import { searchCommands, type Command } from '@/lib/commands'
import { shortcutLabel } from '@/lib/shortcuts'
import { ui } from '@/lib/ui'
import Layer from './Layer.vue'

const query = ref('')
const active = ref(0)
const results = computed(() => searchCommands(query.value, (key) => t(key)))
const optionId = (index: number) => `palette-opt-${index}`
const activeId = computed(() => (results.value[active.value] ? optionId(active.value) : undefined))

watch(query, () => {
  active.value = 0
})

function run(command: Command | undefined) {
  if (!command) return
  ui.palette = false
  command.run()
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'ArrowDown') {
    event.preventDefault()
    active.value = Math.min(active.value + 1, results.value.length - 1)
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    active.value = Math.max(active.value - 1, 0)
  } else if (event.key === 'Enter') {
    event.preventDefault()
    run(results.value[active.value])
  }
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
      <div
        v-for="(command, index) in results"
        :id="optionId(index)"
        :key="command.id"
        class="pal-opt"
        :class="{ 'is-active': index === active }"
        role="option"
        :aria-selected="index === active"
        @click="run(command)"
        @mousemove="active = index"
      >
        <component :is="command.icon" v-if="command.icon" :size="18" aria-hidden="true" />
        <span class="pal-main">{{ t(command.label) }}</span>
        <kbd v-if="command.keys">{{ shortcutLabel(command.keys) }}</kbd>
      </div>
    </div>
    <p v-if="!results.length" class="pal-none muted">{{ t('web.palette.empty') }}</p>
  </Layer>
</template>
