<script setup lang="ts">
// New or edit customer (customer.form.*), in a drawer over the list. Name and
// phone first; "Mais dados" holds e-mail, CPF/CNPJ (Brazil only), address and
// the segment fields, and opens by itself when any is filled. Nothing is saved
// before "Salvar"; closing with changes asks first, also when editing (the app
// only protects a new one, defect 14). A new customer with a phone already in
// use asks before saving (customer.form.duplicate-*).
import { computed, reactive, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { changedSince, saveCustomer, type CustomerDetail } from '@/lib/customers/data'
import { findByPhone, mapsUrl, type CustomerRow } from '@/lib/customers/model'
import { applyMask, fieldMasks, groupBySection, namespaceFields, readCustom, segmentField, validateField, writeCustom, type FieldError } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { isMac } from '@/lib/shortcuts'
import { formatTaxId, isValidTaxId, normalizeTaxId, usesTaxId } from '@/lib/tax-id'
import CustomFieldInput from './CustomFieldInput.vue'

const props = defineProps<{
  /** Editing this one; without it, a new customer. */
  customer?: CustomerDetail['customer'] | null
  /** Version read with it: a save over a newer one is refused. */
  version?: string | null
  /** What the search had ("Cadastrar «texto»"). */
  draft?: { name: string; phone: string }
  /** Every customer, for the repeated phone. */
  directory: CustomerRow[]
}>()
const emit = defineEmits<{ saved: [id: string]; open: [id: string]; changed: []; close: [] }>()

const BUILT_IN = ['customer.name', 'customer.phone', 'customer.email', 'customer.address', 'customer.taxId']
const editing = !!props.customer
const country = session.company?.country
const fields = namespaceFields('customer', BUILT_IN)
const phoneMasks = fieldMasks(segmentField('customer.phone'), country)
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const initial = {
  name: props.customer?.name ?? props.draft?.name ?? '',
  phone: props.customer?.phone ?? props.draft?.phone ?? '',
  email: props.customer?.email ?? '',
  address: props.customer?.address ?? '',
  taxId: props.customer?.taxId ? formatTaxId(props.customer.taxId) : '',
  custom: Object.fromEntries(fields.map((field) => [field.key.split('.').pop() as string, readCustom(props.customer?.customData, field) ?? null])) as Record<string, unknown>,
}
const form = reactive({ ...initial, custom: { ...initial.custom } })
const more = ref(!!(initial.email || initial.address || initial.taxId || Object.values(initial.custom).some((v) => v !== null && v !== '')))
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const duplicate = ref<CustomerRow | null>(null)
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const title = computed(() => (editing ? t('editCustomer') : t('web.customers.new')))
const canSave = computed(() => !!form.name.trim() && !saving.value)
const dirty = computed(() => JSON.stringify(form) !== JSON.stringify(initial))
const taxIdError = computed(() => (form.taxId.trim() && !isValidTaxId(form.taxId) ? t('web.customers.taxIdInvalid') : ''))
const fieldErrors = computed(() => Object.fromEntries(fields.map((field) => [field.key, validateField(field, form.custom[field.key.split('.').pop() as string])])) as Record<string, FieldError>)
const sections = computed(() => groupBySection(fields, locale.value, t('web.customers.general')))
const map = computed(() => mapsUrl(form.address, props.customer?.latitude, props.customer?.longitude))
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

function onPhone(event: Event) {
  const input = event.target as HTMLInputElement
  form.phone = applyMask(input.value, phoneMasks)
  input.value = form.phone
}

function errorText(error: FieldError, min?: number, max?: number, minLength?: number): string {
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${min}`
  if (error === 'max') return `${t('maximum')}: ${max}`
  if (error === 'minLength') return `${t('minimum')} ${minLength} ${t('characters')}`
  return ''
}

async function save(skipDuplicate = false) {
  tried.value = true
  if (!form.name.trim()) {
    failed.value = t('customerSaveNeedsName')
    document.getElementById('cf-name')?.focus()
    return
  }
  if (taxIdError.value || Object.values(fieldErrors.value).some(Boolean)) {
    more.value = true
    failed.value = t('web.customers.fixFields')
    return
  }
  // Only a new customer with a phone; never blocks: a number can be shared.
  if (!editing && !skipDuplicate && form.phone.trim()) {
    const found = findByPhone(props.directory, form.phone, country)
    if (found) {
      duplicate.value = found
      return
    }
  }
  saving.value = true
  failed.value = ''
  try {
    const id = await saveCustomer(props.customer?.id ?? null, {
      name: form.name.trim(),
      phone: form.phone.trim() || null,
      email: form.email.trim() || null,
      address: form.address.trim() || null,
      ...(usesTaxId(country) ? { taxId: normalizeTaxId(form.taxId) || null } : {}),
      ...(fields.length || props.customer?.customData ? { customData: writeCustom(props.customer?.customData, fields, form.custom) } : {}),
      ...(editing && props.version ? { version: props.version } : {}),
    })
    allowClose = true
    emit('saved', id)
  } catch (error) {
    // Saved by someone else since it opened: nothing is written over it; the screen reads the new one.
    if (changedSince(error)) {
      allowClose = true
      emit('changed')
      return
    }
    console.warn('customer: not saved', error)
    failed.value = t('customerSaveError')
    if (errorMessageKey(error) !== 'web.error.generic') failed.value = `${t('customerSaveError')} ${t(errorMessageKey(error))}`
  } finally {
    saving.value = false
  }
}

/** The parent navigates to the existing customer; that navigation closes this drawer and the warning. */
function openExisting() {
  const found = duplicate.value
  if (!found) return
  allowClose = true
  emit('open', found.id)
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
    <form class="drawer" data-testid="customer-form" novalidate @submit.prevent="save()" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div>
          <label class="field-label" for="cf-name">{{ label('customer.name') }}</label>
          <input id="cf-name" v-model="form.name" class="field" autocomplete="off" :placeholder="t('customerNamePlaceholder')" :aria-invalid="tried && !form.name.trim()" data-autofocus />
        </div>
        <div>
          <label class="field-label" for="cf-phone">{{ t('customerPhoneLabel') }}</label>
          <input id="cf-phone" :value="form.phone" class="field" type="tel" inputmode="tel" autocomplete="off" aria-describedby="cf-phone-hint" @input="onPhone" />
          <p id="cf-phone-hint" class="sub field-hint">{{ t('customerPhoneHint') }}</p>
        </div>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('web.customers.moreData') }} <span class="sub">{{ t('customerMoreDataHint') }}</span></summary>
          <div class="more-body">
            <div>
              <label class="field-label" for="cf-email">{{ label('customer.email') }}</label>
              <input id="cf-email" v-model="form.email" class="field" type="email" autocomplete="off" :placeholder="t('emailPlaceholder')" />
            </div>
            <div v-if="usesTaxId(country)">
              <label class="field-label" for="cf-taxid">{{ t('cpfCnpj') }}</label>
              <input
                id="cf-taxid"
                v-model="form.taxId"
                class="field"
                autocomplete="off"
                autocapitalize="characters"
                :aria-invalid="!!taxIdError"
                :aria-describedby="taxIdError ? 'cf-taxid-error' : undefined"
                @input="form.taxId = form.taxId.toUpperCase()"
              />
              <p v-if="taxIdError" id="cf-taxid-error" class="field-error">{{ taxIdError }}</p>
            </div>
            <div>
              <label class="field-label" for="cf-address">{{ label('customer.address') }}</label>
              <input id="cf-address" v-model="form.address" class="field" autocomplete="off" :placeholder="t('addressPlaceholder')" />
              <a v-if="map" class="link small" :href="map" target="_blank" rel="noopener">{{ t('openInMaps') }}</a>
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
        <span class="hint" aria-live="polite">{{ !form.name.trim() ? t('customerSaveNeedsName') : '' }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !canSave }" data-testid="save-customer">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
  <Layer v-if="duplicate" kind="dialog" :label="t('customerDuplicateTitle')" @close="duplicate = null">
    <div class="layer-head"><h2 class="layer-title">{{ t('customerDuplicateTitle') }}</h2></div>
    <div class="layer-body"><p>{{ t('customerDuplicateMessage', { name: duplicate.name }) }}</p></div>
    <div class="layer-foot">
      <button type="button" class="btn" data-testid="duplicate-save" @click="duplicate = null; save(true)">{{ t('customerDuplicateSaveAnyway') }}</button>
      <button type="button" class="btn btn--primary" data-autofocus data-testid="duplicate-open" @click="openExisting">{{ t('customerDuplicateOpen') }}</button>
    </div>
  </Layer>
</template>
