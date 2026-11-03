<script setup lang="ts">
// New or edit device (device.form.*). Model or serial is enough; the serial is
// uppercase, follows the segment mask and pattern. Model suggestions come from
// the company's own devices and fill brand and category. The status (with
// useDeviceManagement, on an existing device) is a list to choose from, not a
// menu of actions (defect 18). Nothing is saved before "Salvar", and an error
// is shown (the app shows nothing, defect 6).
import { computed, reactive, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { saveDevice, type DeviceDetail } from '@/lib/customers/data'
import { DEVICE_STATUSES, modelSuggestions, serialError, type DeviceRow, type DeviceStatus } from '@/lib/customers/model'
import { applyMask, fieldMasks, groupBySection, namespaceFields, readCustom, segmentField, validateField, writeCustom, type FieldError } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { isMac } from '@/lib/shortcuts'
import CustomFieldInput from './CustomFieldInput.vue'

const props = defineProps<{
  device?: DeviceDetail['device'] | null
  /** The company's devices, for the model suggestions. */
  devices: DeviceRow[]
  /** Typed in a search ("Cadastrar «texto»"). */
  draft?: { name: string; serial: string }
}>()
const emit = defineEmits<{ saved: [id: string]; close: [] }>()

const BUILT_IN = ['device.category', 'device.brand', 'device.model', 'device.serial']
const editing = !!props.device
const country = session.company?.country
const management = (session.company as { useDeviceManagement?: boolean } | null)?.useDeviceManagement === true
const fields = namespaceFields('device', BUILT_IN)
const serialField = segmentField('device.serial')
const serialMasks = fieldMasks(serialField, country)
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const initial = {
  name: props.device?.name ?? props.draft?.name ?? '',
  serial: props.device?.serial ?? props.draft?.serial ?? '',
  manufacturer: props.device?.manufacturer ?? '',
  category: props.device?.category ?? '',
  description: props.device?.description ?? '',
  status: (props.device?.status ?? '') as DeviceStatus | '',
  custom: Object.fromEntries(fields.map((field) => [field.key.split('.').pop() as string, readCustom(props.device?.customData, field) ?? null])) as Record<string, unknown>,
}
const form = reactive({ ...initial, custom: { ...initial.custom } })
const more = ref(!!(initial.manufacturer || initial.category || initial.description || Object.values(initial.custom).some((v) => v !== null && v !== '')))
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const suggestOpen = ref(false)
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const title = computed(() => (editing ? t('web.devices.edit', { device: label('device._entity') }) : t('web.devices.new', { device: label('device._entity') })))
const dirty = computed(() => JSON.stringify(form) !== JSON.stringify(initial))
const serialProblem = computed(() => serialError(form.serial, form.name, serialField?.pattern))
const suggestions = computed(() => (suggestOpen.value ? modelSuggestions(props.devices, form.name) : []))
const fieldErrors = computed(() => Object.fromEntries(fields.map((field) => [field.key, validateField(field, form.custom[field.key.split('.').pop() as string])])) as Record<string, FieldError>)
const sections = computed(() => groupBySection(fields, locale.value, t('web.customers.general')))
const needsAny = computed(() => t('deviceSaveNeedsAny', { first: label('device.model').toLocaleLowerCase(), second: label('device.serial').toLocaleLowerCase() }))
const statusLabel: Record<DeviceStatus, string> = {
  active: t('deviceStatusActive'),
  maintenance: t('deviceStatusMaintenance'),
  inactive: t('deviceStatusInactive'),
  decommissioned: t('deviceStatusDecommissioned'),
}
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

function onSerial(event: Event) {
  const input = event.target as HTMLInputElement
  form.serial = applyMask(input.value, serialMasks).toUpperCase()
  input.value = form.serial
}

function pickSuggestion(item: { name: string; manufacturer: string | null; category: string | null }) {
  form.name = item.name
  if (item.manufacturer) form.manufacturer = item.manufacturer
  if (item.category) form.category = item.category
  if (item.manufacturer || item.category) more.value = true
  suggestOpen.value = false
}

function errorText(error: FieldError, min?: number, max?: number, minLength?: number): string {
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${min}`
  if (error === 'max') return `${t('maximum')}: ${max}`
  if (error === 'minLength') return `${t('minimum')} ${minLength} ${t('characters')}`
  return ''
}

async function save() {
  tried.value = true
  if (serialProblem.value === 'required') {
    failed.value = needsAny.value
    document.getElementById('df-name')?.focus()
    return
  }
  if (serialProblem.value || Object.values(fieldErrors.value).some(Boolean)) {
    failed.value = t('web.customers.fixFields')
    if (!serialProblem.value) more.value = true
    return
  }
  saving.value = true
  failed.value = ''
  try {
    const saved = await saveDevice(props.device?.id ?? null, {
      name: form.name.trim() || null,
      serial: form.serial.trim().toUpperCase() || null,
      manufacturer: form.manufacturer.trim() || null,
      category: form.category.trim() || null,
      description: form.description.trim() || null,
      ...(editing && management && form.status ? { status: form.status } : {}),
      ...(fields.length || props.device?.customData ? { customData: writeCustom(props.device?.customData, fields, form.custom) } : {}),
    })
    allowClose = true
    emit('saved', saved.id)
  } catch (error) {
    console.warn('device: not saved', error)
    failed.value = `${t('saveFailedTryAgain')} ${errorMessageKey(error) !== 'web.error.generic' ? t(errorMessageKey(error)) : ''}`.trim()
  } finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    event.stopPropagation()
    void save()
  }
}

function guard(): boolean {
  if (allowClose || !dirty.value) return true
  const ok = window.confirm(`${t('web.customers.discardTitle')}\n${t('web.customers.discardBody')}`)
  if (ok) allowClose = true
  return ok
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="device-form" novalidate @submit.prevent="save()" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div class="suggest">
          <label class="field-label" for="df-name">{{ label('device.model') }}</label>
          <input
            id="df-name"
            v-model="form.name"
            class="field"
            autocomplete="off"
            role="combobox"
            aria-autocomplete="list"
            aria-controls="df-suggestions"
            :aria-expanded="suggestions.length > 0"
            data-autofocus
            @input="suggestOpen = true"
            @keydown.esc.stop="suggestOpen = false"
            @blur="suggestOpen = false"
          />
          <ul v-if="suggestions.length" id="df-suggestions" class="suggest-list" role="listbox" :aria-label="t('web.devices.suggestions')" data-testid="model-suggestions">
            <li v-for="item in suggestions" :key="`${item.name}|${item.manufacturer}|${item.category}`" role="option" aria-selected="false" @mousedown.prevent="pickSuggestion(item)">
              <span>{{ item.name }}</span>
              <small v-if="item.manufacturer || item.category" class="sub">{{ [item.manufacturer, item.category].filter(Boolean).join(' · ') }}</small>
            </li>
          </ul>
        </div>
        <div>
          <label class="field-label" for="df-serial">{{ label('device.serial') }}</label>
          <input
            id="df-serial"
            :value="form.serial"
            class="field num"
            autocomplete="off"
            autocapitalize="characters"
            :placeholder="(serialField?.placeholder as string | undefined) ?? ''"
            :aria-invalid="tried && !!serialProblem"
            :aria-describedby="tried && serialProblem === 'pattern' ? 'df-serial-error' : undefined"
            @input="onSerial"
          />
          <p v-if="tried && serialProblem === 'pattern'" id="df-serial-error" class="field-error">{{ t('invalidFormat') }}</p>
        </div>
        <fieldset v-if="editing && management" class="choice-set" data-testid="device-status">
          <legend class="field-label">{{ t('web.devices.status') }}</legend>
          <label v-for="status in DEVICE_STATUSES" :key="status" class="check-row">
            <input v-model="form.status" type="radio" name="df-status" :value="status" />
            <span>{{ statusLabel[status] }}</span>
          </label>
        </fieldset>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('web.customers.moreData') }} <span class="sub">{{ label('device.brand') }}, {{ t('deviceCategory').toLocaleLowerCase() }}</span></summary>
          <div class="more-body">
            <div>
              <label class="field-label" for="df-brand">{{ label('device.brand') }}</label>
              <input id="df-brand" v-model="form.manufacturer" class="field" autocomplete="off" />
            </div>
            <div>
              <label class="field-label" for="df-category">{{ t('deviceCategory') }}</label>
              <input id="df-category" v-model="form.category" class="field" autocomplete="off" />
            </div>
            <div>
              <label class="field-label" for="df-description">{{ label('device.description') }}</label>
              <textarea id="df-description" v-model="form.description" class="field" rows="2"></textarea>
            </div>
            <template v-for="section in sections" :key="section.title">
              <h3 class="form-section">{{ section.title }}</h3>
              <CustomFieldInput
                v-for="field in section.fields"
                :key="field.key"
                v-model="form.custom[field.key.split('.').pop() as string]"
                :field="field"
                :error="tried || form.custom[field.key.split('.').pop() as string] ? errorText(fieldErrors[field.key] ?? null, field.min, field.max, field.minLength) : ''"
              />
            </template>
          </div>
        </details>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ !form.name.trim() && !form.serial.trim() ? needsAny : '' }}</span>
        <button type="submit" class="btn btn--primary" :aria-disabled="saving" data-testid="save-device">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
</template>
