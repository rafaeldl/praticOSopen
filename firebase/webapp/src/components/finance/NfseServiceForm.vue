<script setup lang="ts">
// "Serviço da nota" (nfse.setup.service, nfse.setup.municipal-picker): the
// city's service, searched in its list (400 ms after typing) or typed as code
// and name; ISS (suggested by the service when empty), "O cliente retém o ISS",
// the other taxes and the text with {os} and {servicos}. Saving without
// autoIssue keeps the choice saved (the server does).
import { computed, onBeforeUnmount, ref, shallowRef } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { formatNumber } from '@/lib/format'
import { municipalServices, saveService } from '@/lib/nfse/data'
import { DEFAULT_TEMPLATE, parsePercent, type MunicipalService, type NfseSetup, type ServiceSettings, type Taxes } from '@/lib/nfse/model'
import { country } from '@/lib/orders/text'

const props = defineProps<{ current: ServiceSettings | null }>()
const emit = defineEmits<{ close: []; saved: [setup: NfseSetup] }>()

const percentText = (value: number | undefined) => (value ? formatNumber(value, country()) : '')
const typing = ref(!!props.current?.municipalServiceCode)
const serviceId = ref(props.current?.municipalServiceId ?? null)
const serviceName = ref(props.current?.municipalServiceCode ? '' : (props.current?.municipalServiceName ?? ''))
const code = ref(props.current?.municipalServiceCode ?? '')
const name = ref(props.current?.municipalServiceCode ? props.current.municipalServiceName : '')
const taxes = props.current?.taxes
const retainIss = ref(taxes?.retainIss ?? false)
const tax = ref<Record<Exclude<keyof Taxes, 'retainIss'>, string>>({
  iss: percentText(taxes?.iss),
  pis: percentText(taxes?.pis),
  cofins: percentText(taxes?.cofins),
  csll: percentText(taxes?.csll),
  inss: percentText(taxes?.inss),
  ir: percentText(taxes?.ir),
})
const OTHER = ['pis', 'cofins', 'csll', 'inss', 'ir'] as const
const template = ref(props.current?.descriptionTemplate ?? DEFAULT_TEMPLATE)
const valid = computed(() => (typing.value ? !!code.value.trim() && !!name.value.trim() : !!serviceId.value))
const saving = ref(false)
const failed = ref('')
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false
const snapshot = () => JSON.stringify([typing.value, serviceId.value, code.value, name.value, retainIss.value, tax.value, template.value])
const initial = snapshot()
const dirty = computed(() => snapshot() !== initial)

// The city's list, searched as the person types (400 ms).
const query = ref('')
const results = shallowRef<MunicipalService[] | null>(null)
const searchError = ref('')
let timer = 0
let request = 0
async function search(text: string) {
  const mine = ++request
  try {
    const list = await municipalServices(text)
    if (mine !== request) return
    results.value = list
    searchError.value = ''
  } catch (error) {
    if (mine !== request) return
    searchError.value = t(errorMessageKey(error))
  }
}
function onQuery() {
  clearTimeout(timer)
  timer = window.setTimeout(() => void search(query.value), 400)
}
onBeforeUnmount(() => clearTimeout(timer))
if (!typing.value) void search('')

function pick(service: MunicipalService) {
  serviceId.value = service.id
  serviceName.value = service.description
  // ISS suggested by the city's service, only when the field was empty.
  if (typeof service.issTax === 'number' && !tax.value.iss.trim()) tax.value.iss = percentText(service.issTax)
}

function toggleTyping() {
  typing.value = !typing.value
  if (!typing.value && results.value === null) void search(query.value)
}

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  if (saving.value || !valid.value) return
  saving.value = true
  failed.value = ''
  try {
    const setup = await saveService({
      municipalServiceId: typing.value ? null : serviceId.value,
      municipalServiceCode: typing.value ? code.value.trim() : null,
      municipalServiceName: typing.value ? name.value.trim() : serviceName.value,
      taxes: {
        retainIss: retainIss.value,
        iss: parsePercent(tax.value.iss),
        pis: parsePercent(tax.value.pis),
        cofins: parsePercent(tax.value.cofins),
        csll: parsePercent(tax.value.csll),
        inss: parsePercent(tax.value.inss),
        ir: parsePercent(tax.value.ir),
      },
      descriptionTemplate: template.value.trim() || DEFAULT_TEMPLATE,
    })
    allowClose = true
    emit('saved', setup)
  } catch (error) {
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('nfseSetupService')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="nfse-service-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('nfseSetupService') }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <template v-if="typing">
          <div>
            <label class="field-label" for="ns-code">{{ t('nfseServiceCode') }}</label>
            <input id="ns-code" v-model="code" class="field" maxlength="30" data-autofocus />
          </div>
          <div>
            <label class="field-label" for="ns-name">{{ t('nfseServiceName') }}</label>
            <input id="ns-name" v-model="name" class="field" maxlength="500" />
          </div>
        </template>
        <fieldset v-else class="nfse-service-pick">
          <legend class="field-label">{{ t('nfseServicePickTitle') }}</legend>
          <p v-if="serviceName" class="nfse-picked" data-testid="nfse-service-picked"><Check :size="14" aria-hidden="true" /> {{ serviceName }}</p>
          <input v-model="query" class="field" type="search" :aria-label="t('nfseServiceSearch')" :placeholder="t('nfseServiceSearch')" data-autofocus @input="onQuery" />
          <p v-if="searchError" class="field-error" role="alert">{{ searchError }}</p>
          <p v-else-if="results === null" class="muted" role="status">{{ t('web.loading') }}</p>
          <p v-else-if="!results.length" class="muted">{{ t('nfseServiceSearchEmpty') }}</p>
          <ul v-else class="nfse-results">
            <li v-for="service in results" :key="service.id">
              <button type="button" class="nfse-result" :aria-pressed="service.id === serviceId" @click="pick(service)">{{ service.description }}</button>
            </li>
          </ul>
        </fieldset>
        <p><button type="button" class="link" data-testid="nfse-service-toggle" @click="toggleTyping">{{ typing ? t('nfseServicePickTitle') : t('nfseServiceTypeCode') }}</button></p>
        <div>
          <label class="field-label" for="ns-iss">{{ t('nfseIss') }}</label>
          <input id="ns-iss" v-model="tax.iss" class="field" inputmode="decimal" placeholder="0" />
        </div>
        <label class="check-row">
          <input v-model="retainIss" class="check" type="checkbox" />
          <span>{{ t('nfseRetainIss') }}</span>
        </label>
        <details class="more-options">
          <summary>{{ t('nfseOtherTaxes') }}</summary>
          <p class="field-hint">{{ t('nfseTaxesNote') }}</p>
          <div v-for="key in OTHER" :key="key">
            <label class="field-label" :for="`ns-${key}`">{{ key.toUpperCase() }}</label>
            <input :id="`ns-${key}`" v-model="tax[key]" class="field" inputmode="decimal" placeholder="0" />
          </div>
        </details>
        <div>
          <label class="field-label" for="ns-template">{{ t('nfseTemplateLabel') }}</label>
          <textarea id="ns-template" v-model="template" class="field" rows="3" maxlength="1000"></textarea>
          <p class="field-hint">{{ t('nfseTemplateHint', { os: '{os}', servicos: '{servicos}' }) }}</p>
        </div>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ valid ? '' : t('nfseServiceMissing') }}</span>
        <button type="submit" class="btn btn--primary" :disabled="saving || !valid" data-testid="nfse-service-save">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
