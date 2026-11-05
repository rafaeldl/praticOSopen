<script setup lang="ts">
// New or edit device (device.form.*). Model or serial is enough; the serial is
// uppercase, follows the segment mask and pattern. Model suggestions come from
// the company's own devices and fill brand and category. The status (with
// useDeviceManagement, on an existing device) is a list to choose from, not a
// menu of actions (defect 18). Nothing is saved before "Salvar", and an error
// is shown (the app shows nothing, defect 6). The photo (device.form.photo)
// waits in the browser and goes up only after the device exists, so closing
// with X never leaves a device behind (the app creates it on picking a photo);
// the button says it is uploading, and a failed upload is said (the app is silent).
// Only replaced, never removed, as the app.
import { computed, onBeforeUnmount, reactive, ref, toRef, watch } from 'vue'
import { Camera, Check, ImagePlus, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { changedSince, saveDevice, uploadDevicePhoto, type DeviceDetail } from '@/lib/customers/data'
import { DEVICE_STATUSES, modelSuggestions, serialError, type DeviceRow, type DeviceStatus } from '@/lib/customers/model'
import { readingFieldOf } from '@/lib/device-reading'
import { useMask, fieldMasks, groupBySection, namespaceFields, readCustom, segmentField, validateField, writeCustom, type FieldError } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { isMac } from '@/lib/shortcuts'
import CustomFieldInput from './CustomFieldInput.vue'

const props = defineProps<{
  device?: DeviceDetail['device'] | null
  version?: string | null
  /** The company's devices, for the model suggestions. */
  devices: DeviceRow[]
  /** Typed in a search ("Cadastrar «texto»"). */
  draft?: { name: string; serial: string }
}>()
/** saved: `notice` replaces "Salvo" (the device was saved, the photo was not). */
const emit = defineEmits<{ saved: [id: string, notice?: string]; changed: []; close: [] }>()

const BUILT_IN = ['device.category', 'device.brand', 'device.model', 'device.serial']
const editing = !!props.device
const country = computed(() => session.company?.country)
const management = (session.company as { useDeviceManagement?: boolean } | null)?.useDeviceManagement === true
// The segment may still be loading: the fields, the serial's mask and pattern follow it.
const fieldList = computed(() => namespaceFields('device', BUILT_IN))
const fields = fieldList.value
const serialFieldRef = computed(() => segmentField('device.serial'))
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
// Fields of a segment that arrived after the form opened: they come with what the record already has.
watch(fieldList, (list) => {
  for (const field of list) {
    const name = field.key.split('.').pop() as string
    if (name in form.custom) continue
    const value = readCustom(props.device?.customData, field) ?? null
    initial.custom[name] = value
    form.custom[name] = value
  }
})
const MAX_PHOTO = 10 * 1024 * 1024
const photo = ref<{ file: File; url: string } | null>(null)
const photoError = ref('')
const uploading = ref(false)
const readingName = readingFieldOf(fields)?.key.split('.').pop()
const more = ref(!!(props.device?.photo || initial.manufacturer || initial.category || initial.description || Object.entries(initial.custom).some(([name, v]) => name !== readingName && v !== null && v !== '')))
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const suggestOpen = ref(false)
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const title = computed(() => (editing ? t('web.devices.edit', { device: label('device._entity') }) : t('web.devices.new', { device: label('device._entity') })))
const dirty = computed(() => JSON.stringify(form) !== JSON.stringify(initial) || !!photo.value)
const shownPhoto = computed(() => photo.value?.url ?? props.device?.photo ?? null)
const serialProblem = computed(() => serialError(form.serial, form.name, serialFieldRef.value?.pattern))
const suggestions = computed(() => (suggestOpen.value ? modelSuggestions(props.devices, form.name) : []))
const fieldErrors = computed(() => Object.fromEntries(fieldList.value.map((field) => [field.key, validateField(field, form.custom[field.key.split('.').pop() as string])])) as Record<string, FieldError>)
// The reading (odometer, hour meter) sits next to the serial, not in "Mais dados" (docs/DEVICE_READING.md).
const reading = computed(() => readingFieldOf(fieldList.value))
const sections = computed(() => groupBySection(fieldList.value.filter((field) => field.key !== reading.value?.key), locale.value, t('web.customers.general')))
const needsAny = computed(() => t('deviceSaveNeedsAny', { first: label('device.model').toLocaleLowerCase(), second: label('device.serial').toLocaleLowerCase() }))
const statusLabel: Record<DeviceStatus, string> = {
  active: t('deviceStatusActive'),
  maintenance: t('deviceStatusMaintenance'),
  inactive: t('deviceStatusInactive'),
  decommissioned: t('deviceStatusDecommissioned'),
}
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

const onSerial = useMask(toRef(form, 'serial'), () => fieldMasks(serialFieldRef.value, country.value), (text) => text.toUpperCase())

function pickSuggestion(item: { name: string; manufacturer: string | null; category: string | null }) {
  form.name = item.name
  if (item.manufacturer) form.manufacturer = item.manufacturer
  if (item.category) form.category = item.category
  if (item.manufacturer || item.category) more.value = true
  suggestOpen.value = false
}

function choosePhoto(file: File | null | undefined) {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    photoError.value = t('web.catalog.photoNotImage')
    return
  }
  if (file.size >= MAX_PHOTO) {
    photoError.value = t('web.catalog.photoTooBig')
    return
  }
  photoError.value = ''
  if (photo.value) URL.revokeObjectURL(photo.value.url)
  photo.value = { file, url: URL.createObjectURL(file) }
}

