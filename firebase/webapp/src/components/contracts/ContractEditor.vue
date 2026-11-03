<script setup lang="ts">
// "Repetir" of an order (contract.config.*, order.contract.enable). A drawer:
// how often, start, end, and whether the order is born by itself, saved with
// "Salvar" (the app writes each change at once). On an active contract:
// "Pausar" and "Parar de repetir"; on a paused one: "Retomar". Stopping keeps
// the contract in Encerrados with its history (the app erases it, defect 62).
// "Avisar antes" is not offered: nothing reads it, in the app or here.
// The web never creates the order itself: the app or the server do.
import { computed, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import RepeatFields, { type RepeatForm } from './RepeatFields.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { ContractChanged, saveContract, startContract, type ContractOrder } from '@/lib/contracts/data'
import { dayOf, newContract, pauseChanges, resumeChanges, scheduleChanges, stateOf, stopChanges, type ContractPatch } from '@/lib/contracts/model'
import { contractsTitle, stateText } from '@/lib/contracts/text'
import { toIsoDay } from '@/lib/format'
import { orderShort } from '@/lib/orders/text'
import { isMac } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import { wallText } from '@/lib/zone'

const props = defineProps<{ order: ContractOrder }>()
const emit = defineEmits<{ saved: []; close: [] }>()

const layer = ref<InstanceType<typeof Layer> | null>(null)
const today = toIsoDay(new Date())
const current = ref(props.order)
const contract = computed(() => (current.value.isContract ? current.value.contract : null))
const state = computed(() => (contract.value ? stateOf(contract.value) : null))
const formOf = (): RepeatForm => {
  const c = contract.value
  return c
    ? { repeat: { frequency: c.frequency ?? 'monthly', interval: c.interval }, startDay: c.startDate ? dayOf(c.startDate) : today, endDay: c.endDate ? dayOf(c.endDate) : null, autoGenerate: c.autoGenerate }
    : { repeat: { frequency: 'monthly', interval: 1 }, startDay: today, endDay: null, autoGenerate: true }
}
const form = ref<RepeatForm>(formOf())
const initial = ref(JSON.stringify(form.value))
const saving = ref(false)
const failed = ref('')
const confirmStop = ref(false)
let allowClose = false

const dirty = computed(() => JSON.stringify(form.value) !== initial.value)
const title = computed(() => t('orderRepeatRow'))
const who = computed(() => [current.value.customer?.name, current.value.number ? `${orderShort()} ${current.value.number}` : ''].filter(Boolean).join(' · '))
const line = computed(() => (contract.value ? stateText(contract.value, today) : null))
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

function done(message: string) {
  allowClose = true
  showToast(message)
  announce(message)
  emit('saved')
}

async function run(work: () => Promise<void>, message: string) {
  if (saving.value) return
  saving.value = true
  failed.value = ''
  try {
    await work()
    done(message)
  } catch (error) {
    if (error instanceof ContractChanged) {
      // What is there now replaces the form: never written over in silence.
      current.value = error.current
      form.value = formOf()
      initial.value = JSON.stringify(form.value)
      failed.value = t('web.contracts.changed')
    } else {
      console.warn('contracts: not saved', error)
      failed.value = `${t('web.contracts.saveFailed')} ${t(errorMessageKey(error))}`
    }
  } finally {
    saving.value = false
  }
}

function save() {
  const c = contract.value
  if (!c) {
    void run(() => startContract(current.value.id, newContract(form.value, today)), t('web.contracts.started'))
    return
  }
  const patch: ContractPatch = scheduleChanges(c, form.value, today)
  if (!Object.keys(patch).length) {
    allowClose = true
    layer.value?.close()
    return
  }
  void run(() => saveContract(current.value, patch), t('web.contracts.saved'))
}

const pause = () => run(() => saveContract(current.value, pauseChanges(wallText(new Date()))), t('web.contracts.pausedToast'))
const resume = () => contract.value && run(() => saveContract(current.value, resumeChanges(contract.value!, today)), t('web.contracts.resumedToast'))
function stop() {
  confirmStop.value = false
  if (contract.value) void run(() => saveContract(current.value, stopChanges(contract.value!, today)), t('web.contracts.stoppedToast'))
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    save()
  }
}

function guard(): boolean {
  if (allowClose || !dirty.value) return true
  const ok = window.confirm(`${t('orderDiscardTitle')}\n${t('orderDiscardMessage')}`)
  if (ok) allowClose = true
  return ok
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="contract-editor" novalidate @submit.prevent="save" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
        <span class="muted small">{{ who }}</span>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert" data-testid="contract-error">{{ failed }}</p>
        <p v-if="line" class="contract-state" :class="`contract-state--${line.tone}`" data-testid="contract-state">{{ line.text }}</p>
        <template v-if="state !== 'ended'">
          <RepeatFields v-model="form" id-prefix="ce" :today="today" :last-generated="contract?.lastGeneratedDate" />
          <p class="sub field-hint">{{ t('web.contracts.webNeverCreates', { order: orderShort(), title: contractsTitle() }) }}</p>
        </template>
        <div v-if="state === 'active' || state === 'paused'" class="contract-actions">
          <h3 class="form-section">{{ t('web.contracts.pauseOrStop') }}</h3>
          <p class="sub">{{ t('web.contracts.pauseHint', { order: orderShort() }) }}</p>
          <div class="row-actions">
            <button v-if="state === 'active'" type="button" class="btn" data-testid="contract-pause" :aria-disabled="saving" @click="pause">{{ t('web.contracts.pause') }}</button>
            <button v-else type="button" class="btn" data-testid="contract-resume" :aria-disabled="saving" @click="resume">{{ t('web.contracts.resume') }}</button>
            <button type="button" class="btn btn--danger" data-testid="contract-stop" :aria-disabled="saving" @click="confirmStop = true">{{ t('contractStopRepeating') }}</button>
          </div>
        </div>
      </div>
      <div v-if="state !== 'ended'" class="drawer-foot">
        <span class="hint"></span>
        <button type="submit" class="btn btn--primary" :aria-disabled="saving" data-testid="contract-save">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
  <ConfirmDialog
    v-if="confirmStop"
    :title="t('contractStopRepeatingTitle')"
    :body="`${t('contractStopRepeatingMessage')} ${t('web.contracts.stopKeeps')}`"
    :confirm="t('contractStopRepeating')"
    :keep="t('cancel')"
    danger
    @confirm="stop"
    @close="confirmStop = false"
  />
</template>
