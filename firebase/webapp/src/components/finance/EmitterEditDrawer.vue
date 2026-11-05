<script setup lang="ts">
// One line of the emitter (NFS-e direct, spec §4.7): "Serviço da nota" (name,
// national code of 6 digits, ISS), "Inscrição municipal" (empty removes it) or
// "Estilo da descrição" (capitals and separator, with a sample).
import { computed, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { formatNumber } from '@/lib/format'
import { SEPARATORS, stylePreview, updateEmitter, type Emitter } from '@/lib/nfse/direct'
import { parsePercent } from '@/lib/nfse/model'
import { country } from '@/lib/orders/text'

export type EmitterField = 'service' | 'registration' | 'style'

const props = defineProps<{ emitter: Emitter; field: EmitterField }>()
const emit = defineEmits<{ close: []; saved: [] }>()

const service = props.emitter.service
const name = ref(service?.name ?? '')
const code = ref(service?.nationalCode ?? '')
const iss = ref(service?.issRate ? formatNumber(service.issRate, country()) : '')
const registration = ref(props.emitter.municipalRegistration ?? '')
const uppercase = ref(props.emitter.descriptionStyle.uppercase)
const separator = ref(props.emitter.descriptionStyle.separator)
const saving = ref(false)
const failed = ref('')
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const snapshot = () => JSON.stringify([name.value, code.value, iss.value, registration.value, uppercase.value, separator.value])
const initial = snapshot()
const dirty = computed(() => snapshot() !== initial)

const title = computed(() =>
  props.field === 'service' ? t('nfseDirectServiceRow') : props.field === 'registration' ? t('nfseDirectRegistrationRow') : t('nfseDirectStyleRow'),
)
const issValue = computed(() => (iss.value.trim() ? parsePercent(iss.value) : 0))
const valid = computed(() => {
  if (props.field === 'service') return !!name.value.trim() && /^\d{6}$/.test(code.value.trim()) && issValue.value !== null
  return dirty.value
})
const sample = computed(() =>
  stylePreview({ uppercase: uppercase.value, separator: separator.value }, [t('nfseDirectSampleService1'), t('nfseDirectSampleService2')]),
)

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  if (saving.value || !valid.value) return
  saving.value = true
  failed.value = ''
  try {
    if (props.field === 'service') {
      await updateEmitter(props.emitter.id, {
        service: { name: name.value.trim(), nationalCode: code.value.trim(), issRate: issValue.value ?? 0, municipalCode: service?.municipalCode ?? null, nbs: service?.nbs ?? null },
      })
    } else if (props.field === 'registration') {
      await updateEmitter(props.emitter.id, { municipalRegistration: registration.value.trim() || null })
    } else {
      await updateEmitter(props.emitter.id, { descriptionStyle: { uppercase: uppercase.value, separator: separator.value } })
    }
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
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="emitter-edit-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <template v-if="field === 'service'">
          <div>
            <label class="field-label" for="em-name">{{ t('nfseDirectServiceName') }}</label>
            <input id="em-name" v-model="name" class="field" maxlength="200" :placeholder="t('nfseDirectServiceNamePlaceholder')" data-autofocus />
          </div>
          <div>
            <label class="field-label" for="em-code">{{ t('nfseDirectServiceCode') }}</label>
            <input id="em-code" v-model="code" class="field" inputmode="numeric" maxlength="6" placeholder="140101" data-testid="emitter-service-code" />
            <p class="field-hint">{{ t('nfseDirectServiceCodeHint') }}</p>
          </div>
          <div>
            <label class="field-label" for="em-iss">{{ t('nfseIss') }}</label>
            <input id="em-iss" v-model="iss" class="field" inputmode="decimal" placeholder="0" :aria-invalid="issValue === null" />
            <p v-if="issValue === null" class="field-error">{{ t('web.nfse.percentInvalid') }}</p>
          </div>
        </template>
        <div v-else-if="field === 'registration'">
          <label class="field-label" for="em-reg">{{ t('nfseDirectRegistrationRow') }}</label>
          <input id="em-reg" v-model="registration" class="field" maxlength="20" pattern="[A-Za-z0-9./-]*" data-autofocus />
          <p class="field-hint">{{ t('nfseDirectRegistrationHint') }}</p>
        </div>
        <template v-else>
          <label class="check-row">
            <input v-model="uppercase" class="check" type="checkbox" />
            <span>{{ t('nfseDirectStyleUppercase') }}</span>
          </label>
          <fieldset>
            <legend class="field-label">{{ t('nfseDirectSeparatorQuestion') }}</legend>
            <label v-for="option in SEPARATORS" :key="option" class="check-row">
              <input v-model="separator" class="check" type="radio" name="em-sep" :value="option" />
              <span>{{ stylePreview({ uppercase, separator: option }, [t('nfseDirectSampleService1'), t('nfseDirectSampleService2')]) }}</span>
            </label>
          </fieldset>
          <p class="sub">{{ t('nfseDirectStyleSample', { sample }) }}</p>
        </template>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ valid || field !== 'service' ? '' : t('nfseDirectServiceMissing') }}</span>
        <button type="submit" class="btn btn--primary" :disabled="saving || !valid" data-testid="emitter-edit-save">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