function onPaste(event: ClipboardEvent) {
  const file = [...(event.clipboardData?.files ?? [])].find((item) => item.type.startsWith('image/'))
  if (file) {
    event.preventDefault()
    choosePhoto(file)
  }
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
  if (saving.value) return
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
      ...(fieldList.value.length || props.device?.customData ? { customData: writeCustom(props.device?.customData, fieldList.value, form.custom) } : {}),
      ...(editing && props.version ? { version: props.version } : {}),
    })
    allowClose = true
    let notice: string | undefined
    if (photo.value) {
      uploading.value = true
      try {
        const uploaded = await uploadDevicePhoto(saved.id, photo.value.file)
        await saveDevice(saved.id, { photo: uploaded })
      } catch (error) {
        // The device is saved either way: the screen says the photo did not go instead of "Salvo".
        console.warn('device: photo not saved', error)
        notice = t('web.devices.photoFailed')
      } finally {
        uploading.value = false
      }
    }
    emit('saved', saved.id, notice)
  } catch (error) {
    if (changedSince(error)) {
      allowClose = true
      emit('changed')
      return
    }
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

onBeforeUnmount(() => {
  if (photo.value) URL.revokeObjectURL(photo.value.url)
})
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="device-form" novalidate @submit.prevent="save()" @keydown="onKeydown" @paste="onPaste">
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
            :placeholder="(serialFieldRef?.placeholder as string | undefined) ?? ''"
            :aria-invalid="tried && !!serialProblem"
            :aria-describedby="tried && serialProblem === 'pattern' ? 'df-serial-error' : undefined"
            @input="onSerial"
          />
          <p v-if="tried && serialProblem === 'pattern'" id="df-serial-error" class="field-error">{{ t('invalidFormat') }}</p>
        </div>
        <CustomFieldInput
          v-if="reading"
          v-model="form.custom[reading.key.split('.').pop() as string]"
          :field="reading"
          :error="tried || form.custom[reading.key.split('.').pop() as string] ? errorText(fieldErrors[reading.key] ?? null, reading.min, reading.max, reading.minLength) : ''"
          data-testid="device-reading"
        />
        <fieldset v-if="editing && management" class="choice-set" data-testid="device-status">
          <legend class="field-label">{{ t('web.devices.status') }}</legend>
          <label v-for="status in DEVICE_STATUSES" :key="status" class="check-row">
            <input v-model="form.status" type="radio" name="df-status" :value="status" />
            <span>{{ statusLabel[status] }}</span>
          </label>
        </fieldset>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('web.customers.moreData') }} <span class="sub">{{ t('photo') }}, {{ label('device.brand').toLocaleLowerCase() }}, {{ t('deviceCategory').toLocaleLowerCase() }}</span></summary>
          <div class="more-body">
            <div class="dev-photo" data-testid="device-photo" @dragover.prevent @drop.prevent="choosePhoto($event.dataTransfer?.files[0])">
              <span class="field-label">{{ t('photo') }}</span>
              <div class="dev-photo-row">
                <img v-if="shownPhoto" class="dev-thumb" :src="shownPhoto" width="56" height="56" :alt="t('web.catalog.photoPreview')" data-testid="device-photo-preview" />
                <span v-else class="dev-thumb" aria-hidden="true"><Camera :size="22" /></span>
                <label class="btn">
                  <ImagePlus :size="15" aria-hidden="true" />{{ shownPhoto ? t('web.catalog.photoChange') : t('web.catalog.photoPick') }}
                  <input class="sr" type="file" accept="image/*" data-testid="device-photo-file" aria-describedby="df-photo-hint" :disabled="saving" @change="choosePhoto(($event.target as HTMLInputElement).files?.[0])" />
                </label>
              </div>
              <p id="df-photo-hint" class="sub field-hint">{{ t('web.catalog.photoHint') }}</p>
              <p v-if="photoError" class="field-error" role="alert">{{ photoError }}</p>
            </div>
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
          <Check :size="16" aria-hidden="true" />{{ uploading ? t('web.devices.photoUploading') : saving ? t('web.newOrder.saving') : t('save') }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
</template>
