<script setup lang="ts">
// "Nota fiscal" setup (nfse.setup.view, nfse.setup.city-access, nfse.setup.recheck,
// nfse.setup.auto-issue): what is ready and what is missing before the first
// nota, in the app's order (dados fiscais, acesso à prefeitura, serviço). One
// blue button opens the next missing step. Owner and admin only (the server
// answers 403 to anyone else). Back goes where the person came from.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import NfseFiscalForm from '@/components/finance/NfseFiscalForm.vue'
import NfseServiceForm from '@/components/finance/NfseServiceForm.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { nfseSettings, nfseSetup, saveService } from '@/lib/nfse/data'
import { directEnabled } from '@/lib/nfse/direct'
import { cityAccessKind, nextSetupStep, type AutoIssue, type NfseSetup } from '@/lib/nfse/model'
import { showToast } from '@/lib/toast'
import '@/styles/finance.css'

const router = useRouter()
const setup = shallowRef<NfseSetup | null>(null)
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const failure = ref('')
const sandbox = ref(false)
const busy = ref(false)
const open = ref<'fiscal' | 'service' | null>(null)

async function load(quiet = false) {
  if (!quiet) state.value = setup.value ? 'ready' : 'loading'
  busy.value = true
  try {
    const [data, settings] = await Promise.all([nfseSetup(), nfseSettings().catch(() => null)])
    setup.value = data
    sandbox.value = !!settings?.sandbox
    state.value = 'ready'
  } catch (error) {
    failure.value = t(errorMessageKey(error))
    if (!setup.value) state.value = 'failed'
    else showToast(failure.value)
  } finally {
    busy.value = false
  }
}

// Back from the Asaas panel (another tab): the city access is checked again by
// itself (the app only does it on "Já enviei": its defect).
const onFocus = () => {
  if (setup.value?.missing.includes('cityAccess') && !open.value) void load(true)
}
onMounted(async () => {
  // NFS-e direct pilot: its own setup (emitters and certificates).
  if (await directEnabled().catch(() => false)) {
    void router.replace('/invoices/direct')
    return
  }
  void load()
  window.addEventListener('focus', onFocus)
})
onBeforeUnmount(() => window.removeEventListener('focus', onFocus))

const PANEL = 'https://www.asaas.com/'
const SANDBOX_PANEL = 'https://sandbox.asaas.com/'
const panelUrl = computed(() => (sandbox.value ? SANDBOX_PANEL : PANEL))
const missing = computed(() => setup.value?.missing ?? [])
const needsCityAccess = computed(() => !!setup.value?.fiscalInfo && !!setup.value.municipalOptions?.authenticationType && missing.value.includes('cityAccess'))
const cityAccessDone = computed(() => !!setup.value?.fiscalInfo && !missing.value.includes('cityAccess'))
const cityText = computed(() => {
  if (!setup.value) return ''
  const kind = cityAccessKind(setup.value)
  if (kind === 'first') return t('nfseCityAccessFirst')
  if (kind === 'certificate') return t('nfseCityAccessCertificate')
  if (kind === 'token') return t('nfseCityAccessToken')
  if (kind === 'password') return t('nfseCityAccessPassword')
  return t('nfseCityAccessNone')
})
const AUTO: Record<AutoIssue, { label: () => string; hint: () => string }> = {
  manual: { label: () => t('nfseAutoIssueManual'), hint: () => t('nfseAutoIssueManualHint') },
  paid: { label: () => t('nfseAutoIssuePaid'), hint: () => t('nfseAutoIssuePaidHint') },
  completed: { label: () => t('nfseAutoIssueCompleted'), hint: () => t('nfseAutoIssueCompletedHint') },
}
const autoIssue = computed<AutoIssue>(() => setup.value?.service?.autoIssue ?? 'manual')
/**
 * The choice on screen (B5): picking (also with the arrow keys) only marks it;
 * "Salvar" saves, and leaving "Só quando eu pedir" asks first, because from
 * then on the server issues notas by itself.
 */
const autoChoice = ref<AutoIssue | null>(null)
const autoPicked = computed<AutoIssue>(() => autoChoice.value ?? autoIssue.value)
const askingAuto = ref(false)
function saveAuto() {
  if (autoPicked.value === autoIssue.value) return
  if (autoIssue.value === 'manual') askingAuto.value = true
  else void chooseAuto(autoPicked.value)
}

function next() {
  const step = nextSetupStep(missing.value)
  if (step === 'fiscalInfo') open.value = 'fiscal'
  else if (step === 'cityAccess') window.open(panelUrl.value, '_blank', 'noopener')
  else if (step === 'service') open.value = 'service'
}

function saved(next: NfseSetup, what: 'fiscal' | 'service') {
  setup.value = next
  open.value = null
  showToast(what === 'fiscal' ? t('nfseFiscalSaved') : t('nfseServiceSaved'))
}

