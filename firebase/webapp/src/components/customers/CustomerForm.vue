<script setup lang="ts">
// New or edit customer (customer.form.*), in a drawer over the list. Name and
// phone first; "Mais dados" holds e-mail, CPF/CNPJ (Brazil only), address and
// the segment fields, and opens by itself when any is filled. Nothing is saved
// before "Salvar"; closing with changes asks first, also when editing (the app
// only protects a new one, defect 14). A new customer with a phone already in
// use asks before saving (customer.form.duplicate-*).
// With the direct nota on, CPF/CNPJ moves to "Dados para nota" (legal name,
// address with CEP, e-mail of the nota, "Emitir nota sozinha"): a CNPJ fills
// from the Receita and a CEP from ViaCEP, never over what was typed, and a
// CPF/CNPJ another customer has blocks with "Mandar as notas desta loja para
// ela" (customer.invoice-data.*, docs/NFSE_DIRECT.md).
import { computed, onMounted, reactive, ref, toRef, watch } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { changedSince, loadCustomerDirectory, saveCustomer, type CustomerDetail } from '@/lib/customers/data'
import { findByPhone, mapsUrl, type CustomerRow } from '@/lib/customers/model'
import {
  autoIssueOf,
  findByTaxId,
  formatPostalCode,
  INVOICE_OFF,
  invoiceConfig,
  lookupCnpj,
  lookupPostalCode,
  postalCodeDigits,
  showAutoIssue,
  type FiscalAddress,
  type InvoiceConfig,
} from '@/lib/customers/invoice-data'
import { useMask, fieldMasks, groupBySection, namespaceFields, readCustom, segmentField, validateField, writeCustom, type FieldError } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { isMac } from '@/lib/shortcuts'
import { formatTaxId, isValidCnpj, isValidTaxId, normalizeTaxId, usesTaxId } from '@/lib/tax-id'
import CustomFieldInput from './CustomFieldInput.vue'

const props = defineProps<{
  /** Editing this one; without it, a new customer. */
  customer?: CustomerDetail['customer'] | null
  /** Version read with it: a save over a newer one is refused. */
  version?: string | null
  /** What the search had ("Cadastrar «texto»"). */
  draft?: { name: string; phone: string }
  /** Every customer, for the repeated phone and CPF/CNPJ. */
  directory: CustomerRow[]
  /** "Dados para nota"; read from settings when not given (tests give it). */
  invoice?: InvoiceConfig
}>()
const emit = defineEmits<{ saved: [id: string]; open: [id: string]; changed: []; close: [] }>()

