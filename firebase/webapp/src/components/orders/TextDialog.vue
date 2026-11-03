<script setup lang="ts">
// One text of the order (order.sheet.text, order.sheet.address): a field and
// Salvar; Enter saves, closing with a change asks (Layer guard).
import { ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'

const props = defineProps<{ title: string; label: string; value: string }>()
const emit = defineEmits<{ save: [text: string]; close: [] }>()
const text = ref(props.value)
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="emit('save', text)">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
        </div>
        <div class="layer-body">
          <label class="field-label" for="text-dialog-field">{{ label }}</label>
          <input id="text-dialog-field" v-model="text" class="field" maxlength="500" data-autofocus />
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="text.trim() === value.trim()">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
