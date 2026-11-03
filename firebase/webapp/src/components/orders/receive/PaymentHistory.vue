<script setup lang="ts">
// "Já recebido" (pay.order.view, pay.widget.row): payments and discounts, the
// newest day first, with who registered, how it came in and the proof. Remover
// and Desfazer pagamentos ask first and say the consequence; the Asaas ones and
// the shares of a receipt over several orders cannot leave from here.
import { computed, ref, shallowRef } from 'vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { country, money } from '@/lib/orders/text'
import { canRemove, paymentsOf, undoAllState, type Payment } from '@/lib/receive/model'
import '@/styles/receive.css'

const props = defineProps<{ order: Order; canReceive: boolean; canDiscount: boolean; busy?: boolean }>()
const emit = defineEmits<{ remove: [payment: Payment]; undoAll: [] }>()

const payments = computed(() => paymentsOf(props.order.transactions, props.order.documents ?? []))
const undo = computed(() => undoAllState(payments.value))
const asking = shallowRef<Payment | 'all' | null>(null)
const explain = ref(false)

const METHOD: Record<string, () => string> = {
  pix: () => t('paymentMethodPix'),
  cash: () => t('paymentMethodCash'),
  card: () => t('paymentMethodCard'),
  other: () => t('paymentMethodOther'),
}
function how(payment: Payment): string {
  if (payment.type === 'discount') return t('discount')
  if (payment.isAsaas) {
    const type = (payment.billingType ?? '').toUpperCase()
    if (type === 'PIX') return t('receiveViaPix')
    if (type === 'BOLETO') return t('receiveViaBoleto')
    if (type.includes('CARD')) return t('receiveViaCard')
    return t('receiveViaLink')
  }
  return payment.method && METHOD[payment.method] ? METHOD[payment.method]!() : t('payment')
}
const removable = (payment: Payment) => canRemove(payment) && (payment.type === 'discount' ? props.canDiscount : props.canReceive)

function confirm() {
  const target = asking.value
  asking.value = null
  if (target === 'all') emit('undoAll')
  else if (target) emit('remove', target)
}
</script>

<template>
  <section v-if="payments.length" class="pay-history" aria-labelledby="od-paid-title" data-testid="payment-history">
    <h3 id="od-paid-title">{{ t('receiveAlreadyReceived') }}</h3>
    <ul class="pay-list">
      <li v-for="(payment, index) in payments" :key="payment.id ?? index" class="pay-row" data-testid="payment-row">
        <span class="pay-main">
          <span class="num">{{ payment.type === 'discount' ? '− ' : '' }}{{ money(payment.amount) }}</span>
          <span> · {{ how(payment) }}</span>
          <span class="sub">
            {{ payment.paidOn ? formatDate(payment.paidOn, country()) : '' }}<template v-if="payment.createdBy?.name"> · {{ t('web.receive.by', { name: payment.createdBy.name }) }}</template>
          </span>
          <span v-if="payment.receiptGroupId" class="sub">{{ t('web.receive.partOfReceipt') }}</span>
        </span>
        <span class="pay-acts">
          <a v-if="payment.proofUrl" class="link" :href="payment.proofUrl" target="_blank" rel="noopener noreferrer">{{ t('receiveViewReceipt') }}</a>
          <button v-if="removable(payment)" type="button" class="link link--danger" :disabled="busy" :aria-label="t('web.receive.removeOne', { amount: money(payment.amount) })" @click="asking = payment">
            {{ t('web.receive.remove') }}
          </button>
        </span>
      </li>
    </ul>
    <template v-if="canDiscount && undo !== 'none'">
      <button v-if="undo === 'allowed'" type="button" class="link link--danger" :disabled="busy" data-testid="undo-all" @click="asking = 'all'">{{ t('receiveUndoPayments') }}</button>
      <template v-else>
        <button type="button" class="link" @click="explain = !explain">{{ t('receiveUndoPayments') }}</button>
        <p v-if="explain" class="sub" role="status">{{ t('receiptPartOfGroup') }}</p>
      </template>
    </template>
    <ConfirmDialog
      v-if="asking === 'all'"
      :title="t('receiveUndoPayments')"
      :body="t('web.receive.undoAllBody')"
      :confirm="t('receiveUndoPayments')"
      :keep="t('cancel')"
      danger
      @confirm="confirm"
      @close="asking = null"
    />
    <ConfirmDialog
      v-else-if="asking"
      :title="t('web.receive.removeTitle')"
      :body="t('web.receive.removeBody', { what: how(asking), amount: money(asking.amount) })"
      :confirm="t('web.receive.remove')"
      :keep="t('cancel')"
      danger
      @confirm="confirm"
      @close="asking = null"
    />
  </section>
</template>
