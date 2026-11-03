<script setup lang="ts">
// Sua empresa (company.settings.*, company.data.*, company.terms.*): what the
// customer sees on the order, and how the company works. Owner and admin only
// (manageCompany). Switches change at once, lock while saving and go back with
// a notice if the write fails. Turning "Valores e cobrança" off asks first and
// hides money everywhere right away (session.company, no reload). Changing the
// segment asks first: the specialties of the old one go away.
import { computed, onMounted, ref, shallowRef } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import CompanyDataForm from '@/components/settings/CompanyDataForm.vue'
import TermsForm from '@/components/settings/TermsForm.vue'
import { locale, t, type MessageKey } from '@/i18n'
import { segmentLabels } from '@/lib/segments'
import { loadCompany, loadSegments, saveCompany, type CompanyDoc } from '@/lib/settings/data'
import { defaultTerms, localName, type SegmentOption } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/settings.css'

type Feature = 'useFinancial' | 'useScheduling' | 'fieldService' | 'useContracts' | 'useDeviceManagement'

const company = shallowRef<CompanyDoc | null>(null)
const failed = ref(false)
const segments = shallowRef<SegmentOption[] | null>(null)
const segmentsFailed = ref(false)
const saving = ref(false)
const editing = ref<'data' | 'terms' | 'segment' | 'specialties' | null>(null)
const askingOff = ref(false)
const pickedSegment = ref('')
const askingSegment = ref(false)
const pickedSpecialties = ref<string[]>([])

const segment = computed(() => segments.value?.find((item) => item.id === company.value?.segment) ?? null)
const segmentName = computed(() => (segment.value ? localName(segment.value, locale.value) : ''))
const specialtyNames = computed(() => {
  const checked = company.value?.subspecialties ?? []
  return (segment.value?.subspecialties ?? []).filter((sub) => checked.includes(sub.id)).map((sub) => localName(sub, locale.value))
})
const sortedSegments = computed(() => [...(segments.value ?? [])].sort((a, b) => localName(a, locale.value).localeCompare(localName(b, locale.value), locale.value)))
const devicesPlural = computed(() => segmentLabels()['device._entity_plural'])

/** As the app reads them: useFinancial absent is on; the rest absent is off. */
const value = (feature: Feature): boolean => (feature === 'useFinancial' ? company.value?.useFinancial !== false : company.value?.[feature] === true)

const switches = computed(() => {
  const list: { feature: Feature; title: string; sub: MessageKey }[] = [
    { feature: 'useFinancial', title: t('valuesAndBilling'), sub: 'valuesAndBillingHint' },
    { feature: 'useScheduling', title: t('schedulingRow'), sub: 'schedulingRowHint' },
    { feature: 'fieldService', title: t('fieldServiceRow'), sub: 'fieldServiceRowHint' },
    { feature: 'useContracts', title: t('contracts'), sub: 'contractsRowHint' },
  ]
  // "Controle de veículos" only when the segment names its devices (my_company_screen).
  if (devicesPlural.value) list.push({ feature: 'useDeviceManagement', title: t('deviceControlRow', { devices: devicesPlural.value.toLowerCase() }), sub: 'deviceControlRowHint' })
  return list
})

async function load() {
  failed.value = false
  company.value = null
  try {
    company.value = await loadCompany()
  } catch (error) {
    console.error('company: load failed', error)
    failed.value = true
  }
  void readSegments()
}

async function readSegments() {
  segmentsFailed.value = false
  try {
    segments.value = await loadSegments()
  } catch (error) {
    console.error('company: segments failed', error)
    segmentsFailed.value = true
  }
}

function merge(fields: Partial<CompanyDoc>) {
  if (company.value) company.value = { ...company.value, ...fields }
}

