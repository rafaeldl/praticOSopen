<script setup lang="ts">
// "Adicionar CNPJ" / "Trocar certificado" (NFS-e direct, spec §4.2): the A1
// file (dragged in or chosen), its password and the terms. "Enviar" turns
// blue with a file, a password and the terms accepted (checkbox); the server checks the certificate and a
// refusal comes back as a plain sentence. The password lives only in this
// form and in the request: it is cleared after sending and never stored.
import { computed, ref, shallowRef } from 'vue'
import { Check, FileUp, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { certificateFileProblem, uploadCertificate } from '@/lib/nfse/direct'

const props = defineProps<{ emitterId?: string | null; legalName?: string }>()
const emit = defineEmits<{ close: []; saved: [] }>()

// The certificate terms (version TERMS_VERSION in lib/nfse/direct.ts), in the user's language.
const TERMS_URLS = {
  pt: 'https://praticos.app/termo-certificado.html',
  en: 'https://praticos.app/termo-certificado-en.html',
  es: 'https://praticos.app/termo-certificado-es.html',
} as const
const termsUrl = computed(() => TERMS_URLS[locale.value] ?? TERMS_URLS.pt)
const accepted = ref(false)
const file = shallowRef<File | null>(null)
const password = ref('')
const failed = ref('')
const saving = ref(false)
const dragging = ref(false)
const input = ref<HTMLInputElement | null>(null)
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const replace = computed(() => !!props.emitterId)
const ready = computed(() => !!file.value && password.value.length > 0 && accepted.value)

function take(picked: File | null | undefined) {
  if (!picked) return
  const problem = certificateFileProblem(picked)
  file.value = problem ? null : picked
  failed.value = problem ? t('nfseDirectErrorInvalidFile') : ''
}

function onDrop(event: DragEvent) {
  dragging.value = false
  take(event.dataTransfer?.files?.[0])
}

function guard(): boolean {
  if (allowClose || saving.value || (!file.value && !password.value)) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function send() {
  if (saving.value || !ready.value || !file.value) return
  saving.value = true
  failed.value = ''
  try {
    await uploadCertificate(file.value, password.value, props.emitterId)
    password.value = ''
    allowClose = true
    emit('saved')
  } catch (error) {
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="replace ? t('nfseDirectReplaceTitle') : t('nfseDirectAddCnpjTitle')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="certificate-form" novalidate @submit.prevent="send()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ replace ? t('nfseDirectReplaceTitle') : t('nfseDirectAddCnpjTitle') }}</h2>
      </div>
      <div class="drawer-body">
        <p>{{ replace ? t('nfseDirectReplaceIntro', { name: legalName ?? '' }) : t('nfseDirectAddCnpjIntro') }}</p>
        <div
          class="cert-drop"
          :class="{ 'is-over': dragging, 'has-file': !!file }"
          data-testid="certificate-drop"
          @dragover.prevent="dragging = true"
          @dragleave="dragging = false"
          @drop.prevent="onDrop"
        >
          <FileUp :size="22" aria-hidden="true" />
          <p v-if="file" class="cert-file" data-testid="certificate-file"><Check :size="14" aria-hidden="true" /> {{ file.name }}</p>
          <p v-else>{{ t('web.nfseDirect.dropHere') }}</p>
          <button type="button" class="btn" @click="input?.click()">{{ t('nfseDirectPickFile') }}</button>
          <input ref="input" class="sr" type="file" accept=".pfx,.p12,application/x-pkcs12" :aria-label="t('nfseDirectCertificateFile')" @change="take(($event.target as HTMLInputElement).files?.[0])" />
        </div>
        <div>
          <label class="field-label" for="cert-password">{{ t('nfseDirectCertificatePassword') }}</label>
          <input id="cert-password" v-model="password" class="field" type="password" autocomplete="off" maxlength="200" data-testid="certificate-password" @input="failed = ''" />
          <p class="field-hint">{{ t('nfseDirectCertificatePasswordHint') }}</p>
        </div>
        <p v-if="failed" class="field-error" role="alert" data-testid="certificate-error">{{ failed }}</p>
        <p class="sub">
          {{ t('nfseDirectTerms') }}
          <a class="link" :href="termsUrl" target="_blank" rel="noopener noreferrer" data-testid="certificate-terms-link">{{ t('nfseDirectTermsLink') }}</a>
        </p>
        <label class="check-row">
          <input v-model="accepted" class="check" type="checkbox" data-testid="certificate-accept" />
          <span>{{ t('nfseDirectAcceptTerms') }}</span>
        </label>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ ready ? '' : t('nfseDirectUploadMissing') }}</span>
        <button type="submit" class="btn btn--primary" :disabled="saving || !ready" data-testid="certificate-send">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('web.nfseDirect.send') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