/** nfse.setup.auto-issue: saved at once, with the service as it is. */
async function chooseAuto(value: AutoIssue) {
  askingAuto.value = false
  const service = setup.value?.service
  if (!service || value === autoIssue.value || busy.value) return
  busy.value = true
  try {
    setup.value = await saveService({
      municipalServiceId: service.municipalServiceId ?? null,
      municipalServiceCode: service.municipalServiceCode ?? null,
      municipalServiceName: service.municipalServiceName,
      taxes: service.taxes,
      descriptionTemplate: service.descriptionTemplate,
      autoIssue: value,
    })
    autoChoice.value = null
    showToast(t('web.saved'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

function back() {
  if (window.history.length > 1) router.back()
  else void router.push('/invoices')
}
</script>

<template>
  <div class="finance nfse-setup" data-testid="nfse-setup">
    <PageHead :title="t('nfseRowTitle')" :sub="setup ? (setup.ready ? t('nfseSetupHeadReady') : t('nfseSetupHeadMissing', { count: missing.length })) : undefined">
      <button type="button" class="btn btn--ghost" @click="back">{{ t('back') }}</button>
    </PageHead>
    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :body="failure" :retry="() => load()" />
    <template v-else-if="setup">
      <button v-if="!setup.ready" type="button" class="btn btn--primary nfse-next" :disabled="busy" data-testid="nfse-setup-next" @click="next">{{ t('nfseSetupNext') }}</button>
      <ul class="nfse-steps">
        <li>
          <button type="button" class="nfse-step" data-testid="nfse-step-fiscal" @click="open = 'fiscal'">
            <span>{{ t('nfseSetupFiscalInfo') }}</span>
            <span class="sub"><span class="dot" :class="missing.includes('fiscalInfo') ? 'dot--warning' : 'dot--success'" aria-hidden="true"></span>{{ missing.includes('fiscalInfo') ? t('nfseSetupTodo') : t('nfseSetupDone') }}</span>
          </button>
        </li>
        <li>
          <div class="nfse-step" data-testid="nfse-step-city">
            <span>{{ t('nfseSetupCityAccess') }}</span>
            <span class="sub"><span class="dot" :class="cityAccessDone ? 'dot--success' : 'dot--warning'" aria-hidden="true"></span>{{ cityAccessDone ? t('nfseSetupDone') : t('nfseSetupTodo') }}</span>
          </div>
        </li>
        <li>
          <button type="button" class="nfse-step" data-testid="nfse-step-service" @click="open = 'service'">
            <span>{{ t('nfseSetupService') }}</span>
            <span v-if="setup.service" class="sub">{{ setup.service.municipalServiceName }}</span>
            <span v-else class="sub"><span class="dot dot--warning" aria-hidden="true"></span>{{ t('nfseSetupTodo') }}</span>
          </button>
        </li>
      </ul>
      <fieldset v-if="setup.service" class="nfse-auto" :disabled="busy" data-testid="nfse-auto-issue">
        <legend class="field-label">{{ t('nfseAutoIssueQuestion') }}</legend>
        <label v-for="(item, key) in AUTO" :key="key" class="check-row nfse-auto-row">
          <input class="check" type="radio" name="nfse-auto" :value="key" :checked="autoPicked === key" @change="autoChoice = key" />
          <span>{{ item.label() }}<small class="sub"> · {{ item.hint() }}</small></span>
        </label>
        <p v-if="autoPicked !== autoIssue"><button type="button" class="btn btn--primary" :disabled="busy" data-testid="nfse-auto-save" @click="saveAuto">{{ t('save') }}</button></p>
      </fieldset>
      <section class="nfse-city" aria-labelledby="nfse-city-title">
        <h2 id="nfse-city-title" class="form-section">{{ t('nfseSetupCityAccess') }}</h2>
        <p data-testid="nfse-city-text">{{ cityText }}</p>
        <p v-if="setup.municipalOptions?.supportsCancellation === false" class="sub">{{ t('nfseNoCancelNote') }}</p>
        <p v-if="needsCityAccess" class="row-actions">
          <a class="link" :href="panelUrl" target="_blank" rel="noopener noreferrer" data-testid="nfse-open-panel">{{ t('nfseOpenAsaasPanel') }}</a>
          <button type="button" class="link" :disabled="busy" data-testid="nfse-recheck" @click="load(true)">{{ t('nfseCheckAgain') }}</button>
        </p>
      </section>
    </template>
  </div>
  <ConfirmDialog
    v-if="askingAuto"
    :title="t('web.nfse.autoConfirmTitle')"
    :body="autoPicked === 'paid' ? t('nfseAutoIssuePaidHint') : t('nfseAutoIssueCompletedHint')"
    :confirm="t('web.nfse.autoConfirm')"
    :keep="t('cancel')"
    @confirm="chooseAuto(autoPicked)"
    @close="askingAuto = false"
  />
  <NfseFiscalForm v-if="open === 'fiscal' && setup" :current="setup.fiscalInfo" :options="setup.municipalOptions" @saved="(next) => saved(next, 'fiscal')" @close="open = null" />
  <NfseServiceForm v-if="open === 'service' && setup" :current="setup.service" @saved="(next) => saved(next, 'service')" @close="open = null" />
</template>
