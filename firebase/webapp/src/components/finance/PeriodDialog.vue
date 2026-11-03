<script setup lang="ts">
// "Que período?" (fin.report.custom): start and end, from 2020 to today, both
// days included. A start after the end pulls the end along, and the other way
// round, as in the app. Opens with the last 30 days.
import { ref, watch } from 'vue'
import DateField from '@/components/DateField.vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { addDays, isDay, type Days } from '@/lib/finance/period'
import { session } from '@/lib/session'

const props = defineProps<{ today: string; initial?: Days | null }>()
const emit = defineEmits<{ apply: [days: Days]; close: [] }>()

const MIN = '2020-01-01'
const from = ref<string | null>(props.initial?.from ?? addDays(props.today, -29))
const to = ref<string | null>(props.initial?.to ?? props.today)

watch(from, (value) => {
  if (value && to.value && value > to.value) to.value = value
})
watch(to, (value) => {
  if (value && from.value && value < from.value) from.value = value
})

const valid = () => isDay(from.value) && isDay(to.value) && from.value! >= MIN && to.value! <= props.today && from.value! <= to.value!

function apply() {
  if (!valid()) return
  emit('apply', { from: from.value!, to: to.value! })
}
</script>

<template>
  <Layer kind="dialog" :label="t('reportWhichPeriod')" @close="emit('close')">
    <template #default="{ close }">
      <form class="period-form" @submit.prevent="apply">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('reportWhichPeriod') }}</h2>
        </div>
        <div class="layer-body period-fields">
          <DateField id="period-from" v-model="from" :label="t('reportStarts')" :country="session.company?.country" :min="MIN" :max="today" required />
          <DateField id="period-to" v-model="to" :label="t('reportEnds')" :country="session.company?.country" :min="MIN" :max="today" required />
          <p class="sub">{{ t('web.report.bothIncluded') }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="!valid()" data-testid="period-apply">{{ t('web.report.seePeriod') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
