<script setup lang="ts">
// "Termos para o cliente" (company.terms.edit, company.terms.default): one
// text; "Usar texto padrão do segmento" only while empty and when the segment
// has one. Empty saves null, as the app.
import { computed, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { saveCompany } from '@/lib/settings/data'
import { showToast } from '@/lib/toast'
import '@/styles/orders.css'

const props = defineProps<{ terms: string; defaultText: string | null }>()
const emit = defineEmits<{ close: []; saved: [terms: string | null, updatedAt: string] }>()

const text = ref(props.terms)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const saving = ref(false)
const failed = ref('')
let allowClose = false
const dirty = computed(() => text.value !== props.terms)

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  if (saving.value) return
  saving.value = true
  failed.value = ''
  const value = text.value.trim() ? text.value.trim() : null
  try {
    const updatedAt = await saveCompany({ termsOfService: value })
    allowClose = true
    showToast(t('web.company.saved'))
    emit('saved', value, updatedAt)
  } catch (error) {
    console.error('company: terms failed', error)
    failed.value = t('companySettingSaveError')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('customerTerms')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="terms-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('customerTerms') }}</h2>
      </div>
      <div class="drawer-body">
        <p class="sub">{{ t('companyShownOnOrder') }}</p>
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div>
          <label class="field-label" for="tf-terms">{{ t('customerTermsHint') }}</label>
          <textarea id="tf-terms" v-model="text" class="field" rows="12" :placeholder="t('termsOfServicePlaceholder')" data-autofocus></textarea>
        </div>
        <p v-if="!text.trim() && defaultText">
          <button type="button" class="link" data-testid="terms-default" @click="text = defaultText">{{ t('useDefaultTerms') }}</button>
        </p>
      </div>
      <div class="drawer-foot">
        <span class="hint"></span>
        <button type="submit" class="btn btn--primary" :disabled="saving" data-testid="save-terms">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
