<script setup lang="ts">
// The device's reading at this visit (order.device-reading.edit,
// docs/DEVICE_READING.md): "Quilometragem (km)" or "Horímetro (h)" from the
// segment, digits only. Empty removes it.
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'

const props = defineProps<{ title: string; unit?: string; sub?: string; value: number | null }>()
const emit = defineEmits<{ save: [value: number | null]; close: [] }>()
const text = ref(props.value === null ? '' : String(props.value))
const label = computed(() => (props.unit ? `${props.title} (${props.unit})` : props.title))
const typed = computed(() => (text.value.trim() === '' ? null : Number(text.value.trim())))

function onInput(event: Event) {
  const input = event.target as HTMLInputElement
  const digits = input.value.replace(/\D/g, '').slice(0, 9)
  if (digits !== input.value) input.value = digits
  text.value = digits
}
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="emit('save', typed)">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
          <p v-if="sub" class="sub">{{ sub }}</p>
        </div>
        <div class="layer-body">
          <label class="field-label" for="reading-dialog-field">{{ label }}</label>
          <input id="reading-dialog-field" :value="text" class="field num" inputmode="numeric" autocomplete="off" data-autofocus data-testid="reading-input" @input="onInput" />
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="typed === value">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
