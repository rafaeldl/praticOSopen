<script setup lang="ts">
// The order's payment link (pay.widget.charge-card, charge-changed, charge-section):
// waiting, overdue, installments, owed beyond the link, the order that now owes
// less, the plan the server canceled. "Mandar de novo" sends the Asaas link,
// the same one the customer screen sends (one link for both: defect 7).
// "Manter o link" is kept per charge in this browser (defect 9).
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { formatDate, formatMoney } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { orderTitle } from '@/lib/orders/text'
import { whatsappNumber } from '@/lib/phone'
import { cancelOrderCharge, watchOrderCharges } from '@/lib/receive/data'
import { canceledPlanOf, chargeState, localDay, openChargeOf, whatsappLink, type Charge } from '@/lib/receive/model'
import { loadCustomer } from '@/lib/customers/data'
import { session } from '@/lib/session'
import { readStorage, writeStorage } from '@/lib/storage'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature } from '@/lib/plan-feature-gate'
import ChargeDialog from './ChargeDialog.vue'
import '@/styles/receive.css'

// canCharge false: who only receives (consultant) sees the open link to read, never acts on it (#513, R4).
const props = defineProps<{ order: Order; remaining: number; canCharge: boolean }>()
// open: true (a link is open), false (none), null (not known yet, or the read failed).
const emit = defineEmits<{ open: [open: boolean | null] }>()
const phone = ref(props.order.customer?.phone ?? '')

const BR = 'BR'
const charges = shallowRef<Charge[]>([])
const loaded = ref(false)
/** Neither the channel nor the REST read answered: the error with "Tentar de novo" (M1 of #518). */
const failed = ref(false)
const dialog = ref<null | 'new' | 'cancel'>(null)
const busy = ref(false)
const keptKey = 'praticos.keptCharges'
const kept = ref<string[]>(readKept())
const today = localDay(new Date())

function readKept(): string[] {
  try {
    const value = JSON.parse(readStorage(keptKey) ?? '[]')
    return Array.isArray(value) ? value.filter((id) => typeof id === 'string') : []
  } catch {
    return []
  }
}

const open = computed(() => openChargeOf(charges.value))
const state = computed(() => (open.value ? chargeState(open.value, props.remaining, today) : null))
const canceledPlan = computed(() => (open.value ? null : canceledPlanOf(charges.value, props.remaining)))
const showChanged = computed(() => !!open.value && !!state.value?.changed && !kept.value.includes(open.value.id))
const name = computed(() => props.order.customer?.name ?? '')
// The record's phone, not the copy inside the order (defect 80).
const wa = computed(() => whatsappNumber(phone.value, session.company?.country))
const date = (day: string) => formatDate(`${day}T12:00:00`, BR)
const resend = computed(() => {
  const charge = open.value
  if (!charge?.invoiceUrl) return ''
  const hello = name.value ? t('web.share.msgHello', { name: name.value }) : t('web.share.msgHelloNoName')
  return `${hello} ${t('web.charge.msg', { amount: formatMoney(charge.value, BR), orders: orderTitle(props.order), date: date(charge.dueDate) })}\n${charge.invoiceUrl}`
})

let stop: (() => void) | undefined
let alive = true
/** Until the charges are known, the order screen does not offer Receber in blue. */
async function watchCharges() {
  stop?.()
  failed.value = false
  emit('open', null)
  const next = await watchOrderCharges(
    props.order.id,
    (list) => {
      charges.value = list
      failed.value = false
      emit('open', !!openChargeOf(list))
      loaded.value = true
    },
    {
      onFailed: () => {
        failed.value = true
        emit('open', null)
      },
    },
  )
  if (alive) stop = next
  else next()
}
onMounted(() => {
  if (props.order.customer?.id)
    void loadCustomer(props.order.customer.id)
      .then((detail) => detail.customer.phone && (phone.value = detail.customer.phone))
      .catch(() => {})
  void watchCharges()
})
onBeforeUnmount(() => {
  alive = false
  stop?.()
})

function keep() {
  if (!open.value) return
  kept.value = [...kept.value, open.value.id].slice(-50)
  writeStorage(keptKey, JSON.stringify(kept.value))
}

