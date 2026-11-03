<script setup lang="ts">
// Money field. Entering selects everything, so typing replaces the old value
// (REVISAO-UX P0 1). Digits are read as written: "150" is 150, never 1,50.
import { computed, ref, watch } from 'vue'
import { t } from '@/i18n'
import { currencySymbol, formatMoneyInput, parseMoney } from '@/lib/format'

const props = defineProps<{
  id: string
  label: string
  modelValue: number | null
  /** Company country: decides symbol, separators and decimal places. */
  country?: string | null
  required?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [value: number | null] }>()

const input = ref<HTMLInputElement | null>(null)
const text = ref(formatMoneyInput(props.modelValue, props.country))
const invalid = ref(false)
const focused = ref(false)
const errorId = computed(() => `${props.id}-error`)
const symbol = computed(() => currencySymbol(props.country))

watch(
  () => [props.modelValue, props.country] as const,
  ([value, country]) => {
    if (!focused.value) text.value = formatMoneyInput(value, country)
  },
)

function commit() {
  const typed = text.value.trim()
  if (!typed) {
    invalid.value = !!props.required
    if (!props.required) emit('update:modelValue', null)
    return
  }
  const value = parseMoney(typed, props.country)
  if (value === null || value < 0) {
    invalid.value = true
    return
  }
  invalid.value = false
  emit('update:modelValue', value)
  text.value = formatMoneyInput(value, props.country)
}

function onFocus() {
  focused.value = true
  input.value?.select()
}

// A click after focus would drop the selection and put the cursor mid-number.
function keepSelection(event: MouseEvent) {
  if (document.activeElement !== input.value) {
    event.preventDefault()
    input.value?.focus()
  }
}

function onBlur() {
  focused.value = false
  commit()
}
</script>

<template>
  <div>
    <label class="field-label" :for="id">{{ label }}</label>
    <div class="money">
      <span class="money-symbol" aria-hidden="true">{{ symbol }}</span>
      <input
        :id="id"
        ref="input"
        v-model="text"
        class="field money-input"
        type="text"
        inputmode="decimal"
        autocomplete="off"
        :aria-invalid="invalid || undefined"
        :aria-describedby="invalid ? errorId : undefined"
        :aria-required="required || undefined"
        @focus="onFocus"
        @mousedown="keepSelection"
        @blur="onBlur"
        @keydown.enter="commit"
      />
    </div>
    <p v-if="invalid" :id="errorId" class="field-error">{{ t('web.field.invalidMoney') }}</p>
  </div>
</template>
