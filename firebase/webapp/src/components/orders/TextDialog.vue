<script setup lang="ts">
// One text of the order (order.sheet.text, order.sheet.address,
// order.request.edit): a field and Salvar; Enter saves (a multiline text keeps
// Enter for new lines), closing with a change asks (Layer guard).
import { ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'

const props = defineProps<{ title: string; label: string; value: string; multiline?: boolean; placeholder?: string }>()
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
          <textarea v-if="multiline" id="text-dialog-field" v-model="text" class="field" rows="4" maxlength="2000" :placeholder="placeholder" data-autofocus></textarea>
          <input v-else id="text-dialog-field" v-model="text" class="field" maxlength="500" :placeholder="placeholder" data-autofocus />
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="text.trim() === value.trim()">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
