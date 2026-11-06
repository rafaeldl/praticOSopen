<script setup lang="ts">
// "Nota fiscal" of the NFS-e direct (spec §4.1, §4.7, §4.8), owner and admin,
// behind settings/payments.nfseDirectEnabled: the company's CNPJs (✓ on the
// default) with their certificate, "Adicionar CNPJ" (drag the .pfx in),
// "Emitir sozinha quando concluir a OS", and the chosen CNPJ beside the list
// (master-detail): totals, the lines that open their editor, use as default,
// replace and delete the certificate. After a new CNPJ's certificate, and from
// a CNPJ that never imported, "Importar notas" (NfseImportDrawer, spec §4.3).
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Plus } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import CertificateDrawer from '@/components/finance/CertificateDrawer.vue'
import EmitterEditDrawer, { type EmitterField } from '@/components/finance/EmitterEditDrawer.vue'
import NfseImportDrawer from '@/components/finance/NfseImportDrawer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { loadCatalogList } from '@/lib/catalog/data'
import { formatDate, formatMoney } from '@/lib/format'
import {
  AUTO_ISSUE,
  MEI_LIMIT,
  certificateState,
  daysLeft,
  defaultEmitterId,
  deleteCertificate,
  directEnabled,
  sampleServices,
  stylePreview,
  updateDirectSettings,
  watchDirect,
  type AutoIssue,
  type DirectSettings,
  type Emitter,
} from '@/lib/nfse/direct'
import { canUndo, loadBatch, undoImport, type ImportBatch } from '@/lib/nfse/import'
import { country } from '@/lib/orders/text'
import { LAYER_PARAM, withoutParam } from '@/lib/route-layer'
import { formatTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import '@/styles/finance.css'

const route = useRoute()
const router = useRouter()
const emitters = shallowRef<Emitter[] | null>(null)
const settings = shallowRef<DirectSettings>({ defaultEmitterId: null, autoIssue: 'never' })
const state = ref<'loading' | 'ready' | 'failed' | 'off'>('loading')
const busy = ref(false)
const adding = ref(false)
const replacing = ref(false)
const deleting = ref(false)
const editing = ref<EmitterField | null>(null)
/** The emitter whose notas are being imported (the drawer is open). */
const importing = ref<string | null>(null)
const undoing = ref(false)
const lastImport = shallowRef<ImportBatch | null>(null)
const ownServices = shallowRef<string[]>([])
let stop: (() => void) | undefined

async function load() {
  state.value = 'loading'
  stop?.()
  try {
    if (!(await directEnabled())) {
      state.value = 'off'
      return
    }
    loadServices()
    stop = await watchDirect(
      (list) => {
        emitters.value = list
        state.value = 'ready'
      },
      (next) => (settings.value = next),
      () => {
        if (!emitters.value) state.value = 'failed'
      },
    )
  } catch {
    state.value = 'failed'
  }
}
onMounted(load)
onBeforeUnmount(() => stop?.())

const list = computed(() => emitters.value ?? [])
const defaultId = computed(() => defaultEmitterId(list.value, settings.value))
const selectedId = computed(() => (typeof route.query.e === 'string' ? route.query.e : null))
const selected = computed(() => list.value.find((e) => e.id === selectedId.value) ?? null)
const select = (id: string | null) => router.replace({ query: { ...route.query, e: id ?? undefined } })
const samples = computed(() => sampleServices(ownServices.value, [t('nfseDirectSampleService1'), t('nfseDirectSampleService2')]))

/** The company's services, most used first, for the "Estilo da descrição" sample. */
async function loadServices() {
  try {
    const list = await loadCatalogList('service')
    const byId = new Map(list.items.map((item) => [item.id, item.name]))
    const used = list.mostUsed.map((id) => byId.get(id)).filter((name): name is string => !!name)
    ownServices.value = [...used, ...list.items.map((item) => item.name)]
  } catch {
    ownServices.value = []
  }
}

/** Only an active certificate reads the government (the server's rule). */
const canImport = (emitter: Emitter) => ['valid', 'expiring'].includes(certificateState(emitter))
/** City line: empty city means nothing was checked yet. */
const cityText = (emitter: Emitter) =>
  emitter.cityName ? t('nfseDirectNotEnabledInCity', { city: emitter.cityName }) : t('nfseDirectNotEnabledNoCity')

// The last import of the chosen CNPJ, for "Desfazer importação" (30 days).
watch(
  () => [selected.value?.id, selected.value?.importBatchId] as const,
  async ([, batchId]) => {
    lastImport.value = null
    if (!batchId) return
    try {
      const batch = await loadBatch(batchId)
      if (batch && selected.value?.importBatchId === batchId) lastImport.value = batch
    } catch {
      lastImport.value = null
    }
  },
  { immediate: true },
)

/** A new CNPJ: choose it and read its notas right away. */
async function onAdded(result: { emitterId: string | null; created: boolean }) {
  adding.value = false
  showToast(t('nfseDirectCnpjAdded'))
  if (!result.created || !result.emitterId) return
  await nextTick()
  await router.replace({ query: { ...withoutParam(route.query, LAYER_PARAM), e: result.emitterId } })
  importing.value = result.emitterId
}

function onImported() {
  importing.value = null
  showToast(t('nfseImportDone'))
}

async function confirmUndo() {
  const batch = lastImport.value
  undoing.value = false
  if (batch) await run(() => undoImport(batch.id), t('nfseImportUndone'))
}

const DOT: Record<string, string> = { valid: 'dot--success', expiring: 'dot--warning', expired: 'dot--danger', pending: 'dot--neutral', missing: 'dot--neutral' }
function certText(emitter: Emitter): string {
  const s = certificateState(emitter)
  if (s === 'valid') return t('nfseDirectCertValidUntil', { date: formatDate(emitter.certificate?.notAfter ?? null, country()) })
  if (s === 'expiring') return t('nfseDirectCertExpiresIn', { days: daysLeft(emitter) })
  if (s === 'expired') return t('nfseDirectCertExpired')
  if (s === 'pending') return t('nfseDirectCertPending')
  return t('nfseDirectCertMissing')
}
function certLine(emitter: Emitter): string {
  const cert = emitter.certificate
  const s = certificateState(emitter)
  if (!cert || s === 'missing') return t('nfseDirectCertMissing')
  const end = formatDate(cert.notAfter ?? null, country())
  const expires = s === 'expired' ? t('nfseDirectCertExpiredOn', { date: end }) : t('nfseDirectCertExpiresOn', { date: end })
  if (!cert.uploadedBy || !cert.uploadedAt) return expires
  return t('nfseDirectCertSentBy', { expires, name: cert.uploadedBy, date: formatDate(cert.uploadedAt, country()) })
}
const regime = (emitter: Emitter) => (emitter.regime === 'mei' ? t('nfseDirectRegimeMei') : t('nfseDirectRegimeSimples'))

const totals = computed(() => {
  const e = selected.value
  const now = new Date()
  const year = e?.totals?.year === now.getFullYear() ? e.totals.yearValue : 0
  const month = e?.totals?.year === now.getFullYear() && e.totals.month === now.getMonth() + 1 ? e.totals.monthValue : 0
  return { year, month }
})

const AUTO_TEXT: Record<AutoIssue, { label: () => string; hint: () => string }> = {
  never: { label: () => t('nfseDirectAutoIssueNever'), hint: () => t('nfseDirectAutoIssueNeverHint') },
  selectedCustomers: { label: () => t('nfseDirectAutoIssueSelected'), hint: () => t('nfseDirectAutoIssueSelectedHint') },
  allOrders: { label: () => t('nfseDirectAutoIssueAll'), hint: () => t('nfseDirectAutoIssueAllHint') },
}

async function run(call: () => Promise<unknown>, done: string) {
  if (busy.value) return
  busy.value = true
  try {
    await call()
    showToast(done)
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}
const chooseAuto = (value: AutoIssue) => value !== settings.value.autoIssue && run(() => updateDirectSettings({ autoIssue: value }), t('web.saved'))
const useAsDefault = (id: string) => run(() => updateDirectSettings({ defaultEmitterId: id }), t('nfseDirectDefaultSaved'))
async function confirmDelete() {
  const id = selected.value?.id
  deleting.value = false
  if (id) await run(() => deleteCertificate(id), t('nfseDirectCertificateDeleted'))
}

function back() {
  if (window.history.length > 1) router.back()
  else void router.push('/invoices')
}
</script>

<template>
  <div class="finance nfse-direct" data-testid="nfse-direct-setup">
    <PageHead :title="t('nfseRowTitle')" :sub="state === 'ready' ? (list.length ? t('nfseDirectHeadWithEmitters') : t('nfseDirectHeadEmpty')) : undefined">
      <button type="button" class="btn btn--ghost" @click="back">{{ t('back') }}</button>
      <button v-if="state === 'ready'" type="button" class="btn" :class="{ 'btn--primary': !list.length }" data-testid="nfse-direct-add" @click="adding = true">
        <Plus :size="16" aria-hidden="true" />{{ t('nfseDirectAddCnpjTitle') }}
      </button>
    </PageHead>
    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :body="t('nfseDirectErrorGeneric')" :retry="load" />
    <p v-else-if="state === 'off'" class="sub" data-testid="nfse-direct-off">{{ t('nfseDirectErrorNotEnabled') }}</p>
    <div v-else-if="list.length" class="nfse-direct-grid">
      <section aria-labelledby="nfse-emitters-title">
        <h2 id="nfse-emitters-title" class="form-section">{{ t('nfseDirectEmittersSection') }}</h2>
        <ul class="nfse-steps">
          <li v-for="emitter in list" :key="emitter.id">
            <button type="button" class="nfse-step" :aria-current="emitter.id === selectedId || undefined" :data-testid="`nfse-emitter-${emitter.id}`" @click="select(emitter.id)">
              <span>{{ emitter.legalName }}<span v-if="emitter.id === defaultId" class="sub"> · ✓ {{ t('nfseDirectDefault') }}</span></span>
              <span class="sub">{{ regime(emitter) }}</span>
              <span class="sub" :class="{ 'is-danger': certificateState(emitter) === 'expired' }"><span class="dot" :class="DOT[certificateState(emitter)]" aria-hidden="true"></span>{{ certText(emitter) }}</span>
            </button>
          </li>
        </ul>
        <fieldset class="nfse-auto" :disabled="busy" data-testid="nfse-direct-auto">
          <legend class="field-label">{{ t('nfseDirectAutoIssueRow') }}</legend>
          <label v-for="value in AUTO_ISSUE" :key="value" class="check-row nfse-auto-row">
            <input class="check" type="radio" name="nfse-direct-auto" :value="value" :checked="settings.autoIssue === value" @change="chooseAuto(value)" />
            <span>{{ AUTO_TEXT[value].label() }}<small class="sub"> · {{ AUTO_TEXT[value].hint() }}</small></span>
          </label>
        </fieldset>
      </section>
      <section v-if="selected" class="nfse-emitter" :aria-label="selected.legalName" data-testid="nfse-emitter-detail">
        <h2 class="nfse-name">{{ selected.legalName }}</h2>
        <p class="sub">{{ formatTaxId(selected.taxId) }} · {{ regime(selected) }}<template v-if="selected.id === defaultId"> · {{ t('nfseDirectDefault') }}</template></p>
        <p data-testid="nfse-emitter-totals">{{ t('nfseDirectTotals', { year: formatMoney(totals.year, country()), month: formatMoney(totals.month, country()) }) }}</p>
        <p v-if="selected.regime === 'mei'" class="sub" :class="{ 'is-warning': totals.year >= MEI_LIMIT * 0.8 }">
          {{ t('nfseDirectMeiLimit', { value: formatMoney(totals.year, country()), limit: formatMoney(MEI_LIMIT, country()) }) }}
        </p>
        <p v-if="!selected.enabledInCity" class="sub" data-testid="nfse-emitter-city">{{ cityText(selected) }}</p>
        <div v-if="canImport(selected) && !selected.importBatchId" class="nfse-import-offer" data-testid="nfse-emitter-import-offer">
          <p>{{ t('web.nfseDirect.importHint') }}</p>
          <button type="button" class="btn btn--primary" data-testid="nfse-emitter-import" @click="importing = selected.id">{{ t('nfseImportAction') }}</button>
        </div>
        <ul class="nfse-steps">
          <li>
            <button type="button" class="nfse-step" data-testid="nfse-emitter-service" @click="editing = 'service'">
              <span>{{ t('nfseDirectServiceRow') }}</span><span class="sub">{{ selected.service?.name || t('nfseDirectMissing') }}</span>
            </button>
          </li>
          <li>
            <button type="button" class="nfse-step" @click="editing = 'registration'">
              <span>{{ t('nfseDirectRegistrationRow') }}</span><span class="sub">{{ selected.municipalRegistration || t('nfseDirectNone') }}</span>
            </button>
          </li>
          <li>
            <button type="button" class="nfse-step" @click="editing = 'style'">
              <span>{{ t('nfseDirectStyleRow') }}</span><span class="sub" data-testid="nfse-emitter-style">{{ stylePreview(selected.descriptionStyle, samples) }}</span>
            </button>
          </li>
          <li>
            <button type="button" class="nfse-step" data-testid="nfse-emitter-certificate" @click="replacing = true">
              <span>{{ t('nfseDirectCertificateRow') }}</span>
              <span class="sub" :class="{ 'is-danger': certificateState(selected) === 'expired' }"><span class="dot" :class="DOT[certificateState(selected)]" aria-hidden="true"></span>{{ certLine(selected) }}</span>
            </button>
          </li>
        </ul>
        <p class="row-actions">
          <button v-if="selected.id !== defaultId" type="button" class="btn" :disabled="busy" data-testid="nfse-emitter-default" @click="useAsDefault(selected.id)">{{ t('nfseDirectUseAsDefault') }}</button>
          <button v-if="canImport(selected) && selected.importBatchId" type="button" class="btn" data-testid="nfse-emitter-import" @click="importing = selected.id">{{ t('nfseImportAction') }}</button>
          <button type="button" class="btn" @click="replacing = true">{{ certificateState(selected) === 'missing' ? t('nfseDirectSendCertificate') : t('nfseDirectReplaceTitle') }}</button>
          <button v-if="canUndo(lastImport)" type="button" class="link link--danger" :disabled="busy" data-testid="nfse-emitter-undo-import" @click="undoing = true">{{ t('nfseImportUndoAction') }}</button>
          <button v-if="certificateState(selected) !== 'missing'" type="button" class="link link--danger" :disabled="busy" data-testid="nfse-emitter-delete" @click="deleting = true">{{ t('nfseDirectDeleteAction') }}</button>
        </p>
      </section>
    </div>
  </div>
  <CertificateDrawer v-if="adding" @saved="onAdded" @close="adding = false" />
  <NfseImportDrawer v-if="importing" :emitter-id="importing" @applied="onImported" @close="importing = null" />
  <CertificateDrawer
    v-if="replacing && selected"
    :emitter-id="selected.id"
    :legal-name="selected.legalName"
    @saved="replacing = false; showToast(t('nfseDirectCertificateReplaced'))"
    @close="replacing = false"
  />
  <EmitterEditDrawer v-if="editing && selected" :emitter="selected" :field="editing" :samples="samples" @saved="editing = null; showToast(t('nfseDirectSaved'))" @close="editing = null" />
  <ConfirmDialog
    v-if="deleting && selected"
    :title="t('nfseDirectDeleteTitle')"
    :body="t('nfseDirectDeleteMessage', { name: selected.legalName })"
    :confirm="t('nfseDirectDeleteAction')"
    :keep="t('cancel')"
    danger
    @confirm="confirmDelete"
    @close="deleting = false"
  />
  <ConfirmDialog
    v-if="undoing && lastImport"
    :title="t('nfseImportUndoQuestion')"
    :body="t('nfseImportUndoMessage')"
    :confirm="t('nfseImportUndoAction')"
    :keep="t('cancel')"
    danger
    @confirm="confirmUndo"
    @close="undoing = false"
  />
</template>
