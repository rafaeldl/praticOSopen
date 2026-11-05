<script setup lang="ts">
// One field of the segment (DynamicFieldBuilder): text, textarea, number,
// select and date. A select is the browser's own list (choosing is a picker,
// never a menu of actions); a date is saved as the app saves it, ISO with time.
import { computed, useId, watch } from 'vue'
import { locale } from '@/i18n'
import { applyMask, fieldMasks, fieldOptions, fieldTitle, type FormField } from '@/lib/segment-fields'
import { session } from '@/lib/session'

const props = defineProps<{ field: FormField; modelValue: unknown; error?: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: unknown] }>()

const id = `cfx-${useId()}`.replace(/[^\w-]/g, '')
const title = computed(() => fieldTitle(props.field, locale.value))
const options = computed(() => fieldOptions(props.field, locale.value))
const masks = computed(() => fieldMasks(props.field, session.company?.country))
const text = computed(() => (props.modelValue === null || props.modelValue === undefined ? '' : String(props.modelValue)))
const day = computed(() => (typeof props.modelValue === 'string' ? props.modelValue.slice(0, 10) : ''))
const placeholder = computed(() =>
  props.field.type === 'number' && typeof props.field.min === 'number' && typeof props.field.max === 'number'
    ? `${props.field.min} - ${props.field.max}`
    : (props.field.placeholder ?? ''),
)
const upper = computed(() => props.field.textCapitalization === 'characters')
// The company's country can arrive after typing: the value follows the mask then.
watch(masks, (list) => {
  if (typeof props.modelValue !== 'string' || !props.modelValue || !list.length || props.field.type !== 'text') return
  const shaped = upper.value ? applyMask(props.modelValue, list).toUpperCase() : applyMask(props.modelValue, list)
  if (shaped !== props.modelValue) emit('update:modelValue', shaped)
})

function onText(event: Event) {
  const input = event.target as HTMLInputElement | HTMLTextAreaElement
  let value = masks.value.length ? applyMask(input.value, masks.value) : input.value
  if (upper.value) value = value.toUpperCase()
  if (value !== input.value) input.value = value
  emit('update:modelValue', value === '' ? null : value)
}

function onNumber(event: Event) {
  const raw = (event.target as HTMLInputElement).value.trim()
  emit('update:modelValue', raw === '' ? null : /^-?\d+$/.test(raw) ? Number(raw) : raw)
}
</script>

<template>
  <div v-if="['text', 'textarea', 'number', 'select', 'date'].includes(field.type)">
    <label class="field-label" :for="id">{{ title }}<span v-if="field.required" aria-hidden="true"> *</span></label>
    <textarea
      v-if="field.type === 'textarea'"
      :id="id"
      class="field"
      rows="3"
      :value="text"
      :placeholder="placeholder"
      :required="field.required"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @input="onText"
    ></textarea>
    <input
      v-else-if="field.type === 'number'"
      :id="id"
      class="field"
      inputmode="numeric"
      :value="text"
      :placeholder="placeholder"
      :required="field.required"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @input="onNumber"
    />
    <select
      v-else-if="field.type === 'select'"
      :id="id"
      class="field"
      :value="text"
      :required="field.required"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @change="emit('update:modelValue', ($event.target as HTMLSelectElement).value || null)"
    >
      <option value="">—</option>
      <option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option>
    </select>
    <input
      v-else-if="field.type === 'date'"
      :id="id"
      class="field"
      type="date"
      :value="day"
      :data-empty="!day || undefined"
      :required="field.required"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @input="emit('update:modelValue', ($event.target as HTMLInputElement).value ? `${($event.target as HTMLInputElement).value}T00:00:00.000` : null)"
    />
    <input
      v-else
      :id="id"
      class="field"
      :value="text"
      :placeholder="placeholder"
      :required="field.required"
      :autocapitalize="upper ? 'characters' : undefined"
      :inputmode="field.keyboardType === 'number' ? 'numeric' : field.keyboardType === 'phone' ? 'tel' : undefined"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @input="onText"
    />
    <p v-if="error" :id="`${id}-error`" class="field-error">{{ error }}</p>
  </div>
</template>
