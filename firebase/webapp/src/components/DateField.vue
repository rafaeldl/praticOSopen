<script setup lang="ts">
// Native date picker: the phone opens its own wheel (REVISAO-UX P0 2).
// The value is a calendar day, yyyy-mm-dd, never a UTC instant.
import { computed } from 'vue'
import { formatDateLong, fromIsoDay } from '@/lib/format'

const props = defineProps<{
  id: string
  label: string
  modelValue: string | null
  country?: string | null
  min?: string
  max?: string
  required?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string | null] }>()

const preview = computed(() => formatDateLong(fromIsoDay(props.modelValue), props.country))

function onInput(event: Event) {
  emit('update:modelValue', (event.target as HTMLInputElement).value || null)
}
</script>

<template>
  <div>
    <label class="field-label" :for="id">{{ label }}</label>
    <input
      :id="id"
      class="field"
      type="date"
      :value="modelValue ?? ''"
      :data-empty="!modelValue || undefined"
      :min="min"
      :max="max"
      :required="required"
      :aria-describedby="preview ? `${id}-preview` : undefined"
      @input="onInput"
    />
    <p v-if="preview" :id="`${id}-preview`" class="sub field-hint">{{ preview }}</p>
  </div>
</template>
