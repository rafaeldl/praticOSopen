<script setup lang="ts">
// Before a batch writes: the question with the count, every order that changes
// and what it becomes, and what stays as it is. "Agora não" has the focus.
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'

defineProps<{ title: string; lines: { id: string; text: string; right?: string; ai?: boolean }[]; note?: string; confirm: string; disabled?: boolean }>()
const emit = defineEmits<{ confirm: []; close: [] }>()
</script>

<template>
  <Layer kind="dialog" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="layer-body">
        <ul class="batch-lines" data-testid="batch-confirm-lines">
          <li v-for="line in lines" :key="line.id" class="pay-row">
            <span>{{ line.text }}</span>
            <span v-if="line.right" class="muted">{{ line.right }}</span>
          </li>
        </ul>
        <p v-if="note" class="muted">{{ note }}</p>
        <slot />
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" data-autofocus @click="close()">{{ t('web.batch.notNow') }}</button>
        <button type="button" class="btn btn--primary" :disabled="disabled || !lines.length" @click="emit('confirm')">{{ confirm }}</button>
      </div>
    </template>
  </Layer>
</template>