/** Changes at once; locked while saving; back as it was if the write fails. */
async function setFeature(feature: Feature, next: boolean) {
  if (saving.value || !company.value) return
  const previous = company.value[feature]
  saving.value = true
  merge({ [feature]: next })
  try {
    merge({ updatedAt: await saveCompany({ [feature]: next }) })
    announce(t(next ? 'web.company.turnedOn' : 'web.company.turnedOff', { name: switches.value.find((item) => item.feature === feature)?.title ?? '' }))
  } catch (error) {
    console.error('company: switch failed', error)
    merge({ [feature]: previous })
    showToast(feature === 'useFinancial' ? t('valuesAndBillingSaveError') : t('companySettingSaveError'))
  } finally {
    saving.value = false
  }
}

function onSwitch(feature: Feature, event: Event) {
  const input = event.target as HTMLInputElement
  const next = input.checked
  // The box shows the saved value until the write (or the question) decides.
  input.checked = value(feature)
  if (feature === 'useFinancial' && !next) {
    askingOff.value = true
    return
  }
  void setFeature(feature, next)
}

function turnOffValues() {
  askingOff.value = false
  void setFeature('useFinancial', false)
}

function openSegment() {
  pickedSegment.value = company.value?.segment ?? ''
  editing.value = 'segment'
}

async function changeSegment() {
  askingSegment.value = false
  const id = pickedSegment.value
  editing.value = null
  if (!id || id === company.value?.segment) return
  saving.value = true
  try {
    // A new segment clears the specialties of the previous one, as the app.
    const updatedAt = await saveCompany({ segment: id, subspecialties: null })
    merge({ segment: id, subspecialties: null, updatedAt })
    showToast(t('web.company.segmentChanged'))
  } catch (error) {
    console.error('company: segment failed', error)
    showToast(t('companySettingSaveError'))
  } finally {
    saving.value = false
  }
}

function openSpecialties() {
  pickedSpecialties.value = [...(company.value?.subspecialties ?? [])]
  editing.value = 'specialties'
}

async function saveSpecialties() {
  const ids = pickedSpecialties.value
  editing.value = null
  saving.value = true
  try {
    const updatedAt = await saveCompany({ subspecialties: ids.length ? ids : null })
    merge({ subspecialties: ids.length ? ids : null, updatedAt })
    showToast(t('web.company.saved'))
  } catch (error) {
    console.error('company: specialties failed', error)
    showToast(t('companySettingSaveError'))
  } finally {
    saving.value = false
  }
}

/** Someone saved meanwhile: the next edit starts from their version (no loading screen). */
async function refresh() {
  try {
    company.value = await loadCompany()
  } catch (error) {
    console.warn('company: refresh failed', error)
  }
}

