<script setup lang="ts">
// First access of someone without a company and without an invite (docs/ONBOARDING.md):
// Ramo → [Especialidades] → Para o cliente → Início, as lib/screens/onboarding/.
// Each step is in the URL (?step=), so the browser's Back goes one step back.
import { computed, defineAsyncComponent, nextTick, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { locale, t } from '@/i18n'
import { companyPhoneMasks, enterCompany, listSegments, saveCompany, seedCompany, waitForClaim } from '@/lib/onboarding/data'
import {
  countryFor,
  localeTag,
  nameMissing,
  orderedPick,
  segmentName,
  subspecialtyName,
  type OnboardingSegment,
} from '@/lib/onboarding/model'
import { readPending, writePending } from '@/lib/onboarding/pending'
import { applyMask } from '@/lib/segment-fields'
import { session, signOutEverywhere } from '@/lib/session'

type Step = 'segment' | 'specialties' | 'business'

// "Recebi um código de convite" (onboarding.segment.have-invite): the same code screen as Sua conta.
const InviteCodeFlow = defineAsyncComponent(() => import('@/components/InviteCodeFlow.vue'))
const codeOpen = ref(false)

const route = useRoute()
const router = useRouter()
const tag = computed(() => localeTag(locale.value))
const country = countryFor(navigator.languages ?? [navigator.language], locale.value)

const segments = ref<OnboardingSegment[]>([])
const segmentsState = ref<'loading' | 'ready' | 'failed'>('loading')
const segment = ref<OnboardingSegment | null>(null)
const picked = ref(new Set<string>())
const name = ref('')
const phone = ref('')
const useFinancial = ref(true)
const showErrors = ref(false)
const status = ref<'editing' | 'saving' | 'failed'>('editing')
const lastWithSamples = ref(true)
const masks = ref<string[]>([])
/** Company saved by an attempt that failed later (or before a reload): the retry completes it. */
let savedId: string | null = null
/** The seed was asked for: its checklists may be in, so the segment cannot change any more. */
const seedTried = ref(false)

const step = computed<Step>(() => {
  const wanted = route.query.step
  if (!segment.value) return 'segment'
  if (wanted === 'business') return 'business'
  if (wanted === 'specialties' && segment.value.subspecialties.length) return 'specialties'
  return 'segment'
})
const ownerName = computed(() => session.name)
const nameError = computed(() => showErrors.value && nameMissing(name.value, ownerName.value))
const previousTitle = computed(() => (segment.value?.subspecialties.length ? t('onboardingSpecialtiesTitle') : t('onboardingSegmentTitle')))

async function loadSegments() {
  segmentsState.value = 'loading'
  try {
    segments.value = await listSegments()
    segmentsState.value = 'ready'
  } catch (error) {
    console.warn('onboarding: segments failed', error)
    segmentsState.value = 'failed'
  }
}

function pick(next: OnboardingSegment) {
  if (segment.value?.id !== next.id) {
    // Specialties all checked (reasonable default); values and billing from the segment.
    picked.value = new Set(next.subspecialties.map((sub) => sub.id))
    useFinancial.value = next.useFinancialDefault
  }
  segment.value = next
  void router.push({ query: { step: next.subspecialties.length ? 'specialties' : 'business' } })
}

function toggle(id: string) {
  const next = new Set(picked.value)
  if (!next.delete(id)) next.add(id)
  picked.value = next
}

const goBusiness = () => void router.push({ query: { step: 'business' } })
const back = () => router.back()

function onPhone(event: Event) {
  const input = event.target as HTMLInputElement
  phone.value = applyMask(input.value, masks.value)
  if (input.value !== phone.value) input.value = phone.value
}

async function create(withSamples: boolean) {
  if (status.value === 'saving' || !segment.value) return
  if (status.value === 'editing' && nameMissing(name.value, ownerName.value)) {
    showErrors.value = true
    void nextTick(() => document.getElementById('ob-name')?.focus())
    return
  }
  lastWithSamples.value = withSamples
  status.value = 'saving'
  try {
    const id = await saveCompany({
      business: { segment: segment.value, subspecialties: orderedPick(segment.value, picked.value), name: name.value, phone: phone.value, useFinancial: useFinancial.value },
      ownerName: ownerName.value,
      country,
      localeTag: tag.value,
      savedId,
    })
    savedId = id
    // A reload from here on continues the same company (the router sends it back here).
    writePending({ uid: session.uid as string, companyId: id, withSamples, localeTag: tag.value, seedTried: seedTried.value })
    await finish(id, withSamples, tag.value)
  } catch (error) {
    console.error('onboarding: company setup failed', error)
    status.value = 'failed'
  }
}

/** Claim, checklists and samples (only now, at the end), then Início. */
async function finish(id: string, withSamples: boolean, localeTag: string) {
  await waitForClaim(id)
  seedTried.value = true
  writePending({ uid: session.uid as string, companyId: id, withSamples, localeTag, seedTried: true })
  await seedCompany(id, withSamples, localeTag)
  await enterCompany(id)
  writePending(null)
  await router.replace('/')
}

/** After a reload: the company exists, the rest goes on with what was chosen then. */
async function resume() {
  const pending = readPending(session.uid)
  if (!pending) return
  savedId = pending.companyId
  seedTried.value = pending.seedTried
  lastWithSamples.value = pending.withSamples
  status.value = 'saving'
  try {
    await finish(pending.companyId, pending.withSamples, pending.localeTag)
  } catch (error) {
    console.error('onboarding: company setup failed', error)
    status.value = 'failed'
  }
}

const retry = () => (segment.value ? create(lastWithSamples.value) : resume())

/** Back from the error goes to the form with what was typed, not to the previous step. */
function backToForm() {
  status.value = 'editing'
}

async function leave() {
  await signOutEverywhere()
}

// A step without its segment (page reloaded) starts over; after the seed was asked for, only the last step stays.
watch(
  () => route.query.step,
  (wanted) => {
    if (wanted && !segment.value) void router.replace({ query: {} })
    else if (seedTried.value && segment.value && wanted !== 'business') void router.replace({ query: { step: 'business' } })
    void nextTick(() => document.querySelector<HTMLElement>('[data-page-title]')?.focus({ preventScroll: true }))
  },
)

onMounted(() => {
  if (readPending(session.uid)) {
    if (route.query.step) void router.replace({ query: {} })
    void resume()
    return
  }
  if (session.companyId) {
    void router.replace('/')
    return
  }
  if (route.query.step) void router.replace({ query: {} })
  void loadSegments()
  companyPhoneMasks(country).then((list) => (masks.value = list)).catch(() => {})
})
</script>

<template>
  <div class="entry">
    <aside class="entry-side"><AppLogo /></aside>
    <main class="entry-main">
      <div v-if="status === 'saving'" class="entry-box" data-testid="onboarding-saving">
        <LoadingState :label="t('onboardingPreparing')" />
      </div>
      <div v-else-if="status === 'failed'" class="entry-box">
        <div class="ob-top">
          <button v-if="segment" type="button" class="link" @click="backToForm">‹ {{ t('onboardingBusinessTitle') }}</button>
        </div>
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.error.title') }}</h1>
        <p role="alert">{{ t('onboardingCreateError') }}</p>
        <button type="button" class="btn btn--primary btn--wide" @click="retry">{{ t('web.tryAgain') }}</button>
      </div>

      <div v-else-if="step === 'segment'" class="entry-box">
        <div class="ob-top">
          <button type="button" class="link" data-testid="onboarding-sign-out" @click="leave">{{ t('logout') }}</button>
        </div>
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('pickSegmentTitle') }}</h1>
        <p class="muted">{{ t('onboardingSegmentHint') }}</p>
        <LoadingState v-if="segmentsState === 'loading'" />
        <ErrorState v-else-if="segmentsState === 'failed'" :body="t('onboardingSegmentsError')" :retry="loadSegments" />
        <EmptyState v-else-if="!segments.length" :title="t('noSegmentsAvailable')">
          <button type="button" class="btn" @click="loadSegments">{{ t('web.tryAgain') }}</button>
        </EmptyState>
        <ul v-else class="ob-list" :aria-label="t('pickSegmentTitle')">
          <li v-for="item in segments" :key="item.id">
            <button type="button" class="choose-row ob-row" :aria-current="item.id === segment?.id ? 'true' : undefined" @click="pick(item)">
              <span class="ob-emoji" aria-hidden="true">{{ item.icon ?? '🔧' }}</span>
              <span class="ob-name">{{ segmentName(item, tag) }}</span>
              <span v-if="item.id === segment?.id" class="ob-check" aria-hidden="true">✓</span>
            </button>
          </li>
        </ul>
        <button type="button" class="link entry-link" data-testid="onboarding-invite-code" @click="codeOpen = true">{{ t('onboardingInviteCode') }}</button>
      </div>

      <div v-else-if="step === 'specialties' && segment" class="entry-box">
        <div class="ob-top">
          <button type="button" class="link" @click="back">‹ {{ t('onboardingSegmentTitle') }}</button>
        </div>
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('pickSpecialtiesTitle') }}</h1>
        <p class="muted">{{ t('onboardingSpecialtiesHint') }}</p>
        <fieldset class="ob-subs">
          <legend class="sr">{{ t('pickSpecialtiesTitle') }}</legend>
          <label v-for="sub in segment.subspecialties" :key="sub.id" class="check-row choose-row ob-row">
            <input class="check" type="checkbox" :checked="picked.has(sub.id)" @change="toggle(sub.id)" />
            <span v-if="sub.icon" class="ob-emoji" aria-hidden="true">{{ sub.icon }}</span>
            <span class="ob-name">{{ subspecialtyName(sub, tag) }}</span>
          </label>
        </fieldset>
        <button type="button" class="btn btn--primary btn--wide" @click="goBusiness">{{ t('onboardingContinue') }}</button>
      </div>

      <form v-else-if="step === 'business' && segment" class="entry-box" novalidate @submit.prevent="create(true)">
        <div class="ob-top">
          <button v-if="!seedTried" type="button" class="link" @click="back">‹ {{ previousTitle }}</button>
        </div>
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('onboardingBusinessTitle') }}</h1>
        <div>
          <label class="field-label" for="ob-name">{{ t('onboardingBusinessName') }}</label>
          <input
            id="ob-name"
            v-model="name"
            class="field"
            autocomplete="organization"
            :placeholder="t('onboardingBusinessNamePlaceholder')"
            :aria-invalid="nameError ? 'true' : undefined"
            :aria-describedby="nameError ? 'ob-name-error' : undefined"
          />
          <p v-if="nameError" id="ob-name-error" class="field-error" role="alert">{{ t('onboardingBusinessNameRequired') }}</p>
        </div>
        <div>
          <label class="field-label" for="ob-phone">{{ t('onboardingPhoneLabel') }}</label>
          <input id="ob-phone" :value="phone" class="field" type="tel" autocomplete="tel" aria-describedby="ob-phone-hint" @input="onPhone" />
          <p id="ob-phone-hint" class="sub field-hint">{{ t('onboardingPhoneHint') }}</p>
        </div>
        <h2 class="ob-section">{{ t('howYouWork') }}</h2>
        <label class="check-row ob-switch">
          <input v-model="useFinancial" class="check" type="checkbox" role="switch" aria-describedby="ob-financial-hint" />
          <span>
            <span class="ob-name">{{ t('valuesAndBilling') }}</span>
            <span id="ob-financial-hint" class="sub ob-block">{{ t('valuesAndBillingHint') }}</span>
          </span>
        </label>
        <p class="muted">{{ t('onboardingSamplesInfo') }}</p>
        <button type="submit" class="btn btn--primary btn--wide">{{ t('onboardingCreate') }}</button>
        <button type="button" class="link entry-link" @click="create(false)">{{ t('onboardingStartWithoutSamples') }}</button>
      </form>
    </main>
  </div>
  <InviteCodeFlow v-if="codeOpen" @close="codeOpen = false" />
</template>

<style scoped>
.ob-top { min-height: 2.75rem; display: flex; align-items: center; }
.ob-top .link { min-height: 2.75rem; }
.ob-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.5rem; }
.ob-subs { border: 0; margin: 0; padding: 0; display: grid; gap: 0.5rem; }
.ob-row { display: flex; align-items: center; gap: 0.75rem; width: 100%; min-height: 3rem; cursor: pointer; }
.ob-emoji { font-size: 1.25rem; line-height: 1; }
.ob-name { font-weight: 600; overflow-wrap: anywhere; }
.ob-check { margin-left: auto; color: var(--color-accent); font-weight: 700; }
.ob-section { font-size: 0.8125rem; font-weight: 600; color: var(--color-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 0.5rem; }
.ob-switch { align-items: flex-start; min-height: 2.75rem; }
.ob-block { display: block; }
</style>
