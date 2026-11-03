<script setup lang="ts">
// Promised date or visit: native date and time picker, nothing filled in by
// itself (the app starts at the current minute: defect 8), and "Tirar" clears it.
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import { formatDateLong, formatTime } from '@/lib/format'
import Layer from '@/components/Layer.vue'
import { country } from '@/lib/orders/text'
import { instantOf, wallParts } from '@/lib/zone'

const props = defineProps<{ title: string; label: string; value: string | null | undefined; clearLabel: string }>()
const emit = defineEmits<{ save: [value: string | null]; close: [] }>()

const pad = (n: number) => String(n).padStart(2, '0')
/** The stored date on the company's clock, for the picker (lib/zone.ts). */
function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return ''
  const p = wallParts(instantOf(iso))
  return `${p.y}-${pad(p.m)}-${pad(p.d)}T${pad(p.h)}:${pad(p.min)}`
}
const text = ref(toLocalInput(props.value))
const valid = computed(() => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text.value) && !Number.isNaN(instantOf(text.value).getTime()))
const preview = computed(() => {
  if (!valid.value) return ''
  const at = instantOf(text.value)
  return `${formatDateLong(at, country())}, ${formatTime(at, country())}`
})

/** Saved as the app saves it: the company's local time, without a zone (revisão do #521, M1). */
function save() {
  if (valid.value) emit('save', `${text.value}:00.000`)
}
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
        </div>
        <div class="layer-body">
          <label class="field-label" for="order-date">{{ label }}</label>
          <input id="order-date" v-model="text" class="field" type="datetime-local" data-autofocus :aria-describedby="preview ? 'order-date-preview' : undefined" />
          <p v-if="preview" id="order-date-preview" class="sub">{{ preview }}</p>
        </div>
        <div class="layer-foot">
          <button v-if="value" type="button" class="btn btn--ghost btn--danger" @click="emit('save', null)">{{ clearLabel }}</button>
          <span class="spacer"></span>
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="!valid">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