async function cancel() {
  const charge = open.value
  dialog.value = null
  if (!charge || busy.value) return
  busy.value = true
  try {
    await cancelOrderCharge(props.order.id, charge.id)
    showToast(t('receiveCustomerChargeCanceled'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

/** A new link: Starter (#724); the link already made stays. */
function openNew() {
  if (ensurePlanFeature('charges')) dialog.value = 'new'
}

async function copy() {
  try {
    await navigator.clipboard.writeText(open.value?.invoiceUrl ?? '')
    showToast(t('chargeLinkCopied'))
  } catch {
    showToast(t('web.share.copyFailed'))
  }
}
</script>

<template>
  <section v-if="failed" class="charge-card" role="alert" data-testid="charge-error">
    <p>{{ t('web.charge.loadError') }}</p>
    <button type="button" class="btn btn--small" @click="watchCharges">{{ t('web.tryAgain') }}</button>
  </section>
  <section v-else-if="loaded && (canCharge || open)" class="charge-card" aria-labelledby="od-charge-title" data-testid="order-charge">
    <h3 id="od-charge-title">{{ t('chargeLinkSection') }}</h3>
    <template v-if="open && state">
      <p :class="{ 'is-late': state.expired }" data-testid="charge-state">
        <strong v-if="state.expired">{{ t('chargeExpiredOn', { date: date(open.dueDate) }) }}</strong>
        <template v-else>{{ name ? t('chargeWaitingFor', { customer: name }) : t('chargeWaitingPayment') }}</template>
      </p>
      <p class="sub">
        <template v-if="open.mode === 'cardInstallments' && open.installmentCount">{{ t('chargeInstallmentsUntil', { count: open.installmentCount, date: date(open.dueDate) }) }}</template>
        <template v-else>{{ t('chargeDetailUntil', { value: formatMoney(open.value, BR), date: date(open.dueDate) }) }}</template>
      </p>
      <p v-if="open.paidCount && open.installmentCount" class="sub">{{ t('chargeInstallmentsPaid', { paid: open.paidCount, count: open.installmentCount }) }}</p>
      <p v-if="state.outside" class="sub">{{ t('chargeMissingOutsideLink', { value: formatMoney(state.outside, BR) }) }}</p>
      <div v-if="showChanged && canCharge" class="charge-warn" role="status" data-testid="charge-changed">
        <strong>{{ t('chargeOrderChanged') }}</strong>
        <p>{{ t('chargeNowMissing', { remaining: formatMoney(remaining, BR), value: formatMoney(open.value, BR) }) }}</p>
        <div class="row-actions">
          <button type="button" class="btn btn--small btn--primary" @click="openNew">{{ t('chargeGenerateNew', { value: formatMoney(remaining, BR) }) }}</button>
          <button type="button" class="link" @click="keep">{{ t('chargeKeepLink', { value: formatMoney(open.value, BR) }) }}</button>
        </div>
      </div>
      <div class="row-actions">
        <a v-if="wa && resend" class="btn btn--small" :class="{ 'btn--primary': state.expired && !showChanged }" :href="whatsappLink(wa, resend)" target="_blank" rel="noopener noreferrer" data-testid="charge-resend">{{ t('chargeSendAgainWhatsApp') }}</a>
        <button v-if="open.invoiceUrl" type="button" class="link" @click="copy">{{ t('chargeCopyLink') }}</button>
        <button v-if="canCharge && !open.paidCount" type="button" class="link link--danger" :disabled="busy" data-testid="charge-cancel" @click="dialog = 'cancel'">{{ t('chargeCancelLink') }}</button>
      </div>
    </template>
    <div v-else-if="canceledPlan && canCharge" class="charge-warn" role="status">
      <strong>{{ t('chargeInstallmentsCanceled') }}</strong>
      <p>{{ t('chargeSendNewLink', { value: formatMoney(remaining, BR) }) }}</p>
      <button type="button" class="btn btn--small btn--primary" @click="openNew">{{ t('chargeGenerateNew', { value: formatMoney(remaining, BR) }) }}</button>
    </div>
    <button v-else-if="canCharge && remaining > 0" type="button" class="btn btn--small" data-testid="charge-new" @click="openNew">{{ t('chargeSend') }}</button>
    <ChargeDialog
      v-if="dialog === 'new'"
      :order-id="order.id"
      :orders-text="orderTitle(order)"
      :customer-id="order.customer?.id"
      :customer-name="order.customer?.name"
      :owed="remaining"
      @close="dialog = null"
    />
    <ConfirmDialog
      v-else-if="dialog === 'cancel' && open"
      :title="t('receiveCustomerChargeCancelTitle', { amount: formatMoney(open.value, BR) })"
      :body="t('chargeCancelConfirm')"
      :confirm="t('chargeCancelLink')"
      :keep="t('chargeKeepLink', { value: formatMoney(open.value, BR) })"
      danger
      @confirm="cancel"
      @close="dialog = null"
    />
  </section>
</template>