const BUILT_IN = ['customer.name', 'customer.phone', 'customer.email', 'customer.address', 'customer.taxId']
const editing = !!props.customer
// The segment and the company's country may still be loading: everything that depends on them follows them.
const country = computed(() => session.company?.country)
const fieldList = computed(() => namespaceFields('customer', BUILT_IN))
const fields = fieldList.value
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const initial = {
  name: props.customer?.name ?? props.draft?.name ?? '',
  phone: props.customer?.phone ?? props.draft?.phone ?? '',
  email: props.customer?.email ?? '',
  address: props.customer?.address ?? '',
  taxId: props.customer?.taxId ? formatTaxId(props.customer.taxId) : '',
  legalName: props.customer?.legalName ?? '',
  postalCode: formatPostalCode(props.customer?.fiscalAddress?.postalCode),
  street: props.customer?.fiscalAddress?.street ?? '',
  number: props.customer?.fiscalAddress?.number ?? '',
  complement: props.customer?.fiscalAddress?.complement ?? '',
  district: props.customer?.fiscalAddress?.district ?? '',
  cityName: props.customer?.fiscalAddress?.cityName ?? '',
  state: props.customer?.fiscalAddress?.state ?? '',
  invoiceEmail: props.customer?.invoiceEmail ?? '',
  autoIssue: props.customer?.autoIssueInvoice ?? null as boolean | null,
  custom: Object.fromEntries(fields.map((field) => [field.key.split('.').pop() as string, readCustom(props.customer?.customData, field) ?? null])) as Record<string, unknown>,
}
const form = reactive({ ...initial, custom: { ...initial.custom } })
// Name already typed (in the search or ⌘K): the cursor starts on the phone.
const startOnPhone = !editing && !!initial.name.trim() && !initial.phone
// Fields of a segment that arrived after the form opened: they come with what the record already has.
watch(fieldList, (list) => {
  for (const field of list) {
    const name = field.key.split('.').pop() as string
    if (name in form.custom) continue
    const value = readCustom(props.customer?.customData, field) ?? null
    initial.custom[name] = value
    form.custom[name] = value
  }
})
const invoice = ref<InvoiceConfig>(props.invoice ?? INVOICE_OFF)
onMounted(async () => {
  if (!props.invoice) invoice.value = await invoiceConfig()
})
/** CPF/CNPJ lives in "Dados para nota" while the direct nota is on. */
const taxIdInInvoice = computed(() => invoice.value.enabled && usesTaxId(country.value))
const invoiceOpen = ref(
  !!(initial.taxId || initial.legalName || initial.postalCode || initial.street || initial.invoiceEmail || props.customer?.invoiceRecipient),
)
// IBGE code of the city, from a lookup (or the saved address); another city typed drops it.
let cityCode = props.customer?.fiscalAddress?.cityCode ?? null
let cityCodeName = props.customer?.fiscalAddress?.cityName ?? null
type FillKey = 'legalName' | 'postalCode' | 'street' | 'number' | 'complement' | 'district' | 'cityName' | 'state' | 'invoiceEmail'
/** What the lookups wrote, by field: a later lookup may replace it, never what the person typed. */
const filled: Partial<Record<FillKey, string>> = {}
function fill(key: FillKey, value: string | null | undefined, force = false) {
  if (!value) return
  const current = form[key].trim()
  if (!force && current && current !== filled[key]) return
  form[key] = value
  filled[key] = value
}
const cnpjLookup = ref<'' | 'busy' | 'found' | 'notFound'>('')
const cepLookup = ref<'' | 'busy' | 'notFound'>('')
let lookedUpCnpj = ''
let lookedUpCep = ''
watch(
  () => normalizeTaxId(form.taxId),
  async (id) => {
    if (!invoice.value.enabled || id.length !== 14 || !isValidCnpj(id)) {
      cnpjLookup.value = ''
      return
    }
    if (id === lookedUpCnpj) return
    lookedUpCnpj = id
    cnpjLookup.value = 'busy'
    const info = await lookupCnpj(id)
    if (lookedUpCnpj !== id) return
    if (!info) {
      cnpjLookup.value = 'notFound'
      return
    }
    cnpjLookup.value = 'found'
    fill('legalName', info.legalName)
    fillAddress(info.address)
    if (info.email && info.email !== form.email.trim().toLowerCase()) fill('invoiceEmail', info.email)
  },
)
function fillAddress(address: FiscalAddress, force = false) {
  if (address.postalCode) {
    fill('postalCode', formatPostalCode(address.postalCode), force)
    lookedUpCep = address.postalCode
  }
  fill('street', address.street, force)
  fill('number', address.number)
  fill('complement', address.complement)
  fill('district', address.district, force)
  if (address.cityName && (force || !form.cityName.trim() || form.cityName.trim() === filled.cityName)) {
    fill('cityName', address.cityName, true)
    cityCode = address.cityCode
    cityCodeName = address.cityName
  }
  fill('state', address.state, force)
}
watch(
  () => postalCodeDigits(form.postalCode),
  async (cep) => {
    if (cep.length !== 8) {
      cepLookup.value = ''
      return
    }
    if (cep === lookedUpCep) return
    lookedUpCep = cep
    cepLookup.value = 'busy'
    const address = await lookupPostalCode(cep)
    if (lookedUpCep !== cep) return
    cepLookup.value = address ? '' : 'notFound'
    // A new CEP is another place: its street, district and city win over an earlier lookup.
    if (address) fillAddress(address, true)
  },
)
const autoIssueValue = computed(() => autoIssueOf(invoice.value, form.autoIssue))
const taxIdOwner = ref<CustomerRow | null>(null)
let sendNotasTo: CustomerRow | null = null

