<script setup lang="ts">
// "Dados fiscais da empresa" (nfse.setup.fiscal, nfse.setup.fiscal-regime):
// e-mail, inscrição municipal, CNAE, Simples Nacional and, only when the city
// uses them, the special regime ("Nenhum" takes it out) and the service list
// item. Saved in Asaas through the server, which answers the new setup.
import { computed, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { saveFiscalInfo } from '@/lib/nfse/data'
import { isEmail, type CityOptions, type FiscalInfo, type NfseSetup } from '@/lib/nfse/model'

const props = defineProps<{ current: FiscalInfo | null; options: CityOptions | null }>()
const emit = defineEmits<{ close: []; saved: [setup: NfseSetup] }>()

const email = ref(props.current?.email ?? '')
const inscription = ref(props.current?.municipalInscription ?? '')
const cnae = ref(props.current?.cnae ?? '')
const listItem = ref(props.current?.serviceListItem ?? '')
// Simples Nacional starts on, as the app.
const simples = ref(props.current?.simplesNacional ?? true)
const regime = ref(props.current?.specialTaxRegime ?? '')
const regimes = computed(() => (props.options?.usesSpecialTaxRegimes ? (props.options.specialTaxRegimesList ?? []) : []))
const valid = computed(() => isEmail(email.value))
const saving = ref(false)
const failed = ref('')
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false
const initial = JSON.stringify([email.value, inscription.value, cnae.value, listItem.value, simples.value, regime.value])
const dirty = computed(() => JSON.stringify([email.value, inscription.value, cnae.value, listItem.value, simples.value, regime.value]) !== initial)

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  if (saving.value || !valid.value) return
  saving.value = true
  failed.value = ''
  const text = (value: string) => value.trim() || undefined
  try {
    const setup = await saveFiscalInfo({
      email: email.value.trim(),
      simplesNacional: simples.value,
      municipalInscription: text(inscription.value),
      cnae: text(cnae.value),
      ...(regimes.value.length ? { specialTaxRegime: regime.value || undefined } : {}),
      ...(props.options?.usesServiceListItem ? { serviceListItem: text(listItem.value) } : {}),
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
  <Layer ref="layer" kind="drawer" :label="t('nfseSetupFiscalInfo')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="nfse-fiscal-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('nfseSetupFiscalInfo') }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div>
          <label class="field-label" for="nf-email">{{ t('nfseFiscalEmail') }}</label>
          <input id="nf-email" v-model="email" class="field" type="email" autocomplete="email" maxlength="200" data-autofocus />
        </div>
        <div>
          <label class="field-label" for="nf-inscription">{{ t('nfseFiscalMunicipalInscription') }}</label>
          <input id="nf-inscription" v-model="inscription" class="field" inputmode="numeric" maxlength="30" />
        </div>
        <div>
          <label class="field-label" for="nf-cnae">{{ t('nfseFiscalCnae') }}</label>
          <input id="nf-cnae" v-model="cnae" class="field" inputmode="numeric" maxlength="12" />
        </div>
        <div v-if="options?.usesServiceListItem">
          <label class="field-label" for="nf-list-item">{{ t('nfseFiscalServiceListItem') }}</label>
          <input id="nf-list-item" v-model="listItem" class="field" maxlength="20" />
        </div>
        <label class="check-row">
          <input v-model="simples" class="check" type="checkbox" />
          <span>{{ t('nfseFiscalSimples') }}</span>
        </label>
        <div v-if="regimes.length">
          <label class="field-label" for="nf-regime">{{ t('nfseFiscalSpecialRegimeQuestion') }}</label>
          <select id="nf-regime" v-model="regime" class="field">
            <option value="">{{ t('none') }}</option>
            <option v-for="item in regimes" :key="item.value" :value="item.value">{{ item.label }}</option>
          </select>
        </div>
        <p class="field-hint">{{ t('nfseFiscalNote') }}</p>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ valid ? '' : t('nfseFiscalEmailMissing') }}</span>
        <button type="submit" class="btn btn--primary" :disabled="saving || !valid" data-testid="nfse-fiscal-save">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