function saved(fields: Partial<CompanyDoc>) {
  editing.value = null
  merge(fields)
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.company.title') }}</h1>
      <p class="page-sub">{{ t('web.company.lead') }}</p>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!company && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="company">
        <section aria-labelledby="co-order" class="set-section">
          <h2 id="co-order" class="set-h">{{ t('companyShownOnOrder') }}</h2>
          <ul class="set-list">
            <li>
              <button type="button" class="set-row" data-testid="company-data" @click="editing = 'data'">
                <span class="set-avatar" aria-hidden="true"><img v-if="company.logo" :src="company.logo" alt="" /><template v-else>{{ (company.name || '?').charAt(0).toUpperCase() }}</template></span>
                <span class="set-text">
                  <span class="who">{{ company.name || t('companyData') }}</span>
                  <span class="sub">{{ t('companyNameLogoContact') }}</span>
                </span>
              </button>
            </li>
            <li>
              <button type="button" class="set-row" data-testid="company-terms" @click="editing = 'terms'">
                <span class="set-text">
                  <span class="who">{{ t('customerTerms') }}</span>
                  <span class="sub">{{ t('customerTermsHint') }}</span>
                </span>
              </button>
            </li>
          </ul>
        </section>

        <section aria-labelledby="co-work" class="set-section">
          <h2 id="co-work" class="set-h">{{ t('howYouWork') }}</h2>
          <ul class="set-list">
            <li>
              <button type="button" class="set-row" data-testid="company-segment" :disabled="!segments" @click="openSegment">
                <span class="set-text">
                  <span class="who">{{ t('segmentRow') }}</span>
                  <span class="sub">{{ t('segmentRowHint') }}</span>
                </span>
                <span class="set-end">{{ segmentName }}</span>
              </button>
              <p v-if="segmentsFailed" class="field-error" role="alert">
                {{ t('web.company.segmentsFailed') }} <button type="button" class="link" @click="readSegments">{{ t('web.tryAgain') }}</button>
              </p>
            </li>
            <li v-if="segment?.subspecialties.length">
              <button type="button" class="set-row" data-testid="company-specialties" @click="openSpecialties">
                <span class="set-text">
                  <span class="who">{{ t('specialties') }}</span>
                  <span class="sub">{{ specialtyNames.length ? specialtyNames.join(', ') : t('specialtiesNone') }}</span>
                </span>
              </button>
            </li>
            <li v-for="item in switches" :key="item.feature">
              <label class="set-switch" :data-testid="`company-${item.feature}`">
                <span class="set-text">
                  <span class="who">{{ item.title }}</span>
                  <span class="sub">{{ t(item.sub) }}</span>
                </span>
                <input type="checkbox" role="switch" :checked="value(item.feature)" :disabled="saving" @change="onSwitch(item.feature, $event)" />
              </label>
            </li>
          </ul>
        </section>
      </template>
    </div>
  </div>

  <CompanyDataForm v-if="editing === 'data' && company" :company="company" @saved="saved" @stale="refresh" @close="editing = null" />
  <TermsForm
    v-if="editing === 'terms' && company"
    :terms="company.termsOfService ?? ''"
    :default-text="defaultTerms(segment, locale)"
    @saved="(terms, updatedAt) => saved({ termsOfService: terms, updatedAt })"
    @close="editing = null"
  />
  <Layer v-if="editing === 'segment'" kind="dialog" :label="t('pickSegmentTitle')" @close="editing = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('pickSegmentTitle') }}</h2>
      </div>
      <div class="layer-body">
        <fieldset style="border: 0; margin: 0; padding: 0; min-width: 0">
          <legend class="sr">{{ t('pickSegmentTitle') }}</legend>
          <ul class="picker-list" data-testid="segment-list">
            <li v-for="item in sortedSegments" :key="item.id">
              <label class="check-row">
                <input v-model="pickedSegment" type="radio" name="co-segment" :value="item.id" />
                <span>{{ localName(item, locale) }}</span>
              </label>
            </li>
          </ul>
        </fieldset>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" :disabled="!pickedSegment || pickedSegment === company?.segment" data-testid="segment-save" @click="askingSegment = true">{{ t('save') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="askingSegment"
    :title="t('web.company.segmentTitle')"
    :body="t('web.company.segmentBody')"
    :confirm="t('web.company.segmentConfirm')"
    :keep="t('cancel')"
    @confirm="changeSegment"
    @close="askingSegment = false"
  />
  <Layer v-if="editing === 'specialties' && segment" kind="dialog" :label="t('pickSpecialtiesTitle')" @close="editing = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('pickSpecialtiesTitle') }}</h2>
      </div>
      <div class="layer-body">
        <fieldset style="border: 0; margin: 0; padding: 0; min-width: 0">
          <legend class="sr">{{ t('pickSpecialtiesTitle') }}</legend>
          <ul class="picker-list" data-testid="specialty-list">
            <li v-for="sub in segment.subspecialties" :key="sub.id">
              <label class="check-row">
                <input v-model="pickedSpecialties" class="check" type="checkbox" :value="sub.id" />
                <span>{{ localName(sub, locale) }}</span>
              </label>
            </li>
          </ul>
        </fieldset>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" data-testid="specialties-save" @click="saveSpecialties">{{ t('save') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="askingOff"
    :title="t('valuesAndBillingOffTitle')"
    :body="t('valuesAndBillingOffMessage')"
    :confirm="t('valuesAndBillingOffAction')"
    :keep="t('cancel')"
    danger
    @confirm="turnOffValues"
    @close="askingOff = false"
  />
</template>
