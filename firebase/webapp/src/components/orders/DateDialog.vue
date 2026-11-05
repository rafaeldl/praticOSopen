<script setup lang="ts">
// Promised date or visit: nothing filled in by itself (the app starts at the
// current minute: defect 8), and "Tirar" clears it. The cursor starts on a short
// field that understands "amanhã 14h", "+3", "seg 8:30" or "9/5 14h", with ↑/↓ for
// a day and Shift+↑/↓ for half an hour (timed-comparison T7); the native picker
// below stays for the mouse and shows what was understood.
import { computed, ref } from 'vue'
import { locale, t } from '@/i18n'
import { parseQuickWhen, shiftWhen } from '@/lib/quick-when'
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
const quick = ref('')
const quickError = ref(false)
/** What was there before typing: a typed day keeps its time, a typed time keeps its day. */
const base = toLocalInput(props.value)

function onQuick() {
  if (!quick.value.trim()) {
    quickError.value = false
    text.value = base
    return
  }
  const parsed = parseQuickWhen(quick.value, wallParts(new Date()), base, locale.value)
  quickError.value = !parsed
  if (parsed) text.value = parsed
}

function onQuickKey(event: KeyboardEvent) {
  if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return
  event.preventDefault()
  const start = text.value || toLocalInput(new Date().toISOString())
  text.value = shiftWhen(start, event.shiftKey ? 'time' : 'day', event.key === 'ArrowUp' ? 1 : -1)
}
const valid = computed(() => !quickError.value && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text.value) && !Number.isNaN(instantOf(text.value).getTime()))
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
          <label class="field-label" for="order-date-quick">{{ t('web.when.quickLabel') }}</label>
          <input
            id="order-date-quick"
            v-model="quick"
            class="field"
            type="text"
            autocomplete="off"
            data-autofocus
            :aria-invalid="quickError"
            aria-describedby="order-date-hint order-date-preview"
            @input="onQuick"
            @keydown="onQuickKey"
          />
          <p id="order-date-hint" class="sub field-hint">{{ quickError ? t('web.when.quickError') : t('web.when.quickHint') }}</p>
          <label class="field-label" for="order-date">{{ label }}</label>
          <input id="order-date" v-model="text" class="field" type="datetime-local" :data-empty="!text || undefined" :aria-describedby="preview ? 'order-date-preview' : undefined" />
          <p id="order-date-preview" class="sub" aria-live="polite">{{ preview }}</p>
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