function invoiceFields() {
  const text = (value: string) => value.trim() || null
  const cityName = text(form.cityName)
  const postalCode = postalCodeDigits(form.postalCode)
  const address: FiscalAddress = {
    postalCode: postalCode.length === 8 ? postalCode : null,
    street: text(form.street),
    number: text(form.number),
    complement: text(form.complement),
    district: text(form.district),
    cityCode: cityName && cityName === cityCodeName ? cityCode : null,
    cityName,
    state: /^[A-Za-z]{2}$/.test(form.state.trim()) ? form.state.trim().toUpperCase() : null,
  }
  return {
    legalName: text(form.legalName),
    fiscalAddress: Object.values(address).some(Boolean) ? address : null,
    invoiceEmail: text(form.invoiceEmail),
    ...(form.autoIssue !== null ? { autoIssueInvoice: form.autoIssue } : {}),
  }
}

const more = ref(!!(initial.email || initial.address || (initial.taxId && !props.customer?.legalName) || Object.values(initial.custom).some((v) => v !== null && v !== '')))
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
const postalCodeError = computed(() => {
  const digits = postalCodeDigits(form.postalCode)
  return invoice.value.enabled && digits && digits.length !== 8 ? t('invalidFormat') : ''
})
const invoiceEmailError = computed(() => (invoice.value.enabled && form.invoiceEmail.trim() && !/^\S+@\S+\.\S+$/.test(form.invoiceEmail.trim()) ? t('invalidFormat') : ''))
const fieldErrors = computed(() => Object.fromEntries(fieldList.value.map((field) => [field.key, validateField(field, form.custom[field.key.split('.').pop() as string])])) as Record<string, FieldError>)
const sections = computed(() => groupBySection(fieldList.value, locale.value, t('web.customers.general')))
const map = computed(() => mapsUrl(form.address, props.customer?.latitude, props.customer?.longitude))
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

// Typed before the mask arrived: masked when it arrives (useMask).
const onPhone = useMask(toRef(form, 'phone'), () => fieldMasks(segmentField('customer.phone'), country.value))

