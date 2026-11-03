<script setup lang="ts">
import { computed } from 'vue'
import { t } from '@/i18n'
import { shortcutLabel, shortcuts } from '@/lib/shortcuts'
import { ui } from '@/lib/ui'
import Layer from './Layer.vue'

const list = computed(() => [...shortcuts.values()])
</script>

<template>
  <Layer v-slot="{ close }" kind="cheat" :label="t('web.shortcuts.title')" @close="ui.shortcuts = false">
    <div class="layer-head">
      <h2 class="layer-title">{{ t('web.shortcuts.title') }}</h2>
    </div>
    <div class="layer-body cheat">
      <div v-for="item in list" :key="item.keys">
        <span>{{ t(item.label) }}</span>
        <kbd>{{ shortcutLabel(item.keys) }}</kbd>
      </div>
    </div>
    <div class="layer-foot">
      <button type="button" class="btn" @click="close">{{ t('close') }}</button>
    </div>
  </Layer>
</template>
