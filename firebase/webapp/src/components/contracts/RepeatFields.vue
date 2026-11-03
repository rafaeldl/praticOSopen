<script setup lang="ts">
// "Repetir": how often, from when, until when, and whether the order is born by
// itself (contract.config.frequency, .dates, .auto). Used by the contract
// editor and by Nova OS opened as "Novo contrato". Shows the next order the
// schedule gives, before anything is saved.
import { computed } from 'vue'
import DateField from '@/components/DateField.vue'
import { t } from '@/i18n'
import { clampEnd, dayOf, midnight, plannedNext, repeatChoices, repeatKey, repeatOfKey, stepFrom, type Repeat } from '@/lib/contracts/model'
import { dayText, repeatText } from '@/lib/contracts/text'
import { orderShort } from '@/lib/orders/text'
import { session } from '@/lib/session'
import '@/styles/contracts.css'

export interface RepeatForm {
  repeat: Repeat
  startDay: string
  endDay: string | null
  autoGenerate: boolean
}

const props = defineProps<{
  idPrefix: string
  modelValue: RepeatForm
  today: string
  /** Last order born, so the preview never repeats it. */
  lastGenerated?: string | null
}>()
const emit = defineEmits<{ 'update:modelValue': [value: RepeatForm] }>()

const choices = computed(() => repeatChoices(props.modelValue.repeat))
const key = computed(() => repeatKey(props.modelValue.repeat))
const next = computed(() =>
  plannedNext({ frequency: props.modelValue.repeat.frequency, interval: props.modelValue.repeat.interval, startDate: `${props.modelValue.startDay}T00:00:00.000`, lastGeneratedDate: props.lastGenerated ?? null }, props.today),
)
const nextAfterEnd = computed(() => !!next.value && !!props.modelValue.endDay && next.value.slice(0, 10) > props.modelValue.endDay)

function set(patch: Partial<RepeatForm>) {
  const value = { ...props.modelValue, ...patch }
  // A later start pulls the end along, as in the app.
  value.endDay = clampEnd(value.startDay, value.endDay)
  emit('update:modelValue', value)
}

/** Start + 1 year, as the app suggests (29/02 rolls to 01/03). */
function suggestedEnd(): string {
  const next = stepFrom(midnight(props.modelValue.startDay), { frequency: 'yearly', interval: 1 })
  return next ? dayOf(next) : props.modelValue.startDay
}
</script>

<template>
  <div class="repeat-fields">
    <div>
      <label class="field-label" :for="`${idPrefix}-repeat`">{{ t('contractRepeatsTitle') }}</label>
      <select :id="`${idPrefix}-repeat`" class="field" :value="key" @change="set({ repeat: repeatOfKey(($event.target as HTMLSelectElement).value) })">
        <option v-for="choice in choices" :key="repeatKey(choice)" :value="repeatKey(choice)">{{ repeatText(choice) }}</option>
      </select>
    </div>
    <DateField :id="`${idPrefix}-start`" :label="t('contractStarts')" :model-value="modelValue.startDay" :country="session.company?.country" required @update:model-value="(v) => v && set({ startDay: v })" />
    <div class="repeat-end">
      <label class="check-row">
        <input class="check" type="checkbox" :checked="modelValue.endDay === null" :data-testid="`${idPrefix}-no-end`" @change="set({ endDay: ($event.target as HTMLInputElement).checked ? null : suggestedEnd() })" />
        <span>{{ t('contractNoEndDate') }}</span>
      </label>
      <DateField
        v-if="modelValue.endDay !== null"
        :id="`${idPrefix}-end`"
        :label="t('contractEnds')"
        :model-value="modelValue.endDay"
        :min="modelValue.startDay"
        :country="session.company?.country"
        required
        @update:model-value="(v) => set({ endDay: v ?? modelValue.startDay })"
      />
    </div>
    <div>
      <label class="check-row">
        <input class="check" type="checkbox" :checked="modelValue.autoGenerate" :data-testid="`${idPrefix}-auto`" @change="set({ autoGenerate: ($event.target as HTMLInputElement).checked })" />
        <span>{{ t('contractAutoCreate', { order: orderShort() }) }}</span>
      </label>
      <p class="sub field-hint">{{ t('web.contracts.autoHint', { order: orderShort() }) }}</p>
    </div>
    <p class="repeat-next" aria-live="polite" :data-testid="`${idPrefix}-next`">
      <template v-if="!modelValue.autoGenerate">{{ t('web.contracts.noAuto', { order: orderShort() }) }}</template>
      <template v-else-if="!next || nextAfterEnd">{{ t('web.contracts.noNext', { order: orderShort() }) }}</template>
      <template v-else>{{ t('contractNextOrderOn', { order: orderShort(), date: dayText(next) }) }}</template>
    </p>
  </div>
</template>