function errorText(error: FieldError, min?: number, max?: number, minLength?: number): string {
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${min}`
  if (error === 'max') return `${t('maximum')}: ${max}`
  if (error === 'minLength') return `${t('minimum')} ${minLength} ${t('characters')}`
  return ''
}

async function save(skipDuplicate = false, skipTaxId = false) {
  tried.value = true
  if (!form.name.trim()) {
    failed.value = t('customerSaveNeedsName')
    document.getElementById('cf-name')?.focus()
    return
  }
  if (postalCodeError.value || invoiceEmailError.value || (taxIdError.value && taxIdInInvoice.value)) {
    invoiceOpen.value = true
    failed.value = t('web.customers.fixFields')
    return
  }
  if (taxIdError.value || Object.values(fieldErrors.value).some(Boolean)) {
    more.value = true
    failed.value = t('web.customers.fixFields')
    return
  }
  // Only a new customer with a phone; never blocks: a number can be shared.
  if (!editing && !skipDuplicate && form.phone.trim()) {
    const found = findByPhone(props.directory, form.phone, country.value)
    if (found) {
      duplicate.value = found
      return
    }
  }
  // A CPF/CNPJ lives in one customer (spec §4.5): only when it changed, as the app.
  if (!skipTaxId) {
    sendNotasTo = null
    const taxId = normalizeTaxId(form.taxId)
    if (invoice.value.enabled && taxId && taxId !== normalizeTaxId(initial.taxId)) {
      // The list may still be on its way (a link straight to the customer): wait for it, or use what came.
      saving.value = true
      const rows = await loadCustomerDirectory()
        .then((directory) => directory.rows)
        .catch(() => props.directory)
      saving.value = false
      const owner = findByTaxId(rows.length ? rows : props.directory, taxId, props.customer?.id)
      if (owner) {
        taxIdOwner.value = owner
        return
      }
    }
  }
  const sendTo = sendNotasTo
  saving.value = true
  failed.value = ''
  try {
    const id = await saveCustomer(props.customer?.id ?? null, {
      name: form.name.trim(),
      phone: form.phone.trim() || null,
      email: form.email.trim() || null,
      address: form.address.trim() || null,
      ...(usesTaxId(country.value) ? { taxId: sendTo ? null : normalizeTaxId(form.taxId) || null } : {}),
      ...(invoice.value.enabled ? invoiceFields() : {}),
      ...(sendTo ? { invoiceRecipientId: sendTo.id } : {}),
      ...(fieldList.value.length || props.customer?.customData ? { customData: writeCustom(props.customer?.customData, fieldList.value, form.custom) } : {}),
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

/** "Mandar as notas desta loja para ela": saves without the number, with the notas going to the owner. */
function sendNotasToOwner() {
  sendNotasTo = taxIdOwner.value
  taxIdOwner.value = null
  void save(true, true)
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
          <input id="cf-name" v-model="form.name" class="field" autocomplete="off" :placeholder="t('customerNamePlaceholder')" :aria-invalid="tried && !form.name.trim()" :data-autofocus="startOnPhone ? undefined : ''" />
        </div>
        <div>
          <label class="field-label" for="cf-phone">{{ t('customerPhoneLabel') }}</label>
          <input id="cf-phone" :value="form.phone" class="field" type="tel" inputmode="tel" autocomplete="off" aria-describedby="cf-phone-hint" :data-autofocus="startOnPhone ? '' : undefined" @input="onPhone" />
          <p id="cf-phone-hint" class="sub field-hint">{{ t('customerPhoneHint') }}</p>
        </div>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('web.customers.moreData') }} <span class="sub">{{ t('customerMoreDataHint') }}</span></summary>
          <div class="more-body">
            <div>
              <label class="field-label" for="cf-email">{{ label('customer.email') }}</label>
              <input id="cf-email" v-model="form.email" class="field" type="email" autocomplete="off" :placeholder="t('emailPlaceholder')" />
            </div>
            <div v-if="usesTaxId(country) && !taxIdInInvoice">
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
        <details v-if="invoice.enabled" class="more-options" data-testid="customer-invoice-data" :open="invoiceOpen" @toggle="invoiceOpen = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('invoiceDataTitle') }} <span class="sub">{{ t('invoiceDataHint') }}</span></summary>
          <div class="more-body">
            <div v-if="taxIdInInvoice">
              <label class="field-label" for="cf-inv-taxid">{{ t('cpfCnpj') }}</label>
              <input
                id="cf-inv-taxid"
                v-model="form.taxId"
                class="field"
                autocomplete="off"
                autocapitalize="characters"
                :aria-invalid="!!taxIdError"
                aria-describedby="cf-inv-taxid-note"
                @input="form.taxId = form.taxId.toUpperCase()"
              />
              <p id="cf-inv-taxid-note" :class="taxIdError ? 'field-error' : 'sub field-hint'" aria-live="polite" data-testid="invoice-taxid-note">
                {{
                  taxIdError ||
                  (cnpjLookup === 'busy' ? t('invoiceTaxIdLooking') : cnpjLookup === 'found' ? t('invoiceTaxIdFound') : cnpjLookup === 'notFound' ? t('invoiceTaxIdNotFound') : '')
                }}
              </p>
            </div>
            <div>
              <label class="field-label" for="cf-inv-legal">{{ t('invoiceLegalName') }}</label>
              <input id="cf-inv-legal" v-model="form.legalName" class="field" autocomplete="off" :placeholder="t('invoiceLegalNamePlaceholder')" />
            </div>
            <div>
              <label class="field-label" for="cf-inv-cep">{{ t('invoicePostalCode') }}</label>
              <input
                id="cf-inv-cep"
                :value="form.postalCode"
                class="field"
                inputmode="numeric"
                autocomplete="off"
                :placeholder="t('invoicePostalCodePlaceholder')"
                :aria-invalid="!!postalCodeError"
                aria-describedby="cf-inv-cep-note"
                @input="form.postalCode = formatPostalCode(($event.target as HTMLInputElement).value)"
              />
              <p id="cf-inv-cep-note" :class="postalCodeError ? 'field-error' : 'sub field-hint'" aria-live="polite">
                {{ postalCodeError || (cepLookup === 'busy' ? t('invoicePostalCodeLooking') : cepLookup === 'notFound' ? t('invoicePostalCodeNotFound') : '') }}
              </p>
            </div>
            <div>
              <label class="field-label" for="cf-inv-street">{{ t('invoiceStreet') }}</label>
              <input id="cf-inv-street" v-model="form.street" class="field" autocomplete="off" />
            </div>
            <div class="field-pair">
              <div>
                <label class="field-label" for="cf-inv-number">{{ t('invoiceNumber') }}</label>
                <input id="cf-inv-number" v-model="form.number" class="field" autocomplete="off" />
              </div>
              <div>
                <label class="field-label" for="cf-inv-complement">{{ t('invoiceComplement') }}</label>
                <input id="cf-inv-complement" v-model="form.complement" class="field" autocomplete="off" :placeholder="t('optional')" />
              </div>
            </div>
            <div>
              <label class="field-label" for="cf-inv-district">{{ t('invoiceDistrict') }}</label>
              <input id="cf-inv-district" v-model="form.district" class="field" autocomplete="off" />
            </div>
            <div class="field-pair">
              <div>
                <label class="field-label" for="cf-inv-city">{{ t('invoiceCity') }}</label>
                <input id="cf-inv-city" v-model="form.cityName" class="field" autocomplete="off" />
              </div>
              <div>
                <label class="field-label" for="cf-inv-state">{{ t('invoiceState') }}</label>
                <input id="cf-inv-state" v-model="form.state" class="field" maxlength="2" autocomplete="off" :placeholder="t('invoiceStatePlaceholder')" @input="form.state = form.state.toUpperCase()" />
              </div>
            </div>
            <div>
              <label class="field-label" for="cf-inv-email">{{ t('invoiceEmailLabel') }}</label>
              <input
                id="cf-inv-email"
                v-model="form.invoiceEmail"
                class="field"
                type="email"
                autocomplete="off"
                :placeholder="form.email.trim() || t('emailPlaceholder')"
                :aria-invalid="!!invoiceEmailError"
                aria-describedby="cf-inv-email-note"
              />
              <p id="cf-inv-email-note" :class="invoiceEmailError ? 'field-error' : 'sub field-hint'">{{ invoiceEmailError || (form.email.trim() ? t('invoiceEmailFallback') : '') }}</p>
            </div>
            <p v-if="customer?.invoiceRecipient" class="sub" data-testid="invoice-recipient-note">{{ t('invoiceRecipientLabel') }}: {{ customer.invoiceRecipient.name }}</p>
            <label v-if="showAutoIssue(invoice)" class="switch-row" data-testid="invoice-auto-issue">
              <span>{{ t('invoiceAutoIssue') }} <span class="sub">{{ t('invoiceAutoIssueHint') }}</span></span>
              <input type="checkbox" role="switch" :checked="autoIssueValue" @change="form.autoIssue = ($event.target as HTMLInputElement).checked" />
            </label>
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
  <Layer v-if="taxIdOwner" kind="dialog" :label="t('invoiceTaxIdTakenMessage')" @close="taxIdOwner = null">
    <div class="layer-head">
      <h2 class="layer-title">
        {{ normalizeTaxId(form.taxId).length === 11 ? t('invoiceTaxIdTakenCpf', { name: taxIdOwner.legalName || taxIdOwner.name }) : t('invoiceTaxIdTakenCnpj', { name: taxIdOwner.legalName || taxIdOwner.name }) }}
      </h2>
    </div>
    <div class="layer-body"><p>{{ t('invoiceTaxIdTakenMessage') }}</p></div>
    <div class="layer-foot">
      <button type="button" class="btn" data-testid="taxid-back" @click="taxIdOwner = null">{{ t('back') }}</button>
      <button type="button" class="btn btn--primary" data-autofocus data-testid="taxid-send-notas" @click="sendNotasToOwner">{{ t('invoiceTaxIdTakenUse') }}</button>
    </div>
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
