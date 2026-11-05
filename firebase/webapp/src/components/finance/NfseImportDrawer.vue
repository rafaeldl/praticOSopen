<script setup lang="ts">
// "Importar notas" (NFS-e direct, spec §4.3, the app's nfse_import_screen.dart):
// "Lendo suas notas no governo…" while the server reads, then the summary: the
// emitter (service, series of the PraticOS notas), the customers new and
// completed, "Este é o mesmo cliente?" (answered here, unanswered becomes a new
// customer), stores billed on another CNPJ, "Emitir sozinha" (nothing comes
// on) and how many notas link to orders. One yellow button: "Importar".
import { computed, onBeforeUnmount, onMounted, reactive, ref, shallowRef } from 'vue'
import { Check, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { formatNumber } from '@/lib/format'
import { applyImport, customerCounts, readUntilProposed, toAsk, withStores, type ImportBatch } from '@/lib/nfse/import'
import { country } from '@/lib/orders/text'

const props = defineProps<{ emitterId: string }>()
const emit = defineEmits<{ close: []; applied: [] }>()

const batch = shallowRef<ImportBatch | null>(null)
const failed = ref('')
const applying = ref(false)
const applyError = ref('')
/** "Este é o mesmo cliente?" by group key (absent: not answered). */
const same = reactive<Record<string, boolean>>({})
const autoIssue = reactive(new Set<string>())
const layer = ref<InstanceType<typeof Layer> | null>(null)
let closed = false
let allowClose = false

async function read() {
  failed.value = ''
  try {
    await readUntilProposed(props.emitterId, (next) => (batch.value = next), () => closed)
  } catch (error) {
    if (!closed) failed.value = t(errorMessageKey(error))
  }
}
onMounted(read)
onBeforeUnmount(() => (closed = true))

const proposal = computed(() => (batch.value?.status === 'proposed' ? batch.value.proposal : null))
const asked = computed(() => (proposal.value ? toAsk(proposal.value) : []))
const stores = computed(() => (proposal.value ? withStores(proposal.value).flatMap((g) => g.stores.map((s) => ({ ...s, recipient: g.customerName ?? g.legalName }))) : []))
const counts = computed(() => (proposal.value ? customerCounts(proposal.value, same) : { created: 0, completed: 0 }))
const regime = computed(() => {
  const value = proposal.value?.emitter.regime
  return value === 'mei' ? t('nfseDirectRegimeMei') : value === 'simples' ? t('nfseDirectRegimeSimples') : ''
})
const serviceText = computed(() => {
  const service = proposal.value?.emitter.service
  if (!service?.name) return ''
  return service.issRate > 0 ? t('nfseImportServiceValue', { name: service.name, rate: `${formatNumber(service.issRate, country())}%` }) : service.name
})
const headline = computed(() => {
  if (failed.value) return ''
  const p = proposal.value
  if (!p) return t('nfseImportReading')
  return p.notas === 0 ? t('nfseImportHeadlineEmpty') : t('nfseImportHeadline', { notas: p.notas, customers: p.customers })
})

function toggleAuto(id: string, on: boolean) {
  if (on) autoIssue.add(id)
  else autoIssue.delete(id)
}

function guard(): boolean {
  if (allowClose || applying.value || !proposal.value) return true
  const answered = Object.keys(same).length > 0 || autoIssue.size > 0
  return !answered || window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function apply() {
  const current = batch.value
  if (!current || !proposal.value || applying.value) return
  applying.value = true
  applyError.value = ''
  try {
    await applyImport(current.id, { sameCustomer: { ...same }, autoIssueCustomerIds: [...autoIssue] })
    allowClose = true
    emit('applied')
  } catch (error) {
    applyError.value = t(errorMessageKey(error))
  } finally {
    applying.value = false
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('nfseImportTitle')" :guard="guard" @close="emit('close')">
    <form class="drawer nfse-import" data-testid="nfse-import" novalidate @submit.prevent="apply()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('nfseImportTitle') }}</h2>
      </div>
      <div class="drawer-body" :aria-busy="!proposal && !failed">
        <p v-if="headline" data-testid="nfse-import-headline">{{ headline }}</p>
        <ErrorState v-if="failed" :body="failed" :retry="read" />
        <p v-else-if="!proposal" class="sub" role="status" data-testid="nfse-import-reading">{{ t('nfseImportReadingCount', { count: batch?.documentsRead ?? 0 }) }}</p>
        <template v-else>
          <section aria-labelledby="imp-emitter">
            <h3 id="imp-emitter" class="form-section">{{ t('nfseImportEmitterSection') }}</h3>
            <dl class="nfse-import-facts">
              <div>
                <dt>{{ proposal.emitter.legalName }}</dt>
                <dd v-if="regime" class="sub">{{ regime }}</dd>
              </div>
              <div v-if="proposal.emitter.municipalRegistration">
                <dt>{{ t('nfseDirectRegistrationRow') }}</dt>
                <dd>{{ proposal.emitter.municipalRegistration }}</dd>
              </div>
              <div v-if="serviceText" data-testid="nfse-import-service">
                <dt>{{ t('nfseImportServiceRow') }}</dt>
                <dd>{{ serviceText }}</dd>
              </div>
              <div v-if="proposal.emitter.dpsSeries" data-testid="nfse-import-series">
                <dt>{{ t('nfseImportSeriesRow') }}</dt>
                <dd class="num">{{ proposal.emitter.dpsSeries }}</dd>
              </div>
            </dl>
          </section>
          <section v-if="proposal.customers > 0" aria-labelledby="imp-customers">
            <h3 id="imp-customers" class="form-section">{{ t('nfseImportCustomersSection') }}</h3>
            <ul class="nfse-import-list" aria-live="polite">
              <li data-testid="nfse-import-new">{{ t('nfseImportCustomersNew', { count: counts.created }) }}</li>
              <li data-testid="nfse-import-completed">{{ t('nfseImportCustomersCompleted', { count: counts.completed }) }}</li>
            </ul>
            <p class="field-hint">{{ t('nfseImportCustomersHint') }}</p>
          </section>
          <section v-if="asked.length" aria-labelledby="imp-ask">
            <h3 id="imp-ask" class="form-section">{{ t('nfseImportAskSection') }}</h3>
            <fieldset v-for="group in asked" :key="group.key" class="nfse-import-ask" :disabled="applying" :data-testid="`nfse-import-ask-${group.key}`">
              <legend>
                <span class="nfse-import-name">{{ group.legalName }}</span>
                <span class="sub">{{ t('nfseImportAskSubtitle', { customer: group.customerName ?? '' }) }}</span>
              </legend>
              <label class="check-row">
                <input class="check" type="radio" :name="`same-${group.key}`" :checked="same[group.key] === true" @change="same[group.key] = true" />
                <span>{{ t('nfseImportAskSame') }}</span>
              </label>
              <label class="check-row">
                <input class="check" type="radio" :name="`same-${group.key}`" :checked="same[group.key] === false" @change="same[group.key] = false" />
                <span>{{ t('nfseImportAskNew') }}</span>
              </label>
            </fieldset>
            <p class="field-hint">{{ t('nfseImportAskHint') }}</p>
          </section>
          <section v-if="stores.length" aria-labelledby="imp-stores">
            <h3 id="imp-stores" class="form-section">{{ t('nfseImportStoresSection') }}</h3>
            <ul class="nfse-import-list">
              <li v-for="store in stores" :key="store.customerId">
                <span class="nfse-import-name">{{ store.customerName }}</span>
                <span class="sub">{{ t('nfseImportStoreRow', { recipient: store.recipient }) }}</span>
              </li>
            </ul>
          </section>
          <section v-if="proposal.autoIssue.length" aria-labelledby="imp-auto">
            <h3 id="imp-auto" class="form-section">{{ t('nfseImportAutoSection') }}</h3>
            <fieldset class="nfse-import-auto" :disabled="applying">
              <legend class="sub">{{ t('nfseImportAutoQuestion', { count: proposal.autoIssue.length }) }}</legend>
              <label v-for="s in proposal.autoIssue" :key="s.customerId" class="check-row">
                <input class="check" type="checkbox" :checked="autoIssue.has(s.customerId)" :data-testid="`nfse-import-auto-${s.customerId}`" @change="toggleAuto(s.customerId, ($event.target as HTMLInputElement).checked)" />
                <span>{{ s.customerName }}</span>
              </label>
            </fieldset>
          </section>
          <section v-if="proposal.notas > 0" aria-labelledby="imp-notas">
            <h3 id="imp-notas" class="form-section">{{ t('nfseImportNotasSection') }}</h3>
            <ul class="nfse-import-list">
              <li data-testid="nfse-import-linked">{{ t('nfseImportNotasLinked', { count: proposal.linked }) }}</li>
              <li>{{ t('nfseImportNotasHistory', { count: proposal.historyOnly }) }}</li>
            </ul>
          </section>
          <p v-if="applyError" class="field-error" role="alert" data-testid="nfse-import-error">{{ applyError }}</p>
        </template>
      </div>
      <div v-if="proposal" class="drawer-foot">
        <span class="hint"></span>
        <button type="submit" class="btn btn--primary" :disabled="applying" data-testid="nfse-import-apply">
          <Check :size="16" aria-hidden="true" />{{ applying ? t('web.newOrder.saving') : t('nfseImportButton') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
