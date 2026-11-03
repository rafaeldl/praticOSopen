<script setup lang="ts">
// "Nome, logo e contato" (company.data.edit, company.data.logo,
// company.data.country, company.data.discard). Unlike the app: the logo waits
// for "Salvar" like the rest, e-mail and site are checked, the phone mask
// follows the country chosen here, the country list is complete and in the
// person's language, and closing with changes asks first.
import { computed, onBeforeUnmount, reactive, ref } from 'vue'
import { Building2, Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { applyMask, fieldMasks, segmentField } from '@/lib/segment-fields'
import { saveCompany, uploadLogo, type CompanyDoc } from '@/lib/settings/data'
import { companyFields, companyProblems, countryOptions, regionCodes, type CompanyData } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'
import '@/styles/orders.css'

const props = defineProps<{ company: CompanyDoc }>()
const emit = defineEmits<{ close: []; saved: [fields: Partial<CompanyDoc>] }>()

const form = reactive<CompanyData>({
  name: props.company.name ?? '',
  phone: props.company.phone ?? '',
  address: props.company.address ?? '',
  email: props.company.email ?? '',
  site: props.company.site ?? '',
  country: props.company.country ?? '',
})
const initial = JSON.stringify(form)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const tried = ref(false)
const saving = ref(false)
const failed = ref('')
const logoFile = ref<File | null>(null)
const logoPreview = ref<string | null>(null)
const logoError = ref('')
const more = ref(!!(props.company.email || props.company.site || props.company.country))
let allowClose = false

const countries = computed(() => countryOptions(locale.value, regionCodes()))
const problems = computed(() => companyProblems(form))
const dirty = computed(() => JSON.stringify(form) !== initial || !!logoFile.value)
// company.phone of the segment (global), by the country chosen in this form.
const masks = computed(() => fieldMasks(segmentField('company.phone'), form.country || null))
const shownLogo = computed(() => logoPreview.value ?? props.company.logo ?? null)

function onPhone(event: Event) {
  const input = event.target as HTMLInputElement
  form.phone = applyMask(input.value, masks.value)
  if (input.value !== form.phone) input.value = form.phone
}

function onCountry() {
  // A new country brings its mask right away (the app keeps the saved country's).
  if (form.phone) form.phone = applyMask(form.phone, masks.value)
}

function chooseLogo(file: File | undefined) {
  logoError.value = ''
  if (!file) return
  if (!/^image\/(jpeg|png|webp)$/.test(file.type) || file.size > 10 * 1024 * 1024) {
    logoError.value = t('web.company.logoInvalid')
    return
  }
  if (logoPreview.value) URL.revokeObjectURL(logoPreview.value)
  logoFile.value = file
  logoPreview.value = URL.createObjectURL(file)
}

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  tried.value = true
  if (problems.value.length || saving.value) {
    if (problems.value.includes('email') || problems.value.includes('site')) more.value = true
    return
  }
  saving.value = true
  failed.value = ''
  try {
    const fields = companyFields(form)
    await saveCompany(fields)
    let logo: string | undefined
    if (logoFile.value) logo = await uploadLogo(logoFile.value)
    allowClose = true
    showToast(t('web.company.saved'))
    emit('saved', { ...fields, ...(logo ? { logo } : {}) })
  } catch (error) {
    console.error('company: save failed', error)
    failed.value = errorMessageKey(error) === 'web.error.generic' ? t('companySettingSaveError') : t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
    event.preventDefault()
    void save()
  }
}

onBeforeUnmount(() => {
  if (logoPreview.value) URL.revokeObjectURL(logoPreview.value)
})
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('companyNameLogoContact')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="company-form" novalidate @submit.prevent="save()" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('companyNameLogoContact') }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div class="logo-row" @dragover.prevent @drop.prevent="chooseLogo($event.dataTransfer?.files[0])">
          <span class="logo-box">
            <img v-if="shownLogo" :src="shownLogo" :alt="t('web.company.logoAlt')" data-testid="company-logo" />
            <Building2 v-else :size="40" aria-hidden="true" />
          </span>
          <div class="set-section">
            <label class="btn">
              {{ shownLogo ? t('changeLogoLink') : t('addLogo') }}
              <input class="sr" type="file" accept="image/jpeg,image/png,image/webp" data-testid="company-logo-file" aria-describedby="cf-logo-hint" @change="chooseLogo(($event.target as HTMLInputElement).files?.[0])" />
            </label>
            <p id="cf-logo-hint" class="sub field-hint">{{ t('web.company.logoHint') }}</p>
            <p v-if="logoError" class="field-error" role="alert">{{ logoError }}</p>
          </div>
        </div>
        <div>
          <label class="field-label" for="cf-name">{{ t('name') }}</label>
          <input id="cf-name" v-model="form.name" class="field" autocomplete="organization" :placeholder="t('companyNamePlaceholder')" :aria-invalid="tried && problems.includes('name')" data-autofocus />
          <p v-if="tried && problems.includes('name')" class="field-error">{{ t('companyNameRequired') }}</p>
        </div>
        <div>
          <label class="field-label" for="cf-phone">{{ t('phone') }}</label>
          <input id="cf-phone" :value="form.phone" class="field" type="tel" inputmode="tel" autocomplete="tel" @input="onPhone" />
        </div>
        <div>
          <label class="field-label" for="cf-address">{{ t('address') }}</label>
          <textarea id="cf-address" v-model="form.address" class="field" rows="3" :placeholder="t('fullAddress')"></textarea>
        </div>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('moreCompanyData') }}</summary>
          <div class="more-body">
            <div>
              <label class="field-label" for="cf-email">{{ t('email') }}</label>
              <input id="cf-email" v-model="form.email" class="field" type="email" autocomplete="email" :placeholder="t('companyEmailPlaceholder')" :aria-invalid="tried && problems.includes('email')" />
              <p v-if="tried && problems.includes('email')" class="field-error">{{ t('invalidEmail') }}</p>
            </div>
            <div>
              <label class="field-label" for="cf-site">{{ t('website') }}</label>
              <input id="cf-site" v-model="form.site" class="field" type="url" inputmode="url" autocomplete="url" :placeholder="t('websitePlaceholder')" :aria-invalid="tried && problems.includes('site')" />
              <p v-if="tried && problems.includes('site')" class="field-error">{{ t('web.company.invalidSite') }}</p>
            </div>
            <div>
              <label class="field-label" for="cf-country">{{ t('country') }}</label>
              <select id="cf-country" v-model="form.country" class="field" data-testid="company-country" @change="onCountry">
                <option value="">{{ t('web.company.noCountry') }}</option>
                <option v-for="item in countries" :key="item.code" :value="item.code">{{ item.name }}</option>
              </select>
            </div>
          </div>
        </details>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ !form.name.trim() ? t('companyNameRequired') : '' }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !form.name.trim() }" :disabled="saving" data-testid="save-company">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
